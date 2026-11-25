import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';
import '../../models/student_fee_models.dart';
import '../../providers/student_fee_provider.dart';
import '../../services/payment_management_api_service.dart';
import 'dialogs/collect_student_payment_dialog.dart';
import 'dialogs/generate_student_invoice_dialog.dart';
import 'dialogs/apply_student_concession_dialog.dart';
import 'dialogs/add_student_penalty_dialog.dart';
import 'dialogs/student_fee_receipt_dialog.dart';
import 'dialogs/edit_student_fee_structure_dialog.dart';
import 'dialogs/clone_student_fee_structure_dialog.dart';
import 'dialogs/refund_student_fee_dialog.dart';

class StudentFeeTable extends ConsumerStatefulWidget {
  const StudentFeeTable({super.key});

  @override
  ConsumerState<StudentFeeTable> createState() => _StudentFeeTableState();
}

class _StudentFeeTableState extends ConsumerState<StudentFeeTable> {
  // Fee Structure Grid state
  final TextEditingController _feeSearchController = TextEditingController();
  String _feeClassFilter = 'All Classes';
  String _feeSectionFilter = 'All Sections';
  String _feeFrequencyFilter = 'All Frequencies';
  int _feePage = 1;
  final int _feePageSize = 10;

  // Invoices Grid state
  final TextEditingController _invoiceSearchController = TextEditingController();
  String _invoiceStatusFilter = 'All Statuses';
  String _invoiceClassFilter = 'All Classes';
  int _invoicePage = 1;
  final int _invoicePageSize = 10;

  // Payments Grid state
  final TextEditingController _paymentSearchController = TextEditingController();
  String _paymentModeFilter = 'All Modes';
  int _paymentPage = 1;
  final int _paymentPageSize = 10;

  @override
  void dispose() {
    _feeSearchController.dispose();
    _invoiceSearchController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.subTab == 6) {
      return _buildFeeStructureCatalog(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 7) {
      return _buildInvoicesMasterTable(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 8) {
      return _buildPaymentsMasterTable(context, ref, state, notifier, isDark);
    }

    final students = state.studentFeesRoster;
    final allSelected = students.isNotEmpty && state.selectedStudentIds.length == students.length;

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
          if (state.selectedStudentIds.isNotEmpty)
            _buildMultiSelectionBar(context, state, notifier, isDark),

          if (state.isLoading && students.isNotEmpty)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),

          // 2. Data Table with horizontal and vertical scrolling
          Expanded(
            child: state.isLoading && students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No student fee records found',
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
                                  label: _buildSortableHeader('STUDENT', 'name', state, () => notifier.toggleSort('name')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('TOTAL BILLED', 'billed', state, () => notifier.toggleSort('billed')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('PAID', 'paid', state, () => notifier.toggleSort('paid')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('DUE / ADVANCE', 'balance', state, () => notifier.toggleSort('balance')),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('STATUS', 'status', state, () => notifier.toggleSort('status')),
                                ),
                                const DataColumn(
                                  label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                ),
                              ],
                              rows: students.map((s) {
                                final isRowSelected = state.selectedStudentIds.contains(s.studentId);
                                final isDrawerActive = state.isDrawerOpen &&
                                    state.selectedStudentDetail != null &&
                                    (state.selectedStudentDetail!['profile']?['id'] == s.studentId);

                                return DataRow(
                                  selected: isRowSelected,
                                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (isDrawerActive) {
                                      return const Color(0xFF2563EB).withValues(alpha: 0.12);
                                    }
                                    if (isRowSelected) {
                                      return const Color(0xFF2563EB).withValues(alpha: 0.08);
                                    }
                                    return null;
                                  }),
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: isRowSelected,
                                        onChanged: (_) => notifier.toggleStudentSelection(s.studentId),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: () => notifier.openStudentDrawer(s.studentId),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF2563EB),
                                              child: Text(
                                                s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : 'S',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      s.studentName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    if (s.admissionNumber.isNotEmpty) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          s.admissionNumber,
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  '${s.className} | Roll: ${s.rollNumber}',
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
                                      Text(s.totalBilledFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    ),
                                    DataCell(
                                      Text(s.paidAmountFormatted, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                                    ),
                                    DataCell(
                                      s.advanceAmount > 0
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  formatIndianCurrency(s.advanceAmount),
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEEF2FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('Advance Credit', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              s.balanceAmount > 0 ? s.balanceAmountFormatted : '₹ 0 (Cleared)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: s.balanceAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                              ),
                                            ),
                                    ),
                                    DataCell(_buildStatusBadge(s.status)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF2563EB)),
                                            tooltip: 'View 360 Fee Drawer',
                                            onPressed: () => notifier.openStudentDrawer(s.studentId),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF16A34A)),
                                            tooltip: 'Collect Payment',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => CollectStudentPaymentDialog(
                                                  studentId: s.studentId,
                                                  studentName: s.studentName,
                                                  className: s.className,
                                                  rollNumber: s.rollNumber.toString(),
                                                  invoiceId: s.latestInvoiceId,
                                                  defaultAmount: s.balanceAmount > 0 ? s.balanceAmount : 4500.0,
                                                ),
                                              );
                                            },
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'collect', child: Text('Collect Payment', style: TextStyle(fontSize: 12))),
                                              const PopupMenuItem(value: 'invoice', child: Text('Generate Invoice', style: TextStyle(fontSize: 12))),
                                              if (s.advanceAmount > 0 || s.status == 'Overpaid')
                                                const PopupMenuItem(
                                                  value: 'refund',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.currency_exchange_rounded, size: 14, color: Color(0xFFEA580C)),
                                                      SizedBox(width: 8),
                                                      Text('Refund Overpayment', style: TextStyle(fontSize: 12, color: Color(0xFFEA580C), fontWeight: FontWeight.w700)),
                                                    ],
                                                  ),
                                                ),
                                              const PopupMenuItem(value: 'concession', child: Text('Apply Concession / Discount', style: TextStyle(fontSize: 12))),
                                              const PopupMenuItem(value: 'penalty', child: Text('Add Late Fee Fine', style: TextStyle(fontSize: 12))),
                                            ],
                                            onSelected: (val) {
                                              if (val == 'collect') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => CollectStudentPaymentDialog(
                                                    studentId: s.studentId,
                                                    studentName: s.studentName,
                                                    className: s.className,
                                                    rollNumber: s.rollNumber.toString(),
                                                    invoiceId: s.latestInvoiceId,
                                                    defaultAmount: s.balanceAmount > 0 ? s.balanceAmount : 4500.0,
                                                  ),
                                                );
                                              } else if (val == 'refund') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => RefundStudentFeeDialog(
                                                    studentId: s.studentId,
                                                    studentName: s.studentName,
                                                    availableAdvance: s.advanceAmount,
                                                    invoiceId: s.latestInvoiceId,
                                                  ),
                                                );
                                              } else if (val == 'invoice') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => GenerateStudentInvoiceDialog(preselectedStudentId: s.studentId),
                                                );
                                              } else if (val == 'concession') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => ApplyStudentConcessionDialog(
                                                    studentId: s.studentId,
                                                    studentName: s.studentName,
                                                    invoiceId: s.latestInvoiceId ?? '',
                                                  ),
                                                );
                                              } else if (val == 'penalty') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AddStudentPenaltyDialog(
                                                    studentId: s.studentId,
                                                    studentName: s.studentName,
                                                    invoiceId: s.latestInvoiceId ?? '',
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

  Widget _buildSortableHeader(String label, String columnKey, StudentFeeState state, VoidCallback onTap) {
    final isSorted = state.sortColumn == columnKey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (state.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 14,
              color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectionBar(BuildContext context, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6366F1), width: 1.2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 18),
            const SizedBox(width: 8),
            Text(
              '${state.selectedStudentIds.length} student${state.selectedStudentIds.length > 1 ? "s" : ""} selected',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              ),
            ),
            const SizedBox(width: 16),
            // Send Reminder
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
              icon: const Icon(Icons.notifications_active_outlined, size: 16),
              label: const Text('Send Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final ok = await notifier.executeBulkAction('send_reminder');
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment reminders queued for ${state.selectedStudentIds.length} students')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            // Mark as Paid
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Mark as Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Settle Pending Fees'),
                    content: Text('Mark all pending invoices as Paid for ${state.selectedStudentIds.length} selected students?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirm Settle'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.executeBulkAction('mark_paid');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Successfully settled fees for selected students')),
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            // Void Invoices
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Void Invoices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Void Invoices'),
                    content: Text('Void unpaid invoices for ${state.selectedStudentIds.length} selected students?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Void Invoices'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.executeBulkAction('void_invoices');
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

  Widget _buildPaginationFooter(StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
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
              AppSearchableDropdown<int>.fromMenuItems(
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
          decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
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
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
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
      case 'Overpaid':
      case 'Over Paid':
      case 'Advance':
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF4F46E5);
        break;
      case 'Paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Partial':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'Pending':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      case 'Overdue':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'Unbilled':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // =========================================================================
  // TAB 6: ENTERPRISE CLASS & SECTION FEE STRUCTURE ENGINE
  // =========================================================================

  Widget _buildFeeStructureCatalog(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    final q = _feeSearchController.text.trim().toLowerCase();
    final allItems = state.feeStructures;

    final classesList = <String>{'All Classes'};
    for (final c in state.classesList) {
      if (c.isNotEmpty) classesList.add(c);
    }
    for (final c in state.classesWithSections.keys) {
      if (c.isNotEmpty) classesList.add(c);
    }
    for (final f in allItems) {
      if (f.classGrade.isNotEmpty) classesList.add(f.classGrade);
    }

    final sectionsList = <String>{'All Sections'};
    if (_feeClassFilter != 'All Classes' && state.classesWithSections.containsKey(_feeClassFilter)) {
      sectionsList.addAll(state.classesWithSections[_feeClassFilter]!);
    } else {
      for (final f in allItems) {
        if (f.sectionName.isNotEmpty && f.sectionName != 'All Sections') {
          sectionsList.add(f.sectionName);
        }
      }
    }
    if (!sectionsList.contains(_feeSectionFilter)) {
      _feeSectionFilter = 'All Sections';
    }

    const frequenciesList = ['All Frequencies', 'Monthly', 'Quarterly', 'Half-Yearly', 'Annual', 'One-Time'];

    final filtered = allItems.where((f) {
      final matchesSearch = q.isEmpty ||
          f.feeName.toLowerCase().contains(q) ||
          f.feeType.toLowerCase().contains(q) ||
          f.sectionName.toLowerCase().contains(q) ||
          (f.description ?? '').toLowerCase().contains(q);
      final matchesClass = _feeClassFilter == 'All Classes' || f.classGrade == _feeClassFilter || f.classGrade == 'All Classes';
      final matchesSection = _feeSectionFilter == 'All Sections' || f.sectionName == _feeSectionFilter || f.sectionName == 'All Sections';
      final matchesFreq = _feeFrequencyFilter == 'All Frequencies' || f.frequencyType == _feeFrequencyFilter;
      return matchesSearch && matchesClass && matchesSection && matchesFreq;
    }).toList();

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _feePageSize).ceil().clamp(1, 9999);
    final currentPage = _feePage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _feePageSize;
    final pageItems = filtered.skip(startIndex).take(_feePageSize).toList();

    final totalAnnual = filtered.fold<double>(0.0, (sum, f) => sum + f.annualLiability);
    final monthlyTotal = filtered.where((f) => f.frequencyType == 'Monthly').fold<double>(0.0, (sum, f) => sum + f.annualLiability);
    final quarterlyTotal = filtered.where((f) => f.frequencyType == 'Quarterly').fold<double>(0.0, (sum, f) => sum + f.annualLiability);
    final annualCharges = filtered.where((f) => f.frequencyType == 'Annual' || f.frequencyType == 'Half-Yearly').fold<double>(0.0, (sum, f) => sum + f.annualLiability);
    final oneTimeCharges = filtered.where((f) => f.frequencyType == 'One-Time').fold<double>(0.0, (sum, f) => sum + f.amount);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class & Section Fee Structure Engine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text(
                      'Dedicated fee schedules, recurring cycles & automatic billing rules ($totalRecords Fee Heads)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search bar
                    SizedBox(
                      width: 200,
                      height: 38,
                      child: TextField(
                        controller: _feeSearchController,
                        onChanged: (_) => setState(() => _feePage = 1),
                        decoration: InputDecoration(
                          hintText: 'Search fee head...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                    // Class Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: classesList.contains(_feeClassFilter) ? _feeClassFilter : 'All Classes',
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _feeClassFilter = val; _feeSectionFilter = 'All Sections'; _feePage = 1; });
                          },
                        ),
                      ),
                    ),
                    // Section Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: sectionsList.contains(_feeSectionFilter) ? _feeSectionFilter : 'All Sections',
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: sectionsList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _feeSectionFilter = val; _feePage = 1; });
                          },
                        ),
                      ),
                    ),
                    // Frequency Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: frequenciesList.contains(_feeFrequencyFilter) ? _feeFrequencyFilter : 'All Frequencies',
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: frequenciesList.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _feeFrequencyFilter = val; _feePage = 1; });
                          },
                        ),
                      ),
                    ),
                    // Clone Structure Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        side: const BorderSide(color: Color(0xFF8B5CF6)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('Clone Structure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => CloneStudentFeeStructureDialog(
                            initialSourceClass: _feeClassFilter != 'All Classes' ? _feeClassFilter : 'Class 10',
                            initialSourceSection: _feeSectionFilter,
                          ),
                        );
                      },
                    ),
                    // Add Fee Head Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Fee Head', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => EditStudentFeeStructureDialog(
                            isEditing: false,
                            initialClass: _feeClassFilter != 'All Classes' ? _feeClassFilter : 'All Classes',
                            initialSection: _feeSectionFilter != 'All Sections' ? _feeSectionFilter : 'All Sections',
                          ),
                        );
                      },
                    ),
                    // Export CSV
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('Fee Head Name,Category Type,Class,Section,Frequency,Cycle,Amount,Annual Liability,Due Day,Grace Days,Late Fine Amount,Late Fine Type,Mandatory,Refundable');
                        for (final f in filtered) {
                          buffer.writeln(
                            '"${f.feeName}","${f.feeType}","${f.classGrade}","${f.sectionName}","${f.frequencyType}","${f.billingCycle}",${f.amount},${f.annualLiability},${f.dueDayOfCycle},${f.gracePeriodDays},${f.lateFineAmount},"${f.lateFineType}",${f.isMandatory},${f.isRefundable}',
                          );
                        }
                        downloadCsvWeb(buffer.toString(), 'Fee_Structure_${_feeClassFilter}_${DateTime.now().millisecondsSinceEpoch}.csv');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fee structure catalog exported to CSV!'), backgroundColor: Color(0xFF16A34A)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // COHORT ANALYTICS STRIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.groups_rounded, size: 16, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SELECTED COHORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5)),
                        Text('$_feeClassFilter • $_feeSectionFilter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL ANNUAL COMMITMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A), letterSpacing: 0.5)),
                        Text('${formatIndianCurrency(totalAnnual)} / student', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
                Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text('Monthly Tuition: ${formatIndianCurrency(monthlyTotal / 12)}/mo', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_agenda_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text('Quarterly Labs: ${formatIndianCurrency(quarterlyTotal / 4)}/qtr', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (annualCharges > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text('Annual & Exams: ${formatIndianCurrency(annualCharges)}/yr', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                if (oneTimeCharges > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 4),
                      Text('One-Time / Caution: ${formatIndianCurrency(oneTimeCharges)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Data Grid Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('FEE HEAD & CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('CLASS & SECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('FREQUENCY / CYCLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('DUE & LATE FINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('POLICY STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('BASE RATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('ANNUAL TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                SizedBox(width: 90, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Data Grid Rows
          Expanded(
            child: pageItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_clear_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text('No fee heads matching criteria', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pageItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final f = pageItems[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // 1. Fee Head Name & Category
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child: Text(f.feeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                            if (f.isRefundable) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('REFUNDABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(f.feeType, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 2. Class & Section
                            Expanded(
                              flex: 2,
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                    child: Text(f.classGrade, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: f.sectionName == 'All Sections'
                                          ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0))
                                          : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      f.sectionName,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: f.sectionName == 'All Sections' ? const Color(0xFF64748B) : const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 3. Frequency / Billing Cycle
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.frequencyType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text(f.billingCycle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 4. Due & Late Fine
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${f.dueDayOfCycle}th of cycle', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                  Text(
                                    f.lateFineAmount > 0 ? 'Fine: ${f.lateFineFormatted}' : 'Grace: ${f.gracePeriodDays} days',
                                    style: TextStyle(fontSize: 10.5, color: f.lateFineAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            // 5. Policy Status
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: f.isMandatory ? const Color(0xFF2563EB).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  f.isMandatory ? 'Mandatory' : 'Optional',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: f.isMandatory ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                            // 6. Base Amount
                            Expanded(
                              flex: 2,
                              child: Text(f.amountFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
                            ),
                            // 7. Annual Total
                            Expanded(
                              flex: 2,
                              child: Text(f.annualLiabilityFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF16A34A))),
                            ),
                            // 8. Actions
                            SizedBox(
                              width: 90,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                    tooltip: 'Edit Fee Head',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (c) => EditStudentFeeStructureDialog(
                                          isEditing: true,
                                          structureId: f.id,
                                          initialName: f.feeName,
                                          initialType: f.feeType,
                                          initialClass: f.classGrade,
                                          initialSection: f.sectionName,
                                          initialCycle: f.billingCycle,
                                          initialFrequency: f.frequencyType,
                                          initialAmount: f.amount,
                                          initialDueDay: f.dueDayOfCycle,
                                          initialGracePeriod: f.gracePeriodDays,
                                          initialLateFine: f.lateFineAmount,
                                          initialLateFineType: f.lateFineType,
                                          initialDescription: f.description,
                                          initialMandatory: f.isMandatory,
                                          initialRefundable: f.isRefundable,
                                          initialAcademicYear: f.academicYear,
                                          initialAcademicStartDate: f.academicStartDate,
                                          initialInstallmentDates: f.installmentDates,
                                          initialReminderStages: f.reminderStages,
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                    tooltip: 'Delete Fee Head',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Fee Head'),
                                          content: Text('Are you sure you want to delete "${f.feeName}"?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await PaymentManagementApiService.instance.deleteStudentFeeStructure(f.id);
                                        ref.read(studentFeeProvider.notifier).loadAllData();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Pagination Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalRecords == 0
                      ? 'No items'
                      : 'Showing ${startIndex + 1} to ${(startIndex + _feePageSize).clamp(1, totalRecords)} of $totalRecords fee heads',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: currentPage > 1 ? () => setState(() => _feePage = currentPage - 1) : null,
                    ),
                    Text('$currentPage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: currentPage < totalPages ? () => setState(() => _feePage = currentPage + 1) : null,
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

  // =========================================================================
  // TAB 7: ENTERPRISE INVOICES MASTER DATA GRID
  // =========================================================================

  Widget _buildInvoicesMasterTable(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    final q = _invoiceSearchController.text.trim().toLowerCase();
    final allItems = state.invoicesList;
    final classesList = <String>{'All Classes'};
    for (final inv in allItems) {
      if (inv.className != null && inv.className!.isNotEmpty) classesList.add(inv.className!);
    }

    final filtered = allItems.where((inv) {
      final matchesSearch = q.isEmpty ||
          inv.invoiceNumber.toLowerCase().contains(q) ||
          (inv.studentName ?? '').toLowerCase().contains(q) ||
          (inv.rollNumber ?? '').toLowerCase().contains(q) ||
          inv.title.toLowerCase().contains(q);
      final matchesStatus = _invoiceStatusFilter == 'All Statuses' ||
          inv.status.toLowerCase() == _invoiceStatusFilter.toLowerCase();
      final matchesClass = _invoiceClassFilter == 'All Classes' || inv.className == _invoiceClassFilter;
      return matchesSearch && matchesStatus && matchesClass;
    }).toList();

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _invoicePageSize).ceil().clamp(1, 9999);
    final currentPage = _invoicePage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _invoicePageSize;
    final pageItems = filtered.skip(startIndex).take(_invoicePageSize).toList();

    final totalBilled = allItems.fold<double>(0.0, (sum, i) => sum + i.totalBilled);
    final totalPaid = allItems.fold<double>(0.0, (sum, i) => sum + i.paidAmount);
    final totalBal = allItems.fold<double>(0.0, (sum, i) => sum + i.balanceAmount);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School Invoices Master Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('$totalRecords Invoices | Billed: ${formatIndianCurrency(totalBilled)} | Collected: ${formatIndianCurrency(totalPaid)} | Balance Due: ${formatIndianCurrency(totalBal)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search Input
                    SizedBox(
                      width: 230,
                      height: 38,
                      child: TextField(
                        controller: _invoiceSearchController,
                        onChanged: (_) => setState(() => _invoicePage = 1),
                        decoration: InputDecoration(
                          hintText: 'Search invoice #, student...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                    // Status Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: _invoiceStatusFilter,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(value: 'All Statuses', child: Text('All Statuses')),
                            DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                            DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                            DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'Overdue', child: Text('Overdue')),
                            DropdownMenuItem(value: 'Overpaid', child: Text('Overpaid')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() { _invoiceStatusFilter = val; _invoicePage = 1; });
                          },
                        ),
                      ),
                    ),
                    // Class Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: classesList.contains(_invoiceClassFilter) ? _invoiceClassFilter : 'All Classes',
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _invoiceClassFilter = val; _invoicePage = 1; });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('INVOICE #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text('STUDENT & CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text('FEE HEAD & PLAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('DUE DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('BILLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('PAID / BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                SizedBox(width: 130, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Rows
          Expanded(
            child: pageItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text('No invoices matching criteria', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pageItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final inv = pageItems[idx];
                      final hasAdvance = inv.studentAdvanceBalance > 0 && inv.balanceAmount > 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    inv.invoiceNumber,
                                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  Text('${inv.className ?? "Class 10"} | Roll: ${inv.rollNumber ?? "-"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text('${inv.feeType} | ${inv.feePlan}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(inv.dueDate, style: const TextStyle(fontSize: 11.5)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(inv.totalBilledFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.paidAmountFormatted, style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                                  Text('Bal: ${inv.balanceAmountFormatted}', style: TextStyle(fontSize: 11, color: inv.balanceAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildStatusBadge(inv.status),
                            ),
                            SizedBox(
                              width: 130,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Settle with Advance Credit Button
                                  if (hasAdvance)
                                    IconButton(
                                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF059669)),
                                      tooltip: 'Settle from Advance Credit (₹ ${formatIndianCurrency(inv.studentAdvanceBalance)} available)',
                                      onPressed: () async {
                                        final res = await notifier.settleInvoiceFromAdvance(inv.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(res['message']?.toString() ?? 'Invoice settled!'), backgroundColor: const Color(0xFF16A34A)),
                                          );
                                        }
                                      },
                                    )
                                  else if (inv.balanceAmount > 0)
                                    IconButton(
                                      icon: const Icon(Icons.payment_rounded, size: 18, color: Color(0xFF16A34A)),
                                      tooltip: 'Collect Payment',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (c) => CollectStudentPaymentDialog(
                                            studentId: inv.studentId ?? '',
                                            studentName: inv.studentName ?? 'Student',
                                            className: inv.className,
                                            invoiceId: inv.id,
                                            defaultAmount: inv.balanceAmount > 0 ? inv.balanceAmount : inv.totalBilled,
                                          ),
                                        );
                                      },
                                    ),
                                  if (inv.status != 'Paid')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      tooltip: 'Void Invoice',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Void Invoice'),
                                            content: Text('Are you sure you want to void invoice ${inv.invoiceNumber}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                                onPressed: () => Navigator.pop(c, true),
                                                child: const Text('Void Invoice'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await PaymentManagementApiService.instance.voidStudentInvoice(inv.id);
                                          ref.read(studentFeeProvider.notifier).loadAllData();
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Pagination Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalRecords == 0
                      ? 'No items'
                      : 'Showing ${startIndex + 1} to ${(startIndex + _invoicePageSize).clamp(1, totalRecords)} of $totalRecords invoices',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: currentPage > 1 ? () => setState(() => _invoicePage = currentPage - 1) : null,
                    ),
                    Text('$currentPage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: currentPage < totalPages ? () => setState(() => _invoicePage = currentPage + 1) : null,
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

  // =========================================================================
  // TAB 8: ENTERPRISE PAYMENTS & COLLECTIONS MASTER DATA GRID
  // =========================================================================

  Widget _buildPaymentsMasterTable(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    final q = _paymentSearchController.text.trim().toLowerCase();
    final allItems = state.paymentsList;
    final modesList = <String>{'All Modes', 'UPI', 'Bank Transfer', 'Cash', 'Advance Credit Wallet', 'Cheque', 'Card'};

    final filtered = allItems.where((p) {
      final matchesSearch = q.isEmpty ||
          p.receiptNumber.toLowerCase().contains(q) ||
          (p.studentName ?? '').toLowerCase().contains(q) ||
          (p.transactionReference ?? '').toLowerCase().contains(q) ||
          (p.remarks ?? '').toLowerCase().contains(q);
      final matchesMode = _paymentModeFilter == 'All Modes' ||
          p.paymentMethod.toLowerCase().contains(_paymentModeFilter.toLowerCase());
      return matchesSearch && matchesMode;
    }).toList();

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _paymentPageSize).ceil().clamp(1, 9999);
    final currentPage = _paymentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _paymentPageSize;
    final pageItems = filtered.skip(startIndex).take(_paymentPageSize).toList();

    final totalCollected = allItems.fold<double>(0.0, (sum, p) => sum + p.amountPaid);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School Payment Receipts Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('$totalRecords Receipts Issued | Total Collected: ${formatIndianCurrency(totalCollected)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search Input
                    SizedBox(
                      width: 230,
                      height: 38,
                      child: TextField(
                        controller: _paymentSearchController,
                        onChanged: (_) => setState(() => _paymentPage = 1),
                        decoration: InputDecoration(
                          hintText: 'Search receipt, student, UTR...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                    // Payment Mode Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: modesList.contains(_paymentModeFilter) ? _paymentModeFilter : 'All Modes',
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: modesList.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _paymentModeFilter = val; _paymentPage = 1; });
                          },
                        ),
                      ),
                    ),
                    // Export CSV Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('Receipt Number,Student Name,Class,Roll Number,Payment Date,Payment Mode,Transaction Reference,Amount Paid,Status,Remarks');
                        for (final p in filtered) {
                          buffer.writeln(
                            '"${p.receiptNumber}","${p.studentName ?? ''}","${p.className ?? ''}","${p.rollNumber ?? ''}","${p.paymentDate}","${p.paymentMethod}","${p.transactionReference ?? ''}","${p.amountPaid}","${p.status}","${p.remarks ?? ''}"'
                          );
                        }
                        downloadCsvWeb(buffer.toString(), 'Payments_Registry_${DateTime.now().millisecondsSinceEpoch}.csv');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payments registry exported to CSV!'), backgroundColor: Color(0xFF16A34A)),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('RECEIPT #', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text('STUDENT & CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('PAYMENT MODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('TXN / UTR REF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('AMOUNT PAID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('AUDIT STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
                SizedBox(width: 90, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5))),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table Rows
          Expanded(
            child: pageItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text('No payment receipts matching criteria', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pageItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = pageItems[idx];
                      final isAuditLocked = p.amountPaid > 0 ||
                          p.status.toUpperCase() == 'COMPLETED' ||
                          p.status.toUpperCase() == 'SUCCESS';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.receiptNumber,
                                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  Text('${p.className ?? "Class 10"} | Roll: ${p.rollNumber ?? "-"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.paymentDate.length >= 10 ? p.paymentDate.substring(0, 10) : p.paymentDate,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.paymentMethod.contains('Wallet')
                                      ? const Color(0xFF059669).withValues(alpha: 0.1)
                                      : (p.paymentMethod.contains('UPI') ? const Color(0xFF2563EB).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.paymentMethod,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.paymentMethod.contains('Wallet')
                                        ? const Color(0xFF059669)
                                        : (p.paymentMethod.contains('UPI') ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.transactionReference ?? 'N/A',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.amountPaidFormatted,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF16A34A)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: isAuditLocked
                                  ? Tooltip(
                                      message: 'Official Completed Receipt (Immutable - Protected by Financial Audit Compliance)',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF16A34A)),
                                            SizedBox(width: 3),
                                            Text(
                                              'AUDIT LOCKED',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.4),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(p.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                    ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.print_rounded, size: 17, color: Color(0xFF2563EB)),
                                    tooltip: 'View & Print 80mm Slip',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (c) => StudentFeeReceiptDialog(
                                          studentName: p.studentName ?? 'Student',
                                          className: p.className,
                                          rollNumber: p.rollNumber.toString(),
                                          amount: p.amountPaid,
                                          paymentMethod: p.paymentMethod,
                                          receiptNumber: p.receiptNumber,
                                          transactionRef: p.transactionReference,
                                          date: DateTime.tryParse(p.paymentDate) ?? DateTime.now(),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download_rounded, size: 17, color: Color(0xFF16A34A)),
                                    tooltip: 'Download Receipt HTML',
                                    onPressed: () {
                                      downloadStudentFeeReceiptHtml(
                                        receiptNumber: p.receiptNumber,
                                        studentName: p.studentName ?? 'Student',
                                        className: p.className,
                                        rollNumber: p.rollNumber.toString(),
                                        amount: p.amountPaid,
                                        paymentMethod: p.paymentMethod,
                                        transactionRef: p.transactionReference ?? 'TXN-ONLINE-CLEARED',
                                        paymentDate: p.paymentDate,
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Receipt downloaded successfully!'), backgroundColor: Color(0xFF16A34A)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),

          // Pagination Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalRecords == 0
                      ? 'No items'
                      : 'Showing ${startIndex + 1} to ${(startIndex + _paymentPageSize).clamp(1, totalRecords)} of $totalRecords receipts',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: currentPage > 1 ? () => setState(() => _paymentPage = currentPage - 1) : null,
                    ),
                    Text('$currentPage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: currentPage < totalPages ? () => setState(() => _paymentPage = currentPage + 1) : null,
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
