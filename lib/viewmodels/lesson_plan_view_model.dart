import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class LessonPlanViewModel extends ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _generatedLessonPlan;
  String _errorMessage = '';

  // Getters
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get generatedLessonPlan => _generatedLessonPlan;
  String get errorMessage => _errorMessage;

  // Generate lesson plan using AI
  Future<void> generateLessonPlan({
    required String bookName,
    required List<String> chapterNames,
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
        bookName: bookName,
        chapterNames: chapterNames,
      );

      if (response != null) {
        _generatedLessonPlan = response;
        logger.i('Lesson plan generated successfully');
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
    notifyListeners();
  }
}
