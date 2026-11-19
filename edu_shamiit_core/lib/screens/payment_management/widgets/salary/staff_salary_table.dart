import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/staff_salary_provider.dart';
import 'dialogs/process_staff_payout_dialog.dart';
import 'dialogs/edit_staff_salary_structure_dialog.dart';
import 'dialogs/request_salary_advance_dialog.dart';
import 'dialogs/change_staff_payout_status_dialog.dart';
import 'dialogs/staff_payslip_dialog.dart';

class StaffSalaryTable extends ConsumerWidget {
  const StaffSalaryTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.subTab == 4) {
      return _buildSalaryStructuresCatalog(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 5) {
      return _buildPayslipsMasterTable(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 6) {
      return _buildAdvancesMasterTable(context, ref, state, notifier, isDark);
    }

    final staff = state.staffRoster;
    final allSelected = staff.isNotEmpty && state.selectedStaffIds.length == staff.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Floating Multi-Selection Action Toolbar
          if (state.selectedStaffIds.isNotEmpty)
            _buildMultiSelectionBar(context, state, notifier, isDark),

          Expanded(
            child: state.isLoading && staff.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : staff.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No staff salary records found',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 920),
                            child: DataTable(
                              headingRowHeight: 44,
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 58,
                              horizontalMargin: 16,
                              columnSpacing: 18,
                              headingRowColor: WidgetStateProperty.all(
                                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              ),
                              columns: [
                                DataColumn(
                                  label: Checkbox(
                                    value: allSelected,
                                    onChanged: (v) => notifier.toggleSelectAll(v ?? false),
                                  ),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('STAFF MEMBER', 'name', state),
                                  onSort: (_, __) => notifier.toggleSort('name'),
                                ),
                                const DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeader('GROSS SALARY', 'gross', state),
                                  onSort: (_, __) => notifier.toggleSort('gross'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('DEDUCTIONS', 'deductions', state),
                                  onSort: (_, __) => notifier.toggleSort('deductions'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('NET PAY', 'net', state),
                                  onSort: (_, __) => notifier.toggleSort('net'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('STATUS', 'status', state),
                                  onSort: (_, __) => notifier.toggleSort('status'),
                                ),
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                              rows: staff.map((s) {
                                final isRowSelected = state.selectedStaffIds.contains(s.staffId);
                                final isDrawerActive = state.isDrawerOpen &&
                                    state.selectedStaffDetail != null &&
                                    (state.selectedStaffDetail!['profile']?['id'] == s.staffId);

                                return DataRow(
                                  selected: isRowSelected,
                                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (isDrawerActive) {
                                      return const Color(0xFF16A34A).withValues(alpha: 0.12);
                                    }
                                    return null;
                                  }),
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: isRowSelected,
                                        onChanged: (_) => notifier.toggleStaffSelection(s.staffId),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: () => notifier.openStaffDrawer(s.staffId),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF16A34A),
                                              child: Text(
                                                s.staffName.isNotEmpty ? s.staffName[0].toUpperCase() : 'S',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  s.staffName,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  '${s.designation} | ${s.employeeId}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(s.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(
                                      Text(s.grossSalaryFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ),
                                    DataCell(
                                      Text('- ${s.totalDeductionsFormatted}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                                    ),
                                    DataCell(
                                      Text(
                                        s.netSalaryFormatted,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => ChangeStaffPayoutStatusDialog(
                                              staffId: s.staffId,
                                              staffName: s.staffName,
                                              currentStatus: s.status,
                                              payoutId: s.payoutId,
                                              currentPaymentMode: s.paymentMode,
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Tooltip(
                                          message: 'Click to Change Status & Approvals',
                                          child: _buildStatusBadge(s.status),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF2563EB)),
                                            tooltip: 'View 360 Salary Drawer',
                                            onPressed: () => notifier.openStaffDrawer(s.staffId),
                                          ),
                                          if (s.status == 'Paid')
                                            IconButton(
                                              icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF16A34A)),
                                              tooltip: 'View & Print Payslip',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => StaffPayslipDialog(
                                                    payslip: {
                                                      'staff_name': s.staffName,
                                                      'employee_id': s.employeeId,
                                                      'designation': s.designation,
                                                      'department': s.department,
                                                      'payslip_number': s.payslipNumber ?? 'PS-${state.selectedMonthStr}-${s.employeeId}',
                                                      'month_str': state.selectedMonthStr,
                                                      'basic_pay': s.basicPay,
                                                      'hra': s.hra,
                                                      'gross_earnings': s.grossSalary,
                                                      'total_deductions': s.totalDeductions,
                                                      'net_pay': s.actualNetPay,
                                                      'payment_mode': s.paymentMode,
                                                      'transaction_reference': s.transactionReference,
                                                      'payment_date': s.paymentDate,
                                                      'bank_name': s.bankName,
                                                      'account_number': s.accountNumber,
                                                    },
                                                  ),
                                                );
                                              },
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF16A34A)),
                                              tooltip: 'Send Money / Disburse',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => ProcessStaffPayoutDialog(preselectedStaffId: s.staffId),
                                                );
                                              },
                                            ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'status', child: Text('Change Status & Approvals', style: TextStyle(fontSize: 12))),
                                              const PopupMenuItem(value: 'payout', child: Text('Send Money / Disburse', style: TextStyle(fontSize: 12))),
                                              if (s.status == 'Paid')
                                                const PopupMenuItem(value: 'payslip', child: Text('View / Print Payslip', style: TextStyle(fontSize: 12))),
                                              const PopupMenuItem(value: 'structure', child: Text('Edit Salary Structure', style: TextStyle(fontSize: 12))),
                                              const PopupMenuItem(value: 'advance', child: Text('Request Salary Advance', style: TextStyle(fontSize: 12))),
                                            ],
                                            onSelected: (val) {
                                              if (val == 'status') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => ChangeStaffPayoutStatusDialog(
                                                    staffId: s.staffId,
                                                    staffName: s.staffName,
                                                    currentStatus: s.status,
                                                    payoutId: s.payoutId,
                                                    currentPaymentMode: s.paymentMode,
                                                  ),
                                                );
                                              } else if (val == 'payout') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => ProcessStaffPayoutDialog(preselectedStaffId: s.staffId),
                                                );
                                              } else if (val == 'payslip') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => StaffPayslipDialog(
                                                    payslip: {
                                                      'staff_name': s.staffName,
                                                      'employee_id': s.employeeId,
                                                      'designation': s.designation,
                                                      'department': s.department,
                                                      'payslip_number': s.payslipNumber ?? 'PS-${state.selectedMonthStr}-${s.employeeId}',
                                                      'month_str': state.selectedMonthStr,
                                                      'basic_pay': s.basicPay,
                                                      'hra': s.hra,
                                                      'gross_earnings': s.grossSalary,
                                                      'total_deductions': s.totalDeductions,
                                                      'net_pay': s.actualNetPay,
                                                      'payment_mode': s.paymentMode,
                                                      'transaction_reference': s.transactionReference,
                                                      'payment_date': s.paymentDate,
                                                      'bank_name': s.bankName,
                                                      'account_number': s.accountNumber,
                                                    },
                                                  ),
                                                );
                                              } else if (val == 'structure') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => EditStaffSalaryStructureDialog(
                                                    staffId: s.staffId,
                                                    staffName: s.staffName,
                                                    currentBasic: s.basicPay,
                                                    currentHra: s.hra,
                                                  ),
                                                );
                                              } else if (val == 'advance') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => RequestSalaryAdvanceDialog(
                                                    staffId: s.staffId,
                                                    staffName: s.staffName,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),

          // 3. Premium Pagination Footer with Page Size & Numbered Controls
          _buildPaginationFooter(state, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String label, String columnKey, StaffSalaryState state) {
    final isSorted = state.sortColumn == columnKey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 4),
        Icon(
          isSorted
              ? (state.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
              : Icons.unfold_more_rounded,
          size: 14,
          color: isSorted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
        ),
      ],
    );
  }

  Widget _buildMultiSelectionBar(BuildContext context, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text(
              '${state.selectedStaffIds.length} staff member${state.selectedStaffIds.length > 1 ? "s" : ""} selected',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF064E3B),
              ),
            ),
            const SizedBox(width: 16),
            // Disburse Selected
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Disburse Selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Disburse Salaries'),
                    content: Text('Disburse salaries and generate payslips for ${state.selectedStaffIds.length} selected staff members for ${state.selectedMonthStr}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirm Disburse'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final ok = await notifier.executeBulkAction('disburse');
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salaries disbursed successfully for selected staff')),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            // Approve Payouts
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Approve Payouts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final ok = await notifier.executeBulkAction('approve');
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payouts approved for selected staff members')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            // Put On Hold
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              icon: const Icon(Icons.pause_circle_outline, size: 16),
              label: const Text('Put On Hold', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Put Salaries On Hold'),
                    content: Text('Put payroll on hold for ${state.selectedStaffIds.length} selected staff members?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Put On Hold'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.executeBulkAction('hold');
                }
              },
            ),
            const SizedBox(width: 8),
            // Clear selection
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear selection',
              onPressed: () => notifier.clearSelection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final startItem = state.totalItems == 0 ? 0 : (state.currentPage - 1) * state.pageSize + 1;
          final endItem = (state.currentPage * state.pageSize).clamp(0, state.totalItems);

          final pageSizeDropdown = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: state.pageSize,
                underline: const SizedBox.shrink(),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: const [10, 25, 50, 100].map((s) => DropdownMenuItem(value: s, child: Text('$s'))).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setPageSize(val);
                },
              ),
            ],
          );

          final itemsCountText = Text(
            'Showing $startItem-$endItem of ${state.totalItems}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          );

          final paginationButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                onPressed: state.currentPage > 1 ? () => notifier.setPage(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
              ),
              ..._buildPageNumbers(state.currentPage, state.totalPages, (p) => notifier.setPage(p), isDark),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.currentPage + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.totalPages) : null,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    pageSizeDropdown,
                    itemsCountText,
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: paginationButtons,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  pageSizeDropdown,
                  const SizedBox(width: 16),
                  itemsCountText,
                ],
              ),
              paginationButtons,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageNumbers(int current, int total, Function(int) onSelect, bool isDark) {
    if (total <= 1) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(6)),
          child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        )
      ];
    }

    final widgets = <Widget>[];
    final start = (current - 2).clamp(1, total);
    final end = (current + 2).clamp(1, total);

    if (start > 1) {
      widgets.add(InkWell(
        onTap: () => onSelect(1),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text('1', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
        ),
      ));
      if (start > 2) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('..', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ));
      }
    }

    for (int p = start; p <= end; p++) {
      final isSelected = p == current;
      widgets.add(
        InkWell(
          onTap: () => onSelect(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      );
    }

    if (end < total) {
      if (end < total - 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('..', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ));
      }
      widgets.add(InkWell(
        onTap: () => onSelect(total),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Text('$total', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
        ),
      ));
    }

    return widgets;
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Approved':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        break;
      case 'On Hold':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'Processing':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF9333EA);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _buildSalaryStructuresCatalog(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Staff Salary Structures Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('${state.salaryStructures.length} Configured Structures', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.salaryStructures.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final s = state.salaryStructures[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: Text('${s.staffName} (${s.designation})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('Basic: ₹ ${s.basicPay.toInt()} | HRA: ₹ ${s.hra.toInt()} | Bank: ${s.bankName}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.netFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF16A34A))),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                        tooltip: 'Edit Base Pay & Allowances',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (c) => EditStaffSalaryStructureDialog(
                              staffId: s.staffId,
                              staffName: s.staffName,
                              currentBasic: s.basicPay,
                              currentHra: s.hra,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipsMasterTable(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Payslips Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('${state.payslipsList.length} Generated Payslips', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.payslipsList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final p = state.payslipsList[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFF16A34A)),
                  ),
                  title: Text('${p.payslipNumber} - ${p.staffName} (${p.employeeId})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('Period: ${p.monthStr} | Disbursed via: ${p.paymentMode}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.netFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF16A34A))),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF2563EB)),
                        tooltip: 'View & Print Payslip',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (c) => StaffPayslipDialog(
                              payslip: p.rawJson.isNotEmpty ? p.rawJson : {
                                'staff_name': p.staffName,
                                'employee_id': p.employeeId,
                                'designation': p.designation,
                                'department': p.department,
                                'role': p.role,
                                'payslip_number': p.payslipNumber,
                                'month_str': p.monthStr,
                                'basic_pay': p.basicPay,
                                'hra': p.hra,
                                'da': p.da,
                                'ta': p.ta,
                                'special_allowance': p.specialAllowance,
                                'bonus': p.bonus,
                                'gross_earnings': p.grossEarnings,
                                'pf_deduction': p.pfDeduction,
                                'tds': p.tds,
                                'professional_tax': p.professionalTax,
                                'advance_deduction': p.advanceDeduction,
                                'other_deductions': p.otherDeductions,
                                'total_deductions': p.totalDeductions,
                                'net_pay': p.netPay,
                                'payment_mode': p.paymentMode,
                                'transaction_reference': p.transactionReference,
                                'bank_name': p.bankName,
                                'account_number': p.accountNumber,
                                'ifsc_code': p.ifscCode,
                                'pan_number': p.panNumber,
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesMasterTable(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Salary Advance Disbursals & Recovery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('${state.advancesList.length} Active Advances', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.advancesList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final a = state.advancesList[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.request_quote_rounded, color: Color(0xFF059669)),
                  ),
                  title: Text('${a.staffName} (${a.department})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${a.purposeType} | ${a.repaymentMonths} months EMI (₹ ${a.monthlyDeduction}/mo) | Status: ${a.status}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(a.amountFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF059669))),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'Approved', child: Text('Approve Advance')),
                          const PopupMenuItem(value: 'Rejected', child: Text('Reject Advance')),
                          const PopupMenuItem(value: 'Settled', child: Text('Mark as Settled')),
                        ],
                        onSelected: (newStatus) async {
                          final ok = await notifier.updateAdvanceStatus(a.id, newStatus);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Advance marked as $newStatus'), backgroundColor: const Color(0xFF16A34A)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
