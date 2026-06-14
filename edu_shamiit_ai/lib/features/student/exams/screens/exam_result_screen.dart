import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ExamResultScreen extends ConsumerWidget {
  final String examId;
  const ExamResultScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock result metrics
    final totalQuestions = 25;
    final correctAnswers = 19;
    final incorrectAnswers = 4;
    final skippedAnswers = 2;
    
    final scoreObtained = 76.0;
    final totalMarks = 100.0;
    final percentage = (scoreObtained / totalMarks) * 100;
    final accuracy = (correctAnswers / (correctAnswers + incorrectAnswers)) * 100;
    
    final rank = '14th';
    final classTotal = '45 students';
    final grade = 'B+';
    final status = 'PASS';
    
    final timeTaken = '1h 12m';
    final proctorIntegrity = 'Excellent (0 warnings)';

    final topicStats = [
      {'name': 'Electromagnetism', 'accuracy': 90, 'count': '9/10'},
      {'name': 'Optics', 'accuracy': 80, 'count': '4/5'},
      {'name': 'Thermodynamics', 'accuracy': 50, 'count': '3/6'},
      {'name': 'Kinematics', 'accuracy': 75, 'count': '3/4'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Exam Performance Analysis',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF134E4A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.go('/student/exams'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Score Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your Final Score',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$scoreObtained',
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' / $totalMarks',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickMetric('Rank', rank),
                        _buildQuickMetric('Grade', grade),
                        _buildQuickMetric('Status', status, color: Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail statistics card
              const Text('Detailed Statistics', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: StudentColors.border),
                ),
                child: Column(
                  children: [
                    _buildStatDetailRow('Total Questions', '$totalQuestions questions', Icons.quiz),
                    const Divider(),
                    _buildStatDetailRow('Correct Answers', '$correctAnswers correct', Icons.check_circle_outline, color: StudentColors.success),
                    const Divider(),
                    _buildStatDetailRow('Incorrect Answers', '$incorrectAnswers incorrect', Icons.highlight_off, color: StudentColors.error),
                    const Divider(),
                    _buildStatDetailRow('Skipped Answers', '$skippedAnswers skipped', Icons.skip_next_outlined),
                    const Divider(),
                    _buildStatDetailRow('Time Taken', timeTaken, Icons.access_time),
                    const Divider(),
                    _buildStatDetailRow('Accuracy Ratio', '${accuracy.toStringAsFixed(1)}%', Icons.track_changes),
                    const Divider(),
                    _buildStatDetailRow('Integrity Rating', proctorIntegrity, Icons.security, color: Colors.blue),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Topic-wise analysis card
              const Text('Topic Accuracy Mastery', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: StudentColors.border),
                ),
                child: Column(
                  children: topicStats.map((topic) {
                    final acc = topic['accuracy'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(topic['name'] as String, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              Text('${topic['count']} (${acc}%)', style: const TextStyle(fontSize: 11.5, color: StudentColors.text2)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: acc / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                acc >= 75 ? StudentColors.success : (acc >= 50 ? StudentColors.warning : StudentColors.error),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // AI Revision Study Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text(
                          'AI Study Revision Recommendation',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your score in Thermodynamics (50%) is relatively weak. We suggest reviewing pages 140-165 in your textbook and attempting thermodynamics mock sheets.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF312E81),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Primary Actions
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading detailed PDF report...')),
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download PDF Transcript'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF134E4A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    context.go('/student/dashboard');
                  },
                  child: const Text('Return to Home Dashboard'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? const Color(0xFF134E4A), size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 12, color: StudentColors.text2)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? StudentColors.text,
          ),
        ),
      ],
    );
  }
}
