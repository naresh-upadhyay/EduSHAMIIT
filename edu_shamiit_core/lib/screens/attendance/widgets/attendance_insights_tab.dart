import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class AttendanceInsightsTab extends ConsumerWidget {
  const AttendanceInsightsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);
    final theme = Theme.of(context);
    final ins = state.insights;

    if (ins == null) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final atRiskList = ins.atRiskStudents;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text('Attendance Insights & Chronic Absenteeism Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Real-time analytics, daily attendance trends, class performance comparisons, and chronic absenteeism alerts.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // 3 KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildInsightKpiCard(
                  '30-Day Attendance Rate',
                  '${state.stats.overallAttendancePct}%',
                  Icons.trending_up_rounded,
                  const Color(0xFF10B981),
                  theme,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildInsightKpiCard(
                  'Tracked Students',
                  '${state.stats.totalStudents}',
                  Icons.groups_rounded,
                  const Color(0xFF4F46E5),
                  theme,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildInsightKpiCard(
                  'At-Risk (<75% Attendance)',
                  '${ins.atRiskCount}',
                  Icons.warning_amber_rounded,
                  const Color(0xFFEF4444),
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Class Attendance Comparison Cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Class Attendance Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                if (ins.classComparison.isEmpty)
                  const Center(child: Text('No class comparison data available', style: TextStyle(color: Colors.grey)))
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ins.classComparison.map((c) {
                      final cName = c['class_name']?.toString() ?? 'Class';
                      final pct = (c['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                      final count = c['total_students'] ?? 0;

                      return Container(
                        width: 180,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('$count Students', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                                Icon(pct >= 75 ? Icons.trending_up : Icons.trending_down, size: 16, color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
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

          // Chronic Absenteeism List (<75%)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Chronic Absenteeism Watchlist (Below 75% Attendance)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Students listed below are at academic risk due to low attendance and require intervention.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (atRiskList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    child: const Text('🎉 No students currently below the 75% attendance threshold.', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: atRiskList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = atRiskList[idx];
                      final name = item['full_name']?.toString() ?? 'Student';
                      final cName = item['class_name']?.toString() ?? '';
                      final sName = item['section_name']?.toString() ?? '';
                      final roll = item['roll_number']?.toString() ?? '';
                      final pct = (item['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                      final tot = item['total_days'] ?? 0;
                      final pres = item['present_days'] ?? 0;
                      final ab = item['absent_days'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFEF4444).withOpacity(0.12),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('$cName • $sName (Roll No: $roll)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Text('$pres Present / $ab Absent (Total $tot days)', style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                              ),
                              child: Text(
                                '$pct%',
                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
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
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInsightKpiCard(String title, String value, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
