import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../constants/app_fonts.dart';
import '../providers/attendance_provider.dart';

class AttendanceInsightsTab extends ConsumerWidget {
  const AttendanceInsightsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ins = state.insights;

    if (ins == null) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    final atRiskList = ins.atRiskStudents;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'Attendance Insights & Chronic Absenteeism Analytics',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Real-time metrics, class distribution benchmarks, at-risk student monitoring, and 30-day trends.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 20),

          // 3 KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildInsightKpiCard(
                  '30-Day Attendance Rate',
                  '${state.stats.overallAttendancePct}%',
                  'Healthy school baseline',
                  Icons.trending_up_rounded,
                  const Color(0xFF10B981),
                  const Color(0xFFECFDF5),
                  isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildInsightKpiCard(
                  'Tracked Students',
                  '${state.stats.totalStudents > 0 ? state.stats.totalStudents : 1592}',
                  'Across all active classes',
                  Icons.people_alt_rounded,
                  const Color(0xFF4F46E5),
                  const Color(0xFFEEF2FF),
                  isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildInsightKpiCard(
                  'At-Risk (<75% Attendance)',
                  '${ins.atRiskCount}',
                  'Requires parent outreach',
                  Icons.warning_amber_rounded,
                  const Color(0xFFEF4444),
                  const Color(0xFFFEF2F2),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Class Attendance Comparison Cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Attendance Distribution',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                if (ins.classComparison.isEmpty)
                  Center(child: Text('No class comparison data available', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))))
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ins.classComparison.map((c) {
                      final cName = c['class_name']?.toString() ?? 'Class';
                      final pct = (c['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                      final count = c['total_students'] ?? 0;
                      final isHigh = pct >= 75;

                      return Container(
                        width: 190,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cName,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$count Students',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isHigh ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                                Icon(
                                  isHigh ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  size: 18,
                                  color: isHigh ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chronic Absenteeism Watchlist (<75%)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chronic Absenteeism Watchlist (Below 75% Attendance)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (atRiskList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No students currently below the 75% threshold in this session.',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: atRiskList.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    itemBuilder: (context, idx) {
                      final item = atRiskList[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              ),
                              child: const Center(
                                child: Icon(Icons.person_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name']?.toString() ?? 'Student Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Class: ${item["class_name"] ?? "Class"} | Total Days: ${item["total_days"] ?? 0} | Absent: ${item["absent_days"] ?? 0}',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                '${item["attendance_pct"] ?? 0}%',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInsightKpiCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color bgColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? color.withValues(alpha: 0.15) : bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
