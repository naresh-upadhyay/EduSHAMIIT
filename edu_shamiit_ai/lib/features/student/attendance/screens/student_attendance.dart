import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';

class StudentAttendance extends ConsumerStatefulWidget {
  const StudentAttendance({super.key});

  @override
  ConsumerState<StudentAttendance> createState() => _StudentAttendanceState();
}

class _StudentAttendanceState extends ConsumerState<StudentAttendance> {
  @override
  void initState() {
    super.initState();
    // Fetch attendance data when screen loads
    Future.microtask(() {
      ref.read(attendanceProvider.notifier).fetchAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);

    if (attendanceState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (attendanceState.error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFEFF6FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: StudentColors.error),
              const SizedBox(height: 16),
              const Text(
                'Failed to load attendance',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                attendanceState.error!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(attendanceProvider.notifier).fetchAttendance();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate summary data from records
    final records = attendanceState.records;
    final summary = attendanceState.summary;
    
    final overallPct = summary['overall_pct'] as num? ?? 0.0;
    final presentDays = summary['present_days'] as int? ?? 0;
    final absentDays = summary['absent_days'] as int? ?? 0;
    final lateDays = summary['late_days'] as int? ?? 0;
    final totalDays = summary['total_days'] as int? ?? 0;

    // Calculate subject-wise attendance
    final subjectWise = <Map<String, dynamic>>[];
    final subjectMap = <String, Map<String, int>>{};
    
    for (final record in records) {
      final subjectName = record.subjectName ?? 'General';
      if (!subjectMap.containsKey(subjectName)) {
        subjectMap[subjectName] = {'present': 0, 'total': 0};
      }
      if (record.status == 'present' || record.status == 'late') {
        subjectMap[subjectName]!['present'] = (subjectMap[subjectName]!['present'] ?? 0) + 1;
      }
      subjectMap[subjectName]!['total'] = (subjectMap[subjectName]!['total'] ?? 0) + 1;
    }
    
    for (final entry in subjectMap.entries) {
      final present = entry.value['present'] ?? 0;
      final total = entry.value['total'] ?? 0;
      final pct = total > 0 ? (present / total * 100) : 0.0;
      subjectWise.add({
        'subject': entry.key,
        'present': present,
        'total': total,
        'pct': pct,
      });
    }

    // Sort by percentage (lowest first)
    subjectWise.sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));

    // Calculate weekly trend (last 5 days)
    final weekly = <int>[];
    if (records.isNotEmpty) {
      // Group records by date and calculate daily percentage
      final dailyMap = <String, Map<String, int>>{};
      for (final record in records) {
        // Use a simple date grouping (in real app, would use actual dates)
        final dayKey = 'Day ${weekly.length + 1}';
        if (!dailyMap.containsKey(dayKey)) {
          dailyMap[dayKey] = {'present': 0, 'total': 0};
        }
        if (record.status == 'present' || record.status == 'late') {
          dailyMap[dayKey]!['present'] = (dailyMap[dayKey]!['present'] ?? 0) + 1;
        }
        dailyMap[dayKey]!['total'] = (dailyMap[dayKey]!['total'] ?? 0) + 1;
      }
      
      // Take last 5 days or pad with zeros
      final dailyValues = dailyMap.values.take(5).map((d) {
        final present = d['present'] ?? 0;
        final total = d['total'] ?? 0;
        return total > 0 ? ((present / total) * 100).round() : 0;
      }).toList();
      
      while (weekly.length < 5) {
        if (weekly.length < dailyValues.length) {
          weekly.add(dailyValues[weekly.length]);
        } else {
          weekly.add(overallPct.round());
        }
      }
    } else {
      weekly.addAll([0, 0, 0, 0, 0]);
    }

    final data = {
      'overall_pct': overallPct.toDouble(),
      'present_days': presentDays,
      'absent_days': absentDays,
      'late_days': lateDays,
      'total_days': totalDays,
      'subject_wise': subjectWise,
      'weekly': weekly,
    };

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
                          value: ((data['overall_pct'] ?? 0) as num) / 100,
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
                        color: Colors.black.withValues(alpha: 0.04),
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
            color: Colors.black.withValues(alpha: 0.04),
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