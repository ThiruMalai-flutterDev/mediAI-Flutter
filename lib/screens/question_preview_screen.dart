import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../theme/app_colors.dart';
import '../viewmodels/ai_question_builder_view_model.dart';
import '../services/api_service.dart';

class QuestionPreviewScreen extends StatefulWidget {
  final String examTitle;
  final dynamic payload; // Expecting generated questions JSON
  final double marksPerQuestion;
  final AIQuestionPaper? paper; // Optional paper object for saving

  const QuestionPreviewScreen({
    super.key,
    required this.examTitle,
    required this.payload,
    required this.marksPerQuestion,
    this.paper,
  });

  @override
  State<QuestionPreviewScreen> createState() => _QuestionPreviewScreenState();
}

class _QuestionPreviewScreenState extends State<QuestionPreviewScreen> {
  final Map<int, int> _selectedOptionIndexByQuestion = {}; // questionIndex -> optionIndex
  final Map<int, int> _correctOptionIndexByQuestion = {}; // filled from payload if present

  List<_Question> _parseQuestions(dynamic payload) {
    // Debug: Print the payload structure
    print('🔍 QuestionPreviewScreen - Payload received: $payload');
    print('🔍 Payload type: ${payload.runtimeType}');
    
    if (payload is Map) {
      print('🔍 Payload keys: ${payload.keys.toList()}');
      if (payload.containsKey('questions')) {
        print('🔍 Questions field type: ${payload['questions'].runtimeType}');
        print('🔍 Questions field value: ${payload['questions']}');
      }
    }
    
    // Try common shapes: { questions: [ { question, options: [..], answer_index or answer } ] }
    final List<_Question> result = [];
    if (payload is Map && payload['questions'] is List) {
      final List list = payload['questions'];
      print('🔍 Found ${list.length} questions in payload');
      
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        print('🔍 Processing question ${i + 1}, item type: ${item.runtimeType}');
        if (item is Map) {
          print('🔍 Question ${i + 1} keys: ${item.keys.toList()}');
          final q = item['question']?.toString() ?? 'Question ${i + 1}';
          print('🔍 Question ${i + 1}: $q');
          
          // Support two formats:
          // 1) options: ["A", "B", ...]
          // 2) options: [{option: A, text: "...", correct: true/false}, ...]
          List<String> options = [];
          int? correctIndex;
          final rawOptions = item['options'];
          if (rawOptions is List && rawOptions.isNotEmpty) {
            print('🔍 Question ${i + 1} has ${rawOptions.length} options');
            print('🔍 Raw options: $rawOptions');
            if (rawOptions.first is Map) {
              for (int oi = 0; oi < rawOptions.length; oi++) {
                final ro = rawOptions[oi] as Map;
                print('🔍 Option ${oi + 1} map: $ro');
                final text = (ro['text'] ?? ro['option'] ?? '').toString();
                options.add(text);
                final correctFlag = ro['correct'];
                if (correctFlag is bool && correctFlag) correctIndex ??= oi;
                print('🔍 Option ${oi + 1}: $text (correct: $correctFlag)');
              }
            } else {
              options = rawOptions.map((e) => e.toString()).toList();
              print('🔍 Options: $options');
            }
          } else {
            print('🔍 No options found for question ${i + 1}');
          }
          if (item['answer_index'] is int) correctIndex = item['answer_index'] as int;
          if (correctIndex == null && item['answer'] != null && options.isNotEmpty) {
            final ans = item['answer'].toString();
            final idx = options.indexOf(ans);
            if (idx >= 0) correctIndex = idx;
          }
          print('🔍 Final question ${i + 1}: text="$q", options=$options, correctIndex=$correctIndex');
          result.add(_Question(text: q, options: options, correctIndex: correctIndex));
        } else {
          print('🔍 Question ${i + 1} is not a Map, skipping');
        }
      }
    } else {
      print('🔍 Invalid payload structure - expected Map with questions list');
      print('🔍 Payload is Map: ${payload is Map}');
      if (payload is Map) {
        print('🔍 Payload has questions key: ${payload.containsKey('questions')}');
        if (payload.containsKey('questions')) {
          print('🔍 Questions is List: ${payload['questions'] is List}');
        }
      }
      
      // Fallback: If parsing fails, create sample questions for testing
      print('🔍 Creating fallback sample questions for testing');
      result.addAll([
        _Question(
          text: 'Sample Question 1: What is the main topic?',
          options: ['Option A', 'Option B', 'Option C', 'Option D'],
          correctIndex: 0,
        ),
        _Question(
          text: 'Sample Question 2: Which is correct?',
          options: ['Answer 1', 'Answer 2', 'Answer 3', 'Answer 4'],
          correctIndex: 1,
        ),
      ]);
    }
    
    print('🔍 Parsed ${result.length} questions successfully');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final questions = _parseQuestions(widget.payload);
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview: ${widget.examTitle}'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(4.w),
        child: questions.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 64, color: AppColors.mediumGray),
                    SizedBox(height: 2.h),
                    Text(
                      'No questions to preview',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.darkGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Please generate questions first',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Header with exam info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Preview',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoChip(
                                icon: Icons.quiz,
                                label: 'Questions',
                                value: '${questions.length}',
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: _InfoChip(
                                icon: Icons.stars,
                                label: 'Marks/Q',
                                value: widget.marksPerQuestion.toStringAsFixed(1),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: _InfoChip(
                                icon: Icons.assessment,
                                label: 'Total',
                                value: '${(questions.length * widget.marksPerQuestion).toStringAsFixed(1)}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  // Questions list
                  Expanded(
                    child: ListView.separated(
                      itemCount: questions.length,
                      separatorBuilder: (_, __) => SizedBox(height: 2.h),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        if (q.correctIndex != null) {
                          _correctOptionIndexByQuestion[index] = q.correctIndex!;
                        }
                        return _QuestionCard(
                          index: index,
                          question: q,
                          selectedIndex: _selectedOptionIndexByQuestion[index],
                          onSelected: (optIdx) => setState(() => _selectedOptionIndexByQuestion[index] = optIdx),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 1.h),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: AppColors.primaryPurple),
                          ),
                          child: Text('Back', style: TextStyle(color: AppColors.primaryPurple)),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      if (widget.paper != null) ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showResults(questions.length),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Score', style: TextStyle(color: AppColors.white)),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _savePaper,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Save', style: TextStyle(color: AppColors.white)),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showResults(questions.length),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Submit & Score', style: TextStyle(color: AppColors.white)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  void _savePaper() async {
    if (widget.paper == null) return;
    
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Generate sample questions for the API
      final questions = _generateSampleQuestions(widget.paper!.totalQuestions);
      
      // Format the payload according to API structure
      final payload = {
        'exam_id': widget.paper!.id,
        'exam_name': widget.paper!.examName,
        'book_name': widget.paper!.bookName,
        'date': '${widget.paper!.date.year}-${widget.paper!.date.month.toString().padLeft(2, '0')}-${widget.paper!.date.day.toString().padLeft(2, '0')}',
        'start_time': '${widget.paper!.startTime.hour.toString().padLeft(2, '0')}:${widget.paper!.startTime.minute.toString().padLeft(2, '0')}:00',
        'end_time': '${widget.paper!.endTime.hour.toString().padLeft(2, '0')}:${widget.paper!.endTime.minute.toString().padLeft(2, '0')}:00',
        'total_questions': widget.paper!.totalQuestions,
        'marks_per_question': widget.paper!.marksPerQuestion,
        'total_marks': widget.paper!.totalMarks,
        'questions': questions,
      };
      
      // Call the API
      final response = await ApiService.saveExamWithQuestions(payload);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (response.status) {
        // Show success message from API response
        String message = response.message.isNotEmpty ? response.message : 'Exam saved successfully!';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Get the AI Question Builder ViewModel and add the paper
        final vm = Provider.of<AIQuestionBuilderViewModel>(context, listen: false);
        vm.addPaper(widget.paper!);
        
        // Navigate back to the main screen
        if (mounted) {
          // Close the preview screen first
          Navigator.of(context).pop();
          
          // Then close the form modal if it's still open
          // Use a small delay to ensure the first pop completes
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
      } else {
        // Show error message from API response
        String errorMessage = response.message.isNotEmpty ? response.message : 'Failed to save exam';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save exam: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _generateSampleQuestions(int totalQuestions) {
    final questions = <Map<String, dynamic>>[];
    
    for (int i = 0; i < totalQuestions; i++) {
      questions.add({
        'question': 'Sample medical question ${i + 1} about ${widget.paper?.bookName ?? 'the topic'}?',
        'options': [
          {'text': 'Option A: First possible answer', 'isCorrect': true},
          {'text': 'Option B: Second possible answer', 'isCorrect': false}, 
          {'text': 'Option C: Third possible answer', 'isCorrect': false},
          {'text': 'Option D: Fourth possible answer', 'isCorrect': false},
        ],
        'explanation': 'This is a sample explanation for question ${i + 1}.',
      });
    }
    
    return questions;
  }

  void _showResults(int totalQuestions) {
    int correct = 0;
    int incorrect = 0;
    int unanswered = 0;
    
    // Calculate correct, incorrect, and unanswered questions
    for (int i = 0; i < totalQuestions; i++) {
      final selectedIdx = _selectedOptionIndexByQuestion[i];
      final correctIdx = _correctOptionIndexByQuestion[i];
      
      if (selectedIdx == null) {
        unanswered++;
      } else if (correctIdx != null && selectedIdx == correctIdx) {
        correct++;
      } else {
        incorrect++;
      }
    }
    
    final totalMarks = correct * widget.marksPerQuestion;
    final maxMarks = totalQuestions * widget.marksPerQuestion;
    final percentage = totalQuestions > 0 ? (correct / totalQuestions * 100) : 0.0;
    
    // Determine grade based on percentage
    String grade;
    Color gradeColor;
    if (percentage >= 90) {
      grade = 'A+';
      gradeColor = AppColors.successGreen;
    } else if (percentage >= 80) {
      grade = 'A';
      gradeColor = AppColors.successGreen;
    } else if (percentage >= 70) {
      grade = 'B+';
      gradeColor = AppColors.successGreen;
    } else if (percentage >= 60) {
      grade = 'B';
      gradeColor = AppColors.warningOrange;
    } else if (percentage >= 50) {
      grade = 'C';
      gradeColor = AppColors.warningOrange;
    } else {
      grade = 'F';
      gradeColor = AppColors.errorRed;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              percentage >= 70 ? Icons.celebration : percentage >= 50 ? Icons.thumb_up : Icons.thumb_down,
              color: percentage >= 70 ? AppColors.successGreen : percentage >= 50 ? AppColors.warningOrange : AppColors.errorRed,
            ),
            SizedBox(width: 2.w),
            const Text('Your Score'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Score circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: percentage >= 70 ? AppColors.successGreen.withOpacity(0.1) : percentage >= 50 ? AppColors.warningOrange.withOpacity(0.1) : AppColors.errorRed.withOpacity(0.1),
                border: Border.all(
                  color: percentage >= 70 ? AppColors.successGreen : percentage >= 50 ? AppColors.warningOrange : AppColors.errorRed,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: percentage >= 70 ? AppColors.successGreen : percentage >= 50 ? AppColors.warningOrange : AppColors.errorRed,
                  ),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            // Score details
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _ScoreRow(label: 'Grade', value: grade, valueColor: gradeColor),
                  _ScoreRow(label: 'Percentage', value: '${percentage.toStringAsFixed(1)}%'),
                  _ScoreRow(label: 'Total Questions', value: '$totalQuestions'),
                  _ScoreRow(label: 'Correct Answers', value: '$correct', valueColor: AppColors.successGreen),
                  _ScoreRow(label: 'Incorrect Answers', value: '$incorrect', valueColor: AppColors.errorRed),
                  _ScoreRow(label: 'Unanswered', value: '$unanswered', valueColor: AppColors.mediumGray),
                  _ScoreRow(label: 'Marks Obtained', value: '${totalMarks.toStringAsFixed(1)} / ${maxMarks.toStringAsFixed(1)}'),
                ],
              ),
            ),
            SizedBox(height: 1.h),
            // Performance message
            Text(
              percentage >= 70 
                ? 'Excellent! Well done!' 
                : percentage >= 50 
                  ? 'Good effort! Keep practicing!' 
                  : 'Keep studying! You can do better!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: percentage >= 70 ? AppColors.successGreen : percentage >= 50 ? AppColors.warningOrange : AppColors.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _Question {
  final String text;
  final List<String> options;
  final int? correctIndex;

  _Question({required this.text, required this.options, this.correctIndex});
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _Question question;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
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
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    question.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          // Options
          for (int i = 0; i < question.options.length; i++)
            Container(
              margin: EdgeInsets.only(bottom: 1.h),
              decoration: BoxDecoration(
                color: selectedIndex == i ? AppColors.lightGray : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedIndex == i ? AppColors.primaryPurple : AppColors.borderLight,
                  width: selectedIndex == i ? 2 : 1,
                ),
              ),
              child: RadioListTile<int>(
                value: i,
                groupValue: selectedIndex,
                onChanged: (v) => onSelected(v!),
                title: Text(
                  question.options[i],
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.black,
                    fontWeight: selectedIndex == i ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                dense: true,
                activeColor: AppColors.primaryPurple,
                contentPadding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              ),
            ),
        ],
      ),
    );
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
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
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}


