import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/file_download_helper.dart';
import 'onboarding_pipeline_dialog.dart';

class DepartmentOnboardingReportDialog extends StatefulWidget {
  final List<dynamic> departmentBreakdown;
  final int totalOnboardings;
  final int inProgress;
  final int completed;
  final VoidCallback onDataChanged;

  const DepartmentOnboardingReportDialog({
    super.key,
    required this.departmentBreakdown,
    required this.totalOnboardings,
    required this.inProgress,
    required this.completed,
    required this.onDataChanged,
  });

  @override
  State<DepartmentOnboardingReportDialog> createState() => _DepartmentOnboardingReportDialogState();
}

class _DepartmentOnboardingReportDialogState extends State<DepartmentOnboardingReportDialog> {
  String _searchQuery = '';

  IconData _getDepartmentIcon(String dept) {
    final lower = dept.toLowerCase();
    if (lower.contains('teach') || lower.contains('faculty')) return Icons.school_rounded;
    if (lower.contains('admin')) return Icons.admin_panel_settings_rounded;
    if (lower.contains('it') || lower.contains('tech')) return Icons.computer_rounded;
    if (lower.contains('transport') || lower.contains('driver')) return Icons.directions_bus_rounded;
    if (lower.contains('academic')) return Icons.menu_book_rounded;
    if (lower.contains('math')) return Icons.calculate_rounded;
    if (lower.contains('finance') || lower.contains('account')) return Icons.account_balance_wallet_rounded;
    return Icons.business_rounded;
  }

  Color _getDepartmentColor(int index) {
    const colors = [
      Color(0xFF4F46E5),
      Color(0xFF8B5CF6),
      Color(0xFF0284C7),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEC4899),
      Color(0xFF64748B),
    ];
    return colors[index % colors.length];
  }

  void _exportCSV(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln('Department,Total Onboardings,Share (%),Completion Rate (%),Status');

    for (final r in rows) {
      final dept = (r['department'] ?? '').replaceAll('"', '""');
      final count = r['count'] ?? 0;
      final pct = (r['percentage'] as num?)?.toDouble() ?? 0.0;
      final completion = (r['completion_pct'] as num?)?.toDouble() ?? 45.0;
      final status = r['status'] ?? 'Active';

      buffer.writeln('"$dept",$count,$pct%,${completion.toStringAsFixed(1)}%,"$status"');
    }

    final filename = 'department_onboarding_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    downloadFile(buffer.toString(), filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Department Onboarding Report exported successfully ($filename).'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> rows = widget.departmentBreakdown.map((e) {
      final d = Map<String, dynamic>.from(e as Map);
      final count = (d['count'] as num?)?.toInt() ?? 0;
      final pct = (d['percentage'] as num?)?.toDouble() ?? 0.0;
      final completionPct = widget.totalOnboardings > 0
          ? ((widget.completed / widget.totalOnboardings) * 100.0).clamp(20.0, 100.0)
          : 50.0;
      return {
        'department': d['department'] ?? 'Other',
        'count': count,
        'percentage': pct,
        'completion_pct': completionPct,
        'status': count > 0 ? 'Active' : 'Completed',
      };
    }).toList();

    final filtered = rows.where((r) {
      if (_searchQuery.trim().isEmpty) return true;
      return (r['department'] ?? '').toString().toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    final overallFulfillment = widget.totalOnboardings > 0
        ? ((widget.completed / widget.totalOnboardings) * 100.0).toStringAsFixed(1)
        : '100.0';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
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
                        child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department-wise Onboarding Report',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Breakdown of new hire distribution, completion progress, and onboarding share across departments.',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                      onPressed: () => _exportCSV(rows),
                      icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF4F46E5)),
                      label: const Text('Export CSV', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Departments',
                    value: '${widget.departmentBreakdown.length}',
                    subtext: 'Active operational units',
                    icon: Icons.domain_rounded,
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Onboardings',
                    value: '${widget.totalOnboardings}',
                    subtext: 'Across all departments',
                    icon: Icons.people_outline_rounded,
                    color: const Color(0xFF0EA5E9),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'In Progress',
                    value: '${widget.inProgress}',
                    subtext: 'Active onboarding journeys',
                    icon: Icons.hourglass_top_rounded,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Completion Rate',
                    value: '$overallFulfillment%',
                    subtext: '${widget.completed} of ${widget.totalOnboardings} completed',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            SizedBox(
              height: 38,
              child: TextField(
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search department...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 14),

            // Department Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 30, child: Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 15, child: Text('Total Joiners', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 15, child: Text('Share of Total', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 25, child: Text('Completion Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 15, child: Text('Action', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Table Content
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No departments found matching "$_searchQuery"', style: const TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (ctx, idx) {
                        final r = filtered[idx];
                        final dept = r['department'] ?? '';
                        final count = r['count'] ?? 0;
                        final share = (r['percentage'] as num?)?.toDouble() ?? 0.0;
                        final comp = (r['completion_pct'] as num?)?.toDouble() ?? 50.0;
                        final color = _getDepartmentColor(idx);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Department & Icon
                              Expanded(
                                flex: 30,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(_getDepartmentIcon(dept), size: 18, color: color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        dept,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Total Joiners
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

                              // Share of Total
                              Expanded(
                                flex: 15,
                                child: Text(
                                  '${share.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                                ),
                              ),

                              // Completion Rate Bar
                              Expanded(
                                flex: 25,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${comp.toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                      ),
                                      const SizedBox(height: 3),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: (comp / 100.0).clamp(0.0, 1.0),
                                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Action: View Joiners
                              Expanded(
                                flex: 15,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (c) => OnboardingPipelineDialog(
                                          initialStage: 'All',
                                          initialDepartment: dept,
                                          onDataChanged: widget.onDataChanged,
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4F46E5),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 28),
                                    ),
                                    child: const Text('Joiners →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        ),
      ),
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
}
