import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/staff_salary_provider.dart';
import 'dialogs/process_staff_payout_dialog.dart';
import 'dialogs/edit_staff_salary_structure_dialog.dart';
import 'dialogs/request_salary_advance_dialog.dart';
import 'dialogs/change_staff_payout_status_dialog.dart';
import 'dialogs/staff_payslip_dialog.dart';
import 'dialogs/settle_staff_advance_dialog.dart';
import 'dialogs/automated_payroll_dialog.dart';

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

          if (state.isLoading && staff.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
            ),

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
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1080),
                            child: DataTable(
                              headingRowHeight: 44,
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 58,
                              horizontalMargin: 16,
                              columnSpacing: 22,
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
                                  label: _buildSortableHeader('STAFF MEMBER', 'name', state, () => notifier.toggleSort('name')),
                                ),
                                const DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeader('GROSS SALARY', 'gross', state, () => notifier.toggleSort('gross')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('DEDUCTIONS', 'deductions', state, () => notifier.toggleSort('deductions')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('NET PAY', 'net', state, () => notifier.toggleSort('net')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('STATUS', 'status', state, () => notifier.toggleSort('status')),
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
                                                      'role': s.role,
                                                      'payslip_number': s.payslipNumber ?? 'PS--',
                                                      'month_str': state.selectedMonthStr,
                                                      'basic_pay': s.basicPay,
                                                      'hra': s.hra,
                                                      'da': s.da,
                                                      'ta': s.ta,
                                                      'special_allowance': s.specialAllowance,
                                                      'bonus': s.bonus,
                                                      'gross_earnings': s.grossSalary,
                                                      'pf_deduction': s.pfDeduction,
                                                      'tds': s.tds,
                                                      'professional_tax': s.professionalTax,
                                                      'advance_deduction': s.activeAdvanceDeduction,
                                                      'other_deductions': 0.0,
                                                      'total_deductions': s.totalDeductions,
                                                      'net_pay': s.actualNetPay,
                                                      'payment_mode': s.paymentMode,
                                                      'transaction_reference': s.transactionReference,
                                                      'payment_date': s.paymentDate,
                                                      'bank_name': s.bankName,
                                                      'account_number': s.accountNumber,
                                                      'ifsc_code': s.ifscCode,
                                                      'pan_number': s.panNumber,
                                                      'status': s.status,
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
                                                      'role': s.role,
                                                      'payslip_number': s.payslipNumber ?? 'PS--',
                                                      'month_str': state.selectedMonthStr,
                                                      'basic_pay': s.basicPay,
                                                      'hra': s.hra,
                                                      'da': s.da,
                                                      'ta': s.ta,
                                                      'special_allowance': s.specialAllowance,
                                                      'bonus': s.bonus,
                                                      'gross_earnings': s.grossSalary,
                                                      'pf_deduction': s.pfDeduction,
                                                      'tds': s.tds,
                                                      'professional_tax': s.professionalTax,
                                                      'advance_deduction': s.activeAdvanceDeduction,
                                                      'other_deductions': 0.0,
                                                      'total_deductions': s.totalDeductions,
                                                      'net_pay': s.actualNetPay,
                                                      'payment_mode': s.paymentMode,
                                                      'transaction_reference': s.transactionReference,
                                                      'payment_date': s.paymentDate,
                                                      'bank_name': s.bankName,
                                                      'account_number': s.accountNumber,
                                                      'ifsc_code': s.ifscCode,
                                                      'pan_number': s.panNumber,
                                                      'status': s.status,
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

  Widget _buildSortableHeader(String label, String columnKey, StaffSalaryState state, VoidCallback onTap) {
    final isSorted = state.sortColumn == columnKey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (state.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
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

  Widget _buildSortableHeaderGeneric(
    String label,
    String columnKey,
    String currentSortCol,
    bool currentSortAsc, [
    VoidCallback? onTap,
  ]) {
    final isSorted = currentSortCol == columnKey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isSorted ? const Color(0xFF16A34A) : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (currentSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryStructuresCatalog(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    final structures = state.salaryStructures;
    final total = state.structuresTotal;
    final page = state.structuresPage;
    final pageSize = state.structuresPageSize;
    final totalPages = state.structuresTotalPages;
    final startItem = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endItem = total == 0 ? 0 : (startItem + structures.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary Structures Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('$total Configured Structures in Database', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('+ Add Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => const EditStaffSalaryStructureDialog(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh Structures',
                  onPressed: () => notifier.loadSalaryStructures(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (state.isLoading && structures.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),

          // Table
          Expanded(
            child: state.isLoading && structures.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : structures.isEmpty
                    ? Center(
                        child: Text('No salary structures found', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1000),
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
                                  label: _buildSortableHeaderGeneric('STAFF MEMBER', 'name', state.structuresSortColumn, state.structuresSortAscending),
                                  onSort: (_, __) => notifier.toggleStructuresSort('name'),
                                ),
                                const DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('BASIC PAY', 'basic', state.structuresSortColumn, state.structuresSortAscending),
                                  onSort: (_, __) => notifier.toggleStructuresSort('basic'),
                                ),
                                const DataColumn(label: Text('ALLOWANCES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('GROSS SALARY', 'gross', state.structuresSortColumn, state.structuresSortAscending),
                                  onSort: (_, __) => notifier.toggleStructuresSort('gross'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('DEDUCTIONS', 'deductions', state.structuresSortColumn, state.structuresSortAscending),
                                  onSort: (_, __) => notifier.toggleStructuresSort('deductions'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('NET SALARY', 'net', state.structuresSortColumn, state.structuresSortAscending),
                                  onSort: (_, __) => notifier.toggleStructuresSort('net'),
                                ),
                                const DataColumn(label: Text('BANK / DISBURSAL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                              rows: structures.map((s) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFF8B5CF6),
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
                                              Text(s.staffName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                              Text('${s.designation} | ${s.employeeId}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                        child: Text(s.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(Text('₹ ${NumberFormat('#,##,###').format(s.basicPay.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                    DataCell(
                                      Tooltip(
                                        message: 'HRA: ₹${s.hra.toInt()} | DA: ₹${s.da.toInt()} | TA: ₹${s.ta.toInt()}',
                                        child: Text('+ ₹ ${NumberFormat('#,##,###').format((s.hra + s.da + s.ta + s.specialAllowance + s.medicalAllowance).toInt())}', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(Text(s.grossFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                                    DataCell(Text('- ₹ ${NumberFormat('#,##,###').format(s.totalDeductions.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)))),
                                    DataCell(Text(s.netFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)))),
                                    DataCell(
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(s.bankName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          Text(s.accountNumber.isNotEmpty ? s.accountNumber : 'No A/C configured', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                        tooltip: 'Edit Base Pay & Allowances',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (c) => EditStaffSalaryStructureDialog(
                                              initialStructure: s,
                                              staffId: s.staffId,
                                              staffName: s.staffName,
                                              currentBasic: s.basicPay,
                                              currentHra: s.hra,
                                            ),
                                          );
                                        },
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
          const Divider(height: 1),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Rows per page:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: pageSize,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: [10, 25, 50].map((s) => DropdownMenuItem(value: s, child: Text('$s', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setStructuresPageSize(v);
                      },
                    ),
                    const SizedBox(width: 16),
                    Text('Showing $startItem-$endItem of $total structures', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: page > 1 ? () => notifier.setStructuresPage(page - 1) : null,
                    ),
                    Text('$page / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: page < totalPages ? () => notifier.setStructuresPage(page + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipsMasterTable(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    final payslips = state.payslipsList;
    final total = state.payslipsTotal;
    final page = state.payslipsPage;
    final pageSize = state.payslipsPageSize;
    final totalPages = state.payslipsTotalPages;
    final startItem = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endItem = total == 0 ? 0 : (startItem + payslips.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Payslips Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('$total Generated Payslips (${state.selectedMonthStr})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.auto_mode_rounded, size: 18),
                  label: const Text('Automate Payroll Run', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => const AutomatedPayrollDialog(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export Bank File (CSV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    notifier.exportBankDisbursalFile();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading Bank Disbursal File...'), backgroundColor: Color(0xFF2563EB)),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh Payslips',
                  onPressed: () => notifier.loadPayslips(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (state.isLoading && payslips.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),

          // Table
          Expanded(
            child: state.isLoading && payslips.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : payslips.isEmpty
                    ? Center(
                        child: Text('No payslips generated for ${state.selectedMonthStr}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1050),
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
                                  label: _buildSortableHeaderGeneric('PAYSLIP #', 'payslip_number', state.payslipsSortColumn, state.payslipsSortAscending),
                                  onSort: (_, __) => notifier.togglePayslipsSort('payslip_number'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('STAFF MEMBER', 'name', state.payslipsSortColumn, state.payslipsSortAscending),
                                  onSort: (_, __) => notifier.togglePayslipsSort('name'),
                                ),
                                const DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('PERIOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('GROSS', 'gross', state.payslipsSortColumn, state.payslipsSortAscending),
                                  onSort: (_, __) => notifier.togglePayslipsSort('gross'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('DEDUCTIONS', 'deductions', state.payslipsSortColumn, state.payslipsSortAscending),
                                  onSort: (_, __) => notifier.togglePayslipsSort('deductions'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('NET PAY', 'net', state.payslipsSortColumn, state.payslipsSortAscending),
                                  onSort: (_, __) => notifier.togglePayslipsSort('net'),
                                ),
                                const DataColumn(label: Text('MODE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                              rows: payslips.map((p) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(p.payslipNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB))),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFF16A34A),
                                            child: Text(
                                              p.staffName.isNotEmpty ? p.staffName[0].toUpperCase() : 'S',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(p.staffName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                              Text(p.employeeId, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                        child: Text(p.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(Text(p.monthStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                    DataCell(Text(p.grossFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                                    DataCell(Text('- ₹ ${NumberFormat('#,##,###').format(p.totalDeductions.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)))),
                                    DataCell(Text(p.netFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)))),
                                    DataCell(Text(p.paymentMode, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    DataCell(_buildStatusBadge(p.paymentStatus)),
                                    DataCell(
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
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
          const Divider(height: 1),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Rows per page:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: pageSize,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: [10, 25, 50].map((s) => DropdownMenuItem(value: s, child: Text('$s', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setPayslipsPageSize(v);
                      },
                    ),
                    const SizedBox(width: 16),
                    Text('Showing $startItem-$endItem of $total payslips', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: page > 1 ? () => notifier.setPayslipsPage(page - 1) : null,
                    ),
                    Text('$page / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: page < totalPages ? () => notifier.setPayslipsPage(page + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancesMasterTable(BuildContext context, WidgetRef ref, StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    final advances = state.advancesList;
    final total = state.advancesTotal;
    final page = state.advancesPage;
    final pageSize = state.advancesPageSize;
    final totalPages = state.advancesTotalPages;
    final startItem = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endItem = total == 0 ? 0 : (startItem + advances.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.request_quote_rounded, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary Advances & Recovery Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('$total Active Advance Requests', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Request Advance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => const RequestSalaryAdvanceDialog(),
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh Advances',
                  onPressed: () => notifier.loadAdvances(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (state.isLoading && advances.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),

          // Table
          Expanded(
            child: state.isLoading && advances.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : advances.isEmpty
                    ? Center(
                        child: Text('No salary advance records found', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        primary: false,
                        physics: const ClampingScrollPhysics(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1050),
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
                                  label: _buildSortableHeaderGeneric('STAFF MEMBER', 'name', state.advancesSortColumn, state.advancesSortAscending, () => notifier.toggleAdvancesSort('name')),
                                ),
                                const DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('PURPOSE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('ADVANCE AMOUNT', 'amount', state.advancesSortColumn, state.advancesSortAscending, () => notifier.toggleAdvancesSort('amount')),
                                ),
                                const DataColumn(label: Text('REPAID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('OUTSTANDING', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('REPAYMENT PROGRESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                const DataColumn(label: Text('MONTHLY EMI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                                DataColumn(
                                  label: _buildSortableHeaderGeneric('STATUS', 'status', state.advancesSortColumn, state.advancesSortAscending, () => notifier.toggleAdvancesSort('status')),
                                ),
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                              rows: advances.map((a) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFF059669),
                                            child: Text(
                                              a.staffName.isNotEmpty ? a.staffName[0].toUpperCase() : 'S',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(a.staffName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                              Text(a.employeeId, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                        child: Text(a.department, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                    DataCell(Text(a.purposeType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                    DataCell(Text(a.amountFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                                    DataCell(Text(a.amountRepaidFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)))),
                                    DataCell(Text(a.outstandingBalanceFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)))),
                                    DataCell(
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 100,
                                            child: LinearProgressIndicator(
                                              value: (a.progressPct / 100.0).clamp(0.0, 1.0),
                                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              color: a.progressPct >= 100 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                              minHeight: 6,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text('${a.progressPct.toStringAsFixed(0)}% recovered', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text('₹ ${NumberFormat('#,##,###').format(a.monthlyDeduction.toInt())} (${a.repaymentMonths} mo)', style: const TextStyle(fontSize: 12))),
                                    DataCell(_buildStatusBadge(a.status)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (a.status == 'Approved' && a.outstandingBalance > 0)
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF2563EB),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              icon: const Icon(Icons.price_check_rounded, size: 16),
                                              label: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (c) => SettleStaffAdvanceDialog(advance: a),
                                                );
                                              },
                                            ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                                            itemBuilder: (ctx) => [
                                              if (a.status != 'Approved')
                                                const PopupMenuItem(value: 'Approved', child: Text('Approve Advance')),
                                              if (a.status != 'Rejected')
                                                const PopupMenuItem(value: 'Rejected', child: Text('Reject Advance')),
                                              if (a.status != 'Settled')
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
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
          const Divider(height: 1),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Rows per page:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: pageSize,
                      underline: const SizedBox(),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: [10, 25, 50].map((s) => DropdownMenuItem(value: s, child: Text('$s', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setAdvancesPageSize(v);
                      },
                    ),
                    const SizedBox(width: 16),
                    Text('Showing $startItem-$endItem of $total advances', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: page > 1 ? () => notifier.setAdvancesPage(page - 1) : null,
                    ),
                    Text('$page / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: page < totalPages ? () => notifier.setAdvancesPage(page + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
