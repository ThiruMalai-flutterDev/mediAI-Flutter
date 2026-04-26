class LessonPlan {
  final int? id;
  final String bookId;
  final String bookName;
  final String chapterName;
  final String? headingName;
  final List<String>? chapterIds;
  final List<String>? headingIds;
  final String fromDate;
  final String toDate;
  final String? content;
  final String? pdfUrl;
  final Map<String, dynamic>? payload;

  LessonPlan({
    this.id,
    required this.bookId,
    required this.bookName,
    required this.chapterName,
    this.headingName,
    this.chapterIds,
    this.headingIds,
    required this.fromDate,
    required this.toDate,
    this.content,
    this.pdfUrl,
    this.payload,
  });

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    return LessonPlan(
      id: json['id'],
      bookId: json['book_id'] ?? '',
      bookName: json['book_name'] ?? '',
      chapterName: json['chapter_name'] ?? '',
      headingName: json['heading_name'],
      chapterIds: json['chapter_ids'] != null ? List<String>.from(json['chapter_ids']) : null,
      headingIds: json['heading_ids'] != null ? List<String>.from(json['heading_ids']) : null,
      fromDate: json['from_date'] ?? json['from'] ?? json['form'] ?? json['fromDate'] ?? '',
      toDate: json['to_date'] ?? json['to'] ?? json['toDate'] ?? '',
      content: json['content'],
      pdfUrl: json['pdf_url'],
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'book_id': bookId,
      'book_name': bookName,
      'chapter_name': chapterName,
      'from_date': fromDate,
      'to_date': toDate,
      'from': fromDate,
      'to': toDate,
    };
    if (id != null) data['id'] = id;
    if (headingName != null) data['heading_name'] = headingName;
    if (chapterIds != null) data['chapter_ids'] = chapterIds;
    if (headingIds != null) data['heading_ids'] = headingIds;
    if (content != null) data['content'] = content;
    if (pdfUrl != null) data['pdf_url'] = pdfUrl;
    if (payload != null) data['payload'] = payload;
    return data;
  }
}
