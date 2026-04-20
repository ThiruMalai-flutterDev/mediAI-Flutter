import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/api_response.dart';

enum AiOption { common, mediAi }

enum ChapterOption { chapter, nonChapter }

class AIQuestionPaper {
  final String id;
  final String examName;
  final String bookName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int totalQuestions;
  final double marksPerQuestion;
  final double totalMarks;
  final AiOption aiOption;
  final ChapterOption chapterOption;

  AIQuestionPaper({
    required this.id,
    required this.examName,
    required this.bookName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalQuestions,
    required this.marksPerQuestion,
    required this.totalMarks,
    this.aiOption = AiOption.common,
    this.chapterOption = ChapterOption.chapter,
  });

  AIQuestionPaper copyWith({
    String? id,
    String? examName,
    String? bookName,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? totalQuestions,
    double? marksPerQuestion,
    double? totalMarks,
    AiOption? aiOption,
    ChapterOption? chapterOption,
  }) {
    return AIQuestionPaper(
      id: id ?? this.id,
      examName: examName ?? this.examName,
      bookName: bookName ?? this.bookName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
      totalMarks: totalMarks ?? this.totalMarks,
      aiOption: aiOption ?? this.aiOption,
      chapterOption: chapterOption ?? this.chapterOption,
    );
  }
}

class AIQuestionBuilderViewModel extends ChangeNotifier {
  final List<AIQuestionPaper> _papers = [];
  String _searchQuery = '';

  AIQuestionBuilderViewModel();

  List<AIQuestionPaper> get papers {
    if (_searchQuery.isEmpty) return List.unmodifiable(_papers);
    return _papers
        .where((p) =>
            p.bookName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList(growable: false);
  }

  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void addPaper(AIQuestionPaper paper) {
    _papers.add(paper);
    notifyListeners();
  }

  Future<ApiResponse> generateQuestions(AIQuestionPaper paper,
      {List<String>? chapterNames}) async {
    return await ApiService.generateQuestions(
      examName: paper.examName,
      topicOrBookName: paper.bookName,
      date:
          '${paper.date.year.toString().padLeft(4, '0')}-${paper.date.month.toString().padLeft(2, '0')}-${paper.date.day.toString().padLeft(2, '0')}',
      duration: _formatDuration(paper.startTime, paper.endTime),
      totalQuestions: paper.totalQuestions,
      marksPerQuestion: paper.marksPerQuestion,
      aiOption: paper.aiOption == AiOption.common ? 'Common ai' : 'MediAi',
      chapterNames: chapterNames,
      bookName: paper.bookName,
      startTime: _formatTime(paper.startTime),
      endTime: _formatTime(paper.endTime),
    );
  }

  Future<void> loadExams() async {
    try {
      final res = await ApiService.getExams();
      if (res.status && res.data != null) {
        List<dynamic> exams = [];

        // Handle the correct API response structure: {exams: [...]}
        if (res.data is Map<String, dynamic>) {
          final data = res.data as Map<String, dynamic>;
          if (data.containsKey('exams') && data['exams'] is List) {
            exams = data['exams'] as List<dynamic>;
          }
        } else if (res.data is List) {
          // Fallback for direct list response
          exams = res.data as List<dynamic>;
        }

        if (exams.isNotEmpty) {
          _papers
            ..clear()
            ..addAll(exams.map((e) {
              final m = (e as Map<String, dynamic>);
              final dateStr = (m['date'] ?? '') as String;
              DateTime date = DateTime.now();
              if (dateStr.isNotEmpty) {
                try {
                  date = DateTime.parse(dateStr);
                } catch (_) {}
              }
              // Parse start and end times from API response
              final startTimeStr = (m['start_time'] ?? '09:00:00') as String;
              final endTimeStr = (m['end_time'] ?? '10:00:00') as String;
              final startTime = _parseTimeOfDay(startTimeStr);
              final endTime = _parseTimeOfDay(endTimeStr);

              final totalQ =
                  int.tryParse((m['total_questions'] ?? '0').toString()) ?? 0;
              final mpqNum = (m['marks_per_question'] ?? '1').toString();
              final mpq = double.tryParse(mpqNum) ?? 1.0;
              return AIQuestionPaper(
                id: (m['id'] ?? UniqueKey().toString()).toString(),
                examName: (m['exam_name'] ?? 'Exam').toString(),
                bookName: (m['book_name'] ?? '').toString(),
                date: date,
                startTime: startTime,
                endTime: endTime,
                totalQuestions: totalQ,
                marksPerQuestion: mpq,
                totalMarks: (totalQ * mpq).toDouble(),
                aiOption: AiOption.common,
                chapterOption: ChapterOption.chapter,
              );
            }));
          notifyListeners();
        }
      }
    } catch (_) {
      // ignore but keep UI
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Fallback to default time
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  String _formatDuration(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final diff = (endMinutes - startMinutes).clamp(0, 24 * 60);
    final h = diff ~/ 60;
    final m = diff % 60;
    if (m == 0) return '$h hours';
    if (h == 0) return '$m minutes';
    return '$h h $m m';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void updatePaper(String id, AIQuestionPaper updated) {
    final index = _papers.indexWhere((p) => p.id == id);
    if (index != -1) {
      _papers[index] = updated;
      notifyListeners();
    }
  }

  void deletePaper(String id) {
    _papers.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
