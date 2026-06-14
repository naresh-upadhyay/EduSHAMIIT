import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';

class TeacherExamAnalyticsScreen extends ConsumerWidget {
  final String examId;
  const TeacherExamAnalyticsScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock analytics metrics
    final totalAssigned = 45;
    final participated = 42;
    final passRate = 88.0;
    final averageScore = 74.5;
    final highestScore = 98.0;
    final lowestScore = 32.0;

    final topicStats = [
      {'name': 'Electromagnetism', 'accuracy': 92, 'class_avg': '8.2/10'},
      {'name': 'Optics', 'accuracy': 84, 'class_avg': '4.1/5'},
      {'name': 'Kinematics', 'accuracy': 76, 'class_avg': '3.0/4'},
      {'name': 'Thermodynamics', 'accuracy': 52, 'class_avg': '3.1/6'},
    ];

    final difficultyStats = [
      {'level': 'Easy', 'accuracy': 95},
      {'level': 'Medium', 'accuracy': 78},
      {'level': 'Hard', 'accuracy': 46},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Exam Analytics Insights',
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
          onPressed: () => context.go('/teacher/exams'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Parameter Summary Grid Card
              _buildMetricsSummaryGrid(participated, totalAssigned, passRate, averageScore),
              const SizedBox(height: 20),

              // Highest & Lowest Score card
              _buildHighLowScoreCard(highestScore, lowestScore),
              const SizedBox(height: 20),

              // Topic-wise accuracy card
              const Text('Class Topic Accuracy Mastery', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
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
                              Text('Avg: ${topic['class_avg']} (${acc}%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                                acc >= 75 ? Colors.green : (acc >= 50 ? Colors.orange : Colors.red),
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

              // Difficulty level analysis card
              const Text('Question Difficulty Accuracy Index', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: difficultyStats.map((diff) {
                    final acc = diff['accuracy'] as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${diff['level']} Questions', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              Text('${acc}% Accuracy', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: acc / 100,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Excel download triggers
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading detailed CSV analytics report...')),
                    );
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export Analytics PDF Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSummaryGrid(int participated, int total, double passRate, double avg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSummaryGridItem('Participation', '$participated / $total', '93.3%')),
              Container(width: 1, height: 50, color: Colors.grey.shade200),
              Expanded(child: _buildSummaryGridItem('Pass Rate', '$passRate%', 'Emerald status', isSuccess: true)),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(child: _buildSummaryGridItem('Class Average', '$avg / 100', '74.5% score')),
              Container(width: 1, height: 50, color: Colors.grey.shade200),
              Expanded(child: _buildSummaryGridItem('Status', 'PUBLISHED', 'Parents notified', isSuccess: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGridItem(String label, String value, String subtitle, {bool isSuccess = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSuccess ? Colors.green.shade700 : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 9.5, color: isSuccess ? Colors.green.shade600 : Colors.grey)),
      ],
    );
  }

  Widget _buildHighLowScoreCard(double high, double low) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHighLowItem('Highest Score', '$high Marks', 'Sneha Sharma', Colors.indigo.shade800),
          Container(width: 1, height: 40, color: const Color(0xFFC7D2FE)),
          _buildHighLowItem('Lowest Score', '$low Marks', 'Pooja Patel (Needs Remedial)', Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _buildHighLowItem(String label, String score, String name, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(score, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(name, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
