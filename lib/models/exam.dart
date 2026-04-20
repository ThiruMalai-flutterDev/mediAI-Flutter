import 'package:flutter/material.dart';

enum ExamStatus { upcoming, live, expired, completed }

class Exam {
  final String id;
  final String examName;
  final String description;
  final String bookName;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int totalQuestions;
  final double marksPerQuestion;
  final double totalMarks;
  final int durationMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final double? obtainedMarks;

  Exam({
    required this.id,
    required this.examName,
    required this.description,
    required this.bookName,
    required this.startDateTime,
    required this.endDateTime,
    required this.totalQuestions,
    required this.marksPerQuestion,
    required this.durationMinutes,
    this.isCompleted = false,
    this.completedAt,
    this.obtainedMarks,
  }) : totalMarks = totalQuestions * marksPerQuestion;

  ExamStatus get status {
    return _calculateStatus();
  }

  ExamStatus _calculateStatus() {
    final now = DateTime.now();
    
    // If exam is completed, it's always completed regardless of time
    if (isCompleted) {
      return ExamStatus.completed;
    }
    
    // Check time-based status with more precise logic
    if (now.isBefore(startDateTime)) {
      return ExamStatus.upcoming;
    } else if (now.isAfter(endDateTime)) {
      return ExamStatus.expired;
    } else if (now.isAtSameMomentAs(startDateTime) || 
               (now.isAfter(startDateTime) && now.isBefore(endDateTime))) {
      return ExamStatus.live;
    } else {
      // Fallback - should not reach here, but just in case
      return ExamStatus.expired;
    }
  }

  Exam copyWith({
    String? id,
    String? examName,
    String? description,
    String? bookName,
    DateTime? startDateTime,
    DateTime? endDateTime,
    int? totalQuestions,
    double? marksPerQuestion,
    int? durationMinutes,
    bool? isCompleted,
    DateTime? completedAt,
    double? obtainedMarks,
  }) {
    return Exam(
      id: id ?? this.id,
      examName: examName ?? this.examName,
      description: description ?? this.description,
      bookName: bookName ?? this.bookName,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      obtainedMarks: obtainedMarks ?? this.obtainedMarks,
    );
  }

  String get statusText {
    switch (status) {
      case ExamStatus.upcoming:
        return 'Upcoming';
      case ExamStatus.live:
        return 'Live';
      case ExamStatus.expired:
        return 'Expired';
      case ExamStatus.completed:
        return 'Completed';
    }
  }

  Color get statusColor {
    switch (status) {
      case ExamStatus.upcoming:
        return Colors.blue;
      case ExamStatus.live:
        return Colors.green;
      case ExamStatus.expired:
        return Colors.red;
      case ExamStatus.completed:
        return Colors.purple;
    }
  }

  String get formattedStartTime {
    return '${startDateTime.day}/${startDateTime.month}/${startDateTime.year} ${startDateTime.hour.toString().padLeft(2, '0')}:${startDateTime.minute.toString().padLeft(2, '0')}';
  }

  String get formattedEndTime {
    return '${endDateTime.day}/${endDateTime.month}/${endDateTime.year} ${endDateTime.hour.toString().padLeft(2, '0')}:${endDateTime.minute.toString().padLeft(2, '0')}';
  }

  String get durationText {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  String get timeUntilStart {
    final now = DateTime.now();
    final difference = startDateTime.difference(now);
    
    if (difference.isNegative) {
      return 'Started';
    } else if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'now';
    }
  }

  String get timeRemaining {
    final now = DateTime.now();
    final difference = endDateTime.difference(now);
    
    if (difference.isNegative) {
      return 'Expired';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Ending soon';
    }
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    final startDateTime = DateTime.parse(json['startDateTime'] as String);
    final endDateTime = DateTime.parse(json['endDateTime'] as String);
    final isCompleted = json['isCompleted'] as bool? ?? false;
    final completedAt = json['completedAt'] != null 
        ? DateTime.parse(json['completedAt'] as String) 
        : null;
    
    return Exam(
      id: json['id'] as String,
      examName: json['examName'] as String,
      description: json['description'] as String? ?? '',
      bookName: json['bookName'] as String,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      totalQuestions: json['totalQuestions'] as int,
      marksPerQuestion: (json['marksPerQuestion'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      isCompleted: isCompleted,
      completedAt: completedAt,
      obtainedMarks: json['obtainedMarks'] != null 
          ? (json['obtainedMarks'] as num).toDouble() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'examName': examName,
      'description': description,
      'bookName': bookName,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'totalQuestions': totalQuestions,
      'marksPerQuestion': marksPerQuestion,
      'durationMinutes': durationMinutes,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'obtainedMarks': obtainedMarks,
    };
  }

  @override
  String toString() {
    return 'Exam(id: $id, examName: $examName, status: $status)';
  }
}
