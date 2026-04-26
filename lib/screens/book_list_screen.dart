import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../models/book.dart';
import '../viewmodels/book_view_model.dart';
import '../viewmodels/chat_view_model.dart';
import 'online_exam_screen.dart';

class BookListScreen extends StatefulWidget {
  final VoidCallback? onBooksSelected;

  const BookListScreen({super.key, this.onBooksSelected});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isTyping = false;
  bool _isSelectionMode = false;
  bool _showExams = false;
  final Set<String> _selectedBooks = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookViewModel>().loadBooks();
      // Load selected books from chat view model
      _loadSelectedBooks();
    });
    _scrollController.addListener(_onScroll);
  }

  void _loadSelectedBooks() {
    final chatViewModel = context.read<ChatViewModel>();
    setState(() {
      _selectedBooks.clear();
      _selectedBooks.addAll(chatViewModel.selectedBooks);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final bookViewModel = context.read<BookViewModel>();
      if (!bookViewModel.isLoading && bookViewModel.hasMoreData) {
        bookViewModel.loadMoreBooks();
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    // Update typing state
    setState(() {
      _isTyping = query.isNotEmpty;
    });

    // If query is empty, clear search immediately
    if (query.isEmpty) {
      context.read<BookViewModel>().clearSearch();
      return;
    }

    // Set up debounce timer for AI search
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        context.read<BookViewModel>().searchBooks(query);
      }
    });
  }

  void _loadNextPage() {
    context.read<BookViewModel>().nextPage();
  }

  void _loadPreviousPage() {
    context.read<BookViewModel>().previousPage();
  }

  void _toggleSelectionMode() {
    print(
        'DEBUG: Toggling selection mode from $_isSelectionMode to ${!_isSelectionMode}');
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        print('DEBUG: Exiting selection mode, clearing selected books');
        _selectedBooks.clear();
      }
    });
    print('DEBUG: Selection mode is now: $_isSelectionMode');
  }

  void _toggleBookSelection(String bookName) {
    print('DEBUG: Selecting book: $bookName');
    print('DEBUG: Current selected books before: $_selectedBooks');
    setState(() {
      // Clear all previous selections (single selection only)
      _selectedBooks.clear();
      // Add the new selection
      _selectedBooks.add(bookName);
      print('DEBUG: Selected $bookName (single selection)');
    });
    print('DEBUG: Current selected books after: $_selectedBooks');
  }

  void _clearSelection() {
    print('DEBUG: Clearing all selections');
    print('DEBUG: Selected books before clear: $_selectedBooks');
    setState(() {
      _selectedBooks.clear();
    });
    print('DEBUG: Selected books after clear: $_selectedBooks');
  }

  Future<void> _confirmSelection() async {
    if (_selectedBooks.isEmpty) {
      _showSnackBar('Please select a book', isError: true);
      return;
    }

    final chatViewModel = context.read<ChatViewModel>();

    // Update chat view model with selected books
    for (String bookName in _selectedBooks) {
      if (!chatViewModel.selectedBooks.contains(bookName)) {
        chatViewModel.toggleBookSelection(bookName);
      }
    }

    // Remove books that are no longer selected
    final booksToRemove = chatViewModel.selectedBooks
        .where((bookName) => !_selectedBooks.contains(bookName))
        .toList();
    for (String bookName in booksToRemove) {
      chatViewModel.toggleBookSelection(bookName);
    }

    // Select books for chat context
    await chatViewModel.selectBooks();

    if (chatViewModel.errorMessage.isEmpty) {
      _showSnackBar(
          'Book selected successfully! You can now start chatting with context from the selected book.');
      // Switch to chat tab using callback
      if (widget.onBooksSelected != null) {
        widget.onBooksSelected!();
      }
    } else {
      _showSnackBar(chatViewModel.errorMessage, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 4.w,
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 3.w),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : AppColors.primaryPurple,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _startNewChatWithBook(String bookName, String bookTitle) async {
    final chatViewModel = context.read<ChatViewModel>();

    try {
      // Start a new chat session with the selected book
      await chatViewModel.startNewSessionWithBook(bookName, bookTitle);

      if (chatViewModel.errorMessage.isEmpty) {
        _showSnackBar(
            'New chat started with "$bookTitle"! You can now start chatting with context from this book.');
        // Switch to chat tab using callback
        if (widget.onBooksSelected != null) {
          widget.onBooksSelected!();
        }
      } else {
        _showSnackBar(chatViewModel.errorMessage, isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to start new chat with book. Please try again.',
          isError: true);
      print('Error starting new chat with book: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false, // Don't add bottom padding since we're in a tab view
        child: Consumer<BookViewModel>(
          builder: (context, bookViewModel, child) {
            return Column(
              children: [
                // Header
                _buildHeader(bookViewModel),

                // Toggle for Books / Exams
                _buildToggle(),

                if (!_showExams) ...[
                  // Search Bar
                  _buildSearchBar(),

                  // Search Status
                  _buildSearchStatus(bookViewModel),

                  // Content
                  Expanded(
                    child: _buildContent(bookViewModel),
                  ),

                  // Pagination Controls
                  _buildPaginationControls(bookViewModel),
                ] else ...[
                  const Expanded(
                    child: OnlineExamScreen(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showExams = false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: !_showExams
                      ? AppColors.primaryPurple
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Books',
                    style: TextStyle(
                      color: !_showExams ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showExams = true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                decoration: BoxDecoration(
                  color:
                      _showExams ? AppColors.primaryPurple : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Exams',
                    style: TextStyle(
                      color: _showExams ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BookViewModel bookViewModel) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(3.w),
          bottomRight: Radius.circular(3.w),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.library_books,
                color: AppColors.white,
                size: 6.w,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<ChatViewModel>(
                      builder: (context, chatViewModel, child) {
                        if (chatViewModel.selectedBooks.isNotEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Book Selected for Chat',
                                style: TextStyle(
                                  fontSize: 4.w,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                              Text(
                                chatViewModel.selectedBooks.first,
                                style: TextStyle(
                                  fontSize: 2.5.w,
                                  color: AppColors.white.withOpacity(0.9),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSelectionMode
                                  ? 'Select Book for Chat'
                                  : 'Medical Books Library',
                              style: TextStyle(
                                fontSize: 4.w,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              _isSelectionMode
                                  ? _selectedBooks.isEmpty
                                      ? 'No book selected'
                                      : '1 book selected'
                                  : '${bookViewModel.filteredBooksCount} books available • Tap any book to start a new chat',
                              style: TextStyle(
                                fontSize: 2.5.w,
                                color: AppColors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Selection mode toggle or change/clear book buttons
              Consumer<ChatViewModel>(
                builder: (context, chatViewModel, child) {
                  // Show change and clear book buttons if books are already selected
                  if (chatViewModel.selectedBooks.isNotEmpty) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Clear book button
                        IconButton(
                          onPressed: () {
                            print('DEBUG: Clear book button pressed');
                            HapticFeedback.lightImpact();
                            _showClearBookDialog(chatViewModel);
                          },
                          icon: Icon(
                            Icons.clear,
                            color: Colors.red[300],
                            size: 5.w,
                          ),
                          tooltip: 'Clear Selected Book',
                        ),
                        // Change book button
                        IconButton(
                          onPressed: () {
                            print('DEBUG: Change book button pressed');
                            HapticFeedback.lightImpact();
                            _toggleSelectionMode();
                          },
                          icon: Icon(
                            Icons.edit,
                            color: AppColors.white,
                            size: 5.w,
                          ),
                          tooltip: 'Change Book',
                        ),
                      ],
                    );
                  }

                  return IconButton(
                    onPressed: () {
                      print('DEBUG: Selection mode toggle button pressed');
                      HapticFeedback.lightImpact();
                      _toggleSelectionMode();
                    },
                    icon: Icon(
                      _isSelectionMode ? Icons.close : Icons.checklist,
                      color: AppColors.white,
                      size: 5.w,
                    ),
                    tooltip:
                        _isSelectionMode ? 'Exit Selection' : 'Select Books',
                  );
                },
              ),
            ],
          ),
          // Selection controls - only show if no books are selected
          Consumer<ChatViewModel>(
            builder: (context, chatViewModel, child) {
              // Hide selection controls if books are already selected
              if (chatViewModel.selectedBooks.isNotEmpty) {
                return const SizedBox.shrink();
              }

              return _isSelectionMode
                  ? Column(
                      children: [
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _selectedBooks.isNotEmpty
                                    ? () {
                                        print(
                                            'DEBUG: Clear Selection button pressed');
                                        _clearSelection();
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.clear,
                                  size: 3.5.w,
                                ),
                                label: Text(
                                  'Clear',
                                  style: TextStyle(fontSize: 2.8.w),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedBooks.isNotEmpty
                                      ? AppColors.white.withOpacity(0.2)
                                      : AppColors.white.withOpacity(0.1),
                                  foregroundColor: _selectedBooks.isNotEmpty
                                      ? AppColors.white
                                      : AppColors.white.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _selectedBooks.isNotEmpty
                                    ? () {
                                        print(
                                            'DEBUG: Confirm button pressed with ${_selectedBooks.length} selected books');
                                        _confirmSelection();
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.check_circle,
                                  size: 3.5.w,
                                ),
                                label: Text(
                                  'Confirm',
                                  style: TextStyle(fontSize: 2.8.w),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedBooks.isNotEmpty
                                      ? AppColors.white
                                      : AppColors.white.withOpacity(0.3),
                                  foregroundColor: _selectedBooks.isNotEmpty
                                      ? AppColors.primaryPurple
                                      : AppColors.white.withOpacity(0.7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Consumer<BookViewModel>(
      builder: (context, bookViewModel, child) {
        return Container(
          padding: EdgeInsets.all(3.w),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(
              fontSize: 3.w,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search books with AI...',
              hintStyle: TextStyle(
                fontSize: 3.w,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
              prefixIcon:
                  Icon(Icons.search, color: AppColors.primaryPurple, size: 4.w),
              suffixIcon: _buildSearchSuffixIcon(bookViewModel),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.w),
                borderSide: BorderSide(color: AppColors.primaryPurple),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.w),
                borderSide:
                    BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.w),
                borderSide:
                    BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSuffixIcon(BookViewModel bookViewModel) {
    if (bookViewModel.isLoading && bookViewModel.searchQuery.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(2.w),
        child: SizedBox(
          width: 3.w,
          height: 3.w,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryPurple,
          ),
        ),
      );
    }

    if (bookViewModel.searchQuery.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.clear, color: AppColors.primaryPurple, size: 4.w),
            onPressed: () {
              _searchController.clear();
              bookViewModel.clearSearch();
            },
            tooltip: 'Clear Search',
          ),
        ],
      );
    }

    // Return empty widget when no search query
    return const SizedBox.shrink();
  }

  Widget _buildSearchStatus(BookViewModel bookViewModel) {
    // Debug print to help troubleshoot visibility
    print(
        'Search Status Debug: query="${bookViewModel.searchQuery}", loading=${bookViewModel.isLoading}, typing=$_isTyping');

    // Show status if there's a search query, loading, or typing
    if (bookViewModel.searchQuery.isEmpty &&
        !bookViewModel.isLoading &&
        !_isTyping) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(1.5.w),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (_isTyping) ...[
            SizedBox(
              width: 3.w,
              height: 3.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryPurple.withOpacity(0.7),
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Typing...',
                style: TextStyle(
                  fontSize: 3.w,
                  color: AppColors.primaryPurple.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else if (bookViewModel.isLoading &&
              bookViewModel.searchQuery.isNotEmpty) ...[
            SizedBox(
              width: 3.w,
              height: 3.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryPurple,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Searching with AI...',
                style: TextStyle(
                  fontSize: 3.w,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (bookViewModel.searchQuery.isNotEmpty) ...[
            Icon(
              Icons.search,
              size: 4.w,
              color: AppColors.primaryPurple,
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Search results for "${bookViewModel.searchQuery}"',
                style: TextStyle(
                  fontSize: 3.w,
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BookViewModel bookViewModel) {
    if (bookViewModel.isLoading && bookViewModel.books.isEmpty) {
      return _buildLoadingWidget();
    }

    if (bookViewModel.hasError) {
      return _buildErrorWidget(bookViewModel);
    }

    final paginatedBooks = bookViewModel.paginatedBooks;

    if (paginatedBooks.isEmpty) {
      return _buildEmptyWidget(bookViewModel);
    }

    return RefreshIndicator(
      onRefresh: () => bookViewModel.refreshBooks(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 3.w),
        itemCount: paginatedBooks.length + (bookViewModel.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == paginatedBooks.length) {
            return _buildLoadingIndicator();
          }
          return _buildBookItem(paginatedBooks[index]);
        },
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    final isSelected = _selectedBooks.contains(book.bookName);

    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              print(
                  'DEBUG: Book item tapped: ${book.bookName}, selection mode: $_isSelectionMode');
              HapticFeedback.lightImpact();
              _toggleBookSelection(book.bookName);
            }
          : () {
              print('DEBUG: Book item tapped to start new chat: ${book.title}');
              HapticFeedback.lightImpact();
              _startNewChatWithBook(book.bookName, book.title);
            },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 2.w),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPurple.withOpacity(0.1)
              : AppColors.white,
          borderRadius: BorderRadius.circular(3.w),
          border: isSelected
              ? Border.all(color: AppColors.primaryPurple, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryPurple.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Selection radio button or book icon
            if (_isSelectionMode) ...[
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primaryPurple : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(3.w), // Circular for radio button
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.circle,
                        color: Colors.white,
                        size: 2.5.w,
                      )
                    : null,
              ),
              SizedBox(width: 3.w),
            ] else ...[
              // Book Icon with Chat indicator
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(1.5.w),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.book,
                        color: AppColors.primaryPurple,
                        size: 5.w,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 3.w,
                        height: 3.w,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          borderRadius: BorderRadius.circular(1.5.w),
                        ),
                        child: Icon(
                          Icons.chat,
                          color: Colors.white,
                          size: 1.8.w,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 3.w),
            ],

            // Book Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 3.w,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? AppColors.primaryPurple : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.totalPages > 0) ...[
                    SizedBox(height: 0.5.h),
                    Text(
                      '${book.totalPages} pages',
                      style: TextStyle(
                        fontSize: 2.5.w,
                        color: isSelected
                            ? AppColors.primaryPurple.withOpacity(0.8)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                  if (isSelected) ...[
                    SizedBox(height: 0.5.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 2.w, vertical: 0.3.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 3.w,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 2.2.w,
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Selection mode indicator
            if (_isSelectionMode) ...[
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primaryPurple : Colors.grey[400],
                size: 4.w,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryPurple,
            strokeWidth: 3,
          ),
          SizedBox(height: 3.h),
          Text(
            'Loading books...',
            style: TextStyle(
              fontSize: 3.w,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BookViewModel bookViewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 12.w,
            color: Colors.red,
          ),
          SizedBox(height: 3.h),
          Text(
            'Error loading books',
            style: TextStyle(
              fontSize: 4.w,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 1.5.h),
          Text(
            bookViewModel.errorMessage,
            style: TextStyle(
              fontSize: 2.8.w,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 3.h),
          ElevatedButton(
            onPressed: () => bookViewModel.loadBooks(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.w),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 3.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(BookViewModel bookViewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 12.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 3.h),
          Text(
            'No books found',
            style: TextStyle(
              fontSize: 4.w,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 1.5.h),
          Text(
            bookViewModel.searchQuery.isEmpty
                ? 'No books available at the moment'
                : 'No books match your search "${bookViewModel.searchQuery}"',
            style: TextStyle(
              fontSize: 2.8.w,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(3.w),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryPurple,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildPaginationControls(BookViewModel bookViewModel) {
    final totalPages = bookViewModel.totalPages;
    print(
        'Pagination Debug: Total pages: $totalPages, Current page: ${bookViewModel.currentPage}');

    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          ElevatedButton(
            onPressed: bookViewModel.canGoPrevious() ? _loadPreviousPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bookViewModel.canGoPrevious()
                  ? AppColors.primaryPurple
                  : Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.w),
              ),
            ),
            child: Text(
              'Previous',
              style: TextStyle(
                color: bookViewModel.canGoPrevious()
                    ? AppColors.white
                    : Colors.grey[600],
                fontSize: 2.8.w,
              ),
            ),
          ),

          // Page Info
          Text(
            'Page ${bookViewModel.currentPage} of $totalPages',
            style: TextStyle(
              fontSize: 2.8.w,
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Next Button
          ElevatedButton(
            onPressed: bookViewModel.canGoNext() ? _loadNextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: bookViewModel.canGoNext()
                  ? AppColors.primaryPurple
                  : Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.w),
              ),
            ),
            child: Text(
              'Next',
              style: TextStyle(
                color: bookViewModel.canGoNext()
                    ? AppColors.white
                    : Colors.grey[600],
                fontSize: 2.8.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearBookDialog(ChatViewModel chatViewModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: Colors.orange[600],
                size: 5.w,
              ),
              SizedBox(width: 2.w),
              Text(
                'Clear Selected Book',
                style: TextStyle(
                  fontSize: 4.w,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to clear the selected book? You will lose the context from this book and the AI mode toggle will be available again in the chat screen.',
            style: TextStyle(
              fontSize: 3.w,
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 3.w,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearSelectedBook(chatViewModel);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.w),
                ),
              ),
              child: Text(
                'Clear Book',
                style: TextStyle(
                  fontSize: 3.w,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearSelectedBook(ChatViewModel chatViewModel) {
    // Clear the selected books
    chatViewModel.clearSelectedBooks();

    // Update local state
    setState(() {
      _selectedBooks.clear();
    });

    // Show success message
    _showSnackBar(
        'Selected book cleared successfully! The AI mode toggle is now available in the chat screen.');
  }
}
