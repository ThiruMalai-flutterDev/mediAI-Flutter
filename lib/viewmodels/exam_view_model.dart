import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../services/api_service.dart';
import '../services/url_services.dart';

class ExamViewModel extends ChangeNotifier {
  final List<Exam> _exams = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  List<Exam> get exams => List.unmodifiable(_exams);
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Exam> get filteredExams {
    if (_searchQuery.isEmpty) return _exams;
    return _exams
        .where((exam) => 
            exam.examName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            exam.bookName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            exam.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Exam> get upcomingExams => 
      _exams.where((exam) => exam.status == ExamStatus.upcoming).toList();

  List<Exam> get liveExams => 
      _exams.where((exam) => exam.status == ExamStatus.live).toList();

  List<Exam> get expiredExams => 
      _exams.where((exam) => exam.status == ExamStatus.expired).toList();

  List<Exam> get completedExams => 
      _exams.where((exam) => exam.status == ExamStatus.completed).toList();

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void refreshExamStatus() {
    // Force UI to rebuild with updated status calculations
    notifyListeners();
  }

  Future<void> loadExams() async {
    setLoading(true);
    setError(null);
    
    try {
      final response = await ApiService.getExams();
      
      if (response.status && response.data != null) {
        _exams.clear();
        
        if (response.data is List) {
          final List<dynamic> examsData = response.data as List<dynamic>;
          _exams.addAll(examsData.map((examData) => _parseExamFromApi(examData)).toList());
        } else if (response.data is Map<String, dynamic>) {
          // Handle case where API returns a single exam or wrapped response
          final examData = response.data as Map<String, dynamic>;
          if (examData.containsKey('exams') && examData['exams'] is List) {
            final List<dynamic> examsList = examData['exams'] as List<dynamic>;
            _exams.addAll(examsList.map((examData) => _parseExamFromApi(examData)).toList());
          } else {
            // Single exam object
            _exams.add(_parseExamFromApi(examData));
          }
        }
        
        notifyListeners();
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to load exams');
      }
    } catch (e) {
      setError('Failed to load exams: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> createExam(Exam exam) async {
    setLoading(true);
    setError(null);
    
    try {
      // Convert exam to API format
      final examData = _convertExamToApiFormat(exam);
      
      final response = await ApiService.post(
        endpoint: UrlServices.EXAMS,
        json: examData,
        useAuth: true,
      );
      
      if (response.status && response.data != null) {
        // Parse the created exam from response
        final createdExam = _parseExamFromApi(response.data);
        _exams.add(createdExam);
        notifyListeners();
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to create exam');
      }
    } catch (e) {
      setError('Failed to create exam: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> updateExam(Exam exam) async {
    setLoading(true);
    setError(null);
    
    try {
      // Convert exam to API format
      final examData = _convertExamToApiFormat(exam);
      
      final response = await ApiService.put(
        endpoint: '${UrlServices.EXAMS}/${exam.id}',
        json: examData,
        useAuth: true,
      );
      
      if (response.status && response.data != null) {
        // Parse the updated exam from response
        final updatedExam = _parseExamFromApi(response.data);
        final index = _exams.indexWhere((e) => e.id == exam.id);
        if (index != -1) {
          _exams[index] = updatedExam;
          notifyListeners();
        }
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to update exam');
      }
    } catch (e) {
      setError('Failed to update exam: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteExam(String examId) async {
    setLoading(true);
    setError(null);
    
    try {
      final response = await ApiService.delete(
        endpoint: '${UrlServices.EXAMS}/$examId',
        json: {},
        useAuth: true,
      );
      
      if (response.status) {
        _exams.removeWhere((exam) => exam.id == examId);
        notifyListeners();
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to delete exam');
      }
    } catch (e) {
      setError('Failed to delete exam: $e');
    } finally {
      setLoading(false);
    }
  }

  Future<void> startExam(String examId) async {
    setLoading(true);
    setError(null);
    
    try {
      final response = await ApiService.post(
        endpoint: '${UrlServices.EXAMS}/$examId/start',
        json: {},
        useAuth: true,
      );
      
      if (response.status) {
        // Exam started successfully
        notifyListeners();
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to start exam');
      }
    } catch (e) {
      setError('Failed to start exam: $e');
    } finally {
      setLoading(false);
    }
  }

  void markExamAsCompleted(String examId, double obtainedMarks) {
    final index = _exams.indexWhere((exam) => exam.id == examId);
    if (index != -1) {
      final exam = _exams[index];
      final updatedExam = exam.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
        obtainedMarks: obtainedMarks,
      );
      _exams[index] = updatedExam;
      notifyListeners();
    }
  }

  Future<void> submitExam(String examId, double obtainedMarks) async {
    setLoading(true);
    setError(null);
    
    try {
      final response = await ApiService.post(
        endpoint: '${UrlServices.EXAMS}/$examId/submit',
        json: {
          'obtained_marks': obtainedMarks,
          'completed_at': DateTime.now().toIso8601String(),
        },
        useAuth: true,
      );
      
      if (response.status && response.data != null) {
        // Parse the updated exam from response
        final updatedExam = _parseExamFromApi(response.data);
        final index = _exams.indexWhere((e) => e.id == examId);
        if (index != -1) {
          _exams[index] = updatedExam;
          notifyListeners();
        }
      } else {
        setError(response.message.isNotEmpty ? response.message : 'Failed to submit exam');
      }
    } catch (e) {
      setError('Failed to submit exam: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Parse exam data from API response
  Exam _parseExamFromApi(dynamic examData) {
    if (examData is Map<String, dynamic>) {
      final data = examData;
      
      // Parse exam date - your API provides date in YYYY-MM-DD format
      DateTime examDate = DateTime.now();
      if (data['date'] != null) {
        try {
          // Parse the date string (YYYY-MM-DD format)
          final dateStr = data['date'] as String;
          examDate = DateTime.parse(dateStr);
        } catch (e) {
          // Fallback to current time if parsing fails
          examDate = DateTime.now();
        }
      }
      
      // Parse start and end times from your API
      DateTime startDateTime = examDate;
      DateTime endDateTime = examDate;
      
      if (data['start_time'] != null) {
        try {
          final startTimeStr = data['start_time'] as String; // Format: "HH:MM:SS"
          final timeParts = startTimeStr.split(':');
          if (timeParts.length >= 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            startDateTime = DateTime(examDate.year, examDate.month, examDate.day, hour, minute);
          }
        } catch (e) {
          // Fallback to exam date if parsing fails
          startDateTime = examDate;
        }
      }
      
      if (data['end_time'] != null) {
        try {
          final endTimeStr = data['end_time'] as String; // Format: "HH:MM:SS"
          final timeParts = endTimeStr.split(':');
          if (timeParts.length >= 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            endDateTime = DateTime(examDate.year, examDate.month, examDate.day, hour, minute);
            
            // Handle case where end time is next day (e.g., end_time: "01:42:00" means next day 1:42 AM)
            if (endDateTime.isBefore(startDateTime)) {
              endDateTime = endDateTime.add(const Duration(days: 1));
            }
          }
        } catch (e) {
          // Fallback to start time + 1 hour if parsing fails
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }
      }
      
      // Parse numeric fields (API returns them as strings)
      int totalQuestions = 0;
      double marksPerQuestion = 1.0;
      
      if (data['total_questions'] != null) {
        totalQuestions = int.tryParse(data['total_questions'].toString()) ?? 0;
      }
      
      if (data['marks_per_question'] != null) {
        marksPerQuestion = double.tryParse(data['marks_per_question'].toString()) ?? 1.0;
      }
      
      // Calculate duration in minutes
      int durationMinutes = endDateTime.difference(startDateTime).inMinutes;
      if (durationMinutes <= 0) {
        durationMinutes = 60; // Default 1 hour if calculation fails
      }
      
      // Parse completion status
      bool isCompleted = data['has_attended'] ?? false;
      
      return Exam(
        id: data['id']?.toString() ?? UniqueKey().toString(),
        examName: data['exam_name'] ?? 'Untitled Exam',
        description: data['description'] ?? '', // This field might not be in your API
        bookName: data['book_name'] ?? '',
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        totalQuestions: totalQuestions,
        marksPerQuestion: marksPerQuestion,
        durationMinutes: durationMinutes,
        isCompleted: isCompleted,
        completedAt: null, // Your API doesn't provide this field yet
        obtainedMarks: null, // Your API doesn't provide this field yet
      );
    }
    
    // Fallback for unexpected data format
    return Exam(
      id: UniqueKey().toString(),
      examName: 'Unknown Exam',
      description: '',
      bookName: '',
      startDateTime: DateTime.now(),
      endDateTime: DateTime.now().add(const Duration(hours: 1)),
      totalQuestions: 0,
      marksPerQuestion: 1.0,
      durationMinutes: 60,
    );
  }
  
  /// Convert exam to API format
  Map<String, dynamic> _convertExamToApiFormat(Exam exam) {
    return {
      'exam_name': exam.examName,
      'book_name': exam.bookName,
      'date': '${exam.startDateTime.year}-${exam.startDateTime.month.toString().padLeft(2, '0')}-${exam.startDateTime.day.toString().padLeft(2, '0')}',
      'start_time': '${exam.startDateTime.hour.toString().padLeft(2, '0')}:${exam.startDateTime.minute.toString().padLeft(2, '0')}:00',
      'end_time': '${exam.endDateTime.hour.toString().padLeft(2, '0')}:${exam.endDateTime.minute.toString().padLeft(2, '0')}:00',
      'total_questions': exam.totalQuestions.toString(),
      'marks_per_question': exam.marksPerQuestion.toString(),
      'total_marks': exam.totalMarks.toString(),
      'has_attended': exam.isCompleted,
      if (exam.description.isNotEmpty) 'description': exam.description,
    };
  }
}
