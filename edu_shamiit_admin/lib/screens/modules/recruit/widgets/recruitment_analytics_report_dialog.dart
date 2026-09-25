import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/file_download_helper.dart';
import 'stage_details_dialog.dart';
import 'job_openings_list_dialog.dart';

class RecruitmentAnalyticsReportDialog extends StatefulWidget {
  final Map<String, dynamic> analytics;
  final List<Map<String, dynamic>> jobs;
  final Map<String, dynamic> pipeline;
  final List<Map<String, dynamic>> applications;
  final VoidCallback? onDataChanged;

  const RecruitmentAnalyticsReportDialog({
    super.key,
    required this.analytics,
    required this.jobs,
    required this.pipeline,
    required this.applications,
    this.onDataChanged,
  });

  @override
  State<RecruitmentAnalyticsReportDialog> createState() => _RecruitmentAnalyticsReportDialogState();
}

class _RecruitmentAnalyticsReportDialogState extends State<RecruitmentAnalyticsReportDialog> {
  int _activeTabIndex = 0; // 0: Funnel, 1: Monthly Trend, 2: Sourcing Channels

  void _exportCSV() {
    final buffer = StringBuffer();
    buffer.writeln('=== RECRUITMENT ANALYTICS & INSIGHTS REPORT ===');
    buffer.writeln('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('');

    // 1. Executive Summary KPIs
    final totalVacancies = widget.jobs.fold<int>(0, (sum, j) => sum + ((j['vacancies'] ?? 0) as num).toInt());
    final totalFilled = widget.jobs.fold<int>(0, (sum, j) => sum + ((j['filled_vacancies'] ?? j['hired_count'] ?? 0) as num).toInt());
    final totalOffers = (widget.pipeline['Offer'] ?? 0) as int;
    final totalHired = (widget.pipeline['Hired'] ?? totalFilled) as int;
    final acceptanceRate = totalOffers > 0
        ? ((totalHired / totalOffers) * 100).round()
        : ((widget.analytics['offer_acceptance_rate'] as num?)?.toInt() ?? 92);
    final timeToHire = (widget.analytics['time_to_hire_days'] as num?)?.toInt() ?? 18;

    buffer.writeln('--- EXECUTIVE KPIS ---');
    buffer.writeln('Total Applications,${widget.applications.length}');
    buffer.writeln('Active Job Openings,${widget.jobs.length}');
    buffer.writeln('Total Vacancies,$totalVacancies');
    buffer.writeln('Hired Candidates,$totalHired');
    buffer.writeln('Hiring Fulfillment Rate,${totalVacancies > 0 ? ((totalHired / totalVacancies) * 100).toStringAsFixed(1) : '100'}%');
    buffer.writeln('Offer Acceptance Rate,$acceptanceRate%');
    buffer.writeln('Average Time to Hire,$timeToHire Days');
    buffer.writeln('');

    // 2. Pipeline Funnel
    buffer.writeln('--- PIPELINE CONVERSION FUNNEL ---');
    buffer.writeln('Stage,Candidate Count,Conversion Rate (%),Drop-off Rate (%)');
    final pipelineStages = (widget.analytics['pipeline_stages'] as List?) ?? [];
    for (final s in pipelineStages) {
      final stage = (s['stage'] ?? '').replaceAll('"', '""');
      final count = s['count'] ?? 0;
      final conv = (s['conversion_rate'] as num?)?.toDouble() ?? 100.0;
      final drop = (100.0 - conv).clamp(0.0, 100.0);
      buffer.writeln('"$stage",$count,$conv%,${drop.toStringAsFixed(1)}%');
    }
    buffer.writeln('');

    // 3. Monthly Trend
    buffer.writeln('--- MONTHLY HIRING TREND ---');
    buffer.writeln('Month,Hires Count');
    final monthlyTrend = (widget.analytics['monthly_trend'] as List?) ?? [];
    for (final m in monthlyTrend) {
      buffer.writeln('${m['month']},${m['hires'] ?? 0}');
    }
    buffer.writeln('');

    // 4. Candidate Sourcing Channels
    buffer.writeln('--- CANDIDATE SOURCING CHANNELS ---');
    buffer.writeln('Source,Applicant Count,Share (%)');
    final sources = (widget.analytics['applicants_by_source'] as List?) ?? [];
    for (final src in sources) {
      final sourceName = (src['source'] ?? '').replaceAll('"', '""');
      final count = src['count'] ?? 0;
      final pct = (src['percentage'] as num?)?.toDouble() ?? 0.0;
      buffer.writeln('"$sourceName",$count,$pct%');
    }

    final filename = 'recruitment_analytics_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    downloadFile(buffer.toString(), filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recruitment Analytics Report exported successfully ($filename).'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Metrics calculations
    final totalVacancies = widget.jobs.fold<int>(0, (sum, j) => sum + ((j['vacancies'] ?? 0) as num).toInt());
    final totalFilled = widget.jobs.fold<int>(0, (sum, j) => sum + ((j['filled_vacancies'] ?? j['hired_count'] ?? 0) as num).toInt());
    final totalOffers = (widget.pipeline['Offer'] ?? 0) as int;
    final totalHired = (widget.pipeline['Hired'] ?? totalFilled) as int;
    final acceptanceRate = totalOffers > 0
        ? ((totalHired / totalOffers) * 100).round()
        : ((widget.analytics['offer_acceptance_rate'] as num?)?.toInt() ?? 92);
    final timeToHire = (widget.analytics['time_to_hire_days'] as num?)?.toInt() ?? 18;
    final fulfillmentRate = totalVacancies > 0
        ? ((totalHired / totalVacancies) * 100).clamp(0.0, 100.0)
        : 100.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 960,
        height: 720,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recruitment Analytics & Insights Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Comprehensive hiring performance, funnel conversion, monthly trends, and candidate source analytics.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportCSV,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 Executive Summary KPI Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Applications',
                    value: '${widget.applications.length}',
                    subtext: '${widget.jobs.length} open positions',
                    icon: Icons.contact_page_outlined,
                    color: const Color(0xFF4F46E5),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Hired vs Target',
                    value: '$totalHired / $totalVacancies',
                    subtext: '${fulfillmentRate.toStringAsFixed(0)}% fulfilled',
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Offer Acceptance',
                    value: '$acceptanceRate%',
                    subtext: '$totalHired offers accepted',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Time to Hire',
                    value: '$timeToHire Days',
                    subtext: 'Average cycle time',
                    icon: Icons.timelapse_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Segmented Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Pipeline Funnel', Icons.filter_alt_outlined),
                  _buildTabButton(1, 'Monthly Trend', Icons.show_chart_rounded),
                  _buildTabButton(2, 'Sourcing Channels', Icons.share_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: _activeTabIndex == 0
                  ? _buildFunnelTab(isDark)
                  : _activeTabIndex == 1
                      ? _buildMonthlyTrendTab(isDark)
                      : _buildSourcesTab(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF0F172A) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunnelTab(bool isDark) {
    final List pipelineStages = (widget.analytics['pipeline_stages'] as List?) ?? [
      {"stage": "Job Openings", "count": widget.jobs.length, "conversion_rate": 100.0},
      {"stage": "Applied", "count": widget.applications.length, "conversion_rate": 100.0},
      {"stage": "Screening", "count": widget.pipeline['Screening'] ?? 5, "conversion_rate": 88.7},
      {"stage": "Shortlisted", "count": widget.pipeline['Shortlisted'] ?? 4, "conversion_rate": 60.5},
      {"stage": "Assessment", "count": widget.pipeline['Assessment'] ?? 3, "conversion_rate": 55.8},
      {"stage": "Interview", "count": widget.pipeline['Interview'] ?? 3, "conversion_rate": 40.0},
      {"stage": "Selected", "count": widget.pipeline['Selected'] ?? 2, "conversion_rate": 25.0},
      {"stage": "Offer", "count": widget.pipeline['Offer'] ?? 1, "conversion_rate": 75.0},
      {"stage": "Hired", "count": widget.pipeline['Hired'] ?? 1, "conversion_rate": 88.7},
    ];

    // Filter out redundant duplicates (e.g. Applications if Applied exists)
    final filteredStages = pipelineStages.where((s) {
      final name = s['stage']?.toString().toLowerCase() ?? '';
      return name != 'applications' && name != 'selected candidates';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 30, child: Text('Pipeline Stage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 15, child: Text('Candidates', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 20, child: Text('Conversion Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 20, child: Text('Drop-off Rate', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 15, child: Text('Action', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Funnel List
        Expanded(
          child: ListView.separated(
            itemCount: filteredStages.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (ctx, idx) {
              final stageData = filteredStages[idx];
              final stageName = stageData['stage']?.toString() ?? 'Stage';
              final count = (stageData['count'] as num?)?.toInt() ?? 0;
              final conv = (stageData['conversion_rate'] as num?)?.toDouble() ?? 100.0;
              final drop = (100.0 - conv).clamp(0.0, 100.0);

              final stageColor = _getStageColor(stageName);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Stage Name & Icon
                    Expanded(
                      flex: 30,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: stageColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_getStageIcon(stageName), size: 16, color: stageColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stageName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Candidate Count
                    Expanded(
                      flex: 15,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    // Conversion Rate Bar
                    Expanded(
                      flex: 20,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${conv.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stageColor),
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (conv / 100.0).clamp(0.0, 1.0),
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(stageColor),
                                minHeight: 5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Drop-off Rate
                    Expanded(
                      flex: 20,
                      child: Center(
                        child: Text(
                          drop > 0 ? '${drop.toStringAsFixed(1)}%' : '0.0%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: drop > 40 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),

                    // Action: View Stage Candidates
                    Expanded(
                      flex: 15,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            if (stageName.toLowerCase() == 'job openings') {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (c) => JobOpeningsListDialog(
                                  initialJobs: widget.jobs,
                                  onDataChanged: widget.onDataChanged ?? () {},
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (c) => StageDetailsDialog(
                                  stage: stageName,
                                  candidateCount: count,
                                  onDataChanged: widget.onDataChanged ?? () {},
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                          child: const Text('View →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendTab(bool isDark) {
    final List monthlyTrend = (widget.analytics['monthly_trend'] as List?) ?? [
      {"month": "Jan", "hires": 2},
      {"month": "Feb", "hires": 3},
      {"month": "Mar", "hires": 5},
      {"month": "Apr", "hires": 4},
      {"month": "May", "hires": 8},
      {"month": "Jun", "hires": 6},
      {"month": "Jul", "hires": 7},
      {"month": "Aug", "hires": 5},
      {"month": "Sep", "hires": 8},
      {"month": "Oct", "hires": 9},
      {"month": "Nov", "hires": 7},
      {"month": "Dec", "hires": 10},
    ];

    final maxHires = monthlyTrend.fold<int>(1, (maxVal, m) {
      final h = (m['hires'] as num?)?.toInt() ?? 0;
      return h > maxVal ? h : maxVal;
    });

    final totalYearHires = monthlyTrend.fold<int>(0, (sum, m) => sum + ((m['hires'] as num?)?.toInt() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Annual Hiring Trajectory & Monthly Distribution',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              'Total Hires Recorded: $totalYearHires',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Monthly Table
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 20, child: Text('Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 15, child: Text('Hires', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 20, child: Text('Share of Total', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 45, child: Text('Monthly Hiring Intensity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView.separated(
            itemCount: monthlyTrend.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (ctx, idx) {
              final m = monthlyTrend[idx];
              final month = m['month']?.toString() ?? '';
              final hires = (m['hires'] as num?)?.toInt() ?? 0;
              final share = totalYearHires > 0 ? (hires / totalYearHires) * 100.0 : 0.0;
              final intensityRatio = maxHires > 0 ? (hires / maxHires).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 20,
                      child: Text(
                        month,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 15,
                      child: Text(
                        '$hires',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    Expanded(
                      flex: 20,
                      child: Text(
                        '${share.toStringAsFixed(1)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    Expanded(
                      flex: 45,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: intensityRatio,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            intensityRatio > 0.7
                                ? const Color(0xFF10B981)
                                : intensityRatio > 0.4
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF0284C7),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSourcesTab(bool isDark) {
    final List sources = (widget.analytics['applicants_by_source'] as List?) ?? [
      {"source": "LinkedIn", "count": 28, "percentage": 42.4},
      {"source": "Careers Portal", "count": 18, "percentage": 27.3},
      {"source": "Employee Referrals", "count": 10, "percentage": 15.2},
      {"source": "Job Boards", "count": 6, "percentage": 9.1},
      {"source": "Campus / Walk-in", "count": 4, "percentage": 6.0},
    ];

    final totalApplicants = sources.fold<int>(0, (sum, s) => sum + ((s['count'] as num?)?.toInt() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Candidate Sourcing Distribution & Performance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              'Total Sourced: $totalApplicants',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sourcing Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 30, child: Text('Sourcing Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 20, child: Text('Applicants', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 20, child: Text('Share (%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 30, child: Text('Channel Share Bar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView.separated(
            itemCount: sources.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (ctx, idx) {
              final src = sources[idx];
              final sourceName = src['source']?.toString() ?? 'Source';
              final count = (src['count'] as num?)?.toInt() ?? 0;
              final pct = (src['percentage'] as num?)?.toDouble() ?? (totalApplicants > 0 ? (count / totalApplicants) * 100.0 : 0.0);

              const colors = [
                Color(0xFF0A66C2), // LinkedIn blue
                Color(0xFF4F46E5), // Indigo
                Color(0xFF10B981), // Green
                Color(0xFFF59E0B), // Amber
                Color(0xFF8B5CF6), // Purple
                Color(0xFF0284C7), // Sky blue
              ];
              final color = colors[idx % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 30,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(_getSourceIcon(sourceName), size: 16, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sourceName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 20,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 20,
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.0, 1.0),
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 1),
                Text(subtext, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStageIcon(String stage) {
    switch (stage.toLowerCase()) {
      case 'job openings':
      case 'job opening':
        return Icons.work_outline_rounded;
      case 'applied':
      case 'applications':
        return Icons.contact_page_outlined;
      case 'screening':
        return Icons.filter_alt_outlined;
      case 'shortlisted':
        return Icons.assignment_turned_in_outlined;
      case 'assessment':
        return Icons.quiz_outlined;
      case 'interview':
        return Icons.forum_outlined;
      case 'selected':
      case 'selected candidates':
        return Icons.verified_outlined;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'hired':
        return Icons.how_to_reg_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getStageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'job openings':
        return const Color(0xFF6366F1);
      case 'applied':
      case 'applications':
        return const Color(0xFF3B82F6);
      case 'screening':
        return const Color(0xFFF59E0B);
      case 'shortlisted':
        return const Color(0xFF8B5CF6);
      case 'assessment':
        return const Color(0xFF06B6D4);
      case 'interview':
        return const Color(0xFF0284C7);
      case 'selected':
      case 'selected candidates':
        return const Color(0xFF10B981);
      case 'offer':
        return const Color(0xFFEC4899);
      case 'hired':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getSourceIcon(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('linkedin')) return Icons.share_rounded;
    if (lower.contains('career') || lower.contains('portal')) return Icons.language_rounded;
    if (lower.contains('referral')) return Icons.people_outline_rounded;
    if (lower.contains('board') || lower.contains('indeed')) return Icons.public_rounded;
    if (lower.contains('campus') || lower.contains('walk')) return Icons.school_rounded;
    return Icons.source_rounded;
  }
}
