import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../viewmodels/exam_view_model.dart';
import '../models/exam.dart';
import 'exam_taking_screen.dart';

class OnlineExamScreen extends StatefulWidget {
  const OnlineExamScreen({super.key});

  @override
  State<OnlineExamScreen> createState() => _OnlineExamScreenState();
}

class _OnlineExamScreenState extends State<OnlineExamScreen> {
  bool _useTableView = true;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamViewModel>().loadExams();
    });
    
    // Start timer to refresh exam status every minute
    _startStatusTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        context.read<ExamViewModel>().refreshExamStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExamViewModel>(
      builder: (context, vm, _) {
        return Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
            iconTheme: const IconThemeData(color: Colors.black),
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(vm),
                SizedBox(height: 2.h),
                if (vm.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (vm.error != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                          SizedBox(height: 2.h),
                          Text(
                            vm.error!,
                            style: TextStyle(color: Colors.red, fontSize: 12.sp),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 2.h),
                          ElevatedButton(
                            onPressed: () => vm.loadExams(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: vm.loadExams,
                      child: vm.exams.isEmpty
                          ? _buildEmptyState(vm)
                          : (_useTableView ? _buildTable(vm) : _buildCardView(vm)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(ExamViewModel vm) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search exams...',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: vm.setSearchQuery,
          ),
        ),
        SizedBox(width: 3.w),
        Tooltip(
          message: _useTableView ? 'Switch to card view' : 'Switch to table view',
          child: InkWell(
            onTap: () => setState(() => _useTableView = !_useTableView),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_useTableView ? Icons.view_agenda_outlined : Icons.table_chart_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ExamViewModel vm) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 10.h),
        Icon(Icons.quiz_outlined, size: 64.sp, color: Colors.grey.shade400),
        SizedBox(height: 2.h),
        Center(
          child: Text(
            vm.isLoading ? 'Loading exams...' : 'No exams found',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 1.h),
        Center(
          child: Text(
            vm.isLoading 
                ? 'Please wait while we fetch your exams'
                : 'Create your first exam to get started',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardView(ExamViewModel vm) {
    final exams = vm.filteredExams;
    return ListView.separated(
      itemCount: exams.length,
      separatorBuilder: (_, __) => SizedBox(height: 2.h),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _ExamCard(
          exam: exam,
          onTakeTest: () => _handleTakeTest(exam, vm),
          onViewResults: () => _showExamResults(exam),
        );
      },
    );
  }

  Widget _buildTable(ExamViewModel vm) {
    final exams = vm.filteredExams;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 180.w),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          primary: true,
          child: DataTable(
            headingTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            dataTextStyle: const TextStyle(color: Colors.black),
            columns: const [
              DataColumn(label: Text('Exam Name', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Book', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Start Time', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('End Time', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Duration', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Questions', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Total Marks', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Status', style: TextStyle(color: Colors.black))),
              DataColumn(label: Text('Actions', style: TextStyle(color: Colors.black))),
            ],
            rows: exams.map((exam) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          exam.examName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (exam.description.isNotEmpty)
                          Text(
                            exam.description,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(exam.bookName)),
                  DataCell(Text(exam.formattedStartTime)),
                  DataCell(Text(exam.formattedEndTime)),
                  DataCell(Text(exam.durationText)),
                  DataCell(Text('${exam.totalQuestions}')),
                  DataCell(Text('${exam.totalMarks.toInt()}')),
                  DataCell(
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: exam.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: exam.statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        exam.statusText,
                        style: TextStyle(
                          color: exam.statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                  ),
                  DataCell(_buildActionButtons(exam, vm)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(Exam exam, ExamViewModel vm) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (exam.status == ExamStatus.live)
          ElevatedButton(
            onPressed: () => _handleTakeTest(exam, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Take Test',
              style: TextStyle(fontSize: 10.sp, color: Colors.white),
            ),
          )
        else if (exam.status == ExamStatus.upcoming)
          Text(
            'Starts ${exam.timeUntilStart}',
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (exam.status == ExamStatus.expired)
          Text(
            'Expired',
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          )
        else if (exam.status == ExamStatus.completed)
          ElevatedButton(
            onPressed: () => _showExamResults(exam),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              minimumSize: Size.zero,
            ),
            child: Text(
              'View Results',
              style: TextStyle(fontSize: 10.sp, color: Colors.white),
            ),
          ),
      ],
    );
  }


  void _handleTakeTest(Exam exam, ExamViewModel vm) {
    // Double-check status before allowing exam start
    final currentStatus = exam.status;
    
    if (currentStatus == ExamStatus.live) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Exam'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you ready to start "${exam.examName}"?'),
              SizedBox(height: 1.h),
              Text('Duration: ${exam.durationText}'),
              Text('Total Questions: ${exam.totalQuestions}'),
              Text('Total Marks: ${exam.totalMarks.toInt()}'),
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
                // Navigate to exam taking screen
                _showExamTakingScreen(exam);
              },
              child: const Text('Start'),
            ),
          ],
        ),
      );
    } else {
      // Show appropriate message based on status
      String message;
      switch (currentStatus) {
        case ExamStatus.upcoming:
          message = 'Exam has not started yet. It will begin ${exam.timeUntilStart}.';
          break;
        case ExamStatus.expired:
          message = 'This exam has expired and is no longer available.';
          break;
        case ExamStatus.completed:
          message = 'You have already completed this exam.';
          break;
        default:
          message = 'This exam is not available at the moment.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showExamTakingScreen(Exam exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExamTakingScreen(exam: exam),
      ),
    );
  }

  void _showExamResults(Exam exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Results: ${exam.examName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Marks: ${exam.totalMarks.toInt()}'),
            Text('Obtained Marks: ${exam.obtainedMarks?.toInt() ?? 0}'),
            Text('Percentage: ${((exam.obtainedMarks ?? 0) / exam.totalMarks * 100).toStringAsFixed(1)}%'),
            Text('Completed At: ${exam.completedAt?.toString() ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}

class _ExamCard extends StatelessWidget {
  final Exam exam;
  final VoidCallback onTakeTest;
  final VoidCallback onViewResults;

  const _ExamCard({
    required this.exam,
    required this.onTakeTest,
    required this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.examName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      if (exam.description.isNotEmpty) ...[
                        SizedBox(height: 0.5.h),
                        Text(
                          exam.description,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: exam.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: exam.statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    exam.statusText,
                    style: TextStyle(
                      color: exam.statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.book,
                    label: 'Book',
                    value: exam.bookName,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.schedule,
                    label: 'Duration',
                    value: exam.durationText,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.quiz,
                    label: 'Questions',
                    value: '${exam.totalQuestions}',
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.grade,
                    label: 'Total Marks',
                    value: '${exam.totalMarks.toInt()}',
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.play_arrow,
                    label: 'Start Time',
                    value: exam.formattedStartTime,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.stop,
                    label: 'End Time',
                    value: exam.formattedEndTime,
                  ),
                ),
              ],
            ),
            if (exam.status == ExamStatus.completed) ...[
              SizedBox(height: 1.h),
              _InfoItem(
                icon: Icons.check_circle,
                label: 'Obtained Marks',
                value: '${exam.obtainedMarks?.toInt() ?? 0}/${exam.totalMarks.toInt()}',
              ),
            ],
            SizedBox(height: 2.h),
            Row(
              children: [
                if (exam.status == ExamStatus.live)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTakeTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      label: const Text('Take Test', style: TextStyle(color: Colors.white)),
                    ),
                  )
                else if (exam.status == ExamStatus.completed)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onViewResults,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.visibility, color: Colors.white),
                      label: const Text('View Results', style: TextStyle(color: Colors.white)),
                    ),
                  )
                else if (exam.status == ExamStatus.upcoming)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: Text(
                          'Starts ${exam.timeUntilStart}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (exam.status == ExamStatus.expired)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          'Expired',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey.shade600),
        SizedBox(width: 1.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

