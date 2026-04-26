import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import '../models/lesson_plan.dart';
import 'package:intl/intl.dart';

class LessonPlanViewModel extends ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _generatedLessonPlan;
  String _errorMessage = '';
  String _pdfUrl = ''; // server pdf_url from response
  String _localPdfPath = ''; // saved local path after download
  
  DateTime? _fromDate;
  DateTime? _toDate;
  List<LessonPlan> _lessonPlans = [];

  // Getters
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get generatedLessonPlan => _generatedLessonPlan;
  String get errorMessage => _errorMessage;
  String get pdfUrl => _pdfUrl;
  String get localPdfPath => _localPdfPath;
  bool get hasPdf => _pdfUrl.isNotEmpty;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  List<LessonPlan> get lessonPlans => _lessonPlans;

  // Set date range
  void setDateRange(DateTime? from, DateTime? to) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  // Generate lesson plan using AI
  Future<void> generateLessonPlan({
    required String bookId,
    required String bookName,
    required List<String> chapterNames,
    required List<String> chapterIds,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    _generatedLessonPlan = null;
    notifyListeners();

    try {
      logger.i(
          'Generating lesson plan for book: $bookName with chapters: $chapterNames');

      // Call AI service to generate lesson plan
      final response = await ApiService.generateLessonPlan(
        bookName: bookId, // Use bookId for generation as per existing logic
        chapterNames: chapterNames,
      );

      if (response != null) {
        _generatedLessonPlan = response;
        _pdfUrl = response['pdf_url'] ?? '';
        logger.i('Lesson plan generated successfully. pdf_url: $_pdfUrl');
        
        // Auto-save the generated lesson plan if dates are selected
        if (_fromDate != null && _toDate != null) {
          await saveLessonPlan(
            bookId: bookId,
            bookName: bookName,
            chapterName: chapterNames.isNotEmpty ? chapterNames.join(', ') : 'Generated Plan',
            chapterIds: chapterIds,
            content: formattedLessonPlan,
            pdfUrl: _pdfUrl,
          );
        }
      } else {
        _errorMessage = 'Failed to generate lesson plan. Please try again.';
        logger.e('Empty response from AI service');
      }
    } catch (e) {
      _errorMessage = 'Error generating lesson plan: ${e.toString()}';
      logger.e('Error generating lesson plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get formatted lesson plan text for display
  String get formattedLessonPlan {
    if (_generatedLessonPlan == null) return '';

    final lessonPlan = _generatedLessonPlan!['lesson_plan'];
    if (lessonPlan == null) return '';

    final buffer = StringBuffer();

    // Learning Objectives
    if (lessonPlan['learning_objectives'] != null) {
      buffer.writeln('📚 LEARNING OBJECTIVES:');
      final objectives = lessonPlan['learning_objectives'] as List;
      for (int i = 0; i < objectives.length; i++) {
        buffer.writeln('${i + 1}. ${objectives[i]}');
      }
      buffer.writeln();
    }

    // Key Concepts
    if (lessonPlan['key_concepts'] != null) {
      buffer.writeln('🔑 KEY CONCEPTS:');
      final concepts = lessonPlan['key_concepts'] as List;
      for (int i = 0; i < concepts.length; i++) {
        buffer.writeln('• ${concepts[i]}');
      }
      buffer.writeln();
    }

    // Teaching Methodology
    if (lessonPlan['teaching_methodology'] != null &&
        lessonPlan['teaching_methodology'].toString().isNotEmpty) {
      buffer.writeln('📖 TEACHING METHODOLOGY:');
      buffer.writeln(lessonPlan['teaching_methodology']);
      buffer.writeln();
    }

    // Assessment Methods
    if (lessonPlan['assessment_methods'] != null &&
        (lessonPlan['assessment_methods'] as List).isNotEmpty) {
      buffer.writeln('📝 ASSESSMENT METHODS:');
      final assessments = lessonPlan['assessment_methods'] as List;
      for (int i = 0; i < assessments.length; i++) {
        buffer.writeln('${i + 1}. ${assessments[i]}');
      }
      buffer.writeln();
    }

    // Resources
    if (lessonPlan['resources'] != null) {
      buffer.writeln('📚 RESOURCES:');
      final resources = lessonPlan['resources'] as List;
      for (int i = 0; i < resources.length; i++) {
        buffer.writeln('${i + 1}. ${resources[i]}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void setLocalPdfPath(String path) {
    _localPdfPath = path;
    notifyListeners();
  }

  // Clear the generated lesson plan
  void clearLessonPlan() {
    _generatedLessonPlan = null;
    _errorMessage = '';
    notifyListeners();
  }

  // Reset all fields
  void reset() {
    _isLoading = false;
    _generatedLessonPlan = null;
    _errorMessage = '';
    _pdfUrl = '';
    _localPdfPath = '';
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  // CRUD Methods
  
  Future<void> fetchLessonPlans() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.getLessonPlans();

      if (response.status && response.data != null) {
        dynamic rawData = response.data;
        List<dynamic> dataList = [];

        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map<String, dynamic>) {
          if (rawData.containsKey('lesson_plans') &&
              rawData['lesson_plans'] is List) {
            dataList = rawData['lesson_plans'];
          } else if (rawData.containsKey('data') && rawData['data'] is List) {
            dataList = rawData['data'];
          } else if (rawData.containsKey('lesson-plans') &&
              rawData['lesson-plans'] is List) {
            dataList = rawData['lesson-plans'];
          }
        }

        _lessonPlans = dataList.map((e) => LessonPlan.fromJson(e)).toList();
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Error fetching lesson plans: $e';
      logger.e('Error fetching lesson plans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }



  Future<void> fetchAllData() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([
      fetchLessonPlans(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveLessonPlan({
    required String bookId,
    required String bookName,
    required String chapterName,
    List<String>? chapterIds,
    String? content,
    String? pdfUrl,
  }) async {
    if (_fromDate == null || _toDate == null) return;
    
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final payload = {
      'book_id': bookId,
      'book_name': bookName,
      'chapter_name': chapterName,
      'chapter_ids': chapterIds,
      'from_date': formatter.format(_fromDate!),
      'to_date': formatter.format(_toDate!),
      'content': content,
      'pdf_url': pdfUrl,
    };

    try {
      final response = await ApiService.createLessonPlan(payload);
      if (response.status) {
        logger.i('Lesson plan saved successfully');
        await fetchAllData();
      } else {
        logger.e('Failed to save lesson plan: ${response.message}');
      }
    } catch (e) {
      logger.e('Error saving lesson plan: $e');
    }
  }

  Future<void> updateLessonPlanDates(int id, DateTime from, DateTime to) async {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final payload = {
      'from_date': formatter.format(from),
      'to_date': formatter.format(to),
    };

    try {
      final response = await ApiService.updateLessonPlan(id, payload);
      if (response.status) {
        logger.i('Lesson plan updated successfully');
        await fetchAllData();
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Error updating lesson plan: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteLessonPlan(int id) async {
    try {
      final response = await ApiService.deleteLessonPlan(id);
      if (response.status) {
        _lessonPlans.removeWhere((element) => element.id == id);
        notifyListeners();
      }
    } catch (e) {
      logger.e('Error deleting lesson plan: $e');
    }
  }
}
