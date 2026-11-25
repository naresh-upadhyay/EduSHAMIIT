import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_leave_kpi_cards.dart';
import 'hostel_leave_filter_bar.dart';
import 'hostel_leave_request_table.dart';
import 'hostel_leave_detail_drawer.dart';
import 'gate_pass_dialog.dart';
import 'hostel_gate_pass_print_dialog.dart';
import 'hostel_leave_calendar_view.dart';

class HostelLeaveTab extends ConsumerStatefulWidget {
  const HostelLeaveTab({super.key});

  @override
  ConsumerState<HostelLeaveTab> createState() => _HostelLeaveTabState();
}

class _HostelLeaveTabState extends ConsumerState<HostelLeaveTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hostelProvider.notifier).loadLeaveOutingData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1100;

        return Stack(
          children: [
            // Main Content Area with Pull-to-refresh
            RefreshIndicator(
              onRefresh: () => notifier.refreshLeaveOuting(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. KPI Metric Summary Cards (Matching Screenshot)
                    const HostelLeaveKPICards(),
                    const SizedBox(height: 20),

                    // 2. Filter & Subtab Bar
                    const HostelLeaveFilterBar(),
                    const SizedBox(height: 18),

                    // 3. Subtab Content Switcher: 0: Leave & Outing Requests, 1: Gate Pass, 2: Movement Calendar
                    if (state.leaveSubTab == 1)
                      // Subtab 1: Gate Pass Hub
                      _buildGatePassHubView(state, notifier, isDark)
                    else if (state.leaveSubTab == 2)
                      // Subtab 2: Visual Movement Calendar
                      const HostelLeaveCalendarView()
                    else
                      // Subtab 0: Requests Table + Right Sidebar
                      _buildRequestsContent(isDesktop, state, isDark),
                  ],
                ),
              ),
            ),

            // Right Slide-Over Detail Drawer when request is selected
            if (state.selectedLeaveRequest != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: HostelLeaveDetailDrawer(
                  key: ValueKey('${state.selectedLeaveRequest!.id}_${state.selectedLeaveRequest!.status}_${state.selectedLeaveRequest!.version}_${state.selectedLeaveRequest!.documents.length}_${state.selectedLeaveRequest!.internalNotes.length}'),
                  request: state.selectedLeaveRequest!,
                  onClose: () => notifier.clearSelectedLeaveRequest(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRequestsContent(bool isDesktop, HostelState state, bool isDark) {
    return const HostelLeaveRequestTable();
  }

  Widget _buildGatePassHubView(HostelState state, HostelNotifier notifier, bool isDark) {
    final passes = state.gatePassesList;
    final total = state.gatePassesPagination['total'] as int? ?? passes.length;
    final page = state.gatePassesPagination['page'] as int? ?? 1;
    final pageSize = state.gatePassesPagination['page_size'] as int? ?? 10;
    final totalPages = state.gatePassesPagination['total_pages'] as int? ?? 1;
    final startIdx = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endIdx = ((page - 1) * pageSize + passes.length).clamp(0, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gate Pass Header & Quick Actions Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 24, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Digital Gate Passes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$total Passes',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time digital entry/exit credentials issued for ${state.selectedAcademicYear}',
                        style: TextStyle(
                          fontSize: 12,
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
                  OutlinedButton.icon(
                    onPressed: () => notifier.loadGatePasses(resetPage: true),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const GatePassDialog(),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                    label: const Text('Open Verification Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Passes Content Body
        if (state.isGatePassesLoading)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Loading issued gate passes...', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else if (passes.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'No Gate Passes Found',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Digital gate passes are automatically generated when leave or outing requests are approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table of passes
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Pass Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Resident Student', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Hostel / Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Type & Destination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Validity Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    ],
                    rows: passes.map((pass) {
                      Color statusColor;
                      switch (pass.status.toUpperCase()) {
                        case 'ACTIVE':
                          statusColor = const Color(0xFF16A34A);
                          break;
                        case 'USED':
                          statusColor = const Color(0xFF2563EB);
                          break;
                        case 'EXPIRED':
                          statusColor = const Color(0xFF64748B);
                          break;
                        case 'CANCELED':
                        case 'REVOKED':
                          statusColor = const Color(0xFFDC2626);
                          break;
                        default:
                          statusColor = const Color(0xFF64748B);
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: pass.passNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied ${pass.passNumber} to clipboard'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pass.passNumber,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  child: Text(
                                    pass.studentName.isNotEmpty ? pass.studentName[0] : 'S',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pass.studentName,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (pass.className != null && pass.className!.isNotEmpty)
                                      Text(
                                        '${pass.className!} ${pass.rollNumber != null ? "• Roll ${pass.rollNumber}" : ""}',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              '${pass.hostelName ?? "Hostel"} (Room ${pass.roomNumber ?? "-"})',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pass.requestType,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  pass.destination.isNotEmpty ? pass.destination : 'Local',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From: ${pass.validFromFormatted ?? "-"}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  'Until: ${pass.validUntilFormatted ?? "-"}',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pass.status,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => HostelGatePassPrintDialog(gatePass: pass),
                                    );
                                  },
                                  icon: const Icon(Icons.print_rounded, size: 13, color: Colors.white),
                                  label: const Text('Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 30),
                                    backgroundColor: const Color(0xFF16A34A),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => GatePassDialog(gatePass: pass),
                                    );
                                  },
                                  icon: const Icon(Icons.badge_rounded, size: 13),
                                  label: const Text('Terminal', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                // Pagination Row
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Showing $startIdx - $endIdx of $total gate passes',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Pagination Buttons « < 1 2 3 > »
                                  IconButton(
                                    icon: const Icon(Icons.first_page_rounded, size: 18),
                                    onPressed: page > 1 ? () => notifier.setGatePassPage(1) : null,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'First Page',
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                                    onPressed: page > 1 ? () => notifier.setGatePassPage(page - 1) : null,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Previous Page',
                                  ),
                                  const SizedBox(width: 8),

                                  // Numbered Pages window around current page
                                  ...(() {
                                    final start = (page - 2).clamp(1, (totalPages - 4).clamp(1, totalPages));
                                    final count = (totalPages - start + 1).clamp(1, 5);
                                    return List.generate(count, (i) {
                                      final p = start + i;
                                      final isCurrent = p == page;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3),
                                        child: InkWell(
                                          onTap: () => notifier.setGatePassPage(p),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: isCurrent
                                                  ? const Color(0xFF2563EB)
                                                  : isDark
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$p',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                                color: isCurrent
                                                    ? Colors.white
                                                    : isDark
                                                        ? Colors.white
                                                        : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    });
                                  })(),

                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                    onPressed: page < totalPages ? () => notifier.setGatePassPage(page + 1) : null,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Next Page',
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.last_page_rounded, size: 18),
                                    onPressed: page < totalPages ? () => notifier.setGatePassPage(totalPages) : null,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Last Page',
                                  ),

                                  const SizedBox(width: 20),

                                  // Rows per page selector
                                  Text(
                                    'Rows per page',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    height: 28,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<int>.fromMenuItems(
                                        value: pageSize,
                                        isDense: true,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        items: const [10, 25, 50, 100].map((s) {
                                          return DropdownMenuItem<int>(
                                            value: s,
                                            child: Text('$s'),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            notifier.setGatePassPageSize(val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
