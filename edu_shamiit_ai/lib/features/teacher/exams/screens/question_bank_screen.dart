import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedSubject = 'All';
  String _selectedDifficulty = 'All';
  List<QuestionBankItem> _questions = [];
  List<TeacherSubject> _subjects = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getSubjects(),
        _apiService.getQuestionBank(
          subject: _selectedSubject,
          difficulty: _selectedDifficulty,
        ),
      ]);

      setState(() {
        _subjects = results[0] as List<TeacherSubject>;
        _questions = results[1] as List<QuestionBankItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _filterQuestions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final qs = await _apiService.getQuestionBank(
        subject: _selectedSubject,
        difficulty: _selectedDifficulty,
      );
      setState(() {
        _questions = qs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportTemplate(String type) async {
    try {
      final subject = _selectedSubject != 'All'
          ? _selectedSubject
          : (_subjects.isNotEmpty ? _subjects.first.name : 'Physics');
      final url = Uri.parse(
          '${_apiService.baseUrl}/teacher/question-bank/export-template?type=${type.toLowerCase()}&subject=${Uri.encodeComponent(subject)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export template: $e')),
      );
    }
  }

  Future<void> _handleBulkUpload(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.first.bytes != null) {
        setState(() {
          _isLoading = true;
        });

        final csvContent = utf8.decode(result.files.first.bytes!);
        final subject = _selectedSubject != 'All'
            ? _selectedSubject
            : (_subjects.isNotEmpty ? _subjects.first.name : 'Physics');

        final count = await _apiService.bulkUploadQuestions(
            csvContent, subject, type.toLowerCase());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully imported $count questions!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadData();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to upload questions: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Question Bank Repository',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
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
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Add Question',
            onPressed: () => _showQuestionFormDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            tooltip: 'Bulk Import/Export',
            onPressed: () => _showBulkImportExportPanel(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar
            _buildFilterBar(),

            // Consolidation metrics header
            _buildStatsHeader(),

            // List of questions in repository
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text('Error: $_error',
                              style: const TextStyle(color: Colors.red)))
                      : _questions.isEmpty
                          ? const Center(
                              child: Text(
                                  'No questions in repository. Click "+" to add.'))
                          : Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1000),
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16, top: 8, bottom: 80),
                                  itemCount: _questions.length,
                                  itemBuilder: (context, index) {
                                    return _buildQuestionTile(
                                        _questions[index]);
                                  },
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final List<String> subjectOptions = [
      'All',
      ..._subjects.map((s) => s.name).toSet()
    ];
    if (!subjectOptions.contains(_selectedSubject)) {
      _selectedSubject = 'All';
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSubject,
              decoration: const InputDecoration(
                  labelText: 'Subject',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              items: subjectOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedSubject = v!;
                });
                _filterQuestions();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedDifficulty,
              decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              items: const ['All', 'Easy', 'Medium', 'Hard']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedDifficulty = v!;
                });
                _filterQuestions();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_questions.length} Questions',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _questionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'mcq':
        return 'Single Select';
      case 'multi_correct':
        return 'Multi Select';
      case 'short_answer':
        return 'Short Answer';
      case 'long_answer':
        return 'Long Answer';
      case 'subjective':
        return 'Subjective';
      case 'numerical':
        return 'Numerical';
      case 'true_false':
        return 'True / False';
      default:
        return type.toUpperCase();
    }
  }

  Widget _buildQuestionTile(QuestionBankItem question) {
    Color levelColor;
    switch (question.difficulty.toLowerCase()) {
      case 'easy':
        levelColor = Colors.green;
        break;
      case 'medium':
        levelColor = Colors.orange;
        break;
      default:
        levelColor = Colors.red;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    question.difficulty,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: levelColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_questionTypeLabel(question.questionType)} • ${question.marks} Marks',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  onPressed: () => _confirmDeleteQuestion(question.id),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              question.questionText,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
            ),
            if (question.options.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...question.options.asMap().entries.map((entry) {
                // For multi_correct, check if option is in comma-separated correct answers
                final bool isCorrect = question.questionType == 'multi_correct'
                    ? question.correctAnswer
                        .split(',')
                        .map((s) => s.trim())
                        .contains(entry.value)
                    : question.correctAnswer == entry.value;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isCorrect
                            ? const Color(0xFF10B981)
                            : Colors.transparent),
                  ),
                  child: Text(
                    '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isCorrect ? FontWeight.bold : FontWeight.normal,
                      color:
                          isCorrect ? const Color(0xFF065F46) : Colors.black87,
                    ),
                  ),
                );
              }),
            ] else if (question.correctAnswer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Correct Answer: ${question.correctAnswer}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5)),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  '${question.subjectName} - ${question.chapter ?? "General"}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showQuestionFormDialog(question: question),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteQuestion(String id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text(
            'Are you sure you want to delete this question from the Question Bank?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              try {
                await _apiService.deleteQuestionFromBank(id);
                _loadData();
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete question: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showQuestionFormDialog({QuestionBankItem? question}) {
    final formKey = GlobalKey<FormState>();
    final qTextController =
        TextEditingController(text: question?.questionText ?? '');
    final chapterController =
        TextEditingController(text: question?.chapter ?? '');
    final marksController =
        TextEditingController(text: question?.marks.toString() ?? '1');

    String qType = question?.questionType ?? 'mcq';
    if (qType == 'subjective') qType = 'short_answer';
    if (qType == 'true_false')
      qType = 'mcq'; // true_false is covered by single-select MCQ
    if (qType != 'mcq' &&
        qType != 'multi_correct' &&
        qType != 'short_answer' &&
        qType != 'long_answer') {
      qType = 'mcq';
    }

    String difficulty = question?.difficulty ?? 'Medium';
    final allowedDiffs = ['Easy', 'Medium', 'Hard'];
    if (!allowedDiffs.contains(difficulty)) {
      final match = allowedDiffs.firstWhere(
        (d) => d.toLowerCase() == difficulty.toLowerCase(),
        orElse: () => 'Medium',
      );
      difficulty = match;
    }

    String selectedSubName = _selectedSubject != 'All'
        ? _selectedSubject
        : (_subjects.isNotEmpty ? _subjects.first.name : 'Physics');
    if (question != null) {
      selectedSubName = question.subjectName;
    }
    final subjectNames = _subjects.map((s) => s.name).toSet().toList();
    if (subjectNames.isEmpty) {
      subjectNames.add(selectedSubName);
    }
    if (!subjectNames.contains(selectedSubName)) {
      selectedSubName = subjectNames.first;
    }

    // MCQ / multi_correct options state
    List<TextEditingController> optionControllers = [];
    if (question != null &&
        (question.questionType == 'mcq' ||
            question.questionType == 'multi_correct')) {
      optionControllers =
          question.options.map((o) => TextEditingController(text: o)).toList();
    } else {
      optionControllers = [
        TextEditingController(text: ''),
        TextEditingController(text: ''),
        TextEditingController(text: ''),
        TextEditingController(text: ''),
      ];
    }
    // Single-select correct answer
    String mcqCorrectAnswer = '';
    if (question != null && question.questionType == 'mcq') {
      mcqCorrectAnswer = question.correctAnswer;
    }
    // Multi-select correct answers (list of correct option texts)
    List<String> multiCorrectAnswers = [];
    if (question != null && question.questionType == 'multi_correct') {
      // stored as comma-separated string or JSON list
      try {
        final decoded = question.correctAnswer;
        if (decoded.startsWith('[')) {
          multiCorrectAnswers = List<String>.from(decoded
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty));
        } else {
          multiCorrectAnswers = decoded
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {
        multiCorrectAnswers = [];
      }
    }

    // Subjective state
    final subjectiveAnswerController = TextEditingController(
      text: (qType == 'short_answer' ||
              qType == 'long_answer' ||
              qType == 'subjective')
          ? (question?.correctAnswer ?? '')
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
        final double width =
            isDesktop ? 550 : MediaQuery.of(context).size.width;
        final beginOffset = isDesktop ? const Offset(1, 0) : const Offset(0, 1);

        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeInOut)),
          child: Align(
            alignment:
                isDesktop ? Alignment.centerRight : Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              borderRadius: isDesktop
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24))
                  : const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
              child: SafeArea(
                bottom: !isDesktop,
                child: SizedBox(
                  width: width,
                  height: isDesktop
                      ? double.infinity
                      : MediaQuery.of(context).size.height * 0.85,
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Form(
                        key: formKey,
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 18),
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    question != null
                                        ? Icons.edit_note
                                        : Icons.add_circle_outline,
                                    color: const Color(0xFF6366F1),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    question != null
                                        ? 'Edit Question'
                                        : 'Add Question to Bank',
                                    style: const TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Color(0xFF64748B)),
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
                                      initialValue: selectedSubName,
                                      decoration: InputDecoration(
                                        labelText: 'Subject',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      items: subjectNames
                                          .map((name) => DropdownMenuItem(
                                              value: name, child: Text(name)))
                                          .toList(),
                                      onChanged: (v) => setDialogState(
                                          () => selectedSubName = v!),
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      initialValue: qType,
                                      decoration: InputDecoration(
                                        labelText: 'Question Type',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'mcq',
                                          child: Row(children: [
                                            Icon(Icons.radio_button_checked,
                                                size: 16,
                                                color: Color(0xFF6366F1)),
                                            SizedBox(width: 8),
                                            Text('Single Select (MCQ)')
                                          ]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'multi_correct',
                                          child: Row(children: [
                                            Icon(Icons.check_box,
                                                size: 16,
                                                color: Color(0xFF059669)),
                                            SizedBox(width: 8),
                                            Text('Multi Select (Checkboxes)')
                                          ]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'short_answer',
                                          child: Row(children: [
                                            Icon(Icons.short_text,
                                                size: 16,
                                                color: Color(0xFFF59E0B)),
                                            SizedBox(width: 8),
                                            Text('Short Answer (Subjective)')
                                          ]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'long_answer',
                                          child: Row(children: [
                                            Icon(Icons.subject,
                                                size: 16,
                                                color: Color(0xFFEF4444)),
                                            SizedBox(width: 8),
                                            Text('Long Answer (Subjective)')
                                          ]),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setDialogState(() {
                                          qType = v!;
                                          // Reset multi correct answers when switching types
                                          if (v != 'multi_correct')
                                            multiCorrectAnswers.clear();
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
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      validator: (v) => v == null || v.isEmpty
                                          ? 'Question is required'
                                          : null,
                                    ),

                                    // DYNAMIC INPUTS ACCORDING TO QUESTION TYPE
                                    if (qType == 'mcq' ||
                                        qType == 'multi_correct') ...[
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Icon(
                                            qType == 'multi_correct'
                                                ? Icons.check_box
                                                : Icons.radio_button_checked,
                                            size: 16,
                                            color: qType == 'multi_correct'
                                                ? const Color(0xFF059669)
                                                : const Color(0xFF6366F1),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            qType == 'multi_correct'
                                                ? 'Options & Correct Answers (check all that apply)'
                                                : 'Configure Options',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      if (qType == 'multi_correct')
                                        const Padding(
                                          padding: EdgeInsets.only(
                                              top: 4, bottom: 8),
                                          child: Text(
                                            'Tick the checkboxes next to all correct options.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B)),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 10),
                                      ...optionControllers
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final ctrl = entry.value;
                                        final optText = ctrl.text.trim();
                                        final isCorrect =
                                            qType == 'multi_correct' &&
                                                multiCorrectAnswers
                                                    .contains(optText);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: Row(
                                            children: [
                                              if (qType == 'multi_correct')
                                                GestureDetector(
                                                  onTap: () {
                                                    setDialogState(() {
                                                      final t =
                                                          ctrl.text.trim();
                                                      if (t.isEmpty) return;
                                                      if (multiCorrectAnswers
                                                          .contains(t)) {
                                                        multiCorrectAnswers
                                                            .remove(t);
                                                      } else {
                                                        multiCorrectAnswers
                                                            .add(t);
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: isCorrect
                                                          ? const Color(
                                                              0xFF059669)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: isCorrect
                                                            ? const Color(
                                                                0xFF059669)
                                                            : const Color(
                                                                0xFFCBD5E1),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: isCorrect
                                                        ? const Icon(
                                                            Icons.check,
                                                            size: 14,
                                                            color: Colors.white)
                                                        : null,
                                                  ),
                                                )
                                              else
                                                CircleAvatar(
                                                  radius: 11,
                                                  backgroundColor:
                                                      const Color(0xFF6366F1)
                                                          .withValues(
                                                              alpha: 0.1),
                                                  child: Text(
                                                    String.fromCharCode(
                                                        65 + idx),
                                                    style: const TextStyle(
                                                        fontSize: 9,
                                                        color:
                                                            Color(0xFF6366F1),
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: ctrl,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Option ${idx + 1}',
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 12,
                                                            vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide: BorderSide(
                                                        color: isCorrect
                                                            ? const Color(
                                                                0xFF059669)
                                                            : const Color(
                                                                0xFFCBD5E1),
                                                      ),
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide: BorderSide(
                                                        color: isCorrect
                                                            ? const Color(
                                                                0xFF059669)
                                                            : const Color(
                                                                0xFFCBD5E1),
                                                      ),
                                                    ),
                                                    filled: isCorrect,
                                                    fillColor:
                                                        const Color(0xFFF0FDF4),
                                                  ),
                                                  onChanged: (v) {
                                                    setDialogState(() {});
                                                  },
                                                ),
                                              ),
                                              if (optionControllers.length > 2)
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      color: Colors.red,
                                                      size: 18),
                                                  onPressed: () {
                                                    setDialogState(() {
                                                      final removed =
                                                          optionControllers[idx]
                                                              .text
                                                              .trim();
                                                      optionControllers
                                                          .removeAt(idx);
                                                      multiCorrectAnswers
                                                          .remove(removed);
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
                                            optionControllers.add(
                                                TextEditingController(
                                                    text: ''));
                                          });
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Option',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                      if (qType == 'mcq') ...[
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          initialValue: (mcqCorrectAnswer
                                                      .isNotEmpty &&
                                                  optionControllers.any((c) =>
                                                      c.text.trim() ==
                                                          mcqCorrectAnswer
                                                              .trim() &&
                                                      c.text.isNotEmpty))
                                              ? mcqCorrectAnswer.trim()
                                              : null,
                                          decoration: InputDecoration(
                                            labelText: 'Correct Answer Option',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          hint: const Text(
                                              'Select Correct Choice'),
                                          items: optionControllers
                                              .where((c) =>
                                                  c.text.trim().isNotEmpty)
                                              .map((c) => c.text.trim())
                                              .toSet()
                                              .map((text) => DropdownMenuItem(
                                                  value: text,
                                                  child: Text(text)))
                                              .toList(),
                                          onChanged: (v) => setDialogState(
                                              () => mcqCorrectAnswer = v!),
                                          validator: (v) => v == null
                                              ? 'Select correct answer'
                                              : null,
                                        ),
                                      ] else if (qType == 'multi_correct') ...[
                                        const SizedBox(height: 4),
                                        if (multiCorrectAnswers.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              '⚠️ Please tick at least one correct answer above.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFEF4444)),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0FDF4),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF86EFAC)),
                                            ),
                                            child: Text(
                                              '✓ Correct: ${multiCorrectAnswers.join(', ')}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF166534),
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                      ],
                                    ] else ...[
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: subjectiveAnswerController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Model/Correct Answer Description',
                                          alignLabelWithHint: true,
                                          hintText:
                                              'Enter key terms or full sentence answer...',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Correct answer description is required'
                                            : null,
                                      ),
                                    ],

                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: chapterController,
                                            decoration: InputDecoration(
                                              labelText: 'Chapter/Topic',
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: marksController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Marks',
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                            validator: (v) => v == null ||
                                                    int.tryParse(v) == null
                                                ? 'Must be integer'
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      initialValue: difficulty,
                                      decoration: InputDecoration(
                                        labelText: 'Difficulty Level',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      items: const ['Easy', 'Medium', 'Hard']
                                          .map((d) => DropdownMenuItem(
                                              value: d, child: Text(d)))
                                          .toList(),
                                      onChanged: (v) =>
                                          setDialogState(() => difficulty = v!),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Footer actions
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                border: Border(
                                    top: BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
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

                                          // extract properties
                                          String correctAns = '';
                                          List<String> options = [];
                                          if (qType == 'mcq') {
                                            correctAns = mcqCorrectAnswer;
                                            options = optionControllers
                                                .map((c) => c.text.trim())
                                                .where((t) => t.isNotEmpty)
                                                .toList();
                                            if (correctAns.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Please select a correct answer option.'),
                                                    backgroundColor:
                                                        Colors.red),
                                              );
                                              return;
                                            }
                                          } else if (qType == 'multi_correct') {
                                            if (multiCorrectAnswers.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Please tick at least one correct answer.'),
                                                    backgroundColor:
                                                        Colors.red),
                                              );
                                              return;
                                            }
                                            options = optionControllers
                                                .map((c) => c.text.trim())
                                                .where((t) => t.isNotEmpty)
                                                .toList();
                                            correctAns =
                                                multiCorrectAnswers.join(', ');
                                          } else {
                                            correctAns =
                                                subjectiveAnswerController.text
                                                    .trim();
                                          }

                                          final body = {
                                            'subject': selectedSubName,
                                            'question_type': qType,
                                            'question_text':
                                                qTextController.text.trim(),
                                            'options': options.isNotEmpty
                                                ? options
                                                : null,
                                            'correct_answer': correctAns,
                                            'chapter':
                                                chapterController.text.trim(),
                                            'marks': int.tryParse(
                                                    marksController.text) ??
                                                1,
                                            'difficulty': difficulty,
                                          };

                                          try {
                                            if (question != null) {
                                              await _apiService
                                                  .updateQuestionInBank(
                                                      question.id, body);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          '🎉 Question updated successfully!')));
                                            } else {
                                              await _apiService
                                                  .addQuestionToBank(body);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          '🎉 Question added to bank!')));
                                            }
                                            _loadData();
                                          } catch (e) {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to save question: $e')),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                          question != null ? 'Save' : 'Add'),
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

  void _showBulkImportExportPanel() {
    String selectedImportType = 'MCQ';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final isDesktop = MediaQuery.of(context).size.width >= 800;
        final double width =
            isDesktop ? 500 : MediaQuery.of(context).size.width;
        final beginOffset = isDesktop ? const Offset(1, 0) : const Offset(0, 1);

        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeInOut)),
          child: Align(
            alignment:
                isDesktop ? Alignment.centerRight : Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              borderRadius: isDesktop
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24))
                  : const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24)),
              child: SafeArea(
                bottom: !isDesktop,
                child: SizedBox(
                  width: width,
                  height: isDesktop
                      ? double.infinity
                      : MediaQuery.of(context).size.height * 0.85,
                  child: StatefulBuilder(
                    builder: (context, setPanelState) {
                      return Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0xFFF1F5F9))),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_upload_outlined,
                                    color: Color(0xFF6366F1), size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'Bulk Import & Export',
                                  style: TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Color(0xFF64748B)),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),

                          // Content
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Warning banner about subject column
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: Color(0xFF2563EB), size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Tip: CSV templates now support a "subject" column. The system maps it case-insensitively (e.g. Physics, Maths) to dynamically link subjects to imported questions.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF1E40AF),
                                                height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Download templates section
                                  const Text(
                                    '1. Download CSV Templates',
                                    style: TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Get structured spreadsheet layouts tailored to specific question formats.',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTemplateDownloadCard(
                                    title: 'Single Select (MCQ) Template',
                                    icon: Icons.radio_button_checked,
                                    iconColor: const Color(0xFF6366F1),
                                    desc:
                                        'Columns: subject, question_text, options (pipe-separated), correct_answer, difficulty, marks, chapter',
                                    onTap: () => _exportTemplate('mcq'),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTemplateDownloadCard(
                                    title: 'Multi Select (Checkboxes) Template',
                                    icon: Icons.check_box,
                                    iconColor: const Color(0xFF059669),
                                    desc:
                                        'Columns: subject, question_text, options (pipe-separated), correct_answers (comma-separated), difficulty, marks, chapter',
                                    onTap: () =>
                                        _exportTemplate('multi_correct'),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTemplateDownloadCard(
                                    title:
                                        'Subjective (Short/Long Answer) Template',
                                    icon: Icons.subject,
                                    iconColor: const Color(0xFFF59E0B),
                                    desc:
                                        'Columns: subject, question_text, model_answer, difficulty, marks, chapter',
                                    onTap: () =>
                                        _exportTemplate('short_answer'),
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Divider(color: Color(0xFFF1F5F9)),
                                  ),

                                  // Upload section
                                  const Text(
                                    '2. Upload Completed CSV Sheet',
                                    style: TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Import your questions dynamically into the repository.',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 16),

                                  DropdownButtonFormField<String>(
                                    initialValue: selectedImportType,
                                    decoration: InputDecoration(
                                      labelText: 'Question Format',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'MCQ',
                                          child: Text('Single Select (MCQ)')),
                                      DropdownMenuItem(
                                          value: 'multi_correct',
                                          child: Text(
                                              'Multi Select (Checkboxes)')),
                                      DropdownMenuItem(
                                          value: 'Short_Answer',
                                          child: Text(
                                              'Subjective (Short/Long Answer)')),
                                    ],
                                    onChanged: (v) => setPanelState(
                                        () => selectedImportType = v!),
                                  ),
                                  const SizedBox(height: 20),

                                  InkWell(
                                    onTap: () async {
                                      Navigator.pop(
                                          context); // Close panel before picking file
                                      _handleBulkUpload(selectedImportType);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 40, horizontal: 20),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF8FAFC),
                                            Color(0xFFEEF2FF)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1)
                                                .withValues(alpha: 0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: const Color(0xFF6366F1)
                                              .withValues(alpha: 0.3),
                                          style: BorderStyle.solid,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEEF2FF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                                Icons.file_upload_outlined,
                                                color: Color(0xFF6366F1),
                                                size: 28),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Select CSV Sheet File',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF1E293B)),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Click to browse files on your device.',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildTemplateDownloadCard({
    required String title,
    required String desc,
    required VoidCallback onTap,
    IconData icon = Icons.description_outlined,
    Color iconColor = const Color(0xFF6366F1),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_download_outlined,
                      size: 14, color: iconColor),
                  const SizedBox(width: 4),
                  Text(
                    'CSV',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: iconColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
