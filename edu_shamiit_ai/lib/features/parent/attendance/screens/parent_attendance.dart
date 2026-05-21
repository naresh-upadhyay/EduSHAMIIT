import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentAttendance extends ConsumerWidget {
  const ParentAttendance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final attendanceAsync = ref.watch(parentAttendanceProvider(null));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Attendance'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const ChildSwitcher(),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: attendanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final records = data['records'] as List<dynamic>? ?? [];

    final overallPct = (summary['overall_pct'] as num?)?.toDouble() ?? 0.0;
    final presentDays = summary['present_days'] as int? ?? 0;
    final absentDays = summary['absent_days'] as int? ?? 0;
    final lateDays = summary['late_days'] as int? ?? 0;
    final totalDays = summary['total_days'] as int? ?? 0;

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          // ── Overall Attendance Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'Overall Attendance'.tr(ref),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${overallPct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _dayStat(
                        'Present'.tr(ref), presentDays, Colors.greenAccent),
                    _dayStat('Absent'.tr(ref), absentDays, Colors.redAccent),
                    _dayStat('Late'.tr(ref), lateDays, Colors.orangeAccent),
                    _dayStat('Total'.tr(ref), totalDays, Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Attendance Progress Bar ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? ParentColors.darkSurface : ParentColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color:
                      isDark ? ParentColors.darkBorder : ParentColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Progress'.tr(ref),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overallPct / 100,
                    minHeight: 12,
                    backgroundColor:
                        isDark ? ParentColors.darkBorder : ParentColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallPct >= 75
                          ? ParentColors.success
                          : overallPct >= 50
                              ? ParentColors.warning
                              : ParentColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      overallPct >= 75
                          ? '✅ Good standing'
                          : overallPct >= 50
                              ? '⚠️ Needs improvement'
                              : '❌ Critical',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ParentColors.darkText2
                            : ParentColors.text2,
                      ),
                    ),
                    Text(
                      'Min 75% required',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ParentColors.darkText3
                            : ParentColors.text3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Recent Records ──
          Text(
            'Recent Records'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (records.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No attendance records found'.tr(ref),
                  style: TextStyle(
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3),
                ),
              ),
            )
          else
            ...records.take(10).map((r) {
              final record = r as Map<String, dynamic>;
              final date = record['date'] ?? '';
              final status = record['status'] ?? 'present';
              final subject = record['subject'] ?? 'General';
              return _buildRecordCard(date, subject, status, isDark);
            }),
        ],
      ),
    );
  }

  Widget _dayStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildRecordCard(
      String date, String subject, String status, bool isDark) {
    final statusColor = status == 'present'
        ? ParentColors.success
        : status == 'late'
            ? ParentColors.warning
            : ParentColors.error;
    final statusBg = status == 'present'
        ? ParentColors.successBg
        : status == 'late'
            ? ParentColors.warningBg
            : ParentColors.errorBg;
    final statusIcon = status == 'present'
        ? '✅'
        : status == 'late'
            ? '⏰'
            : '❌';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? statusColor.withValues(alpha: 0.2) : statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(statusIcon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? statusColor.withValues(alpha: 0.2) : statusBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load attendance'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentAttendanceProvider(null)),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
