import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../models/exam.dart';
import '../models/exam_question.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../viewmodels/exam_view_model.dart';

class ExamTakingScreen extends StatefulWidget {
  final Exam exam;

  const ExamTakingScreen({
    super.key,
    required this.exam,
  });

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  ExamTakingData? _examData;
  bool _isLoading = true;
  String? _error;
  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {}; // questionId -> optionId
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadExamData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExamData() async {
    try {
      final response = await ApiService.get(
        endpoint: 'api/question/${widget.exam.id}',
        params: {},
        useAuth: true,
      );

      if (response.status && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _examData = ExamTakingData.fromJson(data);
          _isLoading = false;
        });
        _startTimer();
      } else {
        setState(() {
          _error = response.message.isNotEmpty ? response.message : 'Failed to load exam data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load exam: $e';
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    if (_examData == null) return;

    // Calculate exam duration from start time to end time
    final examDate = DateTime.parse(_examData!.date);
    final startTimeParts = _examData!.startTime.split(':');
    final endTimeParts = _examData!.endTime.split(':');
    
    // Parse start and end times
    int startHour = int.parse(startTimeParts[0]);
    int startMinute = int.parse(startTimeParts[1]);
    int endHour = int.parse(endTimeParts[0]);
    int endMinute = int.parse(endTimeParts[1]);
    
    // Create start and end datetime
    DateTime startDateTime = DateTime(
      examDate.year,
      examDate.month,
      examDate.day,
      startHour,
      startMinute,
    );
    
    DateTime endDateTime = DateTime(
      examDate.year,
      examDate.month,
      examDate.day,
      endHour,
      endMinute,
    );
    
    // If end time is before start time, it's next day
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
      print('  End time is before start time, adding 1 day');
    }

    // Calculate total exam duration
    final examDuration = endDateTime.difference(startDateTime);
    
    // Debug logging
    print('DEBUG TIMER:');
    print('  Exam date: $examDate');
    print('  Start time: ${_examData!.startTime}');
    print('  End time: ${_examData!.endTime}');
    print('  Start datetime: $startDateTime');
    print('  End datetime: $endDateTime');
    print('  Total exam duration: $examDuration');
    
    // Set the timer to the full exam duration
    _timeRemaining = examDuration;
    print('  Time remaining: $_timeRemaining');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining.inSeconds > 0) {
            _timeRemaining = Duration(seconds: _timeRemaining.inSeconds - 1);
          } else {
            _timer?.cancel();
            // Exam time is up
            _showTimeUpDialog();
          }
        });
      }
    });
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _selectAnswer(int questionId, int optionId) {
    setState(() {
      _selectedAnswers[questionId] = optionId;
    });
  }

  void _nextQuestion() {
    if (_examData != null && _currentQuestionIndex < _examData!.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitExam() async {
    if (_isSubmitting || _hasSubmitted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Calculate score
      int correctAnswers = 0;
      int totalAnswered = _selectedAnswers.length;
      
      print('DEBUG: Total questions: ${_examData!.questions.length}');
      print('DEBUG: Total answered: $totalAnswered');
      print('DEBUG: Selected answers: $_selectedAnswers');
      
      for (final question in _examData!.questions) {
        final selectedOptionId = _selectedAnswers[question.id];
        print('DEBUG: Processing question ${question.id}');
        print('DEBUG: Question text: ${question.questionText}');
        print('DEBUG: Available options:');
        for (final option in question.options) {
          print('  - Option ${option.id}: "${option.text}" (isCorrect: ${option.isCorrect})');
        }
        
        if (selectedOptionId != null) {
          final selectedOption = question.options.firstWhere(
            (option) => option.id == selectedOptionId,
            orElse: () => ExamOption(
              id: 0,
              questionId: question.id,
              text: '',
              isCorrect: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          print('DEBUG: Question ${question.id} - Selected option ${selectedOptionId} - Is correct: ${selectedOption.isCorrect}');
          print('DEBUG: Selected option text: "${selectedOption.text}"');
          if (selectedOption.isCorrect) {
            correctAnswers++;
            print('DEBUG: ✅ Correct answer found for question ${question.id}');
          } else {
            print('DEBUG: ❌ Incorrect answer for question ${question.id}');
          }
        } else {
          print('DEBUG: Question ${question.id} - No answer selected');
        }
        print('---');
      }

      final totalMarks = double.parse(_examData!.totalMarks);
      final marksPerQuestion = double.parse(_examData!.marksPerQuestion);
      final obtainedMarks = correctAnswers * marksPerQuestion;
      
      print('DEBUG: Correct answers: $correctAnswers');
      print('DEBUG: Total marks: $totalMarks');
      print('DEBUG: Marks per question: $marksPerQuestion');
      print('DEBUG: Obtained marks: $obtainedMarks');

      // Submit exam to server
      try {
        final response = await ApiService.post(
          endpoint: 'api/submit-exam',
          json: {
            'exam_id': widget.exam.id,
            'score': obtainedMarks.toInt(),
          },
          useAuth: true,
        );

        if (mounted) {
          _hasSubmitted = true; // Mark as submitted
          
          // Mark exam as completed in the view model
          final examViewModel = Provider.of<ExamViewModel>(context, listen: false);
          examViewModel.markExamAsCompleted(widget.exam.id, obtainedMarks);
          
          // Show score dialog first, then navigate back
          _showScoreDialog(obtainedMarks, totalMarks, correctAnswers, _examData!.questions.length);
          
          // Navigate back after a short delay to ensure dialog is shown
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              Navigator.of(context).pop(); // Go back to exam list
            }
          });
          
          if (response.status) {
            // Show success message after navigation
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🎉 Exam submitted successfully!\nScore: ${obtainedMarks.toInt()}/${totalMarks.toInt()} (${((obtainedMarks/totalMarks)*100).toStringAsFixed(1)}%)'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            });
          } else {
            // Check if it's a duplicate submission error
            if (response.message.contains('already submitted') || response.message.contains('duplicate')) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('📋 Exam was already submitted!\nScore: ${obtainedMarks.toInt()}/${totalMarks.toInt()} (${((obtainedMarks/totalMarks)*100).toStringAsFixed(1)}%)'),
                      backgroundColor: Colors.blue,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              });
            } else {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('💾 Exam completed locally!\nScore: ${obtainedMarks.toInt()}/${totalMarks.toInt()} (${((obtainedMarks/totalMarks)*100).toStringAsFixed(1)}%)'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              });
            }
          }
        }
      } catch (e) {
        // Fallback to local completion if server submission fails
        if (mounted) {
          _hasSubmitted = true; // Mark as submitted even if server failed
          
          // Mark exam as completed in the view model even if server failed
          final examViewModel = Provider.of<ExamViewModel>(context, listen: false);
          examViewModel.markExamAsCompleted(widget.exam.id, obtainedMarks);
          
          // Show score dialog first, then navigate back
          _showScoreDialog(obtainedMarks, totalMarks, correctAnswers, _examData!.questions.length);
          
          // Navigate back after a short delay to ensure dialog is shown
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              Navigator.of(context).pop(); // Go back to exam list
            }
          });
          
          // Check if it's a duplicate submission error
          if (e.toString().contains('already submitted') || e.toString().contains('duplicate')) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📋 Exam was already submitted!\nScore: ${obtainedMarks.toInt()}/${totalMarks.toInt()} (${((obtainedMarks/totalMarks)*100).toStringAsFixed(1)}%)'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            });
          } else {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('💾 Exam completed locally!\nScore: ${obtainedMarks.toInt()}/${totalMarks.toInt()} (${((obtainedMarks/totalMarks)*100).toStringAsFixed(1)}%)'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit exam: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to submit the exam?'),
            SizedBox(height: 1.h),
            Text('Answered: ${_selectedAnswers.length}/${_examData?.questions.length ?? 0}'),
            Text('Unanswered: ${(_examData?.questions.length ?? 0) - _selectedAnswers.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The exam time has expired.'),
            SizedBox(height: 1.h),
            Text('Answered: ${_selectedAnswers.length}/${_examData?.questions.length ?? 0}'),
            Text('Unanswered: ${(_examData?.questions.length ?? 0) - _selectedAnswers.length}'),
            SizedBox(height: 1.h),
            if (_selectedAnswers.isEmpty)
              const Text(
                '⚠️ No answers were selected. The exam will be submitted with a score of 0.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              const Text('Your exam will be submitted with your current answers.'),
          ],
        ),
        actions: [
          if (_selectedAnswers.isNotEmpty) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Allow user to review answers before submitting
                _showSubmitDialog();
              },
              child: const Text('Review Answers'),
            ),
          ],
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedAnswers.isEmpty ? Colors.red : Colors.orange,
            ),
            child: Text(
              _selectedAnswers.isEmpty ? 'Submit (Score: 0)' : 'Submit Now',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showScoreDialog(double obtainedMarks, double totalMarks, int correctAnswers, int totalQuestions) {
    final percentage = (obtainedMarks / totalMarks * 100);
    final incorrectAnswers = _selectedAnswers.length - correctAnswers;
    final unanswered = totalQuestions - _selectedAnswers.length;
    final hasDatabaseIssue = correctAnswers == 0 && _selectedAnswers.isNotEmpty;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasDatabaseIssue ? Icons.warning : 
              percentage >= 70 ? Icons.celebration : 
              percentage >= 50 ? Icons.thumb_up : Icons.thumb_down,
              color: hasDatabaseIssue ? Colors.orange : 
                     percentage >= 70 ? Colors.green : 
                     percentage >= 50 ? Colors.orange : Colors.red,
            ),
            SizedBox(width: 2.w),
            Text(hasDatabaseIssue ? 'Exam Results (Warning)' : 'Exam Results'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Database issue warning
            if (hasDatabaseIssue) ...[
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        '⚠️ All answers marked as incorrect. This may be a database issue - no correct answers are defined for this exam.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
            ],
            
            // Score circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasDatabaseIssue ? Colors.orange.withOpacity(0.1) :
                       percentage >= 70 ? Colors.green.withOpacity(0.1) : 
                       percentage >= 50 ? Colors.orange.withOpacity(0.1) : 
                       Colors.red.withOpacity(0.1),
                border: Border.all(
                  color: hasDatabaseIssue ? Colors.orange :
                         percentage >= 70 ? Colors.green : 
                         percentage >= 50 ? Colors.orange : 
                         Colors.red,
                  width: 4,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: hasDatabaseIssue ? Colors.orange :
                               percentage >= 70 ? Colors.green : 
                               percentage >= 50 ? Colors.orange : 
                               Colors.red,
                      ),
                    ),
                    Text(
                      '${obtainedMarks.toInt()}/${totalMarks.toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 2.h),
            // Score details
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _ScoreRow(label: 'Total Questions', value: '$totalQuestions'),
                  _ScoreRow(label: 'Correct Answers', value: '$correctAnswers', valueColor: Colors.green),
                  _ScoreRow(label: 'Incorrect Answers', value: '$incorrectAnswers', valueColor: Colors.red),
                  _ScoreRow(label: 'Unanswered', value: '$unanswered', valueColor: Colors.grey),
                  _ScoreRow(label: 'Marks Obtained', value: '${obtainedMarks.toInt()} / ${totalMarks.toInt()}'),
                  _ScoreRow(label: 'Percentage', value: '${percentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
            SizedBox(height: 1.h),
            // Performance message
            Text(
              hasDatabaseIssue 
                ? '⚠️ Please contact administrator about exam configuration'
                : percentage >= 70 
                  ? '🎉 Excellent! Well done!' 
                  : percentage >= 50 
                    ? '👍 Good effort! Keep practicing!' 
                    : '📚 Keep studying! You can do better!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: hasDatabaseIssue ? Colors.orange :
                       percentage >= 70 ? Colors.green : 
                       percentage >= 50 ? Colors.orange : 
                       Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasDatabaseIssue ? Colors.orange : Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Exam...'),
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
              SizedBox(height: 2.h),
              Text(
                _error!,
                style: TextStyle(fontSize: 16.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_examData == null || _examData!.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('No Questions'),
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('No questions available for this exam.'),
        ),
      );
    }

    final currentQuestion = _examData!.questions[_currentQuestionIndex];
    final selectedOptionId = _selectedAnswers[currentQuestion.id];

    return Scaffold(
      appBar: AppBar(
        title: Text(_examData!.examName),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            margin: EdgeInsets.only(right: 2.w),
            decoration: BoxDecoration(
              color: _timeRemaining.inMinutes < 5 ? Colors.red : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatTime(_timeRemaining),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: EdgeInsets.all(2.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_examData!.questions.length}',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${_selectedAnswers.length}/${_examData!.questions.length} answered',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _examData!.questions.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                ),
              ],
            ),
          ),
          
          // Exam info header - Using preview screen approach
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.quiz,
                    label: 'Questions',
                    value: '${_examData!.questions.length}',
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.stars,
                    label: 'Marks/Q',
                    value: _examData!.marksPerQuestion,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.assessment,
                    label: 'Total',
                    value: _examData!.totalMarks,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.check_circle,
                    label: 'Answered',
                    value: '${_selectedAnswers.length}',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          
          // Question content - Using preview screen approach
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: _ExamQuestionCard(
                index: _currentQuestionIndex,
                question: currentQuestion,
                selectedOptionId: selectedOptionId,
                onSelected: (optionId) => _selectAnswer(currentQuestion.id, optionId),
              ),
            ),
          ),
          
          // Navigation buttons - Using preview screen approach
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.primaryPurple),
                    ),
                    child: Text('Previous', style: TextStyle(color: AppColors.primaryPurple)),
                  ),
                ),
                SizedBox(width: 2.w),
                if (_currentQuestionIndex < _examData!.questions.length - 1)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Next', style: TextStyle(color: Colors.white)),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasSubmitted ? null : _showSubmitDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasSubmitted ? Colors.grey : AppColors.successGreen,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _hasSubmitted ? 'Already Submitted' : 'Submit & Score',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ScoreRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamQuestionCard extends StatelessWidget {
  final int index;
  final ExamQuestion question;
  final int? selectedOptionId;
  final ValueChanged<int> onSelected;

  const _ExamQuestionCard({
    required this.index,
    required this.question,
    required this.selectedOptionId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Find the correct option
    final correctOption = question.options.firstWhere(
      (option) => option.isCorrect,
      orElse: () => question.options.first, // Fallback if no correct option found
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Q${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          // Options with immediate feedback
          for (int i = 0; i < question.options.length; i++)
            Container(
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: _getOptionBackgroundColor(question.options[i], selectedOptionId, correctOption),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getOptionBorderColor(question.options[i], selectedOptionId, correctOption),
                  width: 2,
                ),
              ),
              child: RadioListTile<int>(
                value: question.options[i].id,
                groupValue: selectedOptionId,
                onChanged: (v) => onSelected(v!),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question.options[i].text,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: _getOptionTextColor(question.options[i], selectedOptionId, correctOption),
                          fontWeight: selectedOptionId == question.options[i].id ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    // Show feedback icons
                    if (selectedOptionId != null) ...[
                      SizedBox(width: 1.w),
                      _getFeedbackIcon(question.options[i], selectedOptionId, correctOption),
                    ],
                  ],
                ),
                dense: true,
                activeColor: _getOptionBorderColor(question.options[i], selectedOptionId, correctOption),
                contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              ),
            ),
          // Show feedback message if an option is selected
          if (selectedOptionId != null) ...[
            SizedBox(height: 1.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: _getFeedbackBackgroundColor(selectedOptionId, correctOption),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getFeedbackBorderColor(selectedOptionId, correctOption),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFeedbackIconData(selectedOptionId, correctOption),
                    color: _getFeedbackIconColor(selectedOptionId, correctOption),
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _getFeedbackMessage(selectedOptionId, correctOption),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: _getFeedbackTextColor(selectedOptionId, correctOption),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getOptionBackgroundColor(ExamOption option, int? selectedId, ExamOption correctOption) {
    if (selectedId == null) {
      return Colors.white;
    }
    
    if (option.id == selectedId) {
      // Selected option
      if (option.isCorrect) {
        return Colors.green.withOpacity(0.1);
      } else {
        return Colors.red.withOpacity(0.1);
      }
    } else if (option.id == correctOption.id) {
      // Correct option (not selected)
      return Colors.green.withOpacity(0.05);
    }
    
    return Colors.white;
  }

  Color _getOptionBorderColor(ExamOption option, int? selectedId, ExamOption correctOption) {
    if (selectedId == null) {
      return option.id == selectedId ? AppColors.primaryPurple : Colors.grey.shade200;
    }
    
    if (option.id == selectedId) {
      // Selected option
      if (option.isCorrect) {
        return Colors.green;
      } else {
        return Colors.red;
      }
    } else if (option.id == correctOption.id) {
      // Correct option (not selected)
      return Colors.green;
    }
    
    return Colors.grey.shade200;
  }

  Color _getOptionTextColor(ExamOption option, int? selectedId, ExamOption correctOption) {
    if (selectedId == null) {
      return Colors.black87;
    }
    
    if (option.id == selectedId) {
      // Selected option
      if (option.isCorrect) {
        return Colors.green.shade800;
      } else {
        return Colors.red.shade800;
      }
    } else if (option.id == correctOption.id) {
      // Correct option (not selected)
      return Colors.green.shade700;
    }
    
    return Colors.black87;
  }

  Widget _getFeedbackIcon(ExamOption option, int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return const SizedBox.shrink();
    
    if (option.id == selectedId) {
      if (option.isCorrect) {
        return Icon(Icons.check_circle, color: Colors.green, size: 20);
      } else {
        return Icon(Icons.cancel, color: Colors.red, size: 20);
      }
    } else if (option.id == correctOption.id) {
      return Icon(Icons.check_circle_outline, color: Colors.green, size: 20);
    }
    
    return const SizedBox.shrink();
  }

  Color _getFeedbackBackgroundColor(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return Colors.transparent;
    
    if (selectedId == correctOption.id) {
      return Colors.green.withOpacity(0.1);
    } else {
      return Colors.red.withOpacity(0.1);
    }
  }

  Color _getFeedbackBorderColor(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return Colors.transparent;
    
    if (selectedId == correctOption.id) {
      return Colors.green.withOpacity(0.3);
    } else {
      return Colors.red.withOpacity(0.3);
    }
  }

  IconData _getFeedbackIconData(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return Icons.help_outline;
    
    if (selectedId == correctOption.id) {
      return Icons.check_circle;
    } else {
      return Icons.cancel;
    }
  }

  Color _getFeedbackIconColor(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return Colors.grey;
    
    if (selectedId == correctOption.id) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  Color _getFeedbackTextColor(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return Colors.grey;
    
    if (selectedId == correctOption.id) {
      return Colors.green.shade800;
    } else {
      return Colors.red.shade800;
    }
  }

  String _getFeedbackMessage(int? selectedId, ExamOption correctOption) {
    if (selectedId == null) return '';
    
    if (selectedId == correctOption.id) {
      return '🎉 Correct! Well done!';
    } else {
      return '❌ Incorrect. The correct answer is highlighted in green.';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 20),
          SizedBox(height: 0.5.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }
}
