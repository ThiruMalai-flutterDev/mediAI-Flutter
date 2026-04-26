import 'package:dr_jebasingh_onco_ai/models/api_response.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../theme/app_colors.dart';
import '../viewmodels/lesson_plan_view_model.dart';
import '../viewmodels/book_view_model.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../models/lesson_plan.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/url_services.dart';

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

  // Calendar state
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showCreationFlow = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // Defer loading books until after the first frame
    // to avoid calling notifyListeners during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBooks();
        context.read<LessonPlanViewModel>().fetchAllData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LessonPlanViewModel, BookViewModel>(
      builder: (context, lessonPlanViewModel, bookViewModel, child) {
        return Column(
          children: [
            _buildCustomHeader(lessonPlanViewModel),
            Expanded(
              child: _showCreationFlow
                  ? _buildCreationFlow(lessonPlanViewModel)
                  : _buildCalendarView(lessonPlanViewModel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomHeader(LessonPlanViewModel viewModel) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      color: AppColors.white,
      child: Row(
        children: [
          if (_showCreationFlow)
            IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primaryGradient[0]),
              onPressed: () => setState(() => _showCreationFlow = false),
            ),
          Expanded(
            child: Text(
              _showCreationFlow ? 'Create Lesson Plan' : 'Lesson Planner',
              style: TextStyle(
                color: AppColors.primaryGradient[0],
                fontWeight: FontWeight.bold,
                fontSize: 5.w,
              ),
              textAlign: _showCreationFlow ? TextAlign.center : TextAlign.start,
            ),
          ),
          if (!_showCreationFlow)
            TextButton.icon(
              onPressed: () => setState(() => _showCreationFlow = true),
              icon: Icon(Icons.add, color: AppColors.primaryGradient[0]),
              label: Text(
                'Create',
                style: TextStyle(color: AppColors.primaryGradient[0]),
              ),
            ),
          if (_showCreationFlow)
            const SizedBox(width: 48), // Balance for back button
        ],
      ),
    );
  }

  Widget _buildCalendarView(LessonPlanViewModel viewModel) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildCalendar(viewModel),
              const Divider(),
              _buildLessonPlanList(viewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreationFlow(LessonPlanViewModel lessonPlanViewModel) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book Selection Section
              _buildBookSelectionSection(),

              SizedBox(height: 4.h),

              // Chapter Selection Section
              if (_selectedBook != null) _buildChapterSelectionSection(),

              SizedBox(height: 4.h),

              // Date Selection Section
              if (_selectedBook != null)
                _buildDateSelectionSection(lessonPlanViewModel),

              SizedBox(height: 4.h),

              // Generate Button
              _buildGenerateButton(lessonPlanViewModel),

              SizedBox(height: 4.h),

              // Generated Lesson Plan
              if (lessonPlanViewModel.generatedLessonPlan != null)
                _buildGeneratedPlan(lessonPlanViewModel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(LessonPlanViewModel viewModel) {
    return TableCalendar<dynamic>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      eventLoader: (day) {
        return _getEventsForDay(day, viewModel.lessonPlans);
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: BoxDecoration(
          color: AppColors.primaryGradient[0],
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.primaryGradient[0].withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: AppColors.primaryGradient[1],
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonDecoration: BoxDecoration(
          color: AppColors.primaryGradient[0],
          borderRadius: BorderRadius.circular(20),
        ),
        formatButtonTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  List<dynamic> _getEventsForDay(
      DateTime day, List<LessonPlan> allPlans) {
    final List<dynamic> events = [];

    // Add lesson plans
    events.addAll(allPlans.where((plan) {
      if (plan.fromDate.isEmpty || plan.toDate.isEmpty) return false;
      try {
        final from = DateTime.parse(plan.fromDate);
        final to = DateTime.parse(plan.toDate);
        
        // Use dates without time for comparison
        final checkDay = DateTime(day.year, day.month, day.day);
        final fromDay = DateTime(from.year, from.month, from.day);
        final toDay = DateTime(to.year, to.month, to.day);
        
        return (checkDay.isAfter(fromDay) || checkDay.isAtSameMomentAs(fromDay)) &&
               (checkDay.isBefore(toDay) || checkDay.isAtSameMomentAs(toDay));
      } catch (e) {
        return false;
      }
    }));


    return events;
  }

  Widget _buildLessonPlanList(LessonPlanViewModel viewModel) {
    final events = _getEventsForDay(
        _selectedDay ?? _focusedDay, viewModel.lessonPlans);

    if (events.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 12.w, color: Colors.grey[300]),
            SizedBox(height: 2.h),
            Text(
              'No lesson plans for this day',
              style: TextStyle(color: Colors.grey[500], fontSize: 4.w),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event is LessonPlan) {
          return _buildPlanItem(event, viewModel);
        }
        return const SizedBox.shrink();
      },
    );
  }


  Widget _buildPlanItem(LessonPlan plan, LessonPlanViewModel viewModel) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(
          plan.bookName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${plan.chapterName}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editLessonPlanDates(plan, viewModel),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => viewModel.deleteLessonPlan(plan.id!),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: ${plan.fromDate} to ${plan.toDate}'),
                SizedBox(height: 1.h),
                if (plan.content != null) ...[
                  const Text('Content:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(plan.content!),
                ],
                if (plan.pdfUrl != null)
                  ElevatedButton.icon(
                    onPressed: () => _openPdf(plan.pdfUrl!),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('View PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGradient[0],
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editLessonPlanDates(
      LessonPlan plan, LessonPlanViewModel viewModel) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.parse(plan.fromDate),
        end: DateTime.parse(plan.toDate),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      await viewModel.updateLessonPlanDates(plan.id!, picked.start, picked.end);
    }
  }

  Future<void> _openPdf(String url) async {
    final fullUrl =
        url.startsWith('http') ? url : '${UrlServices.BASE_URL}$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $fullUrl')),
        );
      }
    }
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

  Widget _buildDateSelectionSection(LessonPlanViewModel viewModel) {
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
                Icons.calendar_today,
                color: AppColors.primaryGradient[0],
                size: 5.w,
              ),
              SizedBox(width: 3.w),
              Text(
                'Select Date Range',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGradient[0],
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  label: 'From Date',
                  selectedDate: viewModel.fromDate,
                  onTap: () => _selectDate(context, viewModel, true),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _buildDatePicker(
                  label: 'To Date',
                  selectedDate: viewModel.toDate,
                  onTap: () => _selectDate(context, viewModel, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 3.w,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              selectedDate != null
                  ? DateFormat('MMM dd, yyyy').format(selectedDate)
                  : 'Select Date',
              style: TextStyle(
                fontSize: 3.5.w,
                color: selectedDate != null ? Colors.black87 : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, LessonPlanViewModel viewModel,
      bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFromDate ? viewModel.fromDate : viewModel.toDate) ??
          DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      confirmText: 'Done',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.borderFocus,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.borderFocus, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isFromDate) {
        viewModel.setDateRange(picked, viewModel.toDate);
      } else {
        viewModel.setDateRange(viewModel.fromDate, picked);
      }
    }
  }

  Widget _buildSavedPlansSection(LessonPlanViewModel viewModel) {
    if (viewModel.lessonPlans.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.w),
          child: Text(
            'Saved Lesson Plans',
            style: TextStyle(
              fontSize: 4.5.w,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGradient[0],
            ),
          ),
        ),
        SizedBox(height: 2.h),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: viewModel.lessonPlans.length,
          itemBuilder: (context, index) {
            final plan = viewModel.lessonPlans[index];
            return Container(
              margin: EdgeInsets.only(bottom: 2.h),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.bookName,
                          style: TextStyle(
                            fontSize: 4.w,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue, size: 5.w),
                        onPressed: () =>
                            _showEditDatesDialog(context, viewModel, plan),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red, size: 5.w),
                        onPressed: () =>
                            _confirmDelete(context, viewModel, plan),
                      ),
                    ],
                  ),
                  Text(
                    plan.chapterName,
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.5.h),
                  Row(
                    children: [
                      Icon(Icons.date_range,
                          size: 4.w, color: Colors.grey[400]),
                      SizedBox(width: 2.w),
                      Text(
                        '${plan.fromDate} to ${plan.toDate}',
                        style: TextStyle(
                          fontSize: 3.w,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showEditDatesDialog(
      BuildContext context, LessonPlanViewModel viewModel, LessonPlan plan) {
    DateTime from = DateTime.parse(plan.fromDate);
    DateTime to = DateTime.parse(plan.toDate);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Dates'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDatePicker(
                    label: 'From Date',
                    selectedDate: from,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: from.isBefore(DateTime(2020))
                            ? DateTime(2020)
                            : (from.isAfter(DateTime(2030))
                                ? DateTime(2030)
                                : from),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        confirmText: 'Done',
                        cancelText: 'Cancel',
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.borderFocus,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.borderFocus,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => from = picked);
                      }
                    },
                  ),
                  SizedBox(height: 2.h),
                  _buildDatePicker(
                    label: 'To Date',
                    selectedDate: to,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: to.isBefore(DateTime(2020))
                            ? DateTime(2020)
                            : (to.isAfter(DateTime(2030))
                                ? DateTime(2030)
                                : to),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        confirmText: 'Done',
                        cancelText: 'Cancel',
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppColors.borderFocus,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.borderFocus,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => to = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    viewModel.updateLessonPlanDates(plan.id!, from, to);
                    Navigator.pop(context);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, LessonPlanViewModel viewModel, LessonPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Lesson Plan'),
        content: Text('Are you sure you want to delete this lesson plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteLessonPlan(plan.id!);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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
              // IconButton(
              //   onPressed: () =>
              //       _copyToClipboard(viewModel.formattedLessonPlan),
              //   icon: Icon(
              //     Icons.copy,
              //     color: AppColors.primaryGradient[0],
              //     size: 4.w,
              //   ),
              // ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.formattedLessonPlan,
                  style: TextStyle(
                    fontSize: 3.5.w,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                if (viewModel.hasPdf) ...[
                  SizedBox(height: 2.h),
                  const Divider(),
                  SizedBox(height: 1.h),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadAsPDF(viewModel),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Lesson Plan PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGradient[0],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
    final viewModel = context.read<LessonPlanViewModel>();

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

    if (viewModel.fromDate == null || viewModel.toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a date range'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final book = _availableBooks.firstWhere((b) => b.bookName == _selectedBook);

    // Find IDs for selected items
    List<String> chapterIds = [];
    for (var chapterTitle in _selectedChapters) {
      final chapter = book.children.firstWhere((c) => c.title == chapterTitle,
          orElse: () => BookChild(id: '', title: '', type: ''));
      if (chapter.id.isNotEmpty) chapterIds.add(chapter.id);
    }

    List<String> subChapterIds = [];
    for (var subTitle in _selectedSubChapters) {
      // Search in all chapters' children
      for (var chapter in book.children) {
        final sub = chapter.children.firstWhere((s) => s.title == subTitle,
            orElse: () => BookChild(id: '', title: '', type: ''));
        if (sub.id.isNotEmpty) {
          subChapterIds.add(sub.id);
          break;
        }
      }
    }

    viewModel
        .generateLessonPlan(
      bookId: _selectedBook!,
      bookName: book.title,
      chapterNames: allSelectedItems,
      chapterIds: chapterIds,
    )
        .then((_) {
      if (viewModel.errorMessage.isEmpty) {
        // STAY ON SCREEN - Don't set _showCreationFlow to false
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Lesson plan generated successfully! Scroll down to view.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
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

      // State variables for download tracking
      ValueNotifier<int> downloadedBytesNotifier = ValueNotifier(0);
      ValueNotifier<int> totalBytesNotifier = ValueNotifier(0);
      ValueNotifier<String> statusNotifier = ValueNotifier('Preparing...');

      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Downloading Lesson Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 2.h),

                // Status message
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (context, status, _) => Text(
                    status,
                    style: TextStyle(
                      fontSize: 3.5.w,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGradient[0],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 2.h),

                // Progress bar
                ValueListenableBuilder<int>(
                  valueListenable: downloadedBytesNotifier,
                  builder: (context, downloaded, _) {
                    return ValueListenableBuilder<int>(
                      valueListenable: totalBytesNotifier,
                      builder: (context, total, _) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: total > 0 ? downloaded / total : 0,
                                minHeight: 8,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryGradient[0],
                                ),
                              ),
                            ),

                            SizedBox(height: 1.5.h),

                            // Progress percentage and size
                            Text(
                              total > 0
                                  ? '${(downloaded / total * 100).toStringAsFixed(0)}% - ${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB / ${(total / 1024 / 1024).toStringAsFixed(2)} MB'
                                  : 'Initializing...',
                              style: TextStyle(
                                fontSize: 3.w,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        ),
      );

      // Call appropriate API based on whether we already have a pdf_url
      ApiResponse response;
      if (viewModel.pdfUrl.isNotEmpty) {
        response = await ApiService.downloadPdfFromUrl(
          pdfUrl: viewModel.pdfUrl,
          fileName: 'Lesson_Plan_${DateTime.now().millisecondsSinceEpoch}.pdf',
          bookId: _selectedBook ?? 'Unknown',
          onProgress: (received, total) {
            downloadedBytesNotifier.value = received;
            totalBytesNotifier.value = total;
          },
          onStatusChange: (status) {
            statusNotifier.value = status;
          },
        );
      } else {
        response = await ApiService.generateLessonPlanPdf(
          bookId: _selectedBook ?? 'Unknown',
          chapterId:
              _selectedChapters.isNotEmpty ? _selectedChapters.first : '',
          headingIds: _selectedChapters,
          chapterName:
              _selectedChapters.isNotEmpty ? _selectedChapters.join(', ') : '',
          headingName:
              _selectedChapters.isNotEmpty ? _selectedChapters.first : '',
          lessonTitle: 'Lesson Plan - ${_selectedBook ?? 'Lesson'}',
          limit: 10,
          onProgress: (received, total) {
            downloadedBytesNotifier.value = received;
            totalBytesNotifier.value = total;
          },
          onStatusChange: (status) {
            statusNotifier.value = status;
          },
        );
      }

      // Close progress dialog
      Navigator.of(context).pop();

      if (response.status && response.data != null) {
        final downloadData = response.data as Map<String, dynamic>;
        final filePath = downloadData['file_path'] as String?;
        final fileName = downloadData['file_name'] as String?;
        final pdfUrl = downloadData['pdf_url'] as String?;

        // Show success message
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 6.w),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Download Successful!',
                      style: TextStyle(
                        fontSize: 4.5.w,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File: $fileName',
                      style: TextStyle(fontSize: 3.2.w),
                    ),
                    SizedBox(height: 1.h),
                    if (pdfUrl != null)
                      Container(
                        padding: EdgeInsets.all(1.5.w),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PDF URL:',
                              style: TextStyle(
                                fontSize: 2.8.w,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              pdfUrl,
                              style: TextStyle(
                                fontSize: 2.6.w,
                                color: Colors.orange[600],
                                fontFamily: 'monospace',
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 1.h),
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Details:',
                            style: TextStyle(
                              fontSize: 3.2.w,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Size: ${downloadData['size'] != null ? ((downloadData['size'] as int) / 1024 / 1024).toStringAsFixed(2) : '0.00'} MB',
                            style: TextStyle(fontSize: 3.w),
                          ),
                          Text(
                            'Downloaded: ${downloadData['downloaded_at'] ?? 'Now'}',
                            style: TextStyle(fontSize: 3.w),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (filePath != null) {
                      await OpenFile.open(filePath);
                    }
                  },
                  icon: Icon(Icons.open_in_new),
                  label: Text('Open PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGradient[0],
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Download failed'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Close dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
