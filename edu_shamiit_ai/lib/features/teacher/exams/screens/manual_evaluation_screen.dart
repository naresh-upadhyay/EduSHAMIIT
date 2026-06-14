import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';

class ManualEvaluationScreen extends ConsumerStatefulWidget {
  final String examId;
  const ManualEvaluationScreen({super.key, required this.examId});

  @override
  ConsumerState<ManualEvaluationScreen> createState() => _ManualEvaluationScreenState();
}

class _ManualEvaluationScreenState extends ConsumerState<ManualEvaluationScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _subjectiveQuestions = [];
  
  int _currentStudentIndex = 0;
  bool _isLoading = true;
  String? _error;
  
  final _scoreController = TextEditingController();
  final _remarksController = TextEditingController();

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
      // 1. Fetch questions to identify subjective items
      final questions = await _apiService.getExamQuestions(widget.examId);
      final subjective = questions.where((q) => q['question_type'] == 'subjective').toList();
      
      // 2. Fetch submissions
      final submissionsData = await _apiService.getExamSubmissions(widget.examId);
      // We filter to submitted/graded submissions
      final filteredSubmissions = submissionsData.where((s) => s['status'] == 'submitted' || s['status'] == 'graded').toList();

      if (mounted) {
        setState(() {
          _subjectiveQuestions = subjective;
          _submissions = filteredSubmissions;
          _isLoading = false;
        });
        _initFieldsForCurrentStudent();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _initFieldsForCurrentStudent() {
    if (_submissions.isEmpty) return;
    final submission = _submissions[_currentStudentIndex];
    final score = submission['score'];
    _scoreController.text = score != null ? score.toString() : '';
    _remarksController.text = ''; // Clear comments
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitGrade() async {
    if (_submissions.isEmpty) return;
    final submission = _submissions[_currentStudentIndex];
    final scoreText = _scoreController.text.trim();
    if (scoreText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a grade score first.')),
      );
      return;
    }
    
    final score = double.tryParse(scoreText);
    if (score == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numerical score.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.gradeExamSubmission(
        widget.examId,
        submission['id'],
        score: score,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Score graded and submitted successfully!'), backgroundColor: Colors.green),
      );

      // Reload submissions and move to next
      final isLast = _currentStudentIndex == _submissions.length - 1;
      await _loadData();
      
      if (!mounted) return;
      if (!isLast) {
        setState(() {
          _currentStudentIndex++;
        });
        _initFieldsForCurrentStudent();
      } else {
        context.pushReplacement('/teacher/exams');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit grade: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open attachment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Subjective Evaluation',
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
          onPressed: () => safeGoBack(context, '/teacher/dashboard'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading submissions: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _submissions.isEmpty
                    ? const Center(
                        child: Text(
                          'No student submissions found for subjective review.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          _buildStudentSelectorHeader(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ..._subjectiveQuestions.map((q) => _buildQuestionBlock(q)),
                                  const SizedBox(height: 20),
                                  _buildGradingForm(),
                                ],
                              ),
                            ),
                          ),
                          _buildNavigationFooter(),
                        ],
                      ),
      ),
    );
  }

  Widget _buildStudentSelectorHeader() {
    final submission = _submissions[_currentStudentIndex];
    final profile = submission['profiles'] as Map<String, dynamic>? ?? {};
    final studentName = profile['full_name']?.toString() ?? 'Student';
    final rollNumber = profile['roll_number']?.toString() ?? 'STU-XXXX';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentStudentIndex > 0
                ? () {
                    setState(() {
                      _currentStudentIndex--;
                    });
                    _initFieldsForCurrentStudent();
                  }
                : null,
          ),
          Column(
            children: [
              Text(
                studentName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                rollNumber,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentStudentIndex < _submissions.length - 1
                ? () {
                    setState(() {
                      _currentStudentIndex++;
                    });
                    _initFieldsForCurrentStudent();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(Map<String, dynamic> question) {
    final submission = _submissions[_currentStudentIndex];
    final answers = submission['answers'] as Map<String, dynamic>? ?? {};
    final qId = question['id'];
    
    final ansVal = answers[qId] ?? answers[qId?.toString()];
    String studentText = 'No response written.';
    String? fileUrl;
    String? filename;

    if (ansVal is Map) {
      studentText = ansVal['text'] ?? '';
      fileUrl = ansVal['file_url'];
      filename = ansVal['filename'];
    } else if (ansVal is String) {
      studentText = ansVal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SUBJECTIVE QUESTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('${question['marks'] ?? 10} Max Marks', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question['question_text'] ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const Divider(height: 24),
          const Text('STUDENT RESPONSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            studentText.isNotEmpty ? studentText : 'No text response written.',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: Colors.black87),
          ),
          if (fileUrl != null) ...[
            const Divider(height: 24),
            const Text('ATTACHED SCAN SHEET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filename ?? 'answer_sheet.pdf',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_red_eye, color: Color(0xFF6366F1)),
                  onPressed: () => _launchUrl(fileUrl!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradingForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GRADING MARKS & FEEDBACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Award Total Score',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Remarks / Comments',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationFooter() {
    final isLast = _currentStudentIndex == _submissions.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitGrade,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(isLast ? 'Grade & Complete Evaluation' : 'Save & Grade Next Student'),
        ),
      ),
    );
  }
}
