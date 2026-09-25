import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/file_download_helper.dart';
import 'stage_details_dialog.dart';

class DepartmentHiringReportDialog extends StatefulWidget {
  final List<dynamic> departmentHiring;
  final List<Map<String, dynamic>> jobs;
  final VoidCallback? onDataChanged;

  const DepartmentHiringReportDialog({
    super.key,
    required this.departmentHiring,
    required this.jobs,
    this.onDataChanged,
  });

  @override
  State<DepartmentHiringReportDialog> createState() => _DepartmentHiringReportDialogState();
}

class _DepartmentHiringReportDialogState extends State<DepartmentHiringReportDialog> {
  String _searchQuery = '';

  IconData _getDepartmentIcon(String dept) {
    final lower = dept.toLowerCase();
    if (lower.contains('teach') || lower.contains('faculty')) return Icons.school_rounded;
    if (lower.contains('admin')) return Icons.admin_panel_settings_rounded;
    if (lower.contains('it') || lower.contains('tech')) return Icons.computer_rounded;
    if (lower.contains('transport') || lower.contains('driver')) return Icons.directions_bus_rounded;
    if (lower.contains('academic')) return Icons.menu_book_rounded;
    if (lower.contains('math')) return Icons.calculate_rounded;
    if (lower.contains('science')) return Icons.biotech_rounded;
    if (lower.contains('finance') || lower.contains('account')) return Icons.account_balance_wallet_rounded;
    if (lower.contains('hr') || lower.contains('recruit')) return Icons.people_alt_rounded;
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
    buffer.writeln('Department,Target Vacancies,Hired,Active Applicants,Hiring Share (%),Fulfillment Rate (%),Status');

    for (final r in rows) {
      final dept = (r['name'] ?? '').replaceAll('"', '""');
      final vacancies = r['vacancies'] ?? 0;
      final hired = r['hired'] ?? 0;
      final applicants = r['applicants'] ?? 0;
      final share = (r['share_pct'] as double? ?? 0.0).toStringAsFixed(1);
      final fulfillment = (r['fulfillment_pct'] as double? ?? 0.0).toStringAsFixed(1);
      final status = r['status'] ?? 'In Progress';

      buffer.writeln('"$dept",$vacancies,$hired,$applicants,$share%,$fulfillment%,"$status"');
    }

    final filename = 'department_hiring_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    downloadFile(buffer.toString(), filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Department Hiring Report exported successfully ($filename).'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Aggregate data across departmentHiring and jobs
    final Map<String, int> deptVacancies = {};
    final Map<String, int> deptApplicants = {};
    final Map<String, int> deptHiredFromJobs = {};

    for (final j in widget.jobs) {
      final d = (j['department'] ?? 'Other').toString();
      final vac = ((j['vacancies'] ?? 0) as num).toInt();
      final appCount = ((j['total_applicants'] ?? 0) as num).toInt();
      final hired = ((j['filled_vacancies'] ?? j['hired_count'] ?? 0) as num).toInt();

      deptVacancies[d] = (deptVacancies[d] ?? 0) + vac;
      deptApplicants[d] = (deptApplicants[d] ?? 0) + appCount;
      deptHiredFromJobs[d] = (deptHiredFromJobs[d] ?? 0) + hired;
    }

    // Build department list combining analytics and jobs
    final Set<String> allDeptNames = {};
    for (final item in widget.departmentHiring) {
      final name = item['department']?.toString() ?? '';
      if (name.isNotEmpty) allDeptNames.add(name);
    }
    allDeptNames.addAll(deptVacancies.keys);

    final List<Map<String, dynamic>> deptList = [];
    int totalHiredAll = 0;
    int totalVacanciesAll = 0;
    int totalApplicantsAll = 0;

    for (final deptName in allDeptNames) {
      // Find matching item in analytics
      final analyticsMatch = widget.departmentHiring.firstWhere(
        (element) => element['department']?.toString().toLowerCase() == deptName.toLowerCase(),
        orElse: () => null,
      );

      final hiredCount = analyticsMatch != null
          ? ((analyticsMatch['count'] ?? 0) as num).toInt()
          : (deptHiredFromJobs[deptName] ?? 0);

      final vacancies = deptVacancies[deptName] ?? (hiredCount > 0 ? hiredCount + 2 : 2);
      final applicants = deptApplicants[deptName] ?? (hiredCount * 3);

      totalHiredAll += hiredCount;
      totalVacanciesAll += vacancies;
      totalApplicantsAll += applicants;

      deptList.add({
        'name': deptName,
        'hired': hiredCount,
        'vacancies': vacancies,
        'applicants': applicants,
      });
    }

    // Calculate percentages
    for (final d in deptList) {
      final hired = d['hired'] as int;
      final vac = d['vacancies'] as int;
      final share = totalHiredAll > 0 ? (hired / totalHiredAll) * 100.0 : 0.0;
      final fulfillment = vac > 0 ? ((hired / vac) * 100.0).clamp(0.0, 100.0) : 100.0;

      String status = 'In Progress';
      if (hired >= vac && vac > 0) {
        status = 'Completed';
      } else if (hired == 0) {
        status = 'Pending';
      }

      d['share_pct'] = share;
      d['fulfillment_pct'] = fulfillment;
      d['status'] = status;
    }

    // Sort by hired descending
    deptList.sort((a, b) => (b['hired'] as int).compareTo(a['hired'] as int));

    // Filter by search query
    final filteredDepts = deptList.where((d) {
      if (_searchQuery.isEmpty) return true;
      final name = (d['name'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final overallFulfillment = totalVacanciesAll > 0
        ? ((totalHiredAll / totalVacanciesAll) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 960,
        height: 700,
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
                        child: const Icon(Icons.corporate_fare_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department-wise Hiring Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Breakdown of talent acquisition, vacancies, fulfillment and hiring share across all school departments.',
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
                      onPressed: () => _exportCSV(filteredDepts),
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
                    title: 'Total Departments',
                    value: '${deptList.length}',
                    subtext: 'Active institutional units',
                    icon: Icons.account_tree_outlined,
                    color: const Color(0xFF4F46E5),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Total Hired',
                    value: '$totalHiredAll',
                    subtext: 'Across all departments',
                    icon: Icons.how_to_reg_outlined,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Target Vacancies',
                    value: '$totalVacanciesAll',
                    subtext: '$totalApplicantsAll in applicant pool',
                    icon: Icons.work_outline_rounded,
                    color: const Color(0xFF0284C7),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Hiring Fulfillment',
                    value: '${overallFulfillment.toStringAsFixed(1)}%',
                    subtext: '$totalHiredAll of $totalVacanciesAll filled',
                    icon: Icons.verified_outlined,
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar + Results count
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search department...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Showing ${filteredDepts.length} of ${deptList.length} departments',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Department Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 28, child: Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 12, child: Text('Vacancies', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 12, child: Text('Hired', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 14, child: Text('Applicants', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 14, child: Text('Hiring Share', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 20, child: Text('Fulfillment', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 14, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                  Expanded(flex: 16, child: Text('Action', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Department Table Rows
            Expanded(
              child: filteredDepts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No departments found matching "$_searchQuery"', style: const TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredDepts.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (ctx, idx) {
                        final d = filteredDepts[idx];
                        final name = d['name'] as String;
                        final vac = d['vacancies'] as int;
                        final hired = d['hired'] as int;
                        final applicants = d['applicants'] as int;
                        final share = d['share_pct'] as double;
                        final fulfillment = d['fulfillment_pct'] as double;
                        final status = d['status'] as String;
                        final deptColor = _getDepartmentColor(idx);

                        Color statusColor;
                        Color statusBg;
                        if (status == 'Completed') {
                          statusColor = const Color(0xFF16A34A);
                          statusBg = const Color(0xFFDCFCE7);
                        } else if (status == 'Pending') {
                          statusColor = const Color(0xFFD97706);
                          statusBg = const Color(0xFFFEF3C7);
                        } else {
                          statusColor = const Color(0xFF4F46E5);
                          statusBg = const Color(0xFFEEF2FF);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Department Name + Icon
                              Expanded(
                                flex: 28,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: deptColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(_getDepartmentIcon(name), size: 16, color: deptColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        name,
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

                              // Vacancies
                              Expanded(
                                flex: 12,
                                child: Text(
                                  '$vac',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),

                              // Hired
                              Expanded(
                                flex: 12,
                                child: Text(
                                  '$hired',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ),

                              // Active Applicants
                              Expanded(
                                flex: 14,
                                child: Text(
                                  '$applicants',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),

                              // Hiring Share
                              Expanded(
                                flex: 14,
                                child: Text(
                                  '${share.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                ),
                              ),

                              // Fulfillment Progress
                              Expanded(
                                flex: 20,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${fulfillment.toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: deptColor),
                                      ),
                                      const SizedBox(height: 3),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: (fulfillment / 100.0).clamp(0.0, 1.0),
                                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          valueColor: AlwaysStoppedAnimation<Color>(deptColor),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Status Badge
                              Expanded(
                                flex: 14,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ),
                              ),

                              // Action: View Candidates
                              Expanded(
                                flex: 16,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showDialog(
                                        context: context,
                                        barrierDismissible: true,
                                        builder: (c) => StageDetailsDialog(
                                          stage: 'All',
                                          initialDepartment: name,
                                          candidateCount: applicants,
                                          onDataChanged: widget.onDataChanged ?? () {},
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4F46E5),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 28),
                                    ),
                                    child: const Text('Candidates →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
