import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentOnlineExam extends ConsumerStatefulWidget {
  const StudentOnlineExam({super.key});

  @override
  ConsumerState<StudentOnlineExam> createState() => _StudentOnlineExamState();
}

class _StudentOnlineExamState extends ConsumerState<StudentOnlineExam> {
  final List<Map<String, dynamic>> _upcomingExams = [
    {
      'subject': 'Mathematics',
      'type': 'Final',
      'date': '28',
      'month': 'MAR',
      'time': '🕘 9:00 – 12:00 AM · 3 hrs',
      'hall': 'Hall A',
    },
    {
      'subject': 'Physics',
      'type': 'Final',
      'date': '30',
      'month': 'MAR',
      'time': '🕘 9:00 – 12:00 AM · 3 hrs',
      'hall': 'Hall B',
    },
    {
      'subject': 'Chemistry',
      'type': 'Final',
      'date': '01',
      'month': 'APR',
      'time': '🕘 9:00 – 12:00 AM · 3 hrs',
      'hall': 'Lab 2',
    },
    {
      'subject': 'English',
      'type': 'Final',
      'date': '03',
      'month': 'APR',
      'time': '🕘 10:00 AM – 1:00 PM',
      'hall': 'Hall A',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Exams',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white15,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🤖 AI Prep',
                    style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Next Exam Countdown
                _buildCountdownCard(),
                
                const SizedBox(height: 12),
                
                // AI Prep Tip
                _buildAITipCard(),
                
                const SizedBox(height: 16),
                
                // Section Title
                const Text(
                  'Exam Schedule',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Exam List
                ..._upcomingExams.map((exam) => _buildExamCard(exam)),
                
                const SizedBox(height: 16),
                
                // Online Exam Portal
                _buildOnlineExamPortal(),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF134E4A).withOpacity(0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Next Exam',
            style: TextStyle(
              fontSize: 11,
              color: StudentColors.text3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '📐 Mathematics — Final',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCountdownBox('05', 'Days'),
              const SizedBox(width: 8),
              _buildCountdownBox('14', 'Hours'),
              const SizedBox(width: 8),
              _buildCountdownBox('32', 'Mins'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF134E4A), Color(0xFF0F766E)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAITipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF134E4A), Color(0xFF0F766E)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🤖 AI Exam Prep Tip',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on your performance, focus on Integration & Calculus. These topics have 65% weightage in finals. Practice 10 problems daily.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white75,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white15,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('📚 Start AI Study Plan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF134E4A), Color(0xFF0F766E)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  exam['date']!,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  exam['month']!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam['subject']!,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exam['time']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              exam['hall']!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: StudentColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineExamPortal() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 Online Exam Portal',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Take MCQ-based exams online with a timer. Upload handwritten answers for subjective sections.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white75,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _startOnlineExam(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: StudentColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('✍️ Take Online Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showUploadDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('📤 Upload Answer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startOnlineExam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ExamInstructionsScreen(),
      ),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📤 Upload Answer Sheet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Subject',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: 'Mathematics',
              items: ['Mathematics', 'Physics', 'Chemistry', 'English'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {},
            ),
            const SizedBox(height: 16),
            Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: StudentColors.border),
                borderRadius: BorderRadius.circular(12),
                borderStyle: BorderStyle.solid,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📸', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to Upload',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    'JPG, PNG, PDF up to 10MB',
                    style: TextStyle(fontSize: 9, color: StudentColors.text3),
                  ),
                ],
              ),
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Answer sheet uploaded successfully!')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

// Exam Instructions Screen
class _ExamInstructionsScreen extends StatelessWidget {
  const _ExamInstructionsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Exam Instructions',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // Exam Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('📏', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      const Text(
                        'Physics Term 2 — Final',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Duration: 90 Minutes · Total Marks: 100',
                        style: TextStyle(
                          fontSize: 12,
                          color: StudentColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📜 General Instructions',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildInstructionItem('You can navigate between questions using the palette or next/prev buttons.'),
                      _buildInstructionItem('MCQs award +4 for correct and -1 for wrong answers.'),
                      _buildInstructionItem('Do NOT switch tabs or minimize the browser. AI monitoring is active.'),
                      _buildInstructionItem('Upload handwritten solutions in the "Upload" modal for subjective parts.'),
                      _buildInstructionItem('Exam will be auto-submitted when the timer hits zero.'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // AI Integrity Check
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: const Text(
                          'AI Integrity Check: We\'ve detected a stable connection. You are ready to begin. Good luck!',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF92400E),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Start Button
                ElevatedButton(
                  onPressed: () => _startExam(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    '🚀 Start Examination',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('●', style: TextStyle(color: StudentColors.primary, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: StudentColors.text2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startExam(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _ExamTakingScreen(),
      ),
    );
  }
}

// Exam Taking Screen
class _ExamTakingScreen extends StatefulWidget {
  const _ExamTakingScreen();

  @override
  State<_ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<_ExamTakingScreen> {
  int _currentQuestion = 0;
  final List<String?> _answers = List.filled(10, null);
  final List<bool> _reviewed = List.filled(10, false);
  int _timeLeft = 90 * 60; // 90 minutes

  final List<Map<String, dynamic>> _questions = [
    {'q': 'What is the speed of light in a vacuum?', 'options': ['3 x 10^8 m/s', '3 x 10^6 m/s', '3 x 10^10 m/s', '3 x 10^5 m/s'], 'correct': 0},
    {'q': 'The SI unit of Electrical Power is:', 'options': ['Joule', 'Watt', 'Ampere', 'Ohm'], 'correct': 1},
    {'q': 'Which lens is used to correct Myopia?', 'options': ['Convex', 'Concave', 'Cylindrical', 'Bifocal'], 'correct': 1},
    {'q': 'Sound waves in air are:', 'options': ['Transverse', 'Longitudinal', 'Electromagnetic', 'Polarized'], 'correct': 1},
    {'q': 'The process of heat transfer through direct contact is:', 'options': ['Convection', 'Radiation', 'Conduction', 'Absorption'], 'correct': 2},
    {'q': 'Which quantity remains constant in a series circuit?', 'options': ['Voltage', 'Resistance', 'Current', 'Power'], 'correct': 2},
    {'q': 'Newton\'s First Law of Motion is also known as:', 'options': ['Law of Force', 'Law of Inertia', 'Law of Action-Reaction', 'Law of Gravity'], 'correct': 1},
    {'q': 'The refractive index of water is approximately:', 'options': ['1.00', '1.33', '1.50', '2.42'], 'correct': 1},
    {'q': 'Which of these is a scalar quantity?', 'options': ['Velocity', 'Acceleration', 'Force', 'Work'], 'correct': 3},
    {'q': 'The frequency of AC in India is:', 'options': ['60 Hz', '50 Hz', '100 Hz', '220 Hz'], 'correct': 1},
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) _timeLeft--;
        });
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = (_timeLeft / 3600).floor();
    final m = ((_timeLeft % 3600) / 60).floor();
    final s = _timeLeft % 60;
    final timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
            decoration: const BoxDecoration(color: Color(0xFF0F172A)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Physics Term 2 — Final Exam',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Arjun Kumar | STU-2024-1082',
                        style: TextStyle(fontSize: 9, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _timeLeft < 300 ? Colors.red : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _timeLeft < 300 ? Colors.red : Colors.red.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⏱️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _timeLeft < 300 ? Colors.white : const Color(0xFFFCA5A5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Question Palette
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudentColors.surface,
              border: Border(bottom: BorderSide(color: StudentColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Question Navigator',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_answers.where((a) => a != null).length} of ${_questions.length} Answered',
                      style: const TextStyle(fontSize: 9, color: StudentColors.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_questions.length, (index) {
                    bool isAnswered = _answers[index] != null;
                    bool isCurrent = index == _currentQuestion;
                    bool isReviewed = _reviewed[index];

                    Color bgColor;
                    if (isCurrent) bgColor = StudentColors.primary;
                    else if (isReviewed) bgColor = StudentColors.warning;
                    else if (isAnswered) bgColor = StudentColors.success;
                    else bgColor = const Color(0xFFF1F5F9);

                    return GestureDetector(
                      onTap: () => setState(() => _currentQuestion = index),
                      child: Container(
                        width: 32,
                        height: 28,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrent ? StudentColors.primary : StudentColors.border,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isCurrent ? Colors.white : (isAnswered ? Colors.white : StudentColors.text3),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Question Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StudentColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentQuestion + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: StudentColors.text3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: StudentColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '+4 / -1 Marks',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _questions[_currentQuestion]['q']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(4, (optIndex) {
                      return _buildOption(
                        _questions[_currentQuestion]['options'][optIndex],
                        optIndex,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudentColors.surface,
              border: Border(top: BorderSide(color: StudentColors.border)),
            ),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => _showExitDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: StudentColors.text2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Exit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _reviewed[_currentQuestion] = !_reviewed[_currentQuestion];
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _reviewed[_currentQuestion] ? StudentColors.warning : const Color(0xFFF1F5F9),
                    foregroundColor: _reviewed[_currentQuestion] ? Colors.white : StudentColors.text2,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _reviewed[_currentQuestion] ? '🚩 Marked' : '🚩 Review',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                if (_currentQuestion < _questions.length - 1)
                  ElevatedButton(
                    onPressed: () => setState(() => _currentQuestion++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: StudentColors.text2,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('< Prev', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                if (_currentQuestion == _questions.length - 1)
                  ElevatedButton(
                    onPressed: () => _submitExam(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Submit Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                if (_currentQuestion < _questions.length - 1)
                  ElevatedButton(
                    onPressed: () => setState(() => _currentQuestion++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Next →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(String text, int index) {
    final isSelected = _answers[_currentQuestion] == index;
    return GestureDetector(
      onTap: () => setState(() => _answers[_currentQuestion] = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? StudentColors.primaryLight : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? StudentColors.primary : StudentColors.border,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? StudentColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? StudentColors.primary : StudentColors.text3, width: 1.5),
              ),
              child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? StudentColors.primary : StudentColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🛑 Exit Examination?'),
        content: const Text('Walking away now will submit your exam as-is. This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay & Work'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentColors.error),
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            child: const Text('Yes, Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _submitExam() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Final Submission?'),
        content: Text('You have answered ${_answers.where((a) => a != null).length} of ${_questions.length} questions. Are you sure you want to submit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentColors.success),
            onPressed: () {
              Navigator.pop(context);
              _showSuccessScreen();
            },
            child: const Text('Yes, Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF0FDF4),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✅', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                    'Exam Submitted!',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Physics Term 2 — Final Exam',
                    style: TextStyle(fontSize: 13, color: StudentColors.success),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StudentColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: StudentColors.success.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Submission ID', style: TextStyle(fontSize: 12, color: StudentColors.text3)),
                            const Text('EV-EX-2024-8742', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Submitted at', style: TextStyle(fontSize: 12, color: StudentColors.text3)),
                            Text(DateTime.now().toString().substring(11, 16), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Text('${_answers.where((a) => a != null).length}/${_questions.length}', style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 20, fontWeight: FontWeight.w800, color: StudentColors.success)),
                                    const Text('Attempted', style: TextStyle(fontSize: 10, color: Color(0xFF065F46))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    const Text('+250', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                                    const Text('XP Earned', style: TextStyle(fontSize: 10, color: Color(0xFF1E40AF))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)]),
                            border: Border.all(color: StudentColors.success, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Text('🤖', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'AI Verdict: Integrity maintained. No screen switches detected. Results will be published on April 10.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.go('/student/dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Home Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}