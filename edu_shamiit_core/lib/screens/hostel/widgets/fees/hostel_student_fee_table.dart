import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../../models/hostel_fee_models.dart';
import 'dialogs/collect_payment_dialog.dart';
import 'dialogs/generate_invoice_dialog.dart';
import 'dialogs/apply_concession_dialog.dart';
import 'dialogs/add_penalty_dialog.dart';

class HostelStudentFeeTable extends ConsumerWidget {
  const HostelStudentFeeTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.feesSubTab == 4) {
      return _buildFeeStructureCatalog(context, ref, state, notifier, isDark);
    }
    if (state.feesSubTab == 5) {
      return _buildInvoicesMasterTable(context, ref, state, notifier, isDark);
    }
    if (state.feesSubTab == 6) {
      return _buildPaymentsMasterTable(context, ref, state, notifier, isDark);
    }
    if (state.feesSubTab == 7) {
      return _buildRefundsMasterTable(context, ref, state, notifier, isDark);
    }

    final students = state.studentFeesRoster;
    final pagination = state.feesPagination;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Content / Loading
          Expanded(
            child: state.isFeesLoading && students.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 12),
                        Text(
                          'Loading student fee records...',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              'No student fee records found matching criteria',
                              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 880),
                              child: DataTable(
                                sortColumnIndex: _getFeesSortColumnIndex(state.feesSortBy),
                                sortAscending: state.feesSortOrder == 'ASC',
                                headingRowColor: WidgetStateProperty.all(
                                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                ),
                                headingRowHeight: 46,
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 58,
                                horizontalMargin: 16,
                                columnSpacing: 18,
                                showCheckboxColumn: true,
                                onSelectAll: (val) {
                                  notifier.selectAllFeeAccounts(val ?? false);
                                },
                                columns: [
                                  _buildDataColumn(context, 'STUDENT', 'student_name', state, notifier),
                                  _buildDataColumn(context, 'ROOM & HOSTEL', 'room_number', state, notifier),
                                  _buildDataColumn(context, 'FEE PLAN', 'plan_name', state, notifier),
                                  _buildDataColumn(context, 'TOTAL BILLED', 'total_billed', state, notifier),
                                  _buildDataColumn(context, 'PAID', 'total_paid', state, notifier),
                                  _buildDataColumn(context, 'BALANCE', 'balance_due', state, notifier),
                                  _buildDataColumn(context, 'STATUS', 'fee_status', state, notifier),
                                  const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                                ],
                                rows: students.map((s) {
                                  final isSelected = state.selectedFeeAccountIds.contains(s.id);
                                  return DataRow(
                                    selected: isSelected,
                                    onSelectChanged: (val) {
                                      notifier.toggleSelectFeeAccount(s.id);
                                    },
                                    cells: [
                                      // 1. Student Name & Roll
                                      DataCell(
                                        InkWell(
                                          onTap: () => notifier.openFeeDrawer(s.studentId),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildAvatar(s.studentName),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    s.studentName,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${s.admissionNumber} • ${s.className}',
                                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // 2. Room & Hostel
                                      DataCell(
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              s.hostelName,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              'Room ${s.roomNumber}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 3. Fee Plan
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            s.planName,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 4. Total Billed
                                      DataCell(
                                        Text(
                                          s.totalBilledFormatted,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),

                                      // 5. Total Paid
                                      DataCell(
                                        Text(
                                          s.totalPaidFormatted,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),

                                      // 6. Balance Due
                                      DataCell(
                                        Text(
                                          s.balanceDueFormatted,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: s.balanceDue > 0
                                                ? (s.feeStatus == 'Overdue' ? const Color(0xFFDC2626) : const Color(0xFFD97706))
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),

                                      // 7. Status Pill
                                      DataCell(_buildStatusBadge(s.feeStatus, isDark)),

                                      // 8. Actions
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // View / 360 Drawer Button
                                            IconButton(
                                              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                              color: const Color(0xFF2563EB),
                                              tooltip: 'View 360° Profile',
                                              onPressed: () => notifier.openFeeDrawer(s.studentId),
                                            ),
                                            // Collect Payment Button
                                            IconButton(
                                              icon: const Icon(Icons.payment_rounded, size: 18),
                                              color: const Color(0xFF16A34A),
                                              tooltip: 'Collect Fee Payment',
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => CollectPaymentDialog(student: s),
                                                );
                                              },
                                            ),
                                            // More options popup
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              onSelected: (val) {
                                                if (val == 'invoice') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => GenerateInvoiceDialog(student: s),
                                                  );
                                                } else if (val == 'concession') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => ApplyConcessionDialog(student: s),
                                                  );
                                                } else if (val == 'penalty') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AddPenaltyDialog(student: s),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'invoice',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF2563EB)),
                                                      SizedBox(width: 8),
                                                      Text('Generate Invoice', style: TextStyle(fontSize: 12.5)),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'concession',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.loyalty_rounded, size: 16, color: Color(0xFF0D9488)),
                                                      SizedBox(width: 8),
                                                      Text('Apply Concession', style: TextStyle(fontSize: 12.5)),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'penalty',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                                                      SizedBox(width: 8),
                                                      Text('Assess Penalty / Fine', style: TextStyle(fontSize: 12.5)),
                                                    ],
                                                  ),
                                                ),
                                              ],
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

          // Bulk actions bar if selection exists
          if (state.selectedFeeAccountIds.isNotEmpty)
            _buildBulkActionsBar(context, ref, state, notifier, isDark),

          // Pagination Footer matching screenshot
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, footerConstraints) {
                final isNarrow = footerConstraints.maxWidth < 500;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Showing ${students.isEmpty ? 0 : (pagination.page - 1) * pagination.pageSize + 1}-${((pagination.page - 1) * pagination.pageSize + students.length)} of ${pagination.total}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page ${pagination.page} of ${pagination.totalPages > 0 ? pagination.totalPages : 1}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: pagination.page > 1
                                    ? () => notifier.loadStudentFees(page: pagination.page - 1)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: pagination.page < pagination.totalPages
                                    ? () => notifier.loadStudentFees(page: pagination.page + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${students.isEmpty ? 0 : (pagination.page - 1) * pagination.pageSize + 1} to ${((pagination.page - 1) * pagination.pageSize + students.length)} of ${pagination.total} students',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page ${pagination.page} of ${pagination.totalPages > 0 ? pagination.totalPages : 1}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: pagination.page > 1
                              ? () => notifier.loadStudentFees(page: pagination.page - 1)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: pagination.page < pagination.totalPages
                              ? () => notifier.loadStudentFees(page: pagination.page + 1)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Rows:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: AppSearchableDropdown<int>.fromMenuItems(
                              value: [10, 25, 50, 100].contains(state.feesPageSize)
                                  ? state.feesPageSize
                                  : 10,
                              isDense: true,
                              isExpanded: false,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              items: const [10, 25, 50, 100]
                                  .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) notifier.setFeesPageSize(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildDataColumn(
    BuildContext context,
    String label,
    String sortKey,
    HostelState state,
    HostelNotifier notifier,
  ) {
    final isCurrent = state.feesSortBy == sortKey;
    final isAsc = state.feesSortOrder == 'ASC';

    return DataColumn(
      onSort: (colIdx, asc) {
        notifier.setFeesSort(sortKey, asc ? 'ASC' : 'DESC');
      },
      label: InkWell(
        onTap: () {
          final nextOrder = isCurrent && isAsc ? 'DESC' : 'ASC';
          notifier.setFeesSort(sortKey, nextOrder);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Icon(
              isCurrent ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
              size: 14,
              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  int? _getFeesSortColumnIndex(String? sortBy) {
    switch (sortBy) {
      case 'student_name':
        return 0;
      case 'room_number':
        return 1;
      case 'plan_name':
        return 2;
      case 'total_billed':
        return 3;
      case 'total_paid':
        return 4;
      case 'balance_due':
        return 5;
      case 'fee_status':
        return 6;
      default:
        return null;
    }
  }

  Widget _buildAvatar(String name) {
    final initials = name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : 'S',
          style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color text;
    IconData icon;

    switch (status) {
      case 'Over Paid':
      case 'Overpaid':
      case 'OVERPAID':
        bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        icon = Icons.verified_rounded;
        break;
      case 'Paid':
        bg = isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        icon = Icons.check_circle_rounded;
        break;
      case 'Partial':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        icon = Icons.access_time_rounded;
        break;
      case 'Overdue':
        bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        icon = Icons.error_outline_rounded;
        break;
      default:
        bg = isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF1F5F9);
        text = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionsBar(
    BuildContext context,
    WidgetRef ref,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final count = state.selectedFeeAccountIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count selected',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: () async {
              await notifier.sendFeeReminders({
                'academic_year': state.selectedAcademicYear,
                'reminder_type': 'OVERDUE',
                'channel': 'EMAIL',
                'student_ids': state.selectedFeeAccountIds.toList(),
              });
            },
            icon: const Icon(Icons.send_rounded, size: 14),
            label: const Text('Send Reminders', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => notifier.exportFeesCsv(onlySelected: true),
            icon: const Icon(Icons.download_rounded, size: 14),
            label: const Text('Export Selected', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => notifier.selectAllFeeAccounts(false),
            child: const Text('Deselect All', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStructureCatalog(
    BuildContext context,
    WidgetRef ref,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final plans = state.feePlans;
    final plansTotal = state.feePlansPagination['total_records'] as int? ?? plans.length;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hostel Fee Structures & Plans',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$plansTotal configured plans for academic year ${state.selectedAcademicYear}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreatePlanDialog(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Create Fee Structure', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: plans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          'No fee structures found',
                          style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 900),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            ),
                            headingRowHeight: 46,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 64,
                            horizontalMargin: 20,
                            columnSpacing: 20,
                            columns: [
                              _buildGenericSortableColumn('PLAN CODE', 'code', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              _buildGenericSortableColumn('PLAN NAME', 'name', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              _buildGenericSortableColumn('ROOM TYPE', 'room_type', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              _buildGenericSortableColumn('BILLING CYCLE', 'billing_cycle', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              _buildGenericSortableColumn('ANNUAL FEE', 'total_annual_amount', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              const DataColumn(label: Text('FEE HEADS BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                              _buildGenericSortableColumn('STATUS', 'status', state.feePlansSortBy, state.feePlansSortOrder, notifier.setFeePlansSort, isDark: isDark, uppercaseHeader: true),
                              const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                            ],
                            rows: plans.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.code,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (p.description != null && p.description!.isNotEmpty)
                                          Text(
                                            p.description!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${p.roomType} (${p.roomCategory})',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.billingCycle,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      p.formattedTotal,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: p.heads.map((h) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Text(
                                            '${h.feeHeadName}: ₹${h.amount.toInt()}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        p.status,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                                      color: const Color(0xFF2563EB),
                                      tooltip: 'View Plan Details',
                                      onPressed: () => _showPlanDetailsModal(context, p, isDark),
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
          _buildSubTabPaginationFooter(
            pagination: state.feePlansPagination,
            currentCount: plans.length,
            pageSize: state.feePlansPageSize,
            itemLabel: 'plans',
            onPageChanged: notifier.setFeePlansPage,
            onPageSizeChanged: notifier.setFeePlansPageSize,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateFeeStructureDialog(ref: ref),
    );
  }

  void _showPlanDetailsModal(BuildContext context, HostelFeePlanModel plan, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(plan.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan Code: ${plan.code}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Room Type: ${plan.roomType} (${plan.roomCategory})'),
              Text('Billing: ${plan.billingCycle} • Total: ${plan.formattedTotal}'),
              const SizedBox(height: 12),
              const Text('Fee Heads Breakdown:', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...plan.heads.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('• ${h.feeHeadName} (${h.feeHeadCode})', style: const TextStyle(fontSize: 13)),
                        Text('₹ ${h.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INVOICES MASTER TABLE (Subtab 5)
  // ==========================================================================

  Widget _buildInvoicesMasterTable(
    BuildContext context,
    WidgetRef ref,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final invoices = state.invoicesList;
    final invoicesTotal = state.invoicesPagination['total_records'] as int? ?? invoices.length;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hostel Fee Invoices ($invoicesTotal)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'All billed term invoices and fee schedules for ${state.selectedAcademicYear}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const GenerateInvoiceDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Generate Invoice', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          Expanded(
            child: invoices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No invoices recorded for this period', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 800),
                        child: DataTable(
                          columns: [
                            _buildGenericSortableColumn('Invoice #', 'invoice_number', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Student', 'student_name', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Billing Period', 'billing_period', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Total', 'net_amount', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Paid', 'paid_amount', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Balance', 'balance_amount', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                            _buildGenericSortableColumn('Status', 'status', state.invoicesSortBy, state.invoicesSortOrder, notifier.setInvoicesSort, isDark: isDark),
                          ],
                          rows: invoices.map((inv) {
                            final isPaid = inv.status.toUpperCase() == 'PAID';
                            return DataRow(
                              cells: [
                                DataCell(Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
                                DataCell(Text(inv.studentName ?? 'Student')),
                                DataCell(Text(inv.billingPeriod)),
                                DataCell(Text('₹ ${inv.netAmount.toInt()}')),
                                DataCell(Text('₹ ${inv.paidAmount.toInt()}')),
                                DataCell(Text('₹ ${inv.balanceAmount.toInt()}', style: TextStyle(color: inv.balanceAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      inv.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                      ),
                                    ),
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
          _buildSubTabPaginationFooter(
            pagination: state.invoicesPagination,
            currentCount: invoices.length,
            pageSize: state.invoicesPageSize,
            itemLabel: 'invoices',
            onPageChanged: notifier.setInvoicesPage,
            onPageSizeChanged: notifier.setInvoicesPageSize,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PAYMENTS MASTER TABLE (Subtab 6)
  // ==========================================================================

  Widget _buildPaymentsMasterTable(
    BuildContext context,
    WidgetRef ref,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final payments = state.paymentsList;
    final paymentsTotal = state.paymentsPagination['total_records'] as int? ?? payments.length;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Transactions ($paymentsTotal)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Real-time collection log and verified receipts',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const CollectPaymentDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Record Payment', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          Expanded(
            child: payments.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No payment transactions recorded yet', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 750),
                        child: DataTable(
                          columns: [
                            _buildGenericSortableColumn('Receipt #', 'receipt_number', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                            _buildGenericSortableColumn('Student', 'student_name', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                            _buildGenericSortableColumn('Amount', 'amount', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                            _buildGenericSortableColumn('Method', 'payment_method', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                            _buildGenericSortableColumn('Date', 'payment_date', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                            _buildGenericSortableColumn('Status', 'status', state.paymentsSortBy, state.paymentsSortOrder, notifier.setPaymentsSort, isDark: isDark),
                          ],
                          rows: payments.map((pmt) {
                            return DataRow(
                              cells: [
                                DataCell(Text(pmt.receiptNumber, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
                                DataCell(Text(pmt.studentName ?? 'Student')),
                                DataCell(Text(pmt.amountFormatted, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF16A34A)))),
                                DataCell(Text(pmt.paymentMethod)),
                                DataCell(Text(pmt.paymentDate ?? 'Recent')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      pmt.status,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                                    ),
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
          _buildSubTabPaginationFooter(
            pagination: state.paymentsPagination,
            currentCount: payments.length,
            pageSize: state.paymentsPageSize,
            itemLabel: 'payments',
            onPageChanged: notifier.setPaymentsPage,
            onPageSizeChanged: notifier.setPaymentsPageSize,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // REFUNDS MASTER TABLE (Subtab 7)
  // ==========================================================================

  Widget _buildRefundsMasterTable(
    BuildContext context,
    WidgetRef ref,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final refunds = state.refundsList;
    final refundsTotal = state.refundsPagination['total_records'] as int? ?? refunds.length;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.currency_exchange_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deposit Refunds & Settlements ($refundsTotal)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Security deposit clearance upon checkout or bed release',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          Expanded(
            child: refunds.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No pending refund requests', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 750),
                        child: DataTable(
                          columns: [
                            _buildGenericSortableColumn('Student', 'student_name', state.refundsSortBy, state.refundsSortOrder, notifier.setRefundsSort, isDark: isDark),
                            _buildGenericSortableColumn('Amount', 'amount', state.refundsSortBy, state.refundsSortOrder, notifier.setRefundsSort, isDark: isDark),
                            _buildGenericSortableColumn('Reason', 'reason', state.refundsSortBy, state.refundsSortOrder, notifier.setRefundsSort, isDark: isDark),
                            _buildGenericSortableColumn('Requested Date', 'created_at', state.refundsSortBy, state.refundsSortOrder, notifier.setRefundsSort, isDark: isDark),
                            _buildGenericSortableColumn('Status', 'status', state.refundsSortBy, state.refundsSortOrder, notifier.setRefundsSort, isDark: isDark),
                            const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                          ],
                          rows: refunds.map((rf) {
                            final status = rf['status']?.toString() ?? rf['refund_status']?.toString() ?? 'PENDING';
                            final isPending = status.toUpperCase() == 'PENDING';
                            final rfId = rf['id']?.toString() ?? '';
                            return DataRow(
                              cells: [
                                DataCell(Text(rf['student_name']?.toString() ?? 'Resident')),
                                DataCell(Text('₹ ${(rf['amount'] as num?)?.toInt() ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(rf['reason']?.toString() ?? 'Caution Deposit Refund')),
                                DataCell(Text(rf['created_at']?.toString().split('T')[0] ?? 'Recent')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isPending ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  isPending
                                      ? TextButton(
                                          onPressed: () async {
                                            await notifier.approveRefund(rfId, {'status': 'APPROVED'});
                                            notifier.showSuccess('Refund request approved');
                                          },
                                          child: const Text('Approve'),
                                        )
                                      : const Text('Settled', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          _buildSubTabPaginationFooter(
            pagination: state.refundsPagination,
            currentCount: refunds.length,
            pageSize: state.refundsPageSize,
            itemLabel: 'refunds',
            onPageChanged: notifier.setRefundsPage,
            onPageSizeChanged: notifier.setRefundsPageSize,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  DataColumn _buildGenericSortableColumn(
    String label,
    String sortKey,
    String? currentSortBy,
    String currentSortOrder,
    void Function(String key, String order) onSort, {
    required bool isDark,
    bool uppercaseHeader = false,
  }) {
    final isCurrent = currentSortBy == sortKey;
    final isAsc = currentSortOrder.toUpperCase() == 'ASC';
    return DataColumn(
      onSort: (_, asc) => onSort(sortKey, asc ? 'ASC' : 'DESC'),
      label: InkWell(
        onTap: () => onSort(sortKey, isCurrent && isAsc ? 'DESC' : 'ASC'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: uppercaseHeader
                  ? TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                    )
                  : TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                    ),
            ),
            const SizedBox(width: 4),
            Icon(
              isCurrent
                  ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabPaginationFooter({
    required Map<String, dynamic> pagination,
    required int currentCount,
    required int pageSize,
    required String itemLabel,
    required void Function(int page) onPageChanged,
    required void Function(int pageSize) onPageSizeChanged,
    required bool isDark,
  }) {
    final page = pagination['page'] as int? ?? 1;
    final effectiveSize = pagination['page_size'] as int? ?? pageSize;
    final total = pagination['total_records'] as int? ?? currentCount;
    final totalPages = (pagination['total_pages'] as int? ?? 1).clamp(1, 999999);
    final start = total == 0 ? 0 : (page - 1) * effectiveSize + 1;
    final end = (page * effectiveSize) > total ? total : (page * effectiveSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Showing $start-$end of $total $itemLabel',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page $page of $totalPages',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Rows:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<int>.fromMenuItems(
                        value: [10, 25, 50, 100].contains(pageSize) ? pageSize : 10,
                        isDense: true,
                        isExpanded: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: const [10, 25, 50, 100]
                            .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) onPageSizeChanged(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreateFeeStructureDialog extends StatefulWidget {
  final WidgetRef ref;
  const _CreateFeeStructureDialog({required this.ref});

  @override
  State<_CreateFeeStructureDialog> createState() => _CreateFeeStructureDialogState();
}

class _CreateFeeStructureDialogState extends State<_CreateFeeStructureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _amountController = TextEditingController(text: '36000');
  final _descController = TextEditingController();
  String _roomType = 'Standard';
  String _category = 'Non-AC';
  String _billingCycle = 'MONTHLY';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final amt = double.tryParse(_amountController.text.trim()) ?? 36000.0;
    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'room_type': _roomType,
      'room_category': _category,
      'billing_cycle': _billingCycle,
      'total_annual_amount': amt,
      'total_cycle_amount': amt / 12,
      'description': _descController.text.trim(),
      'heads': [
        {'fee_head_code': 'ROOM_RENT', 'fee_head_name': 'Room Rent', 'amount': amt * 0.6, 'charge_type': 'RECURRING', 'frequency': 'MONTHLY', 'is_mandatory': true},
        {'fee_head_code': 'MESS_FEE', 'fee_head_name': 'Mess Fee', 'amount': amt * 0.3, 'charge_type': 'RECURRING', 'frequency': 'MONTHLY', 'is_mandatory': true},
        {'fee_head_code': 'MAINTENANCE', 'fee_head_name': 'Maintenance', 'amount': amt * 0.1, 'charge_type': 'RECURRING', 'frequency': 'MONTHLY', 'is_mandatory': true},
      ],
    };

    final ok = await widget.ref.read(hostelProvider.notifier).createFeeStructure(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Fee Structure', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Plan Name *', hintText: 'e.g. Executive Single AC'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Plan name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Plan Code *', hintText: 'e.g. EXEC-AC-1'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Plan code is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _roomType,
                        decoration: const InputDecoration(labelText: 'Room Type'),
                        items: ['Standard', 'Deluxe', 'Premium', 'Single', 'Sharing']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _roomType = v ?? 'Standard'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: ['Non-AC', 'AC']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v ?? 'Non-AC'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _billingCycle,
                        decoration: const InputDecoration(labelText: 'Billing Cycle'),
                        items: ['MONTHLY', 'QUARTERLY', 'ANNUALLY']
                            .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _billingCycle = v ?? 'MONTHLY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Annual Fee (₹) *'),
                        validator: (v) {
                          final n = double.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Invalid fee amount';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Plan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
