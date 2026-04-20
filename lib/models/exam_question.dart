class ExamQuestion {
  final int id;
  final int examId;
  final String questionText;
  final String aiOption;
  final List<ExamOption> options;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamQuestion({
    required this.id,
    required this.examId,
    required this.questionText,
    required this.aiOption,
    required this.options,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'] ?? 0,
      examId: json['exam_id'] ?? 0,
      questionText: json['question_text'] ?? '',
      aiOption: json['ai_option'] ?? '',
      options: (json['options'] as List<dynamic>?)
          ?.map((option) => ExamOption.fromJson(option))
          .toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'question_text': questionText,
      'ai_option': aiOption,
      'options': options.map((option) => option.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ExamOption {
  final int id;
  final int questionId;
  final String text;
  final bool isCorrect;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamOption({
    required this.id,
    required this.questionId,
    required this.text,
    required this.isCorrect,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExamOption.fromJson(Map<String, dynamic> json) {
    return ExamOption(
      id: json['id'] ?? 0,
      questionId: json['question_id'] ?? 0,
      text: json['text'] ?? '',
      isCorrect: json['is_correct'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'text': text,
      'is_correct': isCorrect,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ExamTakingData {
  final int id;
  final String examName;
  final String bookName;
  final String date;
  final String startTime;
  final String endTime;
  final String totalQuestions;
  final String marksPerQuestion;
  final String totalMarks;
  final List<ExamQuestion> questions;

  ExamTakingData({
    required this.id,
    required this.examName,
    required this.bookName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalQuestions,
    required this.marksPerQuestion,
    required this.totalMarks,
    required this.questions,
  });

  factory ExamTakingData.fromJson(Map<String, dynamic> json) {
    return ExamTakingData(
      id: json['id'] ?? 0,
      examName: json['exam_name'] ?? '',
      bookName: json['book_name'] ?? '',
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      totalQuestions: json['total_questions'] ?? '0',
      marksPerQuestion: json['marks_per_question'] ?? '0',
      totalMarks: json['total_marks'] ?? '0',
      questions: (json['questions'] as List<dynamic>?)
          ?.map((question) => ExamQuestion.fromJson(question))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_name': examName,
      'book_name': bookName,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'total_questions': totalQuestions,
      'marks_per_question': marksPerQuestion,
      'total_marks': totalMarks,
      'questions': questions.map((question) => question.toJson()).toList(),
    };
  }
}



