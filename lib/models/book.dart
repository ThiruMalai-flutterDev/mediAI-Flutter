class Book {
  final String bookName;
  final String title;
  final int totalPages;
  final List<BookChild> children;

  Book({
    required this.bookName,
    required this.title,
    required this.totalPages,
    this.children = const [],
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    // Handle children (chapters) if present
    List<BookChild> childrenList = [];
    if (json['children'] != null && json['children'] is List) {
      childrenList = (json['children'] as List)
          .map((child) => BookChild.fromJson(child as Map<String, dynamic>))
          .toList();
    }

    return Book(
      // Prefer explicit book_name, then id, then title as identifier
      bookName:
          (json['book_name'] ?? json['id'] ?? json['title'] ?? '').toString(),
      // Prefer title, then fall back to book_name or id for display
      title:
          (json['title'] ?? json['book_name'] ?? json['id'] ?? '').toString(),
      // Use total_pages when available, otherwise approximate from children length
      totalPages: json['total_pages'] ??
          (json['children'] is List ? (json['children'] as List).length : 0),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_name': bookName,
      'title': title,
      'total_pages': totalPages,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Book(bookName: $bookName, title: $title, totalPages: $totalPages, children: ${children.length})';
  }
}

/// Represents a child item (chapter or sub-chapter) within a book
class BookChild {
  final String id;
  final String title;
  final String type;
  final List<BookChild> children;

  BookChild({
    required this.id,
    required this.title,
    required this.type,
    this.children = const [],
  });

  factory BookChild.fromJson(Map<String, dynamic> json) {
    List<BookChild> childrenList = [];
    if (json['children'] != null && json['children'] is List) {
      childrenList = (json['children'] as List)
          .map((child) => BookChild.fromJson(child as Map<String, dynamic>))
          .toList();
    }

    return BookChild(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? 'chapter').toString(),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }

  bool get hasSubChapters => children.isNotEmpty;

  @override
  String toString() {
    return 'BookChild(id: $id, title: $title, type: $type, children: ${children.length})';
  }
}

class BookListResponse {
  final String status;
  final List<Book> books;

  BookListResponse({
    required this.status,
    required this.books,
  });

  factory BookListResponse.fromJson(dynamic json) {
    if (json is List<dynamic>) {
      return BookListResponse(
        status: 'success',
        books: json
            .map((bookJson) => Book.fromJson(bookJson as Map<String, dynamic>))
            .toList(),
      );
    }

    return BookListResponse(
      status: json['status'] ?? '',
      books: (json['books'] as List<dynamic>?)
              ?.map(
                  (bookJson) => Book.fromJson(bookJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'books': books.map((book) => book.toJson()).toList(),
    };
  }
}
