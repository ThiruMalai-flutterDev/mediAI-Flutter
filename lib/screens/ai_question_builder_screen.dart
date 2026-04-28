import 'package:dr_jebasingh_onco_ai/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../theme/app_colors.dart';
import '../viewmodels/ai_question_builder_view_model.dart';
import '../viewmodels/book_view_model.dart';
import '../models/book.dart';
import 'question_preview_screen.dart';

class AIQuestionBuilderScreen extends StatefulWidget {
  const AIQuestionBuilderScreen({super.key});

  @override
  State<AIQuestionBuilderScreen> createState() =>
      _AIQuestionBuilderScreenState();
}

class _AIQuestionBuilderScreenState extends State<AIQuestionBuilderScreen> {
  @override
  void initState() {
    context.read<AIQuestionBuilderViewModel>().loadExams();
    context.read<BookViewModel>().loadBooks();
    super.initState();
  }

  bool _useTableView = true;
  @override
  Widget build(BuildContext context) {
    return Consumer<AIQuestionBuilderViewModel>(
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
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: vm.loadExams,
                    child: vm.papers.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 10.h),
                              // _InitialLoader(onLoad: () => vm.loadExams()),
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h, top: 2.h),
                                child: Center(
                                  child: Text(
                                    'No data found',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11.sp),
                                  ),
                                ),
                              ),
                            ],
                          )
                        // : (_useTableView ? _buildTable(vm) :
                        : _buildList(vm),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(AIQuestionBuilderViewModel vm) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by book name...',
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
        // Tooltip(
        //   message:
        //       _useTableView ? 'Switch to card view' : 'Switch to table view',
        //   child: InkWell(
        //     onTap: () => setState(() => _useTableView = !_useTableView),
        //     borderRadius: BorderRadius.circular(12),
        //     child: Container(
        //       padding: EdgeInsets.all(2.w),
        //       decoration: BoxDecoration(
        //         color: Colors.grey.shade200,
        //         borderRadius: BorderRadius.circular(12),
        //       ),
        //       child: Icon(_useTableView
        //           ? Icons.view_agenda_outlined
        //           : Icons.table_chart_outlined),
        //     ),
        //   ),
        // ),
        SizedBox(width: 3.w),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.6.h),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _openAddEditSheet(context, vm),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add New', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildList(AIQuestionBuilderViewModel vm) {
    return ListView.separated(
      itemCount: vm.papers.length,
      separatorBuilder: (_, __) => SizedBox(height: 2.h),
      itemBuilder: (context, index) {
        final paper = vm.papers[index];
        return _PaperCard(
          paper: paper,
          onEdit: () => _openAddEditSheet(context, vm, existing: paper),
          onDelete: () => vm.deletePaper(paper.id),
        );
      },
    );
  }

  Widget _buildTable(AIQuestionBuilderViewModel vm) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 160.w),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          primary: true,
          child: DataTable(
            headingTextStyle: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600),
            dataTextStyle: const TextStyle(color: Colors.black),
            columns: const [
              DataColumn(
                  label: Text('ID', style: TextStyle(color: Colors.black))),
              DataColumn(
                  label:
                      Text('Exam Name', style: TextStyle(color: Colors.black))),
              DataColumn(
                  label:
                      Text('Book Name', style: TextStyle(color: Colors.black))),
              DataColumn(
                  label: Text('Date', style: TextStyle(color: Colors.black))),
              DataColumn(
                  label: Text('Start Time',
                      style: TextStyle(color: Colors.black))),
              DataColumn(
                  label:
                      Text('End Time', style: TextStyle(color: Colors.black))),
              DataColumn(
                  label: Text('Total Questions',
                      style: TextStyle(color: Colors.black))),
              DataColumn(
                  label: Text('Marks per Question',
                      style: TextStyle(color: Colors.black))),
              DataColumn(
                  label: Text('Total Marks',
                      style: TextStyle(color: Colors.black))),
            ],
            rows: vm.papers.map((p) {
              return DataRow(cells: [
                DataCell(
                    Text(p.id, style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.examName,
                    style: const TextStyle(color: Colors.black))),
                DataCell(Consumer<BookViewModel>(
                  builder: (context, bookVm, _) => Text(
                    bookVm.getBookByName(p.bookName)?.title ?? p.bookName,
                    style: const TextStyle(color: Colors.black),
                  ),
                )),
                DataCell(Text(formatDate(p.date),
                    style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.startTime.format(context),
                    style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.endTime.format(context),
                    style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.totalQuestions.toString(),
                    style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.marksPerQuestion.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.black))),
                DataCell(Text(p.totalMarks.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.black))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddEditSheet(
      BuildContext context, AIQuestionBuilderViewModel vm,
      {AIQuestionPaper? existing}) async {
    // Books will be loaded via search when user starts typing
    final formKey = GlobalKey<FormState>();
    final examNameController =
        TextEditingController(text: existing?.examName ?? '');
    final bookNameController =
        TextEditingController(text: existing?.bookName ?? '');
    DateTime? date = existing?.date;
    TimeOfDay? startTime = existing?.startTime;
    TimeOfDay? endTime = existing?.endTime;
    final totalQuestionsController =
        TextEditingController(text: existing?.totalQuestions.toString() ?? '');
    final marksPerQuestionController = TextEditingController(
        text: existing?.marksPerQuestion.toString() ?? '');
    AiOption aiOption = existing?.aiOption ?? AiOption.common;
    // Chapter option removed from UI; default to Chapter to allow optional chapter names
    ChapterOption chapterOption = ChapterOption.chapter;
    // Chapter input (typeable)
    final TextEditingController chapterTextController = TextEditingController();
    List<String> selectedChapterIds = existing?.chapterIds ?? [];
    List<String> selectedHeadingIds = existing?.headingIds ?? [];
    bool isGenerating = false;
    bool isPreviewing = false;
    dynamic generatedPayload;

    double computeTotalMarks() {
      final tq = int.tryParse(totalQuestionsController.text) ?? 0;
      final mpq = double.tryParse(marksPerQuestionController.text) ?? 0;
      return tq * mpq;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 2.h,
            left: 4.w,
            right: 4.w,
            top: 2.h,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.black),
                            tooltip: 'Back',
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              existing == null
                                  ? 'Add Question Paper'
                                  : 'Edit Question Paper',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      // Chapter/Non-Chapter option removed
                      // _FormField(
                      //   label: 'AI Options',
                      //   child: Row(
                      //     children: [
                      //       Flexible(
                      //         child: Row(
                      //           mainAxisSize: MainAxisSize.min,
                      //           children: [
                      //             Radio<AiOption>(
                      //               value: AiOption.common,
                      //               groupValue: aiOption,
                      //               onChanged: (v) => setSheetState(
                      //                   () => aiOption = v ?? AiOption.common),
                      //             ),
                      //             const Text('Common Ai'),
                      //           ],
                      //         ),
                      //       ),
                      //       SizedBox(width: 4.w),
                      //       Flexible(
                      //         child: Row(
                      //           mainAxisSize: MainAxisSize.min,
                      //           children: [
                      //             Radio<AiOption>(
                      //               value: AiOption.mediAi,
                      //               groupValue: aiOption,
                      //               onChanged: (v) => setSheetState(
                      //                   () => aiOption = v ?? AiOption.mediAi),
                      //             ),
                      //             const Text('MediAi'),
                      //           ],
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      _FormField(
                          label: 'Exam Name',
                          child: TextFormField(
                            controller: examNameController,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          )),
                      _FormField(
                          label: 'Books Name',
                          child: _BookDropdown(
                            initial: bookNameController.text,
                            chapterOption: chapterOption,
                            onChanged: (val) {
                              bookNameController.text = val ?? '';
                              chapterTextController.clear();
                              selectedChapterIds = [];
                              selectedHeadingIds = [];
                            },
                            onChaptersChanged: (chapters) {
                              selectedChapterIds = chapters;
                            },
                            onHeadingsChanged: (headings) {
                              selectedHeadingIds = headings;
                            },
                          )),
                      _FormField(
                          label: 'Date',
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) {
                                  final theme = Theme.of(context);
                                  return Theme(
                                    data: theme.copyWith(
                                      textTheme: theme.textTheme.apply(
                                        bodyColor: Colors.black,
                                        displayColor: Colors.black,
                                      ),
                                      colorScheme: theme.colorScheme.copyWith(
                                        onSurface: Colors.black,
                                        onPrimary: Colors.white,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null)
                                setSheetState(() => date = picked);
                            },
                            child: Text(date == null
                                ? 'Select date'
                                : formatDate(date!)),
                          )),
                      Row(
                        children: [
                          Expanded(
                              child: _FormField(
                                  label: 'Start Time',
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            startTime ?? TimeOfDay.now(),
                                        builder: (context, child) {
                                          final theme = Theme.of(context);
                                          return Theme(
                                            data: theme.copyWith(
                                              textTheme: theme.textTheme.apply(
                                                bodyColor: Colors.black,
                                                displayColor: Colors.black,
                                              ),
                                              colorScheme:
                                                  theme.colorScheme.copyWith(
                                                onSurface: Colors.black,
                                                onPrimary: Colors.white,
                                              ),
                                              textButtonTheme:
                                                  TextButtonThemeData(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.black,
                                                ),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null)
                                        setSheetState(() => startTime = picked);
                                    },
                                    child: Text(startTime == null
                                        ? 'Select'
                                        : startTime!.format(context)),
                                  ))),
                          SizedBox(width: 3.w),
                          Expanded(
                              child: _FormField(
                                  label: 'End Time',
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: endTime ?? TimeOfDay.now(),
                                        builder: (context, child) {
                                          final theme = Theme.of(context);
                                          return Theme(
                                            data: theme.copyWith(
                                              textTheme: theme.textTheme.apply(
                                                bodyColor: Colors.black,
                                                displayColor: Colors.black,
                                              ),
                                              colorScheme:
                                                  theme.colorScheme.copyWith(
                                                onSurface: Colors.black,
                                                onPrimary: Colors.white,
                                              ),
                                              textButtonTheme:
                                                  TextButtonThemeData(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.black,
                                                ),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null)
                                        setSheetState(() => endTime = picked);
                                    },
                                    child: Text(endTime == null
                                        ? 'Select'
                                        : endTime!.format(context)),
                                  ))),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                              child: _FormField(
                                  label: 'Total Questions',
                                  child: TextFormField(
                                    controller: totalQuestionsController,
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        (int.tryParse(v ?? '') == null)
                                            ? 'Enter number'
                                            : null,
                                    onChanged: (_) => setSheetState(() {}),
                                  ))),
                          SizedBox(width: 3.w),
                          Expanded(
                              child: _FormField(
                                  label: 'Marks per Question',
                                  child: TextFormField(
                                    controller: marksPerQuestionController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (v) =>
                                        (double.tryParse(v ?? '') == null)
                                            ? 'Enter number'
                                            : null,
                                    onChanged: (_) => setSheetState(() {}),
                                  ))),
                        ],
                      ),
                      _FormField(
                          label: 'Total Marks',
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 1.6.h, horizontal: 3.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            child: Text(computeTotalMarks().toStringAsFixed(2)),
                          )),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (isGenerating || isPreviewing)
                                  ? null
                                  : () {
                                      Navigator.of(context).maybePop();
                                    },
                              child: const Text('Cancel'),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: (isGenerating || isPreviewing)
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate() ||
                                          date == null ||
                                          startTime == null ||
                                          endTime == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Please complete all fields')),
                                        );
                                        return;
                                      }
                                      setSheetState(() => isPreviewing = true);
                                      try {
                                        final paper = AIQuestionPaper(
                                          id: existing?.id ??
                                              UniqueKey().toString(),
                                          examName:
                                              examNameController.text.trim(),
                                          bookName:
                                              bookNameController.text.trim(),
                                          date: date!,
                                          startTime: startTime!,
                                          endTime: endTime!,
                                          totalQuestions: int.parse(
                                              totalQuestionsController.text),
                                          marksPerQuestion: double.parse(
                                              marksPerQuestionController.text),
                                          totalMarks: computeTotalMarks(),
                                          aiOption: aiOption,
                                          chapterOption: chapterOption,
                                          chapterIds: selectedChapterIds,
                                          headingIds: selectedHeadingIds,
                                        );

                                        final res = await vm.generateQuestions(
                                          paper,
                                          chapterIds: selectedChapterIds.isNotEmpty ? selectedChapterIds : null,
                                          headingIds: selectedHeadingIds.isNotEmpty ? selectedHeadingIds : null,
                                          difficulty: 'medium', // Default to medium as requested
                                        );

                                        if (context.mounted) {
                                          if (res.status && res.data != null) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    QuestionPreviewScreen(
                                                  examTitle: paper.examName,
                                                  payload: res.data,
                                                  marksPerQuestion:
                                                      paper.marksPerQuestion,
                                                  paper: paper,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed to generate preview: ${res.message}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted)
                                          setSheetState(
                                              () => isPreviewing = false);
                                      }
                                    },
                              child: isPreviewing
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child:
                                              const CircularProgressIndicator(
                                                  strokeWidth: 2),
                                        ),
                                        SizedBox(width: 2.w),
                                        const Flexible(
                                          child: Text(
                                            'Loading...',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Preview'),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: isGenerating
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate() ||
                                          date == null ||
                                          startTime == null ||
                                          endTime == null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Please complete all fields')),
                                        );
                                        return;
                                      }
                                      final paper = AIQuestionPaper(
                                        id: existing?.id ??
                                            UniqueKey().toString(),
                                        examName:
                                            examNameController.text.trim(),
                                        bookName:
                                            bookNameController.text.trim(),
                                        date: date!,
                                        startTime: startTime!,
                                        endTime: endTime!,
                                        totalQuestions: int.parse(
                                            totalQuestionsController.text),
                                        marksPerQuestion: double.parse(
                                            marksPerQuestionController.text),
                                        totalMarks: computeTotalMarks(),
                                        aiOption: aiOption,
                                        chapterOption: chapterOption,
                                        chapterIds: selectedChapterIds,
                                        headingIds: selectedHeadingIds,
                                      );
                                      setSheetState(() => isGenerating = true);
                                      try {
                                        if (existing == null) {
                                          vm.addPaper(paper);
                                        } else {
                                          vm.updatePaper(existing.id, paper);
                                        }
                                        // Parse typed chapters
                                        final typedChapters =
                                            chapterTextController.text
                                                .split(',')
                                                .map((e) => e.trim())
                                                .where((e) => e.isNotEmpty)
                                                .toList();
                                        final res = await vm.generateQuestions(
                                          paper,
                                          chapterIds: selectedChapterIds.isNotEmpty ? selectedChapterIds : null,
                                          headingIds: selectedHeadingIds.isNotEmpty ? selectedHeadingIds : null,
                                          difficulty: 'medium',
                                        );

                                        if (context.mounted) {
                                          if (res.status && res.data != null) {
                                            // Store generated data for the preview button
                                            setSheetState(() =>
                                                generatedPayload = res.data);

                                            // Automatically navigate to preview
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    QuestionPreviewScreen(
                                                  examTitle: paper.examName,
                                                  payload: res.data,
                                                  marksPerQuestion:
                                                      paper.marksPerQuestion,
                                                  paper: paper,
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Failed: ${res.message}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      } finally {
                                        if (mounted)
                                          setSheetState(
                                              () => isGenerating = false);
                                      }
                                    },
                              child: isGenerating
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 18,
                                          width: 18,
                                          child:
                                              const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white),
                                        ),
                                        SizedBox(width: 2.w),
                                        Flexible(
                                          child: Text(
                                            'Generating...',
                                            style:
                                                TextStyle(color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Generate',
                                      style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
}

class _PaperCard extends StatelessWidget {
  final AIQuestionPaper paper;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaperCard({
    required this.paper,
    required this.onEdit,
    required this.onDelete,
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
                        'ID: ${paper.id}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 0.4.h),
                      Text(
                        paper.examName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: Consumer<BookViewModel>(
                    builder: (context, bookVm, _) => _InfoItem(
                      icon: Icons.book,
                      label: 'Book Name',
                      value: bookVm.getBookByName(paper.bookName)?.title ??
                          paper.bookName,
                    ),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: formatDate(paper.date),
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
                    label: 'Total Questions',
                    value: '${paper.totalQuestions}',
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.speed,
                    label: 'Marks per Question',
                    value: paper.marksPerQuestion.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.grade,
                    label: 'Total Marks',
                    value: paper.totalMarks.toStringAsFixed(2),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.play_arrow,
                    label: 'Start Time',
                    value: paper.startTime.format(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.stop,
                    label: 'End Time',
                    value: paper.endTime.format(context),
                  ),
                ),
                const Spacer(),
              ],
            ),
            SizedBox(height: 2.h),
            // Row(
            //   children: [
            //     Expanded(
            //       child: ElevatedButton.icon(
            //         onPressed: () async {
            //           // Show loading indicator
            //           showDialog(
            //             context: context,
            //             barrierDismissible: false,
            //             builder: (context) =>
            //                 const Center(child: CircularProgressIndicator()),
            //           );

            //           try {
            //             // Fetch the specific exam details (including questions)
            //             final response = await ApiService.getExamById(paper.id);

            //             // Close loading indicator
            //             if (context.mounted) Navigator.pop(context);

            //             dynamic payload = {};
            //             if (response.status && response.data != null) {
            //               payload = response.data;
            //             }

            //             if (context.mounted) {
            //               Navigator.push(
            //                 context,
            //                 MaterialPageRoute(
            //                   builder: (context) => QuestionPreviewScreen(
            //                     examTitle: paper.examName,
            //                     payload: payload,
            //                     marksPerQuestion: paper.marksPerQuestion,
            //                     paper: paper,
            //                   ),
            //                 ),
            //               );
            //             }
            //           } catch (e) {
            //             // Close loading indicator
            //             if (context.mounted) Navigator.pop(context);

            //             if (context.mounted) {
            //               ScaffoldMessenger.of(context).showSnackBar(
            //                 SnackBar(
            //                     content: Text('Error loading questions: $e')),
            //               );
            //             }
            //           }
            //         },
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: AppColors.primaryPurple,
            //           padding: EdgeInsets.symmetric(vertical: 1.5.h),
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(8),
            //           ),
            //         ),
            //         icon: const Icon(Icons.visibility, color: Colors.white),
            //         label: const Text('Preview Paper',
            //             style: TextStyle(color: Colors.white)),
            //       ),
            //     ),
            //   ],
            // ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14.sp, color: AppColors.primaryPurple.withOpacity(0.7)),
        SizedBox(width: 2.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade800)),
          SizedBox(height: 0.8.h),
          child,
        ],
      ),
    );
  }
}

class _InitialLoader extends StatefulWidget {
  final Future<void> Function() onLoad;
  const _InitialLoader({required this.onLoad});

  @override
  State<_InitialLoader> createState() => _InitialLoaderState();
}

class _InitialLoaderState extends State<_InitialLoader> {
  bool _called = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_called) {
      _called = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onLoad();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _BookDropdown extends StatefulWidget {
  final String? initial;
  final ValueChanged<String?> onChanged;
  final ChapterOption chapterOption;
  final ValueChanged<List<String>>? onChaptersChanged;
  final ValueChanged<List<String>>? onHeadingsChanged;

  const _BookDropdown(
      {this.initial,
      required this.onChanged,
      required this.chapterOption,
      this.onChaptersChanged,
      this.onHeadingsChanged});

  @override
  State<_BookDropdown> createState() => _BookDropdownState();
}

class _BookDropdownState extends State<_BookDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String? _selectedBook;

  // Chapter selection state
  List<String> _availableChapters = [];
  List<String> _selectedChapters = [];
  List<BookChild> _availableChaptersWithSubChapters = [];
  Map<String, List<BookChild>> _subChaptersMap = {};
  List<String> _selectedSubChapters = [];
  bool _isLoadingChapters = false;
  bool _showChapterDropdown = false;

  String _getChapterTitle(String id) {
    final chapter = _availableChaptersWithSubChapters.firstWhere(
      (c) => c.id == id,
      orElse: () => BookChild(id: id, title: id, type: 'chapter'),
    );
    return chapter.title;
  }

  String _getSubChapterTitle(String id) {
    for (var chapter in _availableChaptersWithSubChapters) {
      final sub = chapter.children.firstWhere(
        (s) => s.id == id,
        orElse: () => BookChild(id: '', title: '', type: ''),
      );
      if (sub.id.isNotEmpty) return sub.title;
    }
    return id;
  }

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initial;
    _searchController.text = widget.initial ?? '';
    // Load initial books based on chapter option
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookVm = context.read<BookViewModel>();
      bookVm
          .loadBooksByChapterMode(
        chapterMode: widget.chapterOption == ChapterOption.chapter,
      )
          .then((_) {
        if (mounted && widget.initial != null) {
          final book = bookVm.getBookByName(widget.initial!);
          if (book != null) {
            setState(() {
              _searchController.text = book.title;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _selectedBook = null;
      });
      widget.onChanged(null);
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounce search to avoid too many API calls
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query) {
        context.read<BookViewModel>().searchBooks(query);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _BookDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterOption != widget.chapterOption) {
      // Reload books when chapter option changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<BookViewModel>().loadBooksByChapterMode(
              chapterMode: widget.chapterOption == ChapterOption.chapter,
            );
      });
      // Reset selection when the source list changes
      setState(() {
        _selectedBook = null;
        _searchController.clear();
        _isSearching = false;
      });
      widget.onChanged(null);
    }
  }

  void _selectBook(String bookName, String bookTitle) {
    setState(() {
      _selectedBook = bookName;
      _isSearching = false;
      _showChapterDropdown = true;
      _selectedChapters = [];
      _selectedSubChapters = [];
    });
    _searchController.text = bookTitle.isNotEmpty ? bookTitle : bookName;
    widget.onChanged(bookName);
    _searchFocusNode.unfocus();
    _loadChapters(bookName);
  }

  Future<void> _loadChapters(String bookName) async {
    setState(() {
      _isLoadingChapters = true;
      _availableChapters = [];
      _availableChaptersWithSubChapters = [];
      _subChaptersMap = {};
      _selectedSubChapters = [];
      _selectedChapters = [];
    });

    final bookViewModel = context.read<BookViewModel>();

    // Try to get chapters with sub-chapters first
    final chaptersWithSubChapters =
        await bookViewModel.getChaptersWithSubChapters(bookName);

    if (mounted) {
      if (chaptersWithSubChapters.isNotEmpty) {
        // Use the new format with sub-chapters
        setState(() {
          _availableChaptersWithSubChapters = chaptersWithSubChapters;
          _availableChapters =
              chaptersWithSubChapters.map((c) => c.title).toList();

          // Build sub-chapters map
          for (var chapter in chaptersWithSubChapters) {
            if (chapter.hasSubChapters) {
              _subChaptersMap[chapter.title] = chapter.children;
            }
          }
          _isLoadingChapters = false;
        });
      } else {
        // Fallback to simple chapters - but these don't have IDs in the simple titles list
        // However, we can use titles as IDs if needed or update the viewmodel
        final chapters = await bookViewModel.getChaptersOfBook(bookName);
        if (mounted) {
          setState(() {
            _availableChapters = chapters;
            _isLoadingChapters = false;
          });
        }
      }
    }
  }

  void _showChapterSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Select Chapters',
                style: TextStyle(
                  fontSize: 4.5.w,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: 50.h,
                child: _availableChaptersWithSubChapters.isNotEmpty
                    ? _buildChapterWithSubChaptersList(setDialogState)
                    : _buildSimpleChapterList(setDialogState),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleChapterList(
      void Function(void Function()) setDialogState) {
    return ListView.builder(
      itemCount: _availableChapters.length,
      itemBuilder: (context, index) {
        final chapter = _availableChapters[index];
        final isSelected = _selectedChapters.contains(chapter);

        return CheckboxListTile(
          title: Text(
            chapter,
            style: TextStyle(
              fontSize: 3.5.w,
              color: Colors.black87,
            ),
          ),
          value: isSelected,
          onChanged: (bool? value) {
            setDialogState(() {
              if (value == true) {
                _selectedChapters.add(chapter);
              } else {
                _selectedChapters.remove(chapter);
              }
            });
            widget.onChaptersChanged?.call(_selectedChapters);
            widget.onHeadingsChanged?.call(_selectedSubChapters);
          },
          activeColor: AppColors.primaryPurple,
        );
      },
    );
  }

  Widget _buildChapterWithSubChaptersList(
      void Function(void Function()) setDialogState) {
    return ListView.builder(
      itemCount: _availableChaptersWithSubChapters.length,
      itemBuilder: (context, index) {
        final chapter = _availableChaptersWithSubChapters[index];
        final isChapterSelected = _selectedChapters.contains(chapter.id);
        final hasSubChapters = chapter.hasSubChapters;
        final subChapters = chapter.children;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter checkbox
            CheckboxListTile(
              title: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 3.5.w,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: isChapterSelected,
              onChanged: (bool? value) {
                setDialogState(() {
                  if (value == true) {
                    _selectedChapters.add(chapter.id);
                  } else {
                    _selectedChapters.remove(chapter.id);
                  }
                });
                widget.onChaptersChanged?.call(_selectedChapters);
                widget.onHeadingsChanged?.call(_selectedSubChapters);
              },
              activeColor: AppColors.primaryPurple,
            ),

            // Sub-chapters (indented)
            if (hasSubChapters)
              Container(
                margin: EdgeInsets.only(left: 4.w),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: subChapters.map((subChapter) {
                    final isSubSelected =
                        _selectedSubChapters.contains(subChapter.id);
                    return CheckboxListTile(
                      title: Text(
                        subChapter.title,
                        style: TextStyle(
                          fontSize: 3.2.w,
                          color: Colors.black54,
                        ),
                      ),
                      value: isSubSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedSubChapters.add(subChapter.id);
                          } else {
                            _selectedSubChapters.remove(subChapter.id);
                          }
                        });
                        widget.onHeadingsChanged?.call(_selectedSubChapters);
                      },
                      activeColor: Colors.blue[700],
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookViewModel>(
      builder: (context, bookVm, _) {
        final books = _isSearching ? bookVm.filteredBooks : bookVm.books;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search and select a book...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryPurple),
                ),
              ),
              onChanged: _onSearchChanged,
              onTap: () {
                if (!_isSearching) {
                  setState(() {
                    _isSearching = true;
                  });
                }
              },
            ),
            if (_isSearching && bookVm.isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_isSearching && bookVm.hasError)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Search failed: ${bookVm.errorMessage}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (_isSearching && books.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final isSelected = _selectedBook == book.bookName;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor:
                          AppColors.primaryPurple.withOpacity(0.1),
                      title: Text(
                        book.title.isNotEmpty ? book.title : book.bookName,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      // subtitle:
                      //     book.title.isNotEmpty && book.title != book.bookName
                      //         ? Text(
                      //             book.bookName,
                      //             style: TextStyle(
                      //               color: Colors.grey.shade600,
                      //               fontSize: 11,
                      //             ),
                      //             overflow: TextOverflow.ellipsis,
                      //             maxLines: 1,
                      //           )
                      //         : null,
                      onTap: () => _selectBook(book.bookName, book.title),
                    );
                  },
                ),
              ),
            if (_isSearching &&
                books.isEmpty &&
                !bookVm.isLoading &&
                !bookVm.hasError)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'No books found. Try a different search term.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            // Chapter selection section
            if (_showChapterDropdown && _selectedBook != null) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.list_alt,
                          color: AppColors.primaryPurple,
                          size: 4.w,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Select Chapters',
                          style: TextStyle(
                            fontSize: 4.w,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    if (_isLoadingChapters)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(2.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 4.w,
                                height: 4.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'Loading chapters...',
                                style: TextStyle(
                                  fontSize: 3.w,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_availableChapters.isEmpty)
                      Container(
                        padding: EdgeInsets.all(2.w),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.grey.shade600,
                              size: 4.w,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'No chapters available for this book',
                              style: TextStyle(
                                fontSize: 3.w,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _showChapterSelectionDialog,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedChapters.isEmpty &&
                                          _selectedSubChapters.isEmpty
                                      ? 'Select chapters...'
                                      : '${_selectedChapters.length + _selectedSubChapters.length} selected',
                                  style: TextStyle(
                                    fontSize: 3.5.w,
                                    color: _selectedChapters.isEmpty &&
                                            _selectedSubChapters.isEmpty
                                        ? Colors.grey.shade600
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Display selected chapters and sub-chapters
                    if (_selectedChapters.isNotEmpty ||
                        _selectedSubChapters.isNotEmpty) ...[
                      SizedBox(height: 1.h),
                      Wrap(
                        spacing: 1.w,
                        runSpacing: 0.8.h,
                        children: [
                          ..._selectedChapters.map((chapter) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getChapterTitle(chapter),
                                    style: TextStyle(
                                      fontSize: 3.w,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                  SizedBox(width: 1.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedChapters.remove(chapter);
                                      });
                                      widget.onChaptersChanged?.call(_selectedChapters);
                                      widget.onHeadingsChanged?.call(_selectedSubChapters);
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 3.w,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          ..._selectedSubChapters.map((subChapter) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getSubChapterTitle(subChapter),
                                    style: TextStyle(
                                      fontSize: 3.w,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  SizedBox(width: 1.w),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedSubChapters.remove(subChapter);
                                      });
                                      widget.onChaptersChanged?.call(_selectedChapters);
                                      widget.onHeadingsChanged?.call(_selectedSubChapters);
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 3.w,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MultiChapterSelector extends StatefulWidget {
  final List<String> chapters;
  final List<String> selectedChapters;
  final ValueChanged<List<String>> onSelectionChanged;

  const _MultiChapterSelector({
    required this.chapters,
    required this.selectedChapters,
    required this.onSelectionChanged,
  });

  @override
  State<_MultiChapterSelector> createState() => _MultiChapterSelectorState();
}

class _MultiChapterSelectorState extends State<_MultiChapterSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection summary
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.selectedChapters.isEmpty
                        ? (widget.chapters.isEmpty
                            ? 'No chapters found'
                            : 'Select chapters')
                        : '${widget.selectedChapters.length} chapter(s) selected',
                    style: TextStyle(
                      color: widget.selectedChapters.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),

        // Selected chapters display
        if (widget.selectedChapters.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Wrap(
            spacing: 1.w,
            runSpacing: 0.5.h,
            children: widget.selectedChapters.map((chapter) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chapter,
                      style: TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 1.w),
                    GestureDetector(
                      onTap: () {
                        final updated =
                            List<String>.from(widget.selectedChapters);
                        updated.remove(chapter);
                        widget.onSelectionChanged(updated);
                      },
                      child: Icon(
                        Icons.close,
                        size: 16.sp,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        // Chapter selection list
        if (_isExpanded && widget.chapters.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Container(
            constraints: BoxConstraints(maxHeight: 20.h),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.chapters.length,
              itemBuilder: (context, index) {
                final chapter = widget.chapters[index];
                final isSelected = widget.selectedChapters.contains(chapter);

                return CheckboxListTile(
                  title: Text(
                    chapter,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    final updated = List<String>.from(widget.selectedChapters);
                    if (value == true) {
                      if (!updated.contains(chapter)) {
                        updated.add(chapter);
                      }
                    } else {
                      updated.remove(chapter);
                    }
                    widget.onSelectionChanged(updated);
                  },
                  activeColor: AppColors.primaryPurple,
                  dense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                );
              },
            ),
          ),
        ],

        // Select All / Clear All buttons
        if (_isExpanded && widget.chapters.isNotEmpty) ...[
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget
                        .onSelectionChanged(List<String>.from(widget.chapters));
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primaryPurple),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(vertical: 0.8.h),
                  ),
                  child: Text(
                    'Select All',
                    style: TextStyle(
                      color: AppColors.primaryPurple,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onSelectionChanged([]);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: EdgeInsets.symmetric(vertical: 0.8.h),
                  ),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
