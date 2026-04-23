import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'dart:async';

/// Online Exam Screen - Interactive exam interface with timer and question navigation
class OnlineExamScreen extends StatefulWidget {
  const OnlineExamScreen({super.key});

  @override
  State<OnlineExamScreen> createState() => _OnlineExamScreenState();
}

class _OnlineExamScreenState extends State<OnlineExamScreen> {
  Timer? _timer;
  Duration _timeRemaining = const Duration(hours: 2, minutes: 30);
  int _currentQuestion = 0;
  final Map<int, String?> _answers = {};
  final Map<int, bool> _reviewMarked = {};

  // Mock questions data
  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': 'If f(x) = x² + 3x + 2, find f\'(x).',
      'options': ['2x + 3', '2x + 2', 'x + 3', '2x² + 3'],
      'correct': 0,
      'section': 'Calculus',
    },
    {
      'id': 2,
      'question': 'Evaluate: ∫(2x + 1)dx',
      'options': ['x² + x + C', '2x² + x + C', 'x² + 2x + C', '2x + x² + C'],
      'correct': 0,
      'section': 'Calculus',
    },
    {
      'id': 3,
      'question': 'The value of sin²θ + cos²θ is:',
      'options': ['0', '1', '2', 'sin 2θ'],
      'correct': 1,
      'section': 'Trigonometry',
    },
    {
      'id': 4,
      'question': 'If A = {1, 2, 3} and B = {3, 4, 5}, then A ∩ B is:',
      'options': ['{1, 2, 3, 4, 5}', '{3}', '{1, 2, 4, 5}', '∅'],
      'correct': 1,
      'section': 'Sets',
    },
    {
      'id': 5,
      'question': 'The slope of line passing through (2, 3) and (4, 7) is:',
      'options': ['1', '2', '3', '4'],
      'correct': 1,
      'section': 'Coordinate Geometry',
    },
    {
      'id': 6,
      'question': 'lim(x→0) sin(x)/x equals:',
      'options': ['0', '1', '∞', 'undefined'],
      'correct': 1,
      'section': 'Calculus',
    },
    {
      'id': 7,
      'question': 'The determinant of [[2, 3], [1, 4]] is:',
      'options': ['5', '11', '8', '3'],
      'correct': ['11', '5', '8', '3'].indexOf('5'),
      'section': 'Matrices',
    },
    {
      'id': 8,
      'question': 'If P(A) = 0.4 and P(B) = 0.6, and A, B are independent, P(A∩B) =',
      'options': ['1.0', '0.24', '0.5', '0.8'],
      'correct': 1,
      'section': 'Probability',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining.inSeconds > 0) {
        setState(() {
          _timeRemaining = _timeRemaining - const Duration(seconds: 1);
        });
      } else {
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  void _autoSubmit() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⏰ Time\'s Up!'),
        content: const Text('Your exam has been automatically submitted.'),
        actions: [
          TextButton(
            onPressed: () {
              context.go('/student/exams');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTimer() {
    final hours = _timeRemaining.inHours;
    final minutes = _timeRemaining.inMinutes.remainder(60);
    final seconds = _timeRemaining.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get _answeredCount => _answers.values.where((a) => a != null).length;
  int get _reviewCount => _reviewMarked.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentQuestion];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitWarning();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Main Content
            Expanded(
              child: Row(
                children: [
                  // Question Area
                  Expanded(
                    flex: 3,
                    child: _buildQuestionArea(currentQ),
                  ),

                  // Question Navigator (Sidebar)
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: _buildQuestionNavigator(),
                  ),
                ],
              ),
            ),

            // Bottom Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isWarning = _timeRemaining.inMinutes < 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: _showExitWarning,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Exam Info
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mathematics - Final Exam',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total: 8 Questions • 30 Marks',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),

          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isWarning
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: isWarning ? Colors.red : Colors.white.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: isWarning ? Colors.red : Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimer(),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isWarning ? Colors.red : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildQuestionArea(Map<String, dynamic> question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: StudentColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Q${_currentQuestion + 1}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: StudentColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        question['section'],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Mark for Review
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _reviewMarked[_currentQuestion] = !(_reviewMarked[_currentQuestion] ?? false);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_reviewMarked[_currentQuestion] ?? false)
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_reviewMarked[_currentQuestion] ?? false)
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 14,
                              color: (_reviewMarked[_currentQuestion] ?? false)
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Review',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: (_reviewMarked[_currentQuestion] ?? false)
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  question['question'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Options
          ...List.generate(question['options'].length, (index) {
            final isSelected = _answers[_currentQuestion] == question['options'][index];
            final option = question['options'][index];

            return GestureDetector(
              onTap: () {
                setState(() {
                  _answers[_currentQuestion] = option;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? StudentColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? StudentColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? StudentColors.primary : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? StudentColors.primary : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Subjective Answer Section
          const SizedBox(height: 20),
          const Text(
            'Subjective Answer (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                const Expanded(
                  child: TextField(
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type your detailed answer here...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: const Text(
                      'Attach Image',
                      style: TextStyle(fontSize: 12),
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

  Widget _buildQuestionNavigator() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: const Text(
            'Questions',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildStatRow('Answered', _answeredCount, _questions.length, Colors.green),
              const SizedBox(height: 4),
              _buildStatRow('Unanswered', _questions.length - _answeredCount, _questions.length, Colors.orange),
              const SizedBox(height: 4),
              _buildStatRow('Review', _reviewCount, _questions.length, Colors.amber),
            ],
          ),
        ),

        const Divider(),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final isAnswered = _answers[index] != null;
              final isCurrent = index == _currentQuestion;
              final isReview = _reviewMarked[index] ?? false;

              Color bgColor;
              if (isCurrent) {
                bgColor = StudentColors.primary;
              } else if (isReview) {
                bgColor = Colors.amber;
              } else if (isAnswered) {
                bgColor = Colors.green;
              } else {
                bgColor = const Color(0xFFF1F5F9);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentQuestion = index;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: isCurrent
                        ? Border.all(color: StudentColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCurrent || isAnswered || isReview
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, int value, int total, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          '$value/$total',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous Button
          _buildNavButton(
            '← Previous',
            _currentQuestion > 0,
            () {
              setState(() {
                _currentQuestion--;
              });
            },
          ),

          const Spacer(),

          // Next Button
          if (_currentQuestion < _questions.length - 1)
            _buildNavButton(
              'Next →',
              true,
              () {
                setState(() {
                  _currentQuestion++;
                });
              },
              isPrimary: true,
            )
          else
            // Submit Button
            _buildNavButton(
              '✓ Submit Exam',
              true,
              _showSubmitDialog,
              isPrimary: true,
              isSuccess: true,
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, bool enabled, VoidCallback onPressed,
      {bool isPrimary = false, bool isSuccess = false}) {
    Color bgColor;
    if (isSuccess) {
      bgColor = const Color(0xFF10B981);
    } else if (isPrimary) {
      bgColor = StudentColors.primary;
    } else {
      bgColor = const Color(0xFFF1F5F9);
    }

    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: isPrimary || isSuccess ? Colors.white : const Color(0xFF64748B),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showExitWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Exit Exam?'),
        content: const Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/student/exams');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📝 Submit Exam?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have answered $_answeredCount out of ${_questions.length} questions.'),
            const SizedBox(height: 8),
            if (_reviewCount > 0)
              Text('⚠️ $_reviewCount questions marked for review.'),
            const SizedBox(height: 12),
            const Text('Are you sure you want to submit?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Exam'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _submitExam() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Exam Submitted!',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You answered $_answeredCount questions correctly.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.go('/student/exams');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('View Results'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
