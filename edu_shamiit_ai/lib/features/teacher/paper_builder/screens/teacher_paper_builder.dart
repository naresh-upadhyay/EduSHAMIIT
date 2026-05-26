import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherPaperBuilder extends ConsumerStatefulWidget {
  const TeacherPaperBuilder({super.key});

  @override
  ConsumerState<TeacherPaperBuilder> createState() => _TeacherPaperBuilderState();
}

class _TeacherPaperBuilderState extends ConsumerState<TeacherPaperBuilder> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedSubject = 'All';
  final List<String> _subjects = ['All', 'Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];
  List<PaperQuestion> _questions = [];
  bool _isLoading = true;
  String? _error;
  final List<PaperQuestion> _selectedQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final subject = _selectedSubject == 'All' ? null : _selectedSubject.toLowerCase();
      final questions = await _apiService.getQuestionBank(subject: subject);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'mcq':
        return Icons.radio_button_checked;
      case 'short':
        return Icons.short_text;
      case 'long':
        return Icons.notes;
      default:
        return Icons.question_mark;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Paper Builder',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_selectedQuestions.isNotEmpty)
                  TextButton(
                    onPressed: () => _generatePaper(),
                    child: Text(
                      'Generate (${_selectedQuestions.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // Subject filter
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                final isSelected = _selectedSubject == subject;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSubject = subject);
                    _loadQuestions();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subject,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadQuestions,
                      child: Text('Retry'.tr(ref)),
                    ),
                  ],
                ),
              ),
            ),

          // Questions list
          if (!_isLoading && _error == null)
            Expanded(
              child: _questions.isEmpty
                  ? Center(child: Text('No questions found in question bank'.tr(ref)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(_questions[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(PaperQuestion question) {
    final isSelected = _selectedQuestions.contains(question);
    final typeIcon = _getTypeIcon(question.questionType);
    final difficultyColor = _getDifficultyColor(question.difficulty ?? 'medium');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedQuestions.remove(question);
                } else {
                  _selectedQuestions.add(question);
                }
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                border: Border.all(color: const Color(0xFF6366F1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: difficultyColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: difficultyColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        question.difficulty ?? 'Medium',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: difficultyColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${question.marks} marks',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      question.chapter ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _generatePaper() async {
    if (_selectedQuestions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final totalMarks = _selectedQuestions.fold<int>(0, (sum, q) => sum + q.marks);
      
      await _apiService.generatePaper(
        title: 'Test Paper - ${DateTime.now().toString().split(' ')[0]}',
        subject: _selectedSubject == 'All' ? 'Mathematics' : _selectedSubject.toLowerCase(),
        classId: 'X-A',
        totalMarks: totalMarks,
        duration: '1 hour',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('? Paper generated successfully!'.tr(ref))),
        );
        setState(() {
          _selectedQuestions.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('? Error: $e')),
        );
      }
    }
  }
}
