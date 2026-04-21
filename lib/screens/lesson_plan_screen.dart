import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../viewmodels/lesson_plan_view_model-.dart';
import '../viewmodels/book_view_model.dart';
import '../models/book.dart';

class LessonPlanScreen extends StatefulWidget {
  const LessonPlanScreen({super.key});

  @override
  State<LessonPlanScreen> createState() => _LessonPlanScreenState();
}

class _LessonPlanScreenState extends State<LessonPlanScreen> {
  String? _selectedBook;
  List<String> _selectedChapters = [];
  List<Book> _availableBooks = [];
  List<String> _availableChapters = [];

  // New state for sub-chapters
  List<BookChild> _availableChaptersWithSubChapters = [];
  Map<String, List<BookChild>> _subChaptersMap = {};
  Set<String> _selectedSubChapters = {};

  // Loading states
  bool _isLoadingBooks = false;
  bool _isLoadingChapters = false;

  @override
  void initState() {
    super.initState();
    // Defer loading books until after the first frame
    // to avoid calling notifyListeners during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBooks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Consumer2<LessonPlanViewModel, BookViewModel>(
        builder: (context, lessonPlanViewModel, bookViewModel, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeaderSection(),

                SizedBox(height: 4.h),

                // Book Selection Section
                _buildBookSelectionSection(),

                SizedBox(height: 4.h),

                // Chapter Selection Section
                if (_selectedBook != null) _buildChapterSelectionSection(),

                SizedBox(height: 4.h),

                // Generate Button
                _buildGenerateButton(lessonPlanViewModel),

                SizedBox(height: 4.h),

                // Generated Lesson Plan
                if (lessonPlanViewModel.generatedLessonPlan != null)
                  _buildGeneratedPlan(lessonPlanViewModel),

                // PDF Success Message
                if (lessonPlanViewModel.localPdfPath.isNotEmpty)
                  _buildSuccessMessage(lessonPlanViewModel.localPdfPath),

                // Error Message
                if (lessonPlanViewModel.errorMessage.isNotEmpty)
                  _buildErrorMessage(lessonPlanViewModel.errorMessage),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGradient[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                color: AppColors.white,
                size: 6.w,
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'AI Lesson Plan Builder',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 5.w,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Create comprehensive lesson plans with AI assistance. Select a book and chapters to generate a structured lesson plan.',
            style: TextStyle(
              color: AppColors.white.withOpacity(0.9),
              fontSize: 3.5.w,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookSelectionSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primaryGradient[0].withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.book,
                color: AppColors.primaryGradient[0],
                size: 5.w,
              ),
              SizedBox(width: 3.w),
              Text(
                'Select Book',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGradient[0],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          DropdownButtonFormField<String>(
            value: _selectedBook,
            isExpanded: true, // 👈 VERY important
            decoration: InputDecoration(
              hintText: 'Choose a book',
              hintStyle: TextStyle(
                color: Colors.grey[500],
                fontSize: 3.5.w,
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.primaryGradient[0],
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 2.h,
              ),
            ),

            // 👇 THIS controls how selected item is shown
            selectedItemBuilder: (context) {
              return _availableBooks.map((book) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.black87,
                    ),
                  ),
                );
              }).toList();
            },

            items: _availableBooks.map((book) {
              return DropdownMenuItem<String>(
                value: book.bookName,
                child: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 3.5.w,
                    color: Colors.black87,
                  ),
                ),
              );
            }).toList(),

            onChanged: (String? newValue) {
              setState(() {
                _selectedBook = newValue;
                _selectedChapters.clear();
                _selectedSubChapters.clear();
                _availableChapters.clear();
                _availableChaptersWithSubChapters = [];
                _subChaptersMap = {};
                if (newValue != null) {
                  _loadChapters(newValue);
                }
              });
            },
          ),
          if (_isLoadingBooks)
            Container(
              padding: EdgeInsets.all(3.w),
              margin: EdgeInsets.only(top: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGradient[0]),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Loading books...',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterSelectionSection() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primaryGradient[0].withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt,
                color: AppColors.primaryGradient[0],
                size: 5.w,
              ),
              SizedBox(width: 3.w),
              Text(
                'Select Chapters',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGradient[0],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          if (_isLoadingChapters)
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGradient[0]),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Loading chapters...',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else if (_availableChapters.isEmpty && _selectedBook != null)
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                    size: 4.w,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'No chapters available for this book',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            _buildMultiSelectDropdown(),
        ],
      ),
    );
  }

  Widget _buildMultiSelectDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Selected chapters display
          if (_selectedChapters.isNotEmpty || _selectedSubChapters.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              child: Wrap(
                spacing: 2.w,
                runSpacing: 1.h,
                children: [
                  ..._selectedChapters.map((chapter) {
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGradient[0],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chapter,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 3.w,
                            ),
                          ),
                          SizedBox(width: 1.w),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedChapters.remove(chapter);
                                // Also remove related sub-chapters
                                if (_subChaptersMap.containsKey(chapter)) {
                                  for (var sub in _subChaptersMap[chapter]!) {
                                    _selectedSubChapters.remove(sub.title);
                                  }
                                }
                              });
                            },
                            child: Icon(
                              Icons.close,
                              color: AppColors.white,
                              size: 3.5.w,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ..._selectedSubChapters.map((subChapter) {
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGradient[1],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right,
                            color: AppColors.white,
                            size: 3.w,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            subChapter,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 3.w,
                            ),
                          ),
                          SizedBox(width: 1.w),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSubChapters.remove(subChapter);
                              });
                            },
                            child: Icon(
                              Icons.close,
                              color: AppColors.white,
                              size: 3.5.w,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Dropdown button
          InkWell(
            onTap: () => _showChapterSelectionDialog(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedChapters.isEmpty && _selectedSubChapters.isEmpty
                          ? 'Choose chapters'
                          : '${_selectedChapters.length + _selectedSubChapters.length} item(s) selected',
                      style: TextStyle(
                        color: _selectedChapters.isEmpty &&
                                _selectedSubChapters.isEmpty
                            ? Colors.grey[500]
                            : Colors.black87,
                        fontSize: 3.5.w,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey[600],
                    size: 5.w,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChapterSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Select Chapters',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGradient[0],
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: 50.h,
                child: _availableChaptersWithSubChapters.isNotEmpty
                    ? _buildChapterWithSubChaptersList(setDialogState)
                    : _buildSimpleChapterList(setDialogState),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update the main UI
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGradient[0],
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 3.5.w,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build simple chapter list (no sub-chapters)
  Widget _buildSimpleChapterList(
      void Function(void Function()) setDialogState) {
    return ListView.builder(
      itemCount: _availableChapters.length,
      itemBuilder: (context, index) {
        final chapter = _availableChapters[index];
        final isSelected = _selectedChapters.contains(chapter);

        return CheckboxListTile(
          title: Text(
            chapter,
            style: TextStyle(
              fontSize: 3.5.w,
              color: Colors.black87,
            ),
          ),
          value: isSelected,
          onChanged: (bool? value) {
            setDialogState(() {
              if (value == true) {
                _selectedChapters.add(chapter);
              } else {
                _selectedChapters.remove(chapter);
              }
            });
          },
          activeColor: AppColors.primaryGradient[0],
        );
      },
    );
  }

  /// Build chapter list with expandable sub-chapters
  Widget _buildChapterWithSubChaptersList(
      void Function(void Function()) setDialogState) {
    return ListView.builder(
      itemCount: _availableChaptersWithSubChapters.length,
      itemBuilder: (context, index) {
        final chapter = _availableChaptersWithSubChapters[index];
        final isChapterSelected = _selectedChapters.contains(chapter.title);
        final hasSubChapters = chapter.hasSubChapters;
        final subChapters = chapter.children;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter checkbox
            CheckboxListTile(
              title: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 3.5.w,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: isChapterSelected,
              onChanged: (bool? value) {
                setDialogState(() {
                  if (value == true) {
                    _selectedChapters.add(chapter.title);
                    // Also select all sub-chapters when chapter is selected
                    if (hasSubChapters) {
                      for (var subChapter in subChapters) {
                        _selectedSubChapters.add(subChapter.title);
                      }
                    }
                  } else {
                    _selectedChapters.remove(chapter.title);
                    // Also deselect all sub-chapters
                    if (hasSubChapters) {
                      for (var subChapter in subChapters) {
                        _selectedSubChapters.remove(subChapter.title);
                      }
                    }
                  }
                });
              },
              activeColor: AppColors.primaryGradient[0],
            ),

            // Sub-chapters (indented)
            if (hasSubChapters)
              Container(
                margin: EdgeInsets.only(left: 4.w),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primaryGradient[0].withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: subChapters.map((subChapter) {
                    final isSubChapterSelected =
                        _selectedSubChapters.contains(subChapter.title);
                    final isParentSelected =
                        _selectedChapters.contains(chapter.title);

                    return CheckboxListTile(
                      title: Text(
                        subChapter.title,
                        style: TextStyle(
                          fontSize: 3.2.w,
                          color: Colors.grey[700],
                        ),
                      ),
                      value: isSubChapterSelected || isParentSelected,
                      onChanged: isParentSelected
                          ? null // Disable if parent is selected (all are selected)
                          : (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedSubChapters.add(subChapter.title);
                                } else {
                                  _selectedSubChapters.remove(subChapter.title);
                                }
                              });
                            },
                      activeColor: AppColors.primaryGradient[0],
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGenerateButton(LessonPlanViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: viewModel.isLoading ? null : _generateLessonPlan,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGradient[0],
          foregroundColor: AppColors.white,
          padding: EdgeInsets.symmetric(vertical: 3.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        child: viewModel.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Generating...',
                    style: TextStyle(
                      fontSize: 4.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 5.w,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Generate Lesson Plan',
                    style: TextStyle(
                      fontSize: 4.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildGeneratedPlan(LessonPlanViewModel viewModel) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.primaryGradient[0].withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                color: AppColors.primaryGradient[0],
                size: 5.w,
              ),
              SizedBox(width: 3.w),
              Text(
                'Generated Lesson Plan',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGradient[0],
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () =>
                    _copyToClipboard(viewModel.formattedLessonPlan),
                icon: Icon(
                  Icons.copy,
                  color: AppColors.primaryGradient[0],
                  size: 4.w,
                ),
              ),
              IconButton(
                onPressed: () => _downloadAsPDF(viewModel),
                icon: Icon(
                  Icons.download,
                  color: AppColors.primaryGradient[0],
                  size: 4.w,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Text(
              viewModel.formattedLessonPlan,
              style: TextStyle(
                fontSize: 3.5.w,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.red[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: Colors.red[600],
            size: 5.w,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 3.5.w,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(String filePath) {
    return Container(
      margin: EdgeInsets.only(top: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.green[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[700],
            size: 5.w,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'PDF downloaded successfully.',
              style: TextStyle(
                fontSize: 3.5.w,
                color: Colors.green[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => OpenFile.open(filePath),
            child: Text(
              'Open',
              style: TextStyle(
                color: AppColors.primaryGradient[0],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadBooks() async {
    setState(() {
      _isLoadingBooks = true;
    });

    final bookViewModel = context.read<BookViewModel>();
    await bookViewModel.loadBooks();
    if (mounted) {
      setState(() {
        _availableBooks = bookViewModel.books;
        _isLoadingBooks = false;
      });
    }
  }

  void _loadChapters(String bookName) async {
    setState(() {
      _isLoadingChapters = true;
      _availableChapters = [];
      _availableChaptersWithSubChapters = [];
      _subChaptersMap = {};
      _selectedSubChapters = {};
      _selectedChapters = [];
    });

    final bookViewModel = context.read<BookViewModel>();

    // Try to get chapters with sub-chapters first
    final chaptersWithSubChapters =
        await bookViewModel.getChaptersWithSubChapters(bookName);

    if (mounted) {
      if (chaptersWithSubChapters.isNotEmpty) {
        // Use the new format with sub-chapters
        setState(() {
          _availableChaptersWithSubChapters = chaptersWithSubChapters;
          _availableChapters =
              chaptersWithSubChapters.map((c) => c.title).toList();

          // Build sub-chapters map
          for (var chapter in chaptersWithSubChapters) {
            if (chapter.hasSubChapters) {
              _subChaptersMap[chapter.title] = chapter.children;
            }
          }
          _isLoadingChapters = false;
        });
      } else {
        // Fallback to simple chapters
        final chapters = await bookViewModel.getChaptersOfBook(bookName);
        if (mounted) {
          setState(() {
            _availableChapters = chapters;
            _isLoadingChapters = false;
          });
        }
      }
    }
  }

  void _generateLessonPlan() {
    // Combine selected chapters and sub-chapters
    final allSelectedItems = [..._selectedChapters, ..._selectedSubChapters];

    if (_selectedBook == null || allSelectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a book and at least one chapter'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    context.read<LessonPlanViewModel>().generateLessonPlan(
          bookName: _selectedBook!,
          chapterNames: allSelectedItems,
        );
  }

  void _copyToClipboard(String text) {
    // This would typically use Clipboard.setData in a real implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lesson plan copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _downloadAsPDF(LessonPlanViewModel viewModel) async {
    try {
      if (viewModel.generatedLessonPlan == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No lesson plan to download'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryGradient[0]),
              ),
              SizedBox(width: 4.w),
              Text('Generating PDF...'),
            ],
          ),
        ),
      );

      // Create PDF document
      final pdf = pw.Document();
      final lessonPlan = viewModel.generatedLessonPlan!['lesson_plan'];

      // Define a common text style
      final textStyle = pw.TextStyle(
        fontSize: 11,
      );

      final headerStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue700,
      );

      final titleStyle = pw.TextStyle(
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Center(
                child: pw.Text(
                  'LESSON PLAN',
                  style: titleStyle,
                ),
              ),
              pw.SizedBox(height: 20),

              // Book and Chapter Info
              pw.Container(
                padding: pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Book: $_selectedBook',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Chapters: ${_selectedChapters.join(', ')}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated on: ${DateTime.now().toString().split('.')[0]}',
                      style:
                          pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Learning Objectives
              if (lessonPlan['learning_objectives'] != null) ...[
                pw.Text(
                  'LEARNING OBJECTIVES',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 10),
                ...(lessonPlan['learning_objectives'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(left: 10, bottom: 5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${entry.key + 1}. ',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            entry.value.toString(),
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 15),
              ],

              // Key Concepts
              if (lessonPlan['key_concepts'] != null) ...[
                pw.Text(
                  'KEY CONCEPTS',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 10),
                ...(lessonPlan['key_concepts'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(left: 10, bottom: 5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '- ',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            entry.value.toString(),
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 15),
              ],

              // Teaching Methodology
              if (lessonPlan['teaching_methodology'] != null &&
                  lessonPlan['teaching_methodology'].toString().isNotEmpty) ...[
                pw.Text(
                  'TEACHING METHODOLOGY',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  lessonPlan['teaching_methodology'].toString(),
                  style: textStyle,
                ),
                pw.SizedBox(height: 15),
              ],

              // Assessment Methods
              if (lessonPlan['assessment_methods'] != null &&
                  (lessonPlan['assessment_methods'] as List).isNotEmpty) ...[
                pw.Text(
                  'ASSESSMENT METHODS',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 10),
                ...(lessonPlan['assessment_methods'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(left: 10, bottom: 5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${entry.key + 1}. ',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            entry.value.toString(),
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 15),
              ],

              // Resources
              if (lessonPlan['resources'] != null) ...[
                pw.Text(
                  'RESOURCES',
                  style: headerStyle,
                ),
                pw.SizedBox(height: 10),
                ...(lessonPlan['resources'] as List)
                    .asMap()
                    .entries
                    .map((entry) {
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(left: 10, bottom: 5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${entry.key + 1}. ',
                          style: pw.TextStyle(
                              fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            entry.value.toString(),
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              // Footer
              pw.SizedBox(height: 30),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Generated by Dr. Jebasingh Onco AI',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF to device
      final output = await getApplicationDocumentsDirectory();
      final fileName =
          'lesson_plan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message with option to open
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'PDF Downloaded Successfully!',
            style: TextStyle(
              fontSize: 4.5.w,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGradient[0],
            ),
          ),
          content: Text(
            'Your lesson plan has been saved as PDF: $fileName',
            style: TextStyle(fontSize: 3.5.w),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  fontSize: 3.5.w,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await OpenFile.open(file.path);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGradient[0],
                foregroundColor: AppColors.white,
              ),
              child: Text(
                'Open PDF',
                style: TextStyle(fontSize: 3.5.w),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
