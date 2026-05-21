import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({super.key});

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(parentDashboardProvider);
    final childrenAsync = ref.watch(childrenProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (data) => _buildDashboard(context, data, childrenAsync),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    Map<String, dynamic> data,
    AsyncValue<List<Map<String, dynamic>>> childrenAsync,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract data with safe defaults
    final student = data['student'] as Map<String, dynamic>? ?? {};
    final attendance =
        data['attendance_summary'] as Map<String, dynamic>? ?? {};
    final recentResults = data['recent_results'] as List<dynamic>? ?? [];
    final pendingFees = data['pending_fees'] as List<dynamic>? ?? [];
    final upcomingEvents = data['upcoming_events'] as List<dynamic>? ?? [];

    final attendancePct =
        (attendance['overall_pct'] as num?)?.toDouble() ?? 0.0;
    final presentDays = attendance['present_days'] as int? ?? 0;
    final totalDays = attendance['total_days'] as int? ?? 1;

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.parentHeader,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parent Portal'.tr(ref),
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student['full_name'] ?? 'Loading...'.tr(ref),
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              if (student['class'] != null)
                                Text(
                                  'Class ${student['class']} • Roll ${student['roll_no'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const ChildSwitcher(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Content ──
        SliverToBoxAdapter(
          child: ResponsiveContent(
            child: Padding(
              padding: Responsive.contentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Quick Stats Row ──
                  _buildQuickStats(attendancePct, presentDays, totalDays,
                      pendingFees.length, isDark),
                  const SizedBox(height: 20),

                  // ── Quick Access Grid ──
                  _buildSectionTitle('Quick Access'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _buildQuickAccessGrid(isDark),
                  const SizedBox(height: 20),

                  // ── Recent Results ──
                  if (recentResults.isNotEmpty) ...[
                    _buildSectionTitle('Recent Results'.tr(ref), isDark),
                    const SizedBox(height: 12),
                    ...recentResults.take(3).map((r) =>
                        _buildResultCard(r as Map<String, dynamic>, isDark)),
                    const SizedBox(height: 20),
                  ],

                  // ── Pending Fees ──
                  if (pendingFees.isNotEmpty) ...[
                    _buildSectionTitle('Pending Fees'.tr(ref), isDark),
                    const SizedBox(height: 12),
                    ...pendingFees.take(3).map((f) =>
                        _buildFeeCard(f as Map<String, dynamic>, isDark)),
                    const SizedBox(height: 20),
                  ],

                  // ── Upcoming Events ──
                  if (upcomingEvents.isNotEmpty) ...[
                    _buildSectionTitle('Upcoming Events'.tr(ref), isDark),
                    const SizedBox(height: 12),
                    ...upcomingEvents.take(3).map((e) =>
                        _buildEventCard(e as Map<String, dynamic>, isDark)),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(double attendancePct, int presentDays, int totalDays,
      int pendingFeeCount, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: '📋',
            label: 'Attendance'.tr(ref),
            value: '${attendancePct.toStringAsFixed(1)}%',
            subtitle: '$presentDays/$totalDays days',
            color: ParentColors.primary,
            bgColor: ParentColors.primaryLight,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: '💳',
            label: 'Pending Fees'.tr(ref),
            value: '$pendingFeeCount',
            subtitle: pendingFeeCount == 0 ? 'All clear!' : 'Action needed',
            color: ParentColors.accent,
            bgColor: ParentColors.warningBg,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? ParentColors.darkBorder : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? ParentColors.darkText2 : ParentColors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? ParentColors.darkText : color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? ParentColors.darkText3 : ParentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? ParentColors.darkText : ParentColors.text,
      ),
    );
  }

  Widget _buildQuickAccessGrid(bool isDark) {
    final items = [
      {
        'title': 'Attendance',
        'icon': '📋',
        'route': '/parent/attendance',
        'bg': 'F0FDFA'
      },
      {
        'title': 'Results',
        'icon': '📊',
        'route': '/parent/results',
        'bg': 'FDF4FF'
      },
      {'title': 'Fees', 'icon': '💳', 'route': '/parent/fees', 'bg': 'FEF3C7'},
      {
        'title': 'Homework',
        'icon': '📝',
        'route': '/parent/homework',
        'bg': 'FDF2F8'
      },
      {
        'title': 'Timetable',
        'icon': '🗓️',
        'route': '/parent/timetable',
        'bg': 'EEF2FF'
      },
      {
        'title': 'Transport',
        'icon': '🚌',
        'route': '/parent/transport',
        'bg': 'EFF6FF'
      },
      {
        'title': 'Leave',
        'icon': '✉️',
        'route': '/parent/leave',
        'bg': 'FEF2F2'
      },
      {
        'title': 'Notices',
        'icon': '📢',
        'route': '/parent/notices',
        'bg': 'FFF7ED'
      },
      {
        'title': 'Events',
        'icon': '📅',
        'route': '/parent/events',
        'bg': 'FEF3C7'
      },
      {
        'title': 'Achieve',
        'icon': '🏆',
        'route': '/parent/achievements',
        'bg': 'F0FDF4'
      },
      {
        'title': 'Messages',
        'icon': '💬',
        'route': '/parent/messaging',
        'bg': 'E0E7FF'
      },
      {
        'title': 'Profile',
        'icon': '👤',
        'route': '/parent/profile',
        'bg': 'F1F5F9'
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.85,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => context.go(item['route']!),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? ParentColors.darkSurface
                  : Color(int.parse('0xFF${item['bg']}')),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? ParentColors.darkBorder : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(
                  item['title']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText2 : ParentColors.text2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result, bool isDark) {
    final subject = result['subject'] ?? 'Unknown';
    final score = result['marks_obtained'] ?? 0;
    final maxMarks = result['max_marks'] ?? 100;
    final examTitle = result['exam_title'] ?? '';
    final pct = maxMarks > 0 ? (score / maxMarks * 100) : 0.0;

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
              color: ParentColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ParentColors.primary,
                ),
              ),
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
                  examTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score/$maxMarks',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ParentColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> fee, bool isDark) {
    final title = fee['title'] ?? fee['month'] ?? 'Fee';
    final amount = fee['amount'] ?? 0;
    final dueDate = fee['due_date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? ParentColors.darkBorder
              : ParentColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ParentColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: const Text('💳', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                if (dueDate.isNotEmpty)
                  Text(
                    'Due: $dueDate',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '₹$amount',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ParentColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    final title = event['title'] ?? 'Event';
    final date = event['date'] ?? '';
    final type = event['type'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? ParentColors.darkBorder
              : ParentColors.info.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ParentColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: const Text('📅', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                  ),
              ],
            ),
          ),
          if (type.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ParentColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                type,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.info),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard'.tr(ref),
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentDashboardProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
