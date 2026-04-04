import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentAttendance extends ConsumerStatefulWidget {
  const StudentAttendance({super.key});

  @override
  ConsumerState<StudentAttendance> createState() => _StudentAttendanceState();
}

class _StudentAttendanceState extends ConsumerState<StudentAttendance> {
  Map<String, dynamic>? _attendanceData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _attendanceData = {
        "overall_pct": 94.0,
        "present_days": 94,
        "absent_days": 4,
        "late_days": 2,
        "total_days": 100,
        "subject_wise": [
          { "subject": "Mathematics", "present": 19, "total": 20, "pct": 95.0 },
          { "subject": "Physics", "present": 18, "total": 20, "pct": 90.0 },
          { "subject": "Chemistry", "present": 20, "total": 20, "pct": 100.0 },
          { "subject": "English", "present": 19, "total": 20, "pct": 95.0 },
          { "subject": "Computer Science", "present": 18, "total": 20, "pct": 90.0 },
        ],
        "weekly": [95, 92, 96, 94, 90],
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final data = _attendanceData!;
    final weekly = data['weekly'] as List;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
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
                  'Attendance',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overall Statistics Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overall Attendance',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data['overall_pct']}%',
                              style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: data['overall_pct'] / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    _buildStatCard('✅', '${data['present_days']}', 'Present', StudentColors.successBg, StudentColors.success),
                    const SizedBox(width: 12),
                    _buildStatCard('❌', '${data['absent_days']}', 'Absent', StudentColors.errorBg, StudentColors.error),
                    const SizedBox(width: 12),
                    _buildStatCard('⏰', '${data['late_days']}', 'Late', StudentColors.warningBg, StudentColors.warning),
                  ],
                ),

                const SizedBox(height: 20),

                // Weekly Chart
                const Text(
                  'Weekly Trend',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 4,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: weekly.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                          isCurved: true,
                          color: StudentColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: StudentColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Subject Wise
                const Text(
                  'Subject Wise',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...(data['subject_wise'] as List).map((subject) => _buildSubjectCard(subject)),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final pct = subject['pct'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['subject'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: StudentColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 90 ? StudentColors.success : pct >= 75 ? StudentColors.warning : StudentColors.error,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}