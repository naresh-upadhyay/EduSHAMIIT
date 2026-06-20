import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class ExamPaperBuilderScreen extends ConsumerStatefulWidget {
  final String? examId;
  const ExamPaperBuilderScreen({super.key, this.examId});

  @override
  ConsumerState<ExamPaperBuilderScreen> createState() => _ExamPaperBuilderScreenState();
}

class _ExamPaperBuilderScreenState extends ConsumerState<ExamPaperBuilderScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  
  TeacherExam? _exam;
  List<Map<String, dynamic>> _examQuestions = [];
  bool _isLoading = true;
  String? _error;

  // Selector state variables
  List<TeacherExam> _allExams = [];

  @override
  void initState() {
    super.initState();
    _loadExamData();
  }

  @override
  void didUpdateWidget(covariant ExamPaperBuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.examId != oldWidget.examId) {
      _loadExamData();
    }
  }

  Future<void> _loadExamData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _exam = null;
      _examQuestions = [];
    });

    try {
      final exams = await _apiService.getExams();
      
      // Sort exams in sorted order most recent first by default
      exams.sort((a, b) {
        final dateA = a.createdAt ?? a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      
      if (widget.examId == null) {
        setState(() {
          _allExams = exams;
          _isLoading = false;
        });
        return;
      }

      final matchedExam = exams.firstWhere(
        (e) => e.id == widget.examId,
        orElse: () => throw 'Exam with ID ${widget.examId} not found.',
      );

      final questions = await _apiService.getExamQuestions(widget.examId!);

      setState(() {
        _exam = matchedExam;
        _examQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }



  int get _calculatedTotalMarks {
    return _examQuestions.fold<int>(0, (sum, q) => sum + (int.tryParse(q['marks']?.toString() ?? '1') ?? 1));
  }

  Future<void> _deleteQuestion(String questionId) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiService.deleteExamQuestion(_exam!.id, questionId);
      final questions = await _apiService.getExamQuestions(_exam!.id);
      setState(() {
        _examQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete question: $e')),
      );
    }
  }

  Color _getStatusColor(TeacherExam exam) {
    final status = exam.status.toLowerCase();
    if (status == 'new') {
      return Colors.blue;
    }
    if (status == 'in_progress' || exam.questionMarksSum < exam.totalMarks) {
      return Colors.orange;
    }
    if (exam.startTime == null) {
      return Colors.green;
    }
    final now = DateTime.now();
    final start = exam.startTime!;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    if (now.isBefore(start)) {
      return Colors.blueAccent;
    } else if (now.isAfter(start) && now.isBefore(end)) {
      return Colors.purple;
    } else {
      return Colors.red;
    }
  }

  String _getStatusLabel(TeacherExam exam) {
    final status = exam.status.toLowerCase();
    if (status == 'new') {
      return 'New';
    }
    if (status == 'in_progress' || exam.questionMarksSum < exam.totalMarks) {
      return 'In progress (${exam.questionMarksSum}/${exam.totalMarks})';
    }
    if (exam.startTime == null) {
      return 'Ready';
    }
    final now = DateTime.now();
    final start = exam.startTime!;
    final digits = exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
    final durationMins = int.tryParse(digits) ?? 90;
    final end = exam.endTime ?? start.add(Duration(minutes: durationMins));
    if (now.isBefore(start)) {
      return 'Scheduled';
    } else if (now.isAfter(start) && now.isBefore(end)) {
      return 'Published';
    } else {
      return 'Completed';
    }
  }

  String _formatExamDateTime(TeacherExam exam) {
    if (exam.startTime == null) {
      return 'Not scheduled';
    }
    final dateStr = exam.examDate.toString().split(' ')[0];
    final localStart = exam.startTime!.toLocal();
    final hour = localStart.hour;
    final minute = localStart.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$dateStr at $formattedHour:$minute $period';
  }

  List<AzureGridColumn<TeacherExam>> _buildGridColumns() {
    return [
      AzureGridColumn<TeacherExam>(
        label: 'Exam Title',
        width: 170.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (exam) => Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: exam.examType.toLowerCase() == 'online'
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                exam.examType.toLowerCase() == 'online' ? '🖥️' : '📝',
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exam.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Subject & Marks',
        width: 130.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (exam) => Text('${exam.subject} (${exam.totalMarks}M)'),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Class',
        width: 80.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (exam) => Text(exam.class_),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Category',
        width: 100.0,
        compare: (a, b) => a.examCategory.compareTo(b.examCategory),
        cellBuilder: (exam) {
          Color typeColor = Colors.grey;
          switch (exam.examCategory.toLowerCase()) {
            case 'mid term':
            case 'term':
              typeColor = Colors.blue;
              break;
            case 'unit test':
            case 'unit':
              typeColor = Colors.green;
              break;
            case 'quiz':
            case 'practice test':
              typeColor = Colors.orange;
              break;
            case 'final':
            case 'final exam':
              typeColor = Colors.purple;
              break;
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              exam.examCategory,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Status',
        width: 100.0,
        compare: (a, b) => a.status.compareTo(b.status),
        cellBuilder: (exam) {
          final color = _getStatusColor(exam);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              _getStatusLabel(exam),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          );
        },
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Date & Time',
        width: 160.0,
        cellBuilder: (exam) => Text(_formatExamDateTime(exam)),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Duration',
        width: 85.0,
        cellBuilder: (exam) => Text(exam.duration),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Qns',
        width: 60.0,
        compare: (a, b) => a.questionCount.compareTo(b.questionCount),
        cellBuilder: (exam) => Text(exam.questionCount.toString()),
      ),
      AzureGridColumn<TeacherExam>(
        label: 'Action',
        width: 120.0,
        cellBuilder: (exam) => SizedBox(
          height: 24,
          child: ElevatedButton(
            onPressed: () {
              context.pushReplacement('/teacher/exams/paper-builder?examId=${exam.id}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: const Text(
              'Build Paper',
              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildExamSelectorScreen() {
    final classes = _allExams.map((e) => e.class_).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final subjects = _allExams.map((e) => e.subject).where((s) => s.isNotEmpty).toSet().toList()..sort();
    final categories = _allExams.map((e) => e.examCategory).where((c) => c.isNotEmpty).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Select Exam for Paper Builder',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/exams'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadExamData,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 12.0),
          child: AzureGrid<TeacherExam>(
            title: 'Exams List',
            items: _allExams,
            columns: _buildGridColumns(),
            searchMatcher: (exam) => '${exam.title} ${exam.subject} ${exam.class_} ${exam.examCategory}',
            filters: [
              if (classes.isNotEmpty)
                AzureGridFilter<TeacherExam>(
                  label: 'Class',
                  options: classes,
                  filterFn: (exam, option) => exam.class_ == option,
                ),
              if (subjects.isNotEmpty)
                AzureGridFilter<TeacherExam>(
                  label: 'Subject',
                  options: subjects,
                  filterFn: (exam, option) => exam.subject == option,
                ),
              if (categories.isNotEmpty)
                AzureGridFilter<TeacherExam>(
                  label: 'Category',
                  options: categories,
                  filterFn: (exam, option) => exam.examCategory == option,
                ),
            ],
            onRefresh: _loadExamData,
            mobileCardBuilder: (context, exam) => _buildSelectorExamCard(exam),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorExamCard(TeacherExam exam) {
    Color typeColor = Colors.grey;
    switch (exam.examCategory.toLowerCase()) {
      case 'mid term':
      case 'term':
        typeColor = Colors.blue;
        break;
      case 'unit test':
      case 'unit':
        typeColor = Colors.green;
        break;
      case 'quiz':
      case 'practice test':
        typeColor = Colors.orange;
        break;
      case 'final':
      case 'final exam':
        typeColor = Colors.purple;
        break;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      child: InkWell(
        onTap: () {
          context.pushReplacement('/teacher/exams/paper-builder?examId=${exam.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      exam.examCategory,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(exam).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(exam),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(exam),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatExamDateTime(exam),
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                exam.title,
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.class_, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Class ${exam.class_}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.book, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    exam.subject,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.star, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.totalMarks} Marks',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.help_outline, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.questionCount} Qs',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: exam.examType.toLowerCase() == 'online'
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: exam.examType.toLowerCase() == 'online'
                                ? const Color(0xFFC7D2FE)
                                : const Color(0xFFFED7AA),
                          ),
                        ),
                        child: Text(
                          exam.examType.toLowerCase() == 'online' ? '🖥️ Online' : '📝 Offline',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: exam.examType.toLowerCase() == 'online'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        exam.duration,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Build Paper',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Paper Builder Error'),
          backgroundColor: const Color(0xFF6366F1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => safeGoBack(context, '/teacher/exams'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => safeGoBack(context, '/teacher/exams'),
                  child: const Text('Back to Exams'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.examId == null) {
      return _buildExamSelectorScreen();
    }

    final int targetMarks = _exam?.totalMarks ?? 100;
    final int currentMarks = _calculatedTotalMarks;
    final bool marksMatched = currentMarks == targetMarks;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Exam Paper Builder: ${_exam!.title}',
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/exams'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadExamData,
          ),
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
            tooltip: 'Preview Paper',
            onPressed: _showPaperPreview,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Marks summary panel
            _buildMarksSummaryBar(currentMarks, targetMarks, marksMatched),

            // List of active exam questions
            Expanded(
              child: _examQuestions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'This exam has no questions yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add questions directly or import them from the Question Bank.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _examQuestions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(index, _examQuestions[index]);
                      },
                    ),
            ),

            // Stepper progress action bar
            _buildActionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksSummaryBar(int current, int target, bool matched) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Weightage Added:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.grey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: matched ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$current / $target Marks',
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                color: matched ? const Color(0xFF065F46) : const Color(0xFFD97706), 
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    final rawType = (question['question_type'] ?? 'mcq').toString();
    final type = _questionTypeLabel(rawType);
    final marks = question['marks'] ?? 1;
    final optionsRaw = question['options'];
    List<String> options = [];
    if (optionsRaw is List) {
      options = optionsRaw.map((e) => e.toString()).toList();
    } else if (optionsRaw is String && optionsRaw.isNotEmpty) {
      try {
        options = List<String>.from(json.decode(optionsRaw));
      } catch (_) {}
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
                  child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        'Weight: $marks Marks',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  onPressed: () => _showQuestionFormDialog(question: question),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteQuestion(question['id']),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              question['question_text'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...options.asMap().entries.map((entry) {
                final rawType = (question['question_type'] ?? 'mcq').toString();
                final bool isCorrect = rawType == 'multi_correct'
                    ? (question['correct_answer']?.toString() ?? '').split(',').map((s) => s.trim()).contains(entry.value)
                    : question['correct_answer'] == entry.value;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      color: isCorrect ? const Color(0xFF065F46) : Colors.black87,
                    ),
                  ),
                );
              }),
            ] else if (question['correct_answer'] != null && question['correct_answer'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Correct Answer: ${question['correct_answer']}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _questionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'mcq': return 'Single Select';
      case 'multi_correct': return 'Multi Select';
      case 'short_answer': return 'Short Answer';
      case 'long_answer': return 'Long Answer';
      case 'subjective': return 'Subjective';
      case 'numerical': return 'Numerical';
      case 'true_false': return 'True / False';
      default: return type.toUpperCase();
    }
  }

  Widget _buildActionFooter() {
    final int targetMarks = _exam?.totalMarks ?? 100;
    final int currentMarks = _calculatedTotalMarks;
    final bool marksMatched = currentMarks == targetMarks;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6366F1)),
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: !marksMatched 
                  ? null 
                  : () {
                      context.pushReplacement('/teacher/exams/assign/${_exam!.id}');
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(marksMatched ? 'Proceed to Assign' : 'Assign (Incomplete)'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note, color: Color(0xFF6366F1)),
              title: const Text('Create New Question'),
              subtitle: const Text('Write a new question specifically for this exam.'),
              onTap: () {
                Navigator.pop(context);
                _showQuestionFormDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF10B981)),
              title: const Text('Import from Question Bank'),
              subtitle: const Text('Pull saved questions from your library.'),
              onTap: () {
                Navigator.pop(context);
                _showQuestionBankSelection();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle, color: Colors.orange),
              title: const Text('Auto-Generate from Syllabus'),
              subtitle: const Text('Automatically pick random questions matching the subject.'),
              onTap: () {
                Navigator.pop(context);
                _handleAutoGenerate();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAutoGenerate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all questions from bank for this subject
      final bankQuestions = await _apiService.getQuestionBank(subject: _exam!.subject);
      if (bankQuestions.isEmpty) {
        throw 'No questions found in Question Bank for subject "${_exam!.subject}". Add questions to the bank first.';
      }

      int addedCount = 0;
      int currentTotal = _calculatedTotalMarks;
      final int target = _exam!.totalMarks;

      for (var bq in bankQuestions) {
        if (currentTotal + bq.marks <= target) {
          await _apiService.addExamQuestion(_exam!.id, {
            'question_text': bq.questionText,
            'question_type': bq.questionType,
            'options': bq.options?.isNotEmpty == true ? bq.options : null,
            'correct_answer': bq.correctAnswer,
            'marks': bq.marks,
          });
          currentTotal += bq.marks;
          addedCount++;
        }
      }

      final questions = await _apiService.getExamQuestions(_exam!.id);
      setState(() {
        _examQuestions = questions;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Auto-imported $addedCount questions matching syllabus!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-generation failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _showQuestionBankSelection() async {
    setState(() {
      _isLoading = true;
    });

    List<QuestionBankItem> bankQuestions = [];
    try {
      bankQuestions = await _apiService.getQuestionBank(subject: _exam!.subject);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load bank: $e')));
    }

    setState(() {
      _isLoading = false;
    });

    if (bankQuestions.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Question Bank Empty'),
          content: Text('There are no saved questions for subject "${_exam!.subject}". Please add questions to the Question Bank first.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    final List<QuestionBankItem> selectedItems = [];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final isDesktop = MediaQuery.of(context).size.width >= 800;
        final double width = isDesktop ? 550 : MediaQuery.of(context).size.width;
        final beginOffset = isDesktop ? const Offset(1, 0) : const Offset(0, 1);
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeInOut)),
          child: Align(
            alignment: isDesktop ? Alignment.centerRight : Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              borderRadius: isDesktop
                  ? const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24))
                  : const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              child: SafeArea(
                bottom: !isDesktop,
                child: SizedBox(
                  width: width,
                  height: isDesktop ? double.infinity : MediaQuery.of(context).size.height * 0.85,
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF6366F1), size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Import Questions (${_exam!.subject})',
                                  style: const TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          
                          // Scrollable List of Questions
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: bankQuestions.length,
                              itemBuilder: (context, idx) {
                                final item = bankQuestions[idx];
                                final isSelected = selectedItems.contains(item);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    activeColor: const Color(0xFF6366F1),
                                    title: Text(
                                      item.questionText,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    subtitle: Text(
                                      '${item.questionType.toUpperCase()} • ${item.marks} Marks • ${item.chapter ?? "General"}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    onChanged: (val) {
                                      setSheetState(() {
                                        if (val == true) {
                                          selectedItems.add(item);
                                        } else {
                                          selectedItems.remove(item);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Footer Action Buttons
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: selectedItems.isEmpty
                                        ? null
                                        : () async {
                                            Navigator.pop(context);
                                            setState(() {
                                              _isLoading = true;
                                            });

                                            try {
                                              for (var item in selectedItems) {
                                                await _apiService.addExamQuestion(_exam!.id, {
                                                  'question_text': item.questionText,
                                                  'question_type': item.questionType,
                                                  'options': item.options.isNotEmpty ? item.options : null,
                                                  'correct_answer': item.correctAnswer,
                                                  'marks': item.marks,
                                                });
                                              }

                                              final questions = await _apiService.getExamQuestions(_exam!.id);
                                              setState(() {
                                                _examQuestions = questions;
                                                _isLoading = false;
                                              });
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('🎉 Successfully imported questions!')),
                                              );
                                            } catch (e) {
                                              setState(() {
                                                _isLoading = false;
                                              });
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Import failed: $e')),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('Import Selected (${selectedItems.length})'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuestionFormDialog({Map<String, dynamic>? question}) {
    final formKey = GlobalKey<FormState>();
    final qTextController = TextEditingController(text: question?['question_text'] ?? '');
    final marksController = TextEditingController(text: question?['marks']?.toString() ?? '1');
    
    String qType = question?['question_type'] ?? 'mcq';
    if (qType == 'subjective') qType = 'short_answer';
    if (qType == 'true_false') qType = 'mcq'; // true_false covered by single-select MCQ
    if (qType != 'mcq' && qType != 'multi_correct' && qType != 'short_answer' && qType != 'long_answer') {
      qType = 'mcq';
    }
    
    // MCQ option parsing
    List<TextEditingController> optionControllers = [];
    final optionsRaw = question?['options'];
    List<String> parsedOptions = [];
    if (optionsRaw is List) {
      parsedOptions = optionsRaw.map((e) => e.toString()).toList();
    } else if (optionsRaw is String && optionsRaw.isNotEmpty) {
      try {
        parsedOptions = List<String>.from(json.decode(optionsRaw));
      } catch (_) {}
    }

    if (parsedOptions.isNotEmpty) {
      optionControllers = parsedOptions.map((o) => TextEditingController(text: o)).toList();
    } else {
      optionControllers = [
        TextEditingController(text: ''),
        TextEditingController(text: ''),
        TextEditingController(text: ''),
        TextEditingController(text: ''),
      ];
    }
    String mcqCorrectAnswer = question?['correct_answer'] ?? '';

    // Multi-select correct answers
    List<String> multiCorrectAnswers = [];
    final rawCorrectMulti = question?['correct_answer']?.toString() ?? '';
    if (qType == 'multi_correct' && rawCorrectMulti.isNotEmpty) {
      try {
        if (rawCorrectMulti.startsWith('[')) {
          multiCorrectAnswers = List<String>.from(rawCorrectMulti.replaceAll('[','').replaceAll(']','').replaceAll('"','').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
        } else {
          multiCorrectAnswers = rawCorrectMulti.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {}
    }

    // True/False state (kept for display of legacy questions)
    String tfCorrectAnswer = question?['correct_answer'] ?? 'True';
    if (tfCorrectAnswer.toLowerCase() == 'true') tfCorrectAnswer = 'True';
    if (tfCorrectAnswer.toLowerCase() == 'false') tfCorrectAnswer = 'False';
    if (tfCorrectAnswer != 'True' && tfCorrectAnswer != 'False') tfCorrectAnswer = 'True';
    // Subjective state
    final subjectiveAnswerController = TextEditingController(
      text: (qType == 'short_answer' || qType == 'long_answer' || qType == 'subjective') 
          ? (question?['correct_answer'] ?? '') 
          : '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final isDesktop = MediaQuery.of(context).size.width >= 800;
        final double width = isDesktop ? 550 : MediaQuery.of(context).size.width;
        final beginOffset = isDesktop ? const Offset(1, 0) : const Offset(0, 1);
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeInOut)),
          child: Align(
            alignment: isDesktop ? Alignment.centerRight : Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              borderRadius: isDesktop
                  ? const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24))
                  : const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              child: SafeArea(
                bottom: !isDesktop,
                child: SizedBox(
                  width: width,
                  height: isDesktop ? double.infinity : MediaQuery.of(context).size.height * 0.85,
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Form(
                        key: formKey,
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    question != null ? Icons.edit_note : Icons.add_circle_outline,
                                    color: const Color(0xFF6366F1),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    question != null ? 'Edit Question' : 'Create New Question',
                                    style: const TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Scrollable Fields
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: qType,
                                      decoration: InputDecoration(
                                        labelText: 'Question Type',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'mcq',
                                          child: Row(children: [Icon(Icons.radio_button_checked, size: 16, color: Color(0xFF6366F1)), SizedBox(width: 8), Text('Single Select (MCQ)')]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'multi_correct',
                                          child: Row(children: [Icon(Icons.check_box, size: 16, color: Color(0xFF059669)), SizedBox(width: 8), Text('Multi Select (Checkboxes)')]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'short_answer',
                                          child: Row(children: [Icon(Icons.short_text, size: 16, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text('Short Answer (Subjective)')]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'long_answer',
                                          child: Row(children: [Icon(Icons.subject, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Long Answer (Subjective)')]),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setDialogState(() {
                                          qType = v!;
                                          if (v != 'multi_correct') multiCorrectAnswers.clear();
                                          if (v != 'mcq') mcqCorrectAnswer = '';
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: qTextController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: 'Question Text',
                                        alignLabelWithHint: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      validator: (v) => v == null || v.isEmpty ? 'Question text is required' : null,
                                    ),
                                    
                                    // DYNAMIC INPUTS ACCORDING TO QUESTION TYPE
                                    if (qType == 'mcq' || qType == 'multi_correct') ...[
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Icon(
                                            qType == 'multi_correct' ? Icons.check_box : Icons.radio_button_checked,
                                            size: 16,
                                            color: qType == 'multi_correct' ? const Color(0xFF059669) : const Color(0xFF6366F1),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            qType == 'multi_correct' ? 'Options & Correct Answers (tick all correct)' : 'Configure Options',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      if (qType == 'multi_correct')
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4, bottom: 8),
                                          child: Text(
                                            'Tick checkboxes next to all correct options.',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 10),
                                      ...optionControllers.asMap().entries.map((entry) {
                                        final idx = entry.key;
                                        final ctrl = entry.value;
                                        final optText = ctrl.text.trim();
                                        final isCorrect = qType == 'multi_correct' && multiCorrectAnswers.contains(optText);
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            children: [
                                              if (qType == 'multi_correct')
                                                GestureDetector(
                                                  onTap: () {
                                                    setDialogState(() {
                                                      final t = ctrl.text.trim();
                                                      if (t.isEmpty) return;
                                                      if (multiCorrectAnswers.contains(t)) {
                                                        multiCorrectAnswers.remove(t);
                                                      } else {
                                                        multiCorrectAnswers.add(t);
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: isCorrect ? const Color(0xFF059669) : Colors.white,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: isCorrect ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: isCorrect ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                                  ),
                                                )
                                              else
                                                CircleAvatar(
                                                  radius: 11,
                                                  backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                                                  child: Text(
                                                    String.fromCharCode(65 + idx),
                                                    style: const TextStyle(fontSize: 9, color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: ctrl,
                                                  decoration: InputDecoration(
                                                    hintText: 'Option ${idx + 1}',
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: isCorrect ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: isCorrect ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
                                                    ),
                                                    filled: isCorrect,
                                                    fillColor: const Color(0xFFF0FDF4),
                                                  ),
                                                  onChanged: (v) => setDialogState(() {}),
                                                ),
                                              ),
                                              if (optionControllers.length > 2)
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                                  onPressed: () {
                                                    setDialogState(() {
                                                      final removed = optionControllers[idx].text.trim();
                                                      optionControllers.removeAt(idx);
                                                      multiCorrectAnswers.remove(removed);
                                                    });
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                      TextButton.icon(
                                        onPressed: () {
                                          setDialogState(() {
                                            optionControllers.add(TextEditingController(text: ''));
                                          });
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Option', style: TextStyle(fontSize: 11)),
                                      ),
                                      if (qType == 'mcq') ...[
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          value: (mcqCorrectAnswer.isNotEmpty && optionControllers.any((c) => c.text.trim() == mcqCorrectAnswer.trim() && c.text.isNotEmpty)) ? mcqCorrectAnswer.trim() : null,
                                          decoration: InputDecoration(
                                            labelText: 'Correct Answer Option',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          hint: const Text('Select Correct Choice'),
                                          items: optionControllers
                                              .where((c) => c.text.trim().isNotEmpty)
                                              .map((c) => c.text.trim())
                                              .toSet()
                                              .map((text) => DropdownMenuItem(value: text, child: Text(text)))
                                              .toList(),
                                          onChanged: (v) => setDialogState(() => mcqCorrectAnswer = v!),
                                          validator: (v) => v == null ? 'Select correct answer' : null,
                                        ),
                                      ] else if (qType == 'multi_correct') ...[
                                        const SizedBox(height: 4),
                                        if (multiCorrectAnswers.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              '⚠️ Tick at least one correct answer above.',
                                              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF86EFAC)),
                                            ),
                                            child: Text(
                                              '✓ Correct: ${multiCorrectAnswers.join(', ')}',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                      ],
                                    ] else ...[
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: subjectiveAnswerController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          labelText: 'Model/Correct Answer Description',
                                          alignLabelWithHint: true,
                                          hintText: 'Enter key terms or full sentence answer...',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        validator: (v) => v == null || v.isEmpty ? 'Correct answer description is required' : null,
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: marksController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Marks (Points)',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      validator: (v) => v == null || int.tryParse(v) == null ? 'Must be an integer' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Footer actions
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (formKey.currentState!.validate()) {
                                          Navigator.pop(context);
                                          setState(() {
                                            _isLoading = true;
                                          });

                                          String correctAns = '';
                                          List<String> options = [];
                                          if (qType == 'mcq') {
                                            correctAns = mcqCorrectAnswer;
                                            options = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                                            if (correctAns.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please select a correct answer option.'), backgroundColor: Colors.red),
                                              );
                                              return;
                                            }
                                          } else if (qType == 'multi_correct') {
                                            if (multiCorrectAnswers.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Please tick at least one correct answer.'), backgroundColor: Colors.red),
                                              );
                                              return;
                                            }
                                            options = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                                            correctAns = multiCorrectAnswers.join(', ');
                                          } else {
                                            correctAns = subjectiveAnswerController.text.trim();
                                          }

                                          final body = {
                                            'question_text': qTextController.text.trim(),
                                            'question_type': qType,
                                            'options': options.isNotEmpty ? options : null,
                                            'correct_answer': correctAns,
                                            'marks': int.tryParse(marksController.text) ?? 1,
                                          };

                                          try {
                                            if (question != null) {
                                              await _apiService.updateExamQuestion(_exam!.id, question['id'], body);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Question updated!')));
                                            } else {
                                              await _apiService.addExamQuestion(_exam!.id, body);
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Question added to exam!')));
                                            }
                                            final questions = await _apiService.getExamQuestions(_exam!.id);
                                            setState(() {
                                              _examQuestions = questions;
                                              _isLoading = false;
                                            });
                                          } catch (e) {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed to save question: $e')),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(question != null ? 'Save' : 'Add'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaperPreview() {
    bool isDownloading = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: Color(0xFF6366F1), size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Question Paper Preview',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          if (isDownloading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () async {
                                setDialogState(() {
                                  isDownloading = true;
                                });
                                try {
                                  final bytes = await _apiService.downloadExamPaperPdf(_exam!.id);
                                  final cleanTitle = _exam!.title.replaceAll(RegExp(r'\s+'), '_');
                                  final filename = 'QuestionPaper_$cleanTitle.pdf';
                                  await getDownloadHelper().downloadBytes(bytes, filename);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🎉 Question paper PDF downloaded successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to download PDF: $e'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } finally {
                                  setDialogState(() {
                                    isDownloading = false;
                                  });
                                }
                              },
                              icon: const Icon(Icons.download, size: 14, color: Colors.white),
                              label: const Text(
                                'Download PDF',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Paper Mockup Container
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 700),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // School & Exam Header
                                const Center(
                                  child: Text(
                                    'EDUSHAMIIT ACADEMY',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    _exam!.title.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: Color(0xFF1E293B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 2,
                                  color: const Color(0xFF0F172A),
                                ),
                                const SizedBox(height: 12),

                                // Exam Metadata Table (Subject, Class, Duration, Max Marks)
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.2),
                                    1: FlexColumnWidth(2.5),
                                    2: FlexColumnWidth(1.3),
                                    3: FlexColumnWidth(2.5),
                                  },
                                  children: [
                                    TableRow(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Subject:', style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(_exam!.subject, style: const TextStyle(fontFamily: 'serif', fontSize: 12)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Maximum Marks:', style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text('${_exam!.totalMarks} Marks', style: const TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Class:', style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(_exam!.class_, style: const TextStyle(fontFamily: 'serif', fontSize: 12)),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          child: Text('Duration:', style: TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(_exam!.duration, style: const TextStyle(fontFamily: 'serif', fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 0.5,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),

                                // Student Metadata Fields
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Candidate Name: _______________________________',
                                        style: TextStyle(fontFamily: 'serif', fontSize: 11),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Roll Number: _______________',
                                      style: TextStyle(fontFamily: 'serif', fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Date of Exam: _________________________________',
                                        style: TextStyle(fontFamily: 'serif', fontSize: 11),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Signature: _______________',
                                      style: TextStyle(fontFamily: 'serif', fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1.5,
                                  color: const Color(0xFF0F172A),
                                ),
                                const SizedBox(height: 16),

                                // Instructions to Candidates
                                const Text(
                                  'Instructions to Candidates:',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '1. Write your name and roll number clearly in the spaces provided above.\n'
                                  '2. All questions are compulsory. Check that this paper contains all listed questions.\n'
                                  '3. Read each question carefully before attempting it.',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 0.5,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 20),

                                // Questions Section Header
                                const Center(
                                  child: Text(
                                    'QUESTIONS',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                if (_examQuestions.isEmpty)
                                  const Center(
                                    child: Text(
                                      'No questions added to this draft yet.',
                                      style: TextStyle(fontFamily: 'serif', fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  )
                                else
                                  ..._examQuestions.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final q = entry.value;
                                    final qText = q['question_text'] ?? '';
                                    final qMarks = q['marks'] ?? 1;
                                    final qType = (q['question_type'] ?? 'mcq').toString().toLowerCase();

                                    final optionsRaw = q['options'];
                                    List<String> options = [];
                                    if (optionsRaw is List) {
                                      options = optionsRaw.map((e) => e.toString()).toList();
                                    } else if (optionsRaw is String && optionsRaw.isNotEmpty) {
                                      try {
                                        options = List<String>.from(json.decode(optionsRaw));
                                      } catch (_) {}
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 24.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Question text and marks aligned
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Q${idx + 1}. ',
                                                style: const TextStyle(
                                                  fontFamily: 'serif',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  qText,
                                                  style: const TextStyle(
                                                    fontFamily: 'serif',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '[$qMarks Marks]',
                                                style: const TextStyle(
                                                  fontFamily: 'serif',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Options for MCQ/Multi-select
                                          if (options.isNotEmpty && (qType == 'mcq' || qType == 'multi_correct' || qType == 'single_select' || qType == 'multi_select'))
                                            Padding(
                                              padding: const EdgeInsets.only(left: 28.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: options.asMap().entries.map((opt) {
                                                  final charCode = String.fromCharCode(65 + opt.key);
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                                    child: Text(
                                                      '($charCode) ${opt.value}',
                                                      style: const TextStyle(
                                                        fontFamily: 'serif',
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            )
                                          else if (qType == 'short_answer' || qType == 'subjective')
                                            const Padding(
                                              padding: EdgeInsets.only(left: 28.0, top: 12, bottom: 12),
                                              child: SizedBox(
                                                height: 40,
                                                child: Text(
                                                  'Answer Space: _________________________________________________________________',
                                                  style: TextStyle(fontFamily: 'serif', fontSize: 11, color: Colors.grey),
                                                ),
                                              ),
                                            )
                                          else if (qType == 'long_answer')
                                            const Padding(
                                              padding: EdgeInsets.only(left: 28.0, top: 12, bottom: 12),
                                              child: SizedBox(
                                                height: 80,
                                                child: Text(
                                                  'Answer Space: \n'
                                                  '_________________________________________________________________________________\n'
                                                  '_________________________________________________________________________________',
                                                  style: TextStyle(fontFamily: 'serif', fontSize: 11, color: Colors.grey, height: 1.5),
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 0.3,
                                            color: Colors.grey.shade300,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
