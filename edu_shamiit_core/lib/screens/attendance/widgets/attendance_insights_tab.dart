import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../constants/app_fonts.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../../classes/services/academic_lookup_helper.dart';

class AttendanceInsightsTab extends ConsumerStatefulWidget {
  const AttendanceInsightsTab({super.key});

  @override
  ConsumerState<AttendanceInsightsTab> createState() => _AttendanceInsightsTabState();
}

class _AttendanceInsightsTabState extends ConsumerState<AttendanceInsightsTab> {
  // Local active filter states for Right Panel
  DateTimeRange? _selectedDateRange;
  String _selectedViewBy = 'Overall';
  String? _selectedRole;
  String? _selectedClassId;
  String? _selectedSectionId;
  String _selectedDepartment = 'All Departments';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AcademicLookupHelper.instance.getActiveLookup('DEPARTMENT');
      if (mounted) {
        ref.read(attendanceProvider.notifier).fetchStaffLookups();
        ref.read(attendanceProvider.notifier).fetchInsights();
      }
    });
  }

  void _applyFilters() {
    final notifier = ref.read(attendanceProvider.notifier);
    String viewByCode = 'OVERALL';
    if (_selectedViewBy == 'Students') {
      viewByCode = 'STUDENTS';
    } else if (_selectedViewBy == 'Staff') {
      viewByCode = 'STAFF';
    } else if (_selectedRole != null && _selectedRole!.isNotEmpty) {
      viewByCode = 'STAFF';
    }

    notifier.setInsightsFilters(
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      viewBy: viewByCode,
      role: _selectedRole,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      department: (_selectedDepartment == 'All Departments' || _selectedDepartment == 'ALL')
          ? null
          : _selectedDepartment,
    );
  }

  void _resetFilters() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
      _selectedViewBy = 'Overall';
      _selectedRole = null;
      _selectedClassId = null;
      _selectedSectionId = null;
      _selectedDepartment = 'All Departments';
    });
    ref.read(attendanceProvider.notifier).resetInsightsFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ins = state.insights;
    final isLoading = state.insightsIsLoading && ins == null;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final isTablet = screenWidth >= 768 && screenWidth < 1100;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth < 600 ? 12 : 20,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Sub-Header & Global Toolbar
          _buildHeaderBar(context, isDark, state),
          const SizedBox(height: 16),

          if (isLoading)
            _buildLoadingSkeleton(isDark)
          else if (ins == null)
            _buildEmptyState(context, isDark)
          else ...[
            // Responsive Multi-Column Layout
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Analytics Content Area (Left ~72%)
                  Expanded(
                    flex: 72,
                    child: _buildMainInsightsContent(context, isDark, ins, state, isStacked: false),
                  ),
                  const SizedBox(width: 20),
                  // Dedicated Right Filters & Breakdowns Panel (~28%)
                  Expanded(
                    flex: 28,
                    child: _buildRightSidePanel(context, isDark, ins, state),
                  ),
                ],
              )
            else if (isTablet)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRightFiltersCard(context, isDark, state),
                  const SizedBox(height: 20),
                  _buildMainInsightsContent(context, isDark, ins, state, isStacked: false),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDayOfWeekCard(context, isDark, ins)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDepartmentStaffCard(context, isDark, ins)),
                    ],
                  ),
                ],
              )
            else
              // Mobile View (<768px)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMobileFilterTrigger(context, isDark),
                  const SizedBox(height: 16),
                  _buildMainInsightsContent(context, isDark, ins, state, isStacked: true),
                  const SizedBox(height: 16),
                  _buildDayOfWeekCard(context, isDark, ins),
                  const SizedBox(height: 16),
                  _buildDepartmentStaffCard(context, isDark, ins),
                ],
              ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER BAR & TITLE
  // ==========================================================================

  Widget _buildHeaderBar(BuildContext context, bool isDark, AttendanceState state) {
    final sDate = _selectedDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
    final eDate = _selectedDateRange?.end ?? DateTime.now();
    final dateRangeFormatted =
        '${DateFormat('dd MMM yyyy').format(sDate)} - ${DateFormat('dd MMM yyyy').format(eDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Insights & Analytics',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Comprehensive institutional attendance metrics • $dateRangeFormatted',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.insightsIsLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => ref.read(attendanceProvider.notifier).fetchInsights(),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _handleExportCsv(context),
                icon: const Icon(Icons.file_download_outlined, size: 15),
                label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MAIN CONTENT AREA
  // ==========================================================================

  Widget _buildMainInsightsContent(
    BuildContext context,
    bool isDark,
    AttendanceInsightsModel ins,
    AttendanceState state, {
    required bool isStacked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top 5 KPI Summary Cards with Sparklines
        _buildKpiSummaryRow(context, isDark, ins),
        const SizedBox(height: 20),

        // 2. Middle Row: Attendance Trend Chart & Distribution Donut
        _buildMiddleChartsRow(context, isDark, ins, state, isStacked: isStacked),
        const SizedBox(height: 20),

        // 3. Lower Row: Top Classes (left) & Top Absentees (right)
        if (isStacked) ...[
          _buildTopClassesCard(context, isDark, ins),
          const SizedBox(height: 20),
          _buildTopAbsenteesCard(context, isDark, ins),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 50, child: _buildTopClassesCard(context, isDark, ins)),
              const SizedBox(width: 20),
              Expanded(flex: 50, child: _buildTopAbsenteesCard(context, isDark, ins)),
            ],
          ),
        const SizedBox(height: 20),

        // 4. Actionable Insights & Alert Cards
        _buildInsightsAlertsSection(context, isDark, ins),
      ],
    );
  }

  // ==========================================================================
  // 5 TOP KPI CARDS WITH SPARKLINES (100% MATHEMATICAL PRECISION)
  // ==========================================================================

  Widget _buildKpiSummaryRow(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final kpis = ins.kpis;
    final overall = (kpis['overall'] as Map<String, dynamic>?) ?? {};
    final present = (kpis['present'] as Map<String, dynamic>?) ?? {};
    final absent = (kpis['absent'] as Map<String, dynamic>?) ?? {};
    final late = (kpis['late'] as Map<String, dynamic>?) ?? {};
    final halfDay = (kpis['half_day'] as Map<String, dynamic>?) ?? {};

    final overallVal = (overall['value'] as num?)?.toDouble() ?? 0.0;
    final overallDelta = (overall['delta_pct'] as num?)?.toDouble() ?? 0.0;
    final overallIsPos = (overall['is_positive'] as bool?) ?? (overallDelta >= 0);

    final presVal = (present['value'] as num?)?.toInt() ?? 0;
    final presDelta = (present['delta_count'] as num?)?.toInt() ?? 0;

    final absVal = (absent['value'] as num?)?.toInt() ?? 0;
    final absDelta = (absent['delta_count'] as num?)?.toInt() ?? 0;

    final lateVal = (late['value'] as num?)?.toInt() ?? 0;
    final lateDelta = (late['delta_count'] as num?)?.toInt() ?? 0;

    final halfVal = (halfDay['value'] as num?)?.toInt() ?? 0;
    final halfDelta = (halfDay['delta_count'] as num?)?.toInt() ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;
        final cardWidth = isSmall ? (constraints.maxWidth - 8) / 2 : (constraints.maxWidth - 32) / 5;

        final items = [
          _KpiCardData(
            title: 'Overall Attendance',
            value: '${overallVal.toStringAsFixed(2)}%',
            deltaText: '${overallDelta >= 0 ? '+' : ''}${overallDelta.toStringAsFixed(2)}% vs prior period',
            isPositive: overallIsPos,
            color: const Color(0xFF6366F1),
            sparklinePoints: _parseSparkline(overall['sparkline']),
          ),
          _KpiCardData(
            title: 'Present',
            value: NumberFormat('#,###').format(presVal),
            deltaText: '${presDelta >= 0 ? '↑ +' : '↓ '}$presDelta entries',
            isPositive: presDelta >= 0,
            color: const Color(0xFF10B981),
            sparklinePoints: _parseSparkline(present['sparkline']),
          ),
          _KpiCardData(
            title: 'Absent',
            value: NumberFormat('#,###').format(absVal),
            deltaText: '${absDelta >= 0 ? '↑ +' : '↓ '}$absDelta entries',
            isPositive: absDelta <= 0,
            color: const Color(0xFFEF4444),
            sparklinePoints: _parseSparkline(absent['sparkline']),
          ),
          _KpiCardData(
            title: 'Late',
            value: NumberFormat('#,###').format(lateVal),
            deltaText: '${lateDelta >= 0 ? '↑ +' : '↓ '}$lateDelta entries',
            isPositive: lateDelta <= 0,
            color: const Color(0xFFF59E0B),
            sparklinePoints: _parseSparkline(late['sparkline']),
          ),
          _KpiCardData(
            title: 'Half Day',
            value: NumberFormat('#,###').format(halfVal),
            deltaText: '${halfDelta >= 0 ? '↑ +' : '↓ '}$halfDelta entries',
            isPositive: halfDelta <= 0,
            color: const Color(0xFF3B82F6),
            sparklinePoints: _parseSparkline(halfDay['sparkline']),
          ),
        ];

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _buildSparklineKpiCard(item, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  List<double> _parseSparkline(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    return const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  }

  Widget _buildSparklineKpiCard(_KpiCardData data, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  data.value,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Mini Sparkline Graph
              SizedBox(
                width: 48,
                height: 24,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    dataPoints: data.sparklinePoints,
                    lineColor: data.color,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                data.isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 13,
                color: data.isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  data.deltaText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: data.isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MIDDLE CHARTS ROW: TREND LINE CHART & DISTRIBUTION DONUT
  // ==========================================================================

  Widget _buildMiddleChartsRow(
    BuildContext context,
    bool isDark,
    AttendanceInsightsModel ins,
    AttendanceState state, {
    required bool isStacked,
  }) {
    if (isStacked) {
      return Column(
        children: [
          _buildAttendanceTrendCard(context, isDark, ins, state),
          const SizedBox(height: 16),
          _buildAttendanceDistributionCard(context, isDark, ins),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 68,
          child: _buildAttendanceTrendCard(context, isDark, ins, state),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 32,
          child: _buildAttendanceDistributionCard(context, isDark, ins),
        ),
      ],
    );
  }

  Widget _buildAttendanceTrendCard(
    BuildContext context,
    bool isDark,
    AttendanceInsightsModel ins,
    AttendanceState state,
  ) {
    final granularity = state.insightsGranularity;
    final trendList = ins.trend;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Granularity Pill Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Attendance Trend',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Aggregate attendance percentage performance over time.',
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildGranularitySegment(
                    'Daily',
                    granularity == 'daily',
                    () => ref.read(attendanceProvider.notifier).setInsightsGranularity('daily'),
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildGranularitySegment(
                    'Weekly',
                    granularity == 'weekly',
                    () => ref.read(attendanceProvider.notifier).setInsightsGranularity('weekly'),
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildGranularitySegment(
                    'Monthly',
                    granularity == 'monthly',
                    () => ref.read(attendanceProvider.notifier).setInsightsGranularity('monthly'),
                    isDark,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Interactive Multi-Point Line Chart Canvas
          SizedBox(
            height: 200,
            width: double.infinity,
            child: trendList.isEmpty
                ? Center(
                    child: Text(
                      'No trend data available for selected range',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  )
                : CustomPaint(
                    painter: _AttendanceTrendChartPainter(
                      data: trendList,
                      isDark: isDark,
                      accentColor: const Color(0xFF6366F1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGranularitySegment(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceDistributionCard(
    BuildContext context,
    bool isDark,
    AttendanceInsightsModel ins,
  ) {
    final dist = ins.distribution;
    final total = (dist['total'] as num?)?.toInt() ?? 0;
    final presCnt = (dist['present_count'] as num?)?.toInt() ?? 0;
    final presPct = (dist['present_pct'] as num?)?.toDouble() ?? 0.0;
    final lateCnt = (dist['late_count'] as num?)?.toInt() ?? 0;
    final latePct = (dist['late_pct'] as num?)?.toDouble() ?? 0.0;
    final halfCnt = (dist['half_day_count'] as num?)?.toInt() ?? 0;
    final halfPct = (dist['half_day_pct'] as num?)?.toDouble() ?? 0.0;
    final absCnt = (dist['absent_count'] as num?)?.toInt() ?? 0;
    final absPct = (dist['absent_pct'] as num?)?.toDouble() ?? 0.0;
    final leaveCnt = (dist['leave_count'] as num?)?.toInt() ?? 0;
    final leavePct = (dist['leave_pct'] as num?)?.toDouble() ?? 0.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Distribution',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          // Donut Chart & Live Center Metric
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutDistributionPainter(
                  presentPct: presPct,
                  latePct: latePct,
                  halfDayPct: halfPct,
                  absentPct: absPct,
                  leavePct: leavePct,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        NumberFormat('#,###').format(total),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Total Entries',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Compact Legend Grid
          Column(
            children: [
              _buildLegendRow('Present', '$presCnt ($presPct%)', const Color(0xFF10B981), isDark),
              const SizedBox(height: 4),
              _buildLegendRow('Late', '$lateCnt ($latePct%)', const Color(0xFFF59E0B), isDark),
              const SizedBox(height: 4),
              _buildLegendRow('Half Day', '$halfCnt ($halfPct%)', const Color(0xFF3B82F6), isDark),
              const SizedBox(height: 4),
              _buildLegendRow('Absent', '$absCnt ($absPct%)', const Color(0xFFEF4444), isDark),
              if (leaveCnt > 0) ...[
                const SizedBox(height: 4),
                _buildLegendRow('On Leave', '$leaveCnt ($leavePct%)', const Color(0xFF8B5CF6), isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TOP CLASSES (BY ATTENDANCE %) TABLE CARD
  // ==========================================================================

  Widget _buildTopClassesCard(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final topClasses = ins.topClasses;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Classes (By Attendance %)',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (topClasses.isNotEmpty)
                TextButton(
                  onPressed: () => _openAllClassesModal(context, topClasses, isDark),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All (${topClasses.length})',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Table Header
          Row(
            children: [
              _buildTableHeaderCell('Rank', flex: 1, isDark: isDark),
              _buildTableHeaderCell('Class', flex: 3, isDark: isDark),
              _buildTableHeaderCell('Attendance %', flex: 3, isDark: isDark),
              _buildTableHeaderCell('Present', flex: 2, isDark: isDark, alignRight: true),
              _buildTableHeaderCell('Absent', flex: 2, isDark: isDark, alignRight: true),
              _buildTableHeaderCell('Late', flex: 2, isDark: isDark, alignRight: true),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

          // Table Rows
          if (topClasses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No class records available', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(topClasses.length, 5),
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              itemBuilder: (context, idx) {
                final cl = topClasses[idx];
                final rank = cl['rank'] ?? (idx + 1);
                final className = cl['class_name']?.toString() ?? 'Class';
                final pct = (cl['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                final pres = cl['present'] ?? 0;
                final abs = cl['absent'] ?? 0;
                final late = cl['late'] ?? 0;
                final delta = (cl['trend_delta'] as num?)?.toDouble() ?? 0.0;

                final isGood = pct >= 90.0;
                final isWarning = pct < 75.0;
                final color = isGood
                    ? const Color(0xFF10B981)
                    : (isWarning ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // Rank
                      Expanded(
                        flex: 1,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // Class Name
                      Expanded(
                        flex: 3,
                        child: Text(
                          className,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Attendance % with delta chip
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: (delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w800,
                                  color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Present Count
                      Expanded(
                        flex: 2,
                        child: Text('$pres', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                      // Absent Count
                      Expanded(
                        flex: 2,
                        child: Text('$abs', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: abs > 0 ? const Color(0xFFEF4444) : null)),
                      ),
                      // Late Count
                      Expanded(
                        flex: 2,
                        child: Text('$late', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: late > 0 ? const Color(0xFFF59E0B) : null)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TOP ABSENTEES (CHRONIC WATCHLIST) TABLE CARD
  // ==========================================================================

  Widget _buildTopAbsenteesCard(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final absentees = ins.topAbsentees;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Absentees',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (absentees.isNotEmpty)
                TextButton(
                  onPressed: () => _openAllAbsenteesModal(context, absentees, isDark),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View All (${absentees.length})',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Table Header
          Row(
            children: [
              _buildTableHeaderCell('Rank', flex: 1, isDark: isDark),
              _buildTableHeaderCell('Name', flex: 4, isDark: isDark),
              _buildTableHeaderCell('Class / Dept', flex: 3, isDark: isDark),
              _buildTableHeaderCell('Absent Days', flex: 2, isDark: isDark, alignRight: true),
              _buildTableHeaderCell('Attendance %', flex: 3, isDark: isDark, alignRight: true),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),

          // Table Rows
          if (absentees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No absenteeism risks detected', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(absentees.length, 5),
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              itemBuilder: (context, idx) {
                final st = absentees[idx];
                final rank = st['rank'] ?? (idx + 1);
                final name = st['name']?.toString() ?? 'Student';
                final className = st['class_name']?.toString() ?? 'Class';
                final absentDays = st['absent_days'] ?? 0;
                final pct = (st['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                final studentId = st['student_id']?.toString() ?? st['person_id']?.toString() ?? '';

                return InkWell(
                  onTap: () => _openStudentProfileDrawer(context, studentId, name, isDark),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text('$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ),
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                child: Text(
                                  name.isNotEmpty ? name[0] : 'S',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(className, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('$absentDays', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (pct / 100.0).clamp(0.0, 1.0),
                                    minHeight: 3,
                                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String title, {required int flex, required bool isDark, bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  // ==========================================================================
  // INSIGHTS ALERTS & RISK NOTIFICATIONS
  // ==========================================================================

  Widget _buildInsightsAlertsSection(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final alerts = ins.insightsAlerts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Automated Institutional Insights',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: const Text('All class and staff attendance parameters are performing within benchmark limits.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 700;
              final width = isTwoCol ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: alerts.map((a) {
                  final type = a['type']?.toString().toUpperCase() ?? 'INFO';
                  final title = a['title']?.toString() ?? 'Insight Alert';
                  final msg = a['message']?.toString() ?? '';

                  Color color = const Color(0xFF3B82F6);
                  Color bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.08);
                  IconData icon = Icons.info_outline_rounded;

                  if (type == 'WARNING') {
                    color = const Color(0xFFEF4444);
                    bgColor = const Color(0xFFEF4444).withValues(alpha: 0.08);
                    icon = Icons.warning_amber_rounded;
                  } else if (type == 'SUCCESS' || type == 'EXCELLENT') {
                    color = const Color(0xFF10B981);
                    bgColor = const Color(0xFF10B981).withValues(alpha: 0.08);
                    icon = Icons.check_circle_outline_rounded;
                  }

                  return SizedBox(
                    width: width,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  msg,
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ==========================================================================
  // RIGHT SIDE PANEL: FILTERS, DAY OF WEEK, DEPARTMENT METERS
  // ==========================================================================

  Widget _buildRightSidePanel(
    BuildContext context,
    bool isDark,
    AttendanceInsightsModel ins,
    AttendanceState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRightFiltersCard(context, isDark, state),
        const SizedBox(height: 20),
        _buildDayOfWeekCard(context, isDark, ins),
        const SizedBox(height: 20),
        _buildDepartmentStaffCard(context, isDark, ins),
      ],
    );
  }

  Widget _buildRightFiltersCard(BuildContext context, bool isDark, AttendanceState state) {
    final dateStr = _selectedDateRange == null
        ? 'Select Date Range'
        : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _resetFilters,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Range Field
          _buildFilterLabel('Date Range', isDark),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _pickDateRange(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // View By & Class Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('View By', isDark),
                    const SizedBox(height: 4),
                    _buildViewByDropdown(state, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('Class', isDark),
                    const SizedBox(height: 4),
                    _buildClassDropdown(state, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Section & Department Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('Section (Optional)', isDark),
                    const SizedBox(height: 4),
                    _buildSectionDropdown(state, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterLabel('Department (Staff)', isDark),
                    const SizedBox(height: 4),
                    _buildDepartmentDropdown(state, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Apply Filters Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Apply Filters', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewByDropdown(AttendanceState state, bool isDark) {
    final roles = state.insightsAvailableRoles;
    final currentValue = _selectedRole != null ? 'ROLE:$_selectedRole' : _selectedViewBy;

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'Overall', child: Text('Overall (School-wide)')),
      const DropdownMenuItem(value: 'Students', child: Text('Students')),
      const DropdownMenuItem(value: 'Staff', child: Text('Staff (All Roles)')),
      ...roles.map((r) {
        final code = r['name']?.toString() ?? r['code']?.toString() ?? '';
        final display = r['display_name']?.toString() ?? code;
        return DropdownMenuItem(
          value: 'ROLE:$code',
          child: Text('Role: $display', maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((it) => it.value == currentValue) ? currentValue : 'Overall',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          items: items,
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              if (v.startsWith('ROLE:')) {
                _selectedRole = v.replaceFirst('ROLE:', '');
                _selectedViewBy = 'Role: $_selectedRole';
              } else if (v == 'Students') {
                _selectedRole = 'student';
                _selectedViewBy = 'Students';
              } else if (v == 'Staff') {
                _selectedRole = null;
                _selectedViewBy = 'Staff';
              } else {
                _selectedRole = null;
                _selectedViewBy = 'Overall';
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown(AttendanceState state, bool isDark) {
    final deptNames = <String>{};
    for (final d in state.insightsAvailableDepartments) {
      final name = d['name']?.toString() ?? d['label']?.toString();
      if (name != null && name.isNotEmpty && name != 'All Departments' && name != 'ALL') {
        deptNames.add(name);
      }
    }
    final lookupDepts = AcademicLookupHelper.instance.getCachedLookup('DEPARTMENT');
    for (final it in lookupDepts) {
      if (it.label.isNotEmpty && it.label != 'ALL') deptNames.add(it.label);
    }
    for (final d in state.staffAvailableDepartments) {
      if (d.isNotEmpty && d != 'ALL') deptNames.add(d);
    }
    final sorted = deptNames.toList()..sort();

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'All Departments', child: Text('All Departments')),
      ...sorted.map((name) {
        return DropdownMenuItem(value: name, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis));
      }),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((it) => it.value == _selectedDepartment) ? _selectedDepartment : 'All Departments',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          items: items,
          onChanged: (v) => setState(() => _selectedDepartment = v ?? 'All Departments'),
        ),
      ),
    );
  }

  Widget _buildDayOfWeekCard(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final dowList = ins.dayOfWeek;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance by Day of Week',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          // Vertical Bars Canvas for Mon - Sun
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(
              painter: _DayOfWeekBarPainter(
                data: dowList,
                isDark: isDark,
                barColor: const Color(0xFF8B5CF6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentStaffCard(BuildContext context, bool isDark, AttendanceInsightsModel ins) {
    final deptStats = ins.departmentStats;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance by Department (Staff)',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          if (deptStats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No staff attendance recorded in this period', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
              ),
            )
          else
            ...deptStats.take(6).map((d) {
              final name = d['department']?.toString() ?? 'Department';
              final pct = (d['attendance_pct'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                        Text('${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (pct / 100.0).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              ref.read(attendanceProvider.notifier).setTab(1);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Staff Attendance',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS & DROPDOWNS
  // ==========================================================================

  Widget _buildFilterLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildClassDropdown(AttendanceState state, bool isDark) {
    final classes = state.availableClasses;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: classes.any((c) => c.id == _selectedClassId) ? _selectedClassId : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Classes')),
            ...classes.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) {
            setState(() {
              _selectedClassId = v;
              _selectedSectionId = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSectionDropdown(AttendanceState state, bool isDark) {
    List<dynamic> sections = [];
    if (_selectedClassId != null) {
      final matchedClass = state.availableClasses.where((c) => c.id == _selectedClassId).firstOrNull;
      sections = matchedClass?.sections ?? [];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: sections.any((s) => s.id.toString() == _selectedSectionId) ? _selectedSectionId : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Sections')),
            ...sections.map((s) => DropdownMenuItem<String?>(
              value: s.id.toString(),
              child: Text(s.name.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => setState(() => _selectedSectionId = v),
        ),
      ),
    );
  }

  Widget _buildMobileFilterTrigger(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => _openMobileFiltersBottomSheet(context, isDark),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF4F46E5)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 18),
            SizedBox(width: 8),
            Text(
              'Filter Analytics & Date Range',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2028),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  // ==========================================================================
  // DRILL-DOWN MODALS & DRAWERS
  // ==========================================================================

  void _openStudentProfileDrawer(BuildContext context, String studentId, String studentName, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentInsightsDrawer(studentId: studentId, studentName: studentName, isDark: isDark),
    );
  }

  void _openAllClassesModal(BuildContext context, List<Map<String, dynamic>> classes, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => _AllClassesModal(classes: classes, isDark: isDark),
    );
  }

  void _openAllAbsenteesModal(BuildContext context, List<Map<String, dynamic>> absentees, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => _AllAbsenteesModal(
        absentees: absentees,
        isDark: isDark,
        onSelectStudent: (id, name) {
          Navigator.pop(ctx);
          _openStudentProfileDrawer(context, id, name, isDark);
        },
      ),
    );
  }

  void _openMobileFiltersBottomSheet(BuildContext context, bool isDark) {
    final state = ref.read(attendanceProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, size: 20)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRightFiltersCard(context, isDark, state),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleExportCsv(BuildContext context) async {
    final sDate = _selectedDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
    final eDate = _selectedDateRange?.end ?? DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating attendance insights CSV export...'),
        backgroundColor: Color(0xFF4F46E5),
        duration: Duration(seconds: 2),
      ),
    );

    final api = ref.read(attendanceApiServiceProvider);
    String viewByCode = 'OVERALL';
    if (_selectedViewBy == 'Students') {
      viewByCode = 'STUDENTS';
    } else if (_selectedViewBy == 'Staff') {
      viewByCode = 'STAFF';
    }

    final csvData = await api.exportInsightsReport(
      startDate: DateFormat('yyyy-MM-dd').format(sDate),
      endDate: DateFormat('yyyy-MM-dd').format(eDate),
      viewBy: viewByCode,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      department: _selectedDepartment == 'All Departments' ? null : _selectedDepartment,
    );

    if (csvData != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance report exported successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Container(
      height: 360,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4F46E5)),
          SizedBox(height: 16),
          Text('Aggregating analytics across classes and departments...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.pie_chart_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No attendance analytics available for selected criteria',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text('Try adjusting the date range or selecting "All Classes" to see school metrics.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetFilters,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            child: const Text('Reset to 30-Day Default'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DATA STRUCTURES
// ============================================================================

class _KpiCardData {
  final String title;
  final String value;
  final String deltaText;
  final bool isPositive;
  final Color color;
  final List<double> sparklinePoints;

  _KpiCardData({
    required this.title,
    required this.value,
    required this.deltaText,
    required this.isPositive,
    required this.color,
    required this.sparklinePoints,
  });
}

// ============================================================================
// CUSTOM PAINTERS: SPARKLINES, TREND CHART, DONUT CHART, BAR CHARTS
// ============================================================================

class _SparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final bool isDark;

  _SparklinePainter({
    required this.dataPoints,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final minVal = dataPoints.reduce(math.min);
    final maxVal = dataPoints.reduce(math.max);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final path = Path();
    final stepX = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - ((dataPoints[i] - minVal) / range) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - ((dataPoints[i - 1] - minVal) / range) * (size.height - 4) - 2;
        final ctrlX = (prevX + x) / 2;
        path.cubicTo(ctrlX, prevY, ctrlX, y, x, y);
      }
    }

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}

class _AttendanceTrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  final Color accentColor;

  _AttendanceTrendChartPainter({
    required this.data,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double chartTop = 20;
    final double chartBottom = size.height - 24;
    final double chartHeight = chartBottom - chartTop;
    const double chartLeft = 36;
    final double chartRight = size.width - 12;
    final double chartWidth = chartRight - chartLeft;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
    );

    for (int p = 0; p <= 4; p++) {
      final y = chartBottom - (p / 4.0) * chartHeight;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final textSpan = TextSpan(text: '${p * 25}%', style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(chartLeft - tp.width - 6, y - tp.height / 2));
    }

    final stepX = chartWidth / (data.length - 1 == 0 ? 1 : data.length - 1);
    final linePath = Path();
    final fillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final pct = (data[i]['attendance_pct'] as num?)?.toDouble() ?? 0.0;
      final x = chartLeft + i * stepX;
      final y = chartBottom - (pct / 100.0) * chartHeight;
      points.add(Offset(x, y));

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, chartBottom);
        fillPath.lineTo(x, y);
      } else {
        final prevX = points[i - 1].dx;
        final prevY = points[i - 1].dy;
        final ctrlX = (prevX + x) / 2;
        linePath.cubicTo(ctrlX, prevY, ctrlX, y, x, y);
        fillPath.cubicTo(ctrlX, prevY, ctrlX, y, x, y);
      }

      if (data.length <= 15 || i % ((data.length / 8).ceil()) == 0 || i == data.length - 1) {
        final label = data[i]['label']?.toString() ?? '';
        final lblSpan = TextSpan(text: label, style: textStyle);
        final lblTp = TextPainter(text: lblSpan, textDirection: TextDirection.ltr)..layout();
        lblTp.paint(canvas, Offset(x - lblTp.width / 2, chartBottom + 6));
      }
    }

    fillPath.lineTo(points.last.dx, chartBottom);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        accentColor.withValues(alpha: 0.25),
        accentColor.withValues(alpha: 0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = accentColor;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < points.length; i++) {
      if (data.length > 20 && i % 2 != 0 && i != points.length - 1) continue;
      final pt = points[i];
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 4.0, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceTrendChartPainter oldDelegate) => true;
}

class _DonutDistributionPainter extends CustomPainter {
  final double presentPct;
  final double latePct;
  final double halfDayPct;
  final double absentPct;
  final double leavePct;

  _DonutDistributionPainter({
    required this.presentPct,
    required this.latePct,
    required this.halfDayPct,
    required this.absentPct,
    required this.leavePct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 16.0;

    final slices = [
      {'pct': presentPct, 'color': const Color(0xFF10B981)},
      {'pct': latePct, 'color': const Color(0xFFF59E0B)},
      {'pct': halfDayPct, 'color': const Color(0xFF3B82F6)},
      {'pct': absentPct, 'color': const Color(0xFFEF4444)},
      {'pct': leavePct, 'color': const Color(0xFF8B5CF6)},
    ];

    double startAngle = -math.pi / 2;
    for (final s in slices) {
      final pct = (s['pct'] as double) / 100.0;
      final sweepAngle = pct * 2 * math.pi;
      if (sweepAngle <= 0.001) continue;

      final paint = Paint()
        ..color = s['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutDistributionPainter oldDelegate) => true;
}

class _DayOfWeekBarPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;
  final Color barColor;

  _DayOfWeekBarPainter({
    required this.data,
    required this.isDark,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartBottom = size.height - 20;
    const chartLeft = 24.0;
    final chartRight = size.width - 8;
    final chartWidth = chartRight - chartLeft;

    final displayList = data.isNotEmpty
        ? data
        : [
            {'day_abbr': 'Mon', 'attendance_pct': 0.0},
            {'day_abbr': 'Tue', 'attendance_pct': 0.0},
            {'day_abbr': 'Wed', 'attendance_pct': 0.0},
            {'day_abbr': 'Thu', 'attendance_pct': 0.0},
            {'day_abbr': 'Fri', 'attendance_pct': 0.0},
            {'day_abbr': 'Sat', 'attendance_pct': 0.0},
            {'day_abbr': 'Sun', 'attendance_pct': 0.0},
          ];

    final barWidth = (chartWidth / displayList.length) * 0.45;
    final stepX = chartWidth / displayList.length;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
    );

    for (int i = 0; i < displayList.length; i++) {
      final d = displayList[i];
      final abbr = d['day_abbr']?.toString() ?? 'D';
      final pct = (d['attendance_pct'] as num?)?.toDouble() ?? 0.0;

      final x = chartLeft + i * stepX + (stepX - barWidth) / 2;
      final barHeight = ((pct / 100.0) * (chartBottom - 16)).clamp(0.0, chartBottom - 16);
      final y = chartBottom - barHeight;

      if (barHeight > 0) {
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        );
        canvas.drawRRect(rrect, barPaint);
      }

      final tp = TextPainter(text: TextSpan(text: abbr, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, chartBottom + 4));

      final valTp = TextPainter(
        text: TextSpan(
          text: '${pct.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valTp.paint(canvas, Offset(x + barWidth / 2 - valTp.width / 2, math.max(0, y - 12)));
    }
  }

  @override
  bool shouldRepaint(covariant _DayOfWeekBarPainter oldDelegate) => true;
}

// ============================================================================
// STUDENT / EMPLOYEE ATTENDANCE PROFILE DRAWER (REAL DB DATA)
// ============================================================================

class _StudentInsightsDrawer extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final bool isDark;

  const _StudentInsightsDrawer({
    required this.studentId,
    required this.studentName,
    required this.isDark,
  });

  @override
  ConsumerState<_StudentInsightsDrawer> createState() => _StudentInsightsDrawerState();
}

class _StudentInsightsDrawerState extends ConsumerState<_StudentInsightsDrawer> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  int _historyPage = 1;
  static const int _historyPageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(attendanceApiServiceProvider).getStudentInsightsProfile(widget.studentId);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = (_data?['profile'] as Map<String, dynamic>?) ?? {};
    final stats = (_data?['stats'] as Map<String, dynamic>?) ?? {};
    final heatmap = (_data?['heatmap'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final history = (_data?['history'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final name = profile['full_name']?.toString() ?? widget.studentName;
    final role = profile['role']?.toString() ?? 'student';
    final classOrDept = profile['class_name']?.toString() ?? profile['department']?.toString() ?? 'Class';
    final section = profile['section_name']?.toString() ?? '';
    final admission = profile['admission_number']?.toString() ?? '';

    final attPct = (stats['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final totalDays = stats['total_days'] ?? 0;
    final presentDays = stats['present_days'] ?? 0;
    final absentDays = stats['absent_days'] ?? 0;
    final lateDays = stats['late_days'] ?? 0;
    final halfDays = stats['half_days'] ?? 0;
    final leaveDays = stats['leave_days'] ?? 0;

    final totalHistoryPages = math.max(1, (history.length / _historyPageSize).ceil());
    final startIdx = (_historyPage - 1) * _historyPageSize;
    final endIdx = math.min(startIdx + _historyPageSize, history.length);
    final pagedHistory = (startIdx < history.length) ? history.sublist(startIdx, endIdx) : <Map<String, dynamic>>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0] : 'U',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$classOrDept${section.isNotEmpty ? " • Section $section" : ""}${admission.isNotEmpty ? " • ADM: $admission" : ""}',
                          style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Stats Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatTile('Attendance', '${attPct.toStringAsFixed(1)}%', attPct >= 85 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            _buildStatTile('Present', '${presentDays}d', const Color(0xFF10B981)),
                            _buildStatTile('Absent', '${absentDays}d', const Color(0xFFEF4444)),
                            _buildStatTile('Late', '${lateDays}d', const Color(0xFFF59E0B)),
                            _buildStatTile('Half Day', '${halfDays}d', const Color(0xFF3B82F6)),
                            _buildStatTile('Leave', '${leaveDays}d', const Color(0xFF8B5CF6)),
                            _buildStatTile('Marked', '${totalDays}d', const Color(0xFF64748B)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 30-Day Attendance Calendar Heatmap
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Attendance Calendar Heatmap (Last 30 Days)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            Text(
                              '${heatmap.length} Days Recorded',
                              style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildHeatmapGrid(heatmap),
                        const SizedBox(height: 10),
                        // Heatmap Legend
                        _buildHeatmapLegend(),
                        const SizedBox(height: 24),

                        // Chronological Attendance History Logs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Attendance History Log (${history.length} Entries)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            if (totalHistoryPages > 1)
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 18),
                                    onPressed: _historyPage > 1 ? () => setState(() => _historyPage--) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Text(
                                    ' $_historyPage of $totalHistoryPages ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, size: 18),
                                    onPressed: _historyPage < totalHistoryPages ? () => setState(() => _historyPage++) : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('No historical logs found for this user.', style: TextStyle(fontSize: 12, color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pagedHistory.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              itemBuilder: (context, i) {
                                final log = pagedHistory[i];
                                final date = log['attendance_date']?.toString() ?? '';
                                final st = log['status']?.toString().toUpperCase() ?? 'PRESENT';
                                final remarks = log['remarks']?.toString() ?? '';
                                final updatedBy = log['updated_by_name']?.toString() ?? 'System';
                                final isLocked = (log['locked'] as bool?) ?? false;

                                Color badgeColor = const Color(0xFF10B981);
                                if (st == 'ABSENT') badgeColor = const Color(0xFFEF4444);
                                if (st == 'LATE') badgeColor = const Color(0xFFF59E0B);
                                if (st == 'HALF_DAY') badgeColor = const Color(0xFF3B82F6);
                                if (st == 'ON_LEAVE' || st == 'WORK_FROM_HOME') badgeColor = const Color(0xFF8B5CF6);

                                return ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Text(
                                        date.isNotEmpty ? DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(date)) : '',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          st.replaceAll('_', ' '),
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: badgeColor),
                                        ),
                                      ),
                                      if (isLocked) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFF94A3B8)),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${remarks.isNotEmpty ? "$remarks • " : ""}Recorded by $updatedBy',
                                    style: TextStyle(fontSize: 10.5, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String val, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: col)),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid(List<Map<String, dynamic>> heatmap) {
    if (heatmap.isEmpty) {
      return Text('No calendar records available', style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: heatmap.map((h) {
        final st = h['status']?.toString().toUpperCase() ?? 'NOT_MARKED';
        final dayNum = h['day_number'] ?? 0;
        final date = h['date']?.toString() ?? '';

        Color color = const Color(0xFF64748B).withValues(alpha: 0.2);
        if (st == 'PRESENT') color = const Color(0xFF10B981);
        if (st == 'LATE') color = const Color(0xFFF59E0B);
        if (st == 'HALF_DAY') color = const Color(0xFF3B82F6);
        if (st == 'ABSENT') color = const Color(0xFFEF4444);
        if (st == 'ON_LEAVE' || st == 'WORK_FROM_HOME') color = const Color(0xFF8B5CF6);

        return Tooltip(
          message: '$date: ${st.replaceAll('_', ' ')}',
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: (st == 'NOT_MARKED') ? (widget.isDark ? Colors.white70 : Colors.black87) : Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeatmapLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _buildLegendItem('Present', const Color(0xFF10B981)),
        _buildLegendItem('Late', const Color(0xFFF59E0B)),
        _buildLegendItem('Half Day', const Color(0xFF3B82F6)),
        _buildLegendItem('Absent', const Color(0xFFEF4444)),
        _buildLegendItem('On Leave', const Color(0xFF8B5CF6)),
        _buildLegendItem('Not Marked', const Color(0xFF64748B).withValues(alpha: 0.3)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color col) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      ],
    );
  }
}

// ============================================================================
// ALL CLASSES MODAL (WITH LIVE SEARCH, SORT & PAGINATION)
// ============================================================================

class _AllClassesModal extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final bool isDark;

  const _AllClassesModal({required this.classes, required this.isDark});

  @override
  State<_AllClassesModal> createState() => _AllClassesModalState();
}

class _AllClassesModalState extends State<_AllClassesModal> {
  String _searchQuery = '';
  String _sortBy = 'ATT_DESC';
  int _page = 1;
  int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.classes.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final name = c['class_name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.trim().toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'ATT_DESC') {
        final aP = (a['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        final bP = (b['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        return bP.compareTo(aP);
      } else if (_sortBy == 'ATT_ASC') {
        final aP = (a['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        final bP = (b['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        return aP.compareTo(bP);
      } else if (_sortBy == 'STUDENTS_DESC') {
        final aS = a['total_students'] ?? 0;
        final bS = b['total_students'] ?? 0;
        return (bS as num).compareTo(aS as num);
      } else {
        final aN = a['class_name']?.toString() ?? '';
        final bN = b['class_name']?.toString() ?? '';
        return aN.compareTo(bN);
      }
    });

    final totalPages = math.max(1, (filtered.length / _pageSize).ceil());
    if (_page > totalPages) _page = totalPages;
    final startIdx = (_page - 1) * _pageSize;
    final endIdx = math.min(startIdx + _pageSize, filtered.length);
    final paged = (startIdx < filtered.length) ? filtered.sublist(startIdx, endIdx) : <Map<String, dynamic>>[];

    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Classes Attendance Performance',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),

            // Search & Sort Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _page = 1;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search classes...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: const ['ATT_DESC', 'ATT_ASC', 'STUDENTS_DESC', 'NAME_ASC'].contains(_sortBy) ? _sortBy : 'ATT_DESC',
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ATT_DESC', child: Text('Highest %')),
                    DropdownMenuItem(value: 'ATT_ASC', child: Text('Lowest %')),
                    DropdownMenuItem(value: 'STUDENTS_DESC', child: Text('Most Students')),
                    DropdownMenuItem(value: 'NAME_ASC', child: Text('Name (A-Z)')),
                  ],
                  onChanged: (v) => setState(() => _sortBy = v ?? 'ATT_DESC'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Class List
            Expanded(
              child: paged.isEmpty
                  ? Center(child: Text('No classes match search query', style: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))))
                  : ListView.separated(
                      itemCount: paged.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final cl = paged[i];
                        final name = cl['class_name']?.toString() ?? 'Class';
                        final pct = (cl['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                        final students = cl['total_students'] ?? 0;
                        final pres = cl['present'] ?? 0;
                        final abs = cl['absent'] ?? 0;
                        final late = cl['late'] ?? 0;
                        final delta = (cl['trend_delta'] as num?)?.toDouble() ?? 0.0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                            child: Text('${startIdx + i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 12)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: Text(
                            '$students Students • $pres Present • $abs Absent • $late Late',
                            style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981))),
                              Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    DropdownButton<int>(
                      value: const [10, 25, 50].contains(_pageSize) ? _pageSize : 10,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (v) => setState(() {
                        _pageSize = v ?? 10;
                        _page = 1;
                      }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Page $_page of $totalPages (${filtered.length} total)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: _page < totalPages ? () => setState(() => _page++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ALL ABSENTEES MODAL (WITH LIVE SEARCH, SORT & PAGINATION)
// ============================================================================

class _AllAbsenteesModal extends StatefulWidget {
  final List<Map<String, dynamic>> absentees;
  final bool isDark;
  final Function(String, String) onSelectStudent;

  const _AllAbsenteesModal({
    required this.absentees,
    required this.isDark,
    required this.onSelectStudent,
  });

  @override
  State<_AllAbsenteesModal> createState() => _AllAbsenteesModalState();
}

class _AllAbsenteesModalState extends State<_AllAbsenteesModal> {
  String _searchQuery = '';
  String _sortBy = 'ABSENT_DESC';
  int _page = 1;
  int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.absentees.where((st) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final name = st['name']?.toString().toLowerCase() ?? '';
      final cName = st['class_name']?.toString().toLowerCase() ?? '';
      final role = st['role']?.toString().toLowerCase() ?? '';
      return name.contains(q) || cName.contains(q) || role.contains(q);
    }).toList();

    filtered.sort((a, b) {
      if (_sortBy == 'ABSENT_DESC') {
        final aA = a['absent_days'] ?? 0;
        final bA = b['absent_days'] ?? 0;
        return (bA as num).compareTo(aA as num);
      } else if (_sortBy == 'ATT_ASC') {
        final aP = (a['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        final bP = (b['attendance_pct'] as num?)?.toDouble() ?? 0.0;
        return aP.compareTo(bP);
      } else if (_sortBy == 'CONSEC_DESC') {
        final aC = a['consecutive_absences'] ?? 0;
        final bC = b['consecutive_absences'] ?? 0;
        return (bC as num).compareTo(aC as num);
      } else {
        final aN = a['name']?.toString() ?? '';
        final bN = b['name']?.toString() ?? '';
        return aN.compareTo(bN);
      }
    });

    final totalPages = math.max(1, (filtered.length / _pageSize).ceil());
    if (_page > totalPages) _page = totalPages;
    final startIdx = (_page - 1) * _pageSize;
    final endIdx = math.min(startIdx + _pageSize, filtered.length);
    final paged = (startIdx < filtered.length) ? filtered.sublist(startIdx, endIdx) : <Map<String, dynamic>>[];

    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chronic Absenteeism Watchlist',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),

            // Search & Sort Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _page = 1;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search student, staff or class...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: const ['ABSENT_DESC', 'ATT_ASC', 'CONSEC_DESC', 'NAME_ASC'].contains(_sortBy) ? _sortBy : 'ABSENT_DESC',
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'ABSENT_DESC', child: Text('Most Absences')),
                    DropdownMenuItem(value: 'ATT_ASC', child: Text('Lowest %')),
                    DropdownMenuItem(value: 'CONSEC_DESC', child: Text('Consecutive Absences')),
                    DropdownMenuItem(value: 'NAME_ASC', child: Text('Name (A-Z)')),
                  ],
                  onChanged: (v) => setState(() => _sortBy = v ?? 'ABSENT_DESC'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // Absentee List
            Expanded(
              child: paged.isEmpty
                  ? Center(child: Text('No absentees match search query', style: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))))
                  : ListView.separated(
                      itemCount: paged.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final st = paged[i];
                        final name = st['name']?.toString() ?? 'Person';
                        final cName = st['class_name']?.toString() ?? 'Class';
                        final role = st['role']?.toString() ?? 'student';
                        final abs = st['absent_days'] ?? 0;
                        final consec = st['consecutive_absences'] ?? abs;
                        final pct = (st['attendance_pct'] as num?)?.toDouble() ?? 0.0;
                        final id = st['student_id']?.toString() ?? st['person_id']?.toString() ?? '';

                        return ListTile(
                          onTap: () => widget.onSelectStudent(id, name),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            child: Text(name.isNotEmpty ? name[0] : 'S', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                          ),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '$cName • $abs Days Absent • $consec Consecutive',
                            style: TextStyle(fontSize: 11, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          trailing: Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFEF4444)),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    DropdownButton<int>(
                      value: const [10, 25, 50].contains(_pageSize) ? _pageSize : 10,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (v) => setState(() {
                        _pageSize = v ?? 10;
                        _page = 1;
                      }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Page $_page of $totalPages (${filtered.length} total)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      onPressed: _page < totalPages ? () => setState(() => _page++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
