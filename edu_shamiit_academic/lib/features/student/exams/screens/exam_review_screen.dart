import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/student_api_service.dart';

class ExamReviewScreen extends StatefulWidget {
  final String examId;
  const ExamReviewScreen({super.key, required this.examId});

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  final StudentApiService _apiService = StudentApiService();
  bool _isLoading = true;
  String? _error;
  String _examTitle = 'Answer Review';
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;

  // Palette scroll
  final ScrollController _paletteScroll = ScrollController();

  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _teal = Color(0xFF0D9488);
  static const _tealDark = Color(0xFF115E59);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _paletteScroll.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await _apiService.getOnlineExamResultDetails(widget.examId);
      final raw = (data['question_review'] as List?)?.cast<dynamic>() ?? [];
      if (mounted) {
        setState(() {
          _examTitle = data['exam_title']?.toString() ?? 'Answer Review';
          _questions =
              raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
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

  Color _statusColor(String status) {
    switch (status) {
      case 'correct':
        return const Color(0xFF10B981);
      case 'partial':
        return const Color(0xFFF59E0B);
      case 'incorrect':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B); // skipped
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'correct':
        return Icons.check_circle_rounded;
      case 'partial':
        return Icons.remove_circle_rounded;
      case 'incorrect':
        return Icons.cancel_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'correct':
        return 'Correct';
      case 'partial':
        return 'Partial';
      case 'incorrect':
        return 'Incorrect';
      default:
        return 'Skipped';
    }
  }

  String _qTypeLabel(String type) {
    switch (type) {
      case 'single_select':
        return 'MCQ · Single';
      case 'multi_select':
        return 'MCQ · Multi';
      case 'subjective':
        return 'Subjective';
      case 'true_false':
        return 'True / False';
      case 'fill_blank':
        return 'Fill in Blank';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  void _goTo(int idx) {
    setState(() => _currentIndex = idx);
    // Auto-scroll palette to keep selected chip visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_paletteScroll.hasClients) {
        final target = idx * 44.0; // approx chip width
        _paletteScroll.animateTo(
          target.clamp(0, _paletteScroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _teal),
              SizedBox(height: 16),
              Text(
                'Loading Review...',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontFamily: AppFonts.heading),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      context.go('/student/exams/result/${widget.examId}'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _teal, foregroundColor: Colors.white),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('No questions found for review.',
              style: TextStyle(color: Colors.white60)),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final status = q['status']?.toString() ?? 'skipped';
    final statusColor = _statusColor(status);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ── Question Palette ──────────────────────────────────────────
          _buildPalette(),

          // ── Progress bar ─────────────────────────────────────────────
          Container(
            height: 3,
            color: const Color(0xFF1E293B),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_currentIndex + 1) / _questions.length,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_tealDark, statusColor],
                  ),
                ),
              ),
            ),
          ),

          // ── Main Question Panel ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: _buildQuestionPanel(q, statusColor, status),
            ),
          ),
        ],
      ),
      // ── Bottom Navigation Bar ───────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(statusColor),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _card,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.go('/student/exams/result/${widget.examId}'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _examTitle,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            'Answer Review Mode',
            style: TextStyle(
                fontSize: 10,
                color: Colors.white38,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        // Summary chips
        _buildSummaryChip(
            _questions.where((q) => q['status'] == 'correct').length,
            const Color(0xFF10B981)),
        _buildSummaryChip(
            _questions.where((q) => q['status'] == 'incorrect').length,
            const Color(0xFFEF4444)),
        _buildSummaryChip(
            _questions.where((q) => q['status'] == 'skipped').length,
            const Color(0xFF64748B)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSummaryChip(int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count',
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildPalette() {
    return Container(
      height: 52,
      color: const Color(0xFF162032),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListView.builder(
        controller: _paletteScroll,
        scrollDirection: Axis.horizontal,
        itemCount: _questions.length,
        itemBuilder: (ctx, idx) {
          final q = _questions[idx];
          final status = q['status']?.toString() ?? 'skipped';
          final color = _statusColor(status);
          final isSelected = idx == _currentIndex;

          return GestureDetector(
            onTap: () => _goTo(idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              width: 36,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '${idx + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionPanel(
      Map<String, dynamic> q, Color statusColor, String status) {
    final qNum = q['number'] ?? (_currentIndex + 1);
    final questionText = q['question']?.toString() ?? '';
    final qType = q['type']?.toString() ?? '';
    final maxMarks = (q['max_marks'] as num?)?.toDouble() ?? 1.0;
    final marksObtained = (q['marks_obtained'] as num?)?.toDouble() ?? 0.0;
    final studentAnswer = q['student_answer']?.toString();
    final correctAnswer = q['correct_answer']?.toString();
    final teacherFeedback = q['teacher_feedback']?.toString();
    final options = (q['options'] as List?)?.cast<dynamic>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Question Header Card ──────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status + type row
              Row(
                children: [
                  Icon(_statusIcon(status), color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel(status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  // Marks pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${marksObtained % 1 == 0 ? marksObtained.toInt() : marksObtained} / ${maxMarks % 1 == 0 ? maxMarks.toInt() : maxMarks} marks',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Type label
              Text(
                'Q$qNum  ·  ${_qTypeLabel(qType)}',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              // Question text
              Text(
                questionText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Answer Section ───────────────────────────────────────────
        if (options.isNotEmpty) ...[
          const _SectionLabel(text: 'Options'),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((e) {
            final optIdx = e.key;
            final optText = e.value.toString();
            final optLetter = String.fromCharCode(65 + optIdx);

            final isStudentChoice = studentAnswer != null &&
                (studentAnswer.toUpperCase() == optText.toUpperCase() ||
                    studentAnswer.toUpperCase() == optLetter);
            final isCorrectOption = correctAnswer != null &&
                (correctAnswer.toUpperCase() == optText.toUpperCase() ||
                    correctAnswer.toUpperCase() == optLetter);

            Color optBorder = Colors.white.withValues(alpha: 0.07);
            Color optBg = Colors.white.withValues(alpha: 0.04);
            Color optText0 = Colors.white54;
            IconData? trailIcon;
            Color trailColor = Colors.transparent;

            if (isCorrectOption) {
              optBg = const Color(0xFF064E3B).withValues(alpha: 0.5);
              optBorder = const Color(0xFF10B981);
              optText0 = const Color(0xFF6EE7B7);
              trailIcon = Icons.check_circle_rounded;
              trailColor = const Color(0xFF10B981);
            }
            if (isStudentChoice && !isCorrectOption) {
              optBg = const Color(0xFF7F1D1D).withValues(alpha: 0.4);
              optBorder = const Color(0xFFEF4444);
              optText0 = const Color(0xFFFCA5A5);
              trailIcon = Icons.cancel_rounded;
              trailColor = const Color(0xFFEF4444);
            }
            if (isStudentChoice && isCorrectOption) {
              trailIcon = Icons.check_circle_rounded;
              trailColor = const Color(0xFF10B981);
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: optBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: optBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  // Letter circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCorrectOption
                          ? const Color(0xFF10B981)
                          : (isStudentChoice
                              ? const Color(0xFFEF4444)
                              : Colors.white.withValues(alpha: 0.1)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        optLetter,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: (isCorrectOption || isStudentChoice)
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      optText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: (isCorrectOption || isStudentChoice)
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: optText0,
                      ),
                    ),
                  ),
                  if (trailIcon != null)
                    Icon(trailIcon, size: 18, color: trailColor),
                ],
              ),
            );
          }),
        ],

        // ── Non-MCQ text answers ────────────────────────────────────
        if (options.isEmpty) ...[
          // Your answer
          const _SectionLabel(text: 'Your Answer'),
          const SizedBox(height: 8),
          _buildTextAnswerBlock(
            text: studentAnswer ?? 'Not answered — question was skipped',
            color: status == 'correct'
                ? const Color(0xFF10B981)
                : (status == 'skipped'
                    ? Colors.white38
                    : const Color(0xFFEF4444)),
            bg: status == 'correct'
                ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                : (status == 'skipped'
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFF7F1D1D).withValues(alpha: 0.4)),
            border: status == 'correct'
                ? const Color(0xFF10B981)
                : (status == 'skipped'
                    ? Colors.white12
                    : const Color(0xFFEF4444)),
            italic: studentAnswer == null,
          ),
          // Always show correct answer
          if (correctAnswer != null && correctAnswer.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _SectionLabel(text: 'Correct Answer'),
            const SizedBox(height: 8),
            _buildTextAnswerBlock(
              text: correctAnswer,
              color: const Color(0xFF6EE7B7),
              bg: const Color(0xFF064E3B).withValues(alpha: 0.4),
              border: const Color(0xFF10B981),
            ),
          ],
        ],

        // ── Always show correct answer for MCQ too if skipped ────────
        if (options.isNotEmpty &&
            status == 'skipped' &&
            correctAnswer != null &&
            correctAnswer.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded,
                    size: 14, color: Color(0xFF6EE7B7)),
                const SizedBox(width: 8),
                const Text('Correct Answer: ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w700)),
                Expanded(
                  child: Text(
                    correctAnswer,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Teacher Feedback ─────────────────────────────────────────
        if (teacherFeedback != null && teacherFeedback.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B69).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rate_review_rounded,
                    size: 15, color: Color(0xFFA78BFA)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEACHER FEEDBACK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFA78BFA),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacherFeedback,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDDD6FE),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextAnswerBlock({
    required String text,
    required Color color,
    required Color bg,
    required Color border,
    bool italic = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildBottomNav(Color statusColor) {
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < _questions.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: _card,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          // Prev
          Expanded(
            child: AnimatedOpacity(
              opacity: hasPrev ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: OutlinedButton.icon(
                onPressed: hasPrev ? () => _goTo(_currentIndex - 1) : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${_currentIndex + 1} / ${_questions.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Next / Done
          Expanded(
            child: hasNext
                ? ElevatedButton.icon(
                    onPressed: () => _goTo(_currentIndex + 1),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/student/exams/result/${widget.examId}'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: Colors.white38,
        letterSpacing: 1.2,
      ),
    );
  }
}
