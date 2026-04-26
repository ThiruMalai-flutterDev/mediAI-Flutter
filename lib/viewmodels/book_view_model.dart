import '../models/book.dart';
import '../services/api_service.dart';
import '../services/url_services.dart';
import '../utils/logger.dart';
import 'base_view_model.dart';
import '../models/api_response.dart';

class BookViewModel extends BaseViewModel {
  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingByMode = false;
  List<Book>? _cachedChapterBooks;
  List<Book>? _cachedNonChapterBooks;

  // Getters
  List<Book> get books => _books;
  List<Book> get filteredBooks => _filteredBooks;
  String get searchQuery => _searchQuery;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  bool get hasMoreData => _hasMoreData;

  // Get paginated books for current page
  List<Book> get paginatedBooks {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, _filteredBooks.length);
    logger.i(
        'Pagination: Page $_currentPage, Start: $startIndex, End: $endIndex, Total: ${_filteredBooks.length}');
    if (startIndex >= _filteredBooks.length) {
      print('DEBUG: No books to return for page $_currentPage');
      return [];
    }
    final result = _filteredBooks.sublist(startIndex, endIndex);
    print(
        'DEBUG: Returning ${result.length} books for page $_currentPage: ${result.map((b) => b.bookName).toList()}');
    logger.i('Returning ${result.length} books for page $_currentPage');
    return result;
  }

  // Get total pages
  int get totalPages => (_filteredBooks.length / _itemsPerPage).ceil();

  // Get total books count
  int get totalBooksCount => _books.length;
  int get filteredBooksCount => _filteredBooks.length;

  /// Load books from API
  Future<void> loadBooks() async {
    setLoading(true);
    clearError();

    // List of books endpoints to try (in order of preference)
    final booksEndpoints = [
      // UrlServices.BOOKS, // /ai/books (primary)
      // UrlServices.BOOKS_API, // /api/books (fallback)
      // UrlServices.BOOKS_V1, // /api/v1/books (fallback)
      UrlServices.BOOKS_LIST, // /books (fallback)
    ];

    for (final endpoint in booksEndpoints) {
      try {
        logger.i('Trying books endpoint: $endpoint');
        final response = await ApiService.getBooks(
          endpoint: endpoint,
          params: {},
          useAuth: false,
        );

        if (response.status && response.data != null) {
          final bookListResponse = BookListResponse.fromJson(response.data);
          _books = bookListResponse.books;
          _filterBooks();
          _currentPage = 1;
          _hasMoreData = _books.length >= _itemsPerPage;
          logger.i(
              'Loaded ${_books.length} books successfully from endpoint: $endpoint');
          setLoading(false);
          return; // Success, exit completely
        } else if (response.code == 404) {
          // If 404, try next endpoint
          logger.w('Endpoint $endpoint not found (404), trying next...');
          continue;
        } else if (response.code == -1 &&
            response.message.contains('timeout')) {
          // If timeout, try next endpoint quickly
          logger.w('Endpoint $endpoint timed out, trying next...');
          continue;
        } else {
          // Other errors, show error message
          setError(response.message);
          logger.e('Failed to load books from $endpoint: ${response.message}');
          setLoading(false);
          return; // Exit completely
        }
      } catch (e) {
        logger.w('Error with endpoint $endpoint: $e');
        if (e.toString().contains('timeout') ||
            e.toString().contains('Timeout')) {
          // If timeout, try next endpoint quickly
          logger.w('Endpoint $endpoint timed out, trying next...');
          continue;
        }
        if (endpoint == booksEndpoints.last) {
          // This was the last endpoint, show error
          final errorMessage =
              'Failed to load books. All endpoints unavailable. Please check your internet connection and try again.';
          setError(errorMessage);
          logger.e('All books endpoints failed: $e');
          setLoading(false);
          return; // Exit completely
        }
        // Continue to next endpoint
      }
    }

    // If we get here, all endpoints failed - load mock data for development
    logger.w('Failed to fetch books');
    // logger.w('All books endpoints failed, loading mock data for development');
    // _loadMockBooks();
    setLoading(false);
  }

  /// Load books based on chapter mode
  Future<void> loadBooksByChapterMode(
      {required bool chapterMode, bool useAuth = false}) async {
    if (_isLoadingByMode) return; // prevent overlapping calls
    _isLoadingByMode = true;
    setLoading(true);
    clearError();

    try {
      logger.i(
          'loadBooksByChapterMode: chapterMode=$chapterMode, cachedChapter=${_cachedChapterBooks != null}, cachedNonChapter=${_cachedNonChapterBooks != null}');
      // Serve from cache when available
      if (_cachedChapterBooks != null && _cachedNonChapterBooks != null) {
        logger.i('Serving books from cache');
        _books = chapterMode
            ? List.from(_cachedChapterBooks!)
            : List.from(_cachedNonChapterBooks!);
        logger.i('Books count (cached): ${_books.length}');
        _filterBooks();
        _currentPage = 1;
        _hasMoreData = _books.length >= _itemsPerPage;
        return;
      }

      // Fetch categorized once
      final ApiResponse categorized = await ApiService.getBooks(
        endpoint: UrlServices.BOOKS_LIST_CATEGORIZED,
        params: const {},
        useAuth: true,
      );

      if (categorized.status && categorized.data is Map<String, dynamic>) {
        logger.i('Received categorized books payload');
        final data = categorized.data as Map<String, dynamic>;
        final List<dynamic> chapterRaw =
            (data['chapter_wise_books'] as List<dynamic>?) ?? [];
        final List<dynamic> nonChapterRaw =
            (data['non_chapter_wise_books'] as List<dynamic>?) ?? [];
        _cachedChapterBooks = chapterRaw
            .map((e) => Book.fromJson(e as Map<String, dynamic>))
            .toList();
        _cachedNonChapterBooks = nonChapterRaw
            .map((e) => Book.fromJson(e as Map<String, dynamic>))
            .toList();

        _books = chapterMode
            ? List.from(_cachedChapterBooks!)
            : List.from(_cachedNonChapterBooks!);
        logger.i('Books count (categorized): ${_books.length}');
        _filterBooks();
        _currentPage = 1;
        _hasMoreData = _books.length >= _itemsPerPage;
        return;
      }

      // Fallback: general books list (single array)
      logger.w('Categorized endpoint failed, falling back to ai/books');
      final fallback = await ApiService.getBooks(
          endpoint: UrlServices.BOOKS, params: const {}, useAuth: useAuth);
      if (fallback.status && fallback.data != null) {
        final bookListResponse = BookListResponse.fromJson(fallback.data);
        _cachedChapterBooks = bookListResponse.books;
        _cachedNonChapterBooks = bookListResponse.books;
        _books = List.from(bookListResponse.books);
        logger.i('Books count (fallback ai/books): ${_books.length}');
        _filterBooks();
        _currentPage = 1;
        _hasMoreData = _books.length >= _itemsPerPage;
      } else {
        setError(fallback.message);
      }
    } catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
      _isLoadingByMode = false;
    }
  }

  /// Load more books (for pagination)
  Future<void> loadMoreBooks() async {
    if (isLoading || !_hasMoreData) return;

    setLoading(true);

    try {
      // Since the API returns all books at once, we'll implement client-side pagination
      // In a real scenario, you'd pass page parameters to the API
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate loading

      _hasMoreData = false; // All data is loaded at once
      logger.i('Loaded more books');
    } catch (e) {
      logger.e('Error loading more books: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Search books by query using AI search API
  Future<void> searchBooks(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    _searchQuery = query;
    setLoading(true);
    clearError();

    try {
      logger.i('Searching books with query: $query');
      final response = await ApiService.searchBooks(
        query: query,
        limit: 50, // Get more results for search
        threshold: 0.3,
      );

      if (response.status && response.data != null) {
        // Handle search response format
        if (response.data is Map && response.data.containsKey('books')) {
          final searchData = response.data as Map<String, dynamic>;
          final booksList = searchData['books'] as List<dynamic>? ?? [];

          _books = booksList
              .map(
                  (bookJson) => Book.fromJson(bookJson as Map<String, dynamic>))
              .toList();

          _filterBooks();
          _currentPage = 1;
          _hasMoreData = _books.length >= _itemsPerPage;
          logger.i(
              'Search completed: Found ${_books.length} books for query: $query');
        } else {
          // Fallback to local search if API response format is unexpected
          _performLocalSearch(query);
          logger.w('Unexpected search response format, using local search');
        }
      } else {
        // Fallback to local search if API fails
        logger.w('Search API failed: ${response.message}, using local search');
        _performLocalSearch(query);
      }
    } catch (e) {
      // Fallback to local search if API throws exception
      logger.w('Search API error: $e, using local search');
      _performLocalSearch(query);
    } finally {
      setLoading(false);
    }
  }

  /// Clear search query and reload all books
  Future<void> clearSearch() async {
    _searchQuery = '';
    await loadBooks(); // Reload all books when clearing search
  }

  /// Perform local search as fallback
  void _performLocalSearch(String query) {
    _searchQuery = query;
    _filterBooks();
    _currentPage = 1;
    _hasMoreData = _filteredBooks.length > _itemsPerPage;
    notifyListeners();
    logger.i(
        'Local search completed: Found ${_filteredBooks.length} books for query: $query');
  }

  /// Search books with custom parameters
  Future<void> searchBooksWithParams({
    required String query,
    int limit = 10,
    double threshold = 0.3,
  }) async {
    if (query.isEmpty) {
      await clearSearch();
      return;
    }

    _searchQuery = query;
    setLoading(true);
    clearError();

    try {
      logger.i(
          'Searching books with query: $query, limit: $limit, threshold: $threshold');
      final response = await ApiService.searchBooks(
        query: query,
        limit: limit,
        threshold: threshold,
      );

      if (response.status && response.data != null) {
        // Handle search response format
        if (response.data is Map && response.data.containsKey('books')) {
          final searchData = response.data as Map<String, dynamic>;
          final booksList = searchData['books'] as List<dynamic>? ?? [];

          _books = booksList
              .map(
                  (bookJson) => Book.fromJson(bookJson as Map<String, dynamic>))
              .toList();

          _filterBooks();
          _currentPage = 1;
          _hasMoreData = _books.length >= _itemsPerPage;
          logger.i(
              'Search completed: Found ${_books.length} books for query: $query');
        } else {
          // Fallback to local search if API response format is unexpected
          _performLocalSearch(query);
          logger.w('Unexpected search response format, using local search');
        }
      } else {
        // Fallback to local search if API fails
        logger.w('Search API failed: ${response.message}, using local search');
        _performLocalSearch(query);
      }
    } catch (e) {
      // Fallback to local search if API throws exception
      logger.w('Search API error: $e, using local search');
      _performLocalSearch(query);
    } finally {
      setLoading(false);
    }
  }

  /// Filter books based on search query
  void _filterBooks() {
    if (_searchQuery.isEmpty) {
      _filteredBooks = List.from(_books);
    } else {
      _filteredBooks = _books
          .where((book) =>
              book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              book.bookName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  /// Go to next page
  void nextPage() {
    if (_currentPage < totalPages) {
      _currentPage++;
      logger.i('Next page: $_currentPage of $totalPages');
      notifyListeners();
    }
  }

  /// Go to previous page
  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      logger.i('Previous page: $_currentPage of $totalPages');
      notifyListeners();
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// Check if can go to next page
  bool canGoNext() => _currentPage < totalPages;

  /// Check if can go to previous page
  bool canGoPrevious() => _currentPage > 1;

  /// Get book by index in current page
  Book? getBookByIndex(int index) {
    final paginatedBooks = this.paginatedBooks;
    if (index >= 0 && index < paginatedBooks.length) {
      return paginatedBooks[index];
    }
    return null;
  }

  /// Get book by name
  Book? getBookByName(String bookName) {
    try {
      return _books.firstWhere((book) => book.bookName == bookName);
    } catch (e) {
      return null;
    }
  }

  /// Get books by category (if you want to add categories later)
  List<Book> getBooksByCategory(String category) {
    // This can be implemented when you add categories to the Book model
    return _books
        .where(
            (book) => book.title.toLowerCase().contains(category.toLowerCase()))
        .toList();
  }

  /// Refresh books data
  Future<void> refreshBooks() async {
    await loadBooks();
  }

  /// Get chapters of a specific book (returns list of chapter titles)
  Future<List<String>> getChaptersOfBook(String bookName) async {
    try {
      logger.i('Getting chapters for book: $bookName');

      final response = await ApiService.getChaptersOfBook(
        bookName: bookName,
        useAuth: true,
      );

      if (response.status && response.data != null) {
        final data = response.data;
        List<String> chapters = [];

        // Handle different response formats
        if (data is List) {
          chapters = data.map((chapter) => chapter.toString()).toList();
        } else if (data is Map && data.containsKey('chapters')) {
          final chapterList = data['chapters'] as List?;
          chapters =
              chapterList?.map((chapter) => chapter.toString()).toList() ?? [];
        } else if (data is Map && data.containsKey('data')) {
          final chapterList = data['data'] as List?;
          chapters =
              chapterList?.map((chapter) => chapter.toString()).toList() ?? [];
        } else if (data is Map && data.containsKey('books')) {
          final books = data['books'] as List?;

          final selectedBook = books?.firstWhere(
            (book) => book['id'] == bookName,
            orElse: () => null,
          );

          final chapterList = selectedBook?['children'] as List?;

          chapters = chapterList
                  ?.map((chapter) => chapter['title'] as String)
                  .toList() ??
              [];
        }

        logger.i('Retrieved ${chapters.length} chapters for book: $bookName');
        return chapters;
      } else {
        logger.e('Failed to get chapters: ${response.message}');
        return [];
      }
    } catch (e) {
      logger.e('Error getting chapters for book $bookName: $e');
      return [];
    }
  }

  /// Get chapters with sub-chapters of a specific book (returns BookChild objects)
  Future<List<BookChild>> getChaptersWithSubChapters(String bookName) async {
    try {
      logger.i('Getting chapters with sub-chapters for book: $bookName');

      final response = await ApiService.getChaptersOfBook(
        bookName: bookName,
        useAuth: true,
      );

      if (response.status && response.data != null) {
        final data = response.data;
        List<BookChild> chapters = [];

        // Handle the new response format with nested children
        if (data is Map && data.containsKey('books')) {
          final books = data['books'] as List?;
          final selectedBook = books?.firstWhere(
            (book) => book['id'] == bookName,
            orElse: () => null,
          );

          if (selectedBook != null && selectedBook['children'] != null) {
            final chapterList = selectedBook['children'] as List;
            chapters = chapterList
                .map((chapter) =>
                    BookChild.fromJson(chapter as Map<String, dynamic>))
                .toList();
          }
        } else if (data is List) {
          // Handle list format
          chapters = data
              .map((chapter) =>
                  BookChild.fromJson(chapter as Map<String, dynamic>))
              .toList();
        } else if (data is Map && data.containsKey('chapters')) {
          // Handle chapters key format
          final chapterList = data['chapters'] as List?;
          if (chapterList != null) {
            chapters = chapterList.map((chapter) {
              if (chapter is Map<String, dynamic>) {
                return BookChild.fromJson(chapter);
              }
              return BookChild(
                id: chapter.toString(),
                title: chapter.toString(),
                type: 'chapter',
              );
            }).toList();
          }
        }

        logger.i('Retrieved ${chapters.length} chapters for book: $bookName');
        return chapters;
      } else {
        logger.e('Failed to get chapters: ${response.message}');
        return [];
      }
    } catch (e) {
      logger.e('Error getting chapters for book $bookName: $e');
      return [];
    }
  }

  /// Load mock books for development/testing
  void _loadMockBooks() {
    print('DEBUG: Loading mock books for development');
    _books = [
      Book(
        bookName: 'medical_anatomy_101',
        title: 'Medical Anatomy 101',
        totalPages: 450,
      ),
      Book(
        bookName: 'pharmacology_guide',
        title: 'Complete Pharmacology Guide',
        totalPages: 320,
      ),
      Book(
        bookName: 'surgery_basics',
        title: 'Surgery Basics and Procedures',
        totalPages: 280,
      ),
      Book(
        bookName: 'diagnosis_manual',
        title: 'Clinical Diagnosis Manual',
        totalPages: 380,
      ),
      Book(
        bookName: 'emergency_medicine',
        title: 'Emergency Medicine Handbook',
        totalPages: 420,
      ),
      Book(
        bookName: 'cardiology_essentials',
        title: 'Cardiology Essentials',
        totalPages: 350,
      ),
      Book(
        bookName: 'pediatrics_guide',
        title: 'Pediatrics Clinical Guide',
        totalPages: 290,
      ),
      Book(
        bookName: 'neurology_basics',
        title: 'Neurology Basics',
        totalPages: 310,
      ),
    ];
    _filterBooks();
    _currentPage = 1;
    _hasMoreData = _books.length >= _itemsPerPage;
    print(
        'DEBUG: Loaded ${_books.length} mock books: ${_books.map((b) => b.bookName).toList()}');
    logger.i('Loaded ${_books.length} mock books for development');
  }

  /// Reset all data
  void reset() {
    _books.clear();
    _filteredBooks.clear();
    _searchQuery = '';
    _currentPage = 1;
    _hasMoreData = true;
    clearError();
    notifyListeners();
  }

  /// Get search suggestions based on current query
  List<String> getSearchSuggestions() {
    if (_searchQuery.isEmpty) return [];

    final suggestions = <String>{};
    for (final book in _books) {
      if (book.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        suggestions.add(book.title);
      }
      if (book.bookName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        suggestions.add(book.bookName);
      }
    }
    return suggestions.take(5).toList();
  }

  /// Get popular search terms (most common words in book titles)
  List<String> getPopularSearchTerms() {
    final wordCount = <String, int>{};

    for (final book in _books) {
      final words = book.title.toLowerCase().split(' ');
      for (final word in words) {
        if (word.length > 3) {
          // Only consider words longer than 3 characters
          wordCount[word] = (wordCount[word] ?? 0) + 1;
        }
      }
    }

    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords.take(10).map((entry) => entry.key).toList();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
