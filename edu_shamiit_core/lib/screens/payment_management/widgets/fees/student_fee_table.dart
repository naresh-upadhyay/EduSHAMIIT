import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/student_fee_provider.dart';
import '../../services/payment_management_api_service.dart';
import 'dialogs/collect_student_payment_dialog.dart';
import 'dialogs/generate_student_invoice_dialog.dart';
import 'dialogs/apply_student_concession_dialog.dart';
import 'dialogs/add_student_penalty_dialog.dart';
import 'dialogs/student_fee_receipt_dialog.dart';
import 'dialogs/edit_student_fee_structure_dialog.dart';

class StudentFeeTable extends ConsumerWidget {
  const StudentFeeTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.subTab == 4) {
      return _buildFeeStructureCatalog(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 5) {
      return _buildInvoicesMasterTable(context, ref, state, notifier, isDark);
    }
    if (state.subTab == 6) {
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
                                  label: _buildSortableHeader('STUDENT', 'name', state),
                                  onSort: (_, __) => notifier.toggleSort('name'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('TOTAL BILLED', 'billed', state),
                                  onSort: (_, __) => notifier.toggleSort('billed'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('PAID', 'paid', state),
                                  onSort: (_, __) => notifier.toggleSort('paid'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('BALANCE', 'balance', state),
                                  onSort: (_, __) => notifier.toggleSort('balance'),
                                ),
                                DataColumn(
                                  label: _buildSortableHeader('STATUS', 'status', state),
                                  onSort: (_, __) => notifier.toggleSort('status'),
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
                                                Text(
                                                  s.studentName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
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
                                      Text(
                                        s.balanceAmountFormatted,
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

  Widget _buildSortableHeader(String label, String columnKey, StudentFeeState state) {
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
          color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
        ),
      ],
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
      case 'Overdue':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
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

  Widget _buildFeeStructureCatalog(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('School Fee Structure Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text('${state.feeStructures.length} Active Fee Heads Defined', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Fee Head'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const EditStudentFeeStructureDialog(isEditing: false),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.feeStructures.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final f = state.feeStructures[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: Text(f.feeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('${f.feeType} | ${f.billingCycle} | Applicable: ${f.classGrade} | ${f.isMandatory ? "Mandatory" : "Optional"}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f.amountFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF16A34A))),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
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
                              initialCycle: f.billingCycle,
                              initialAmount: f.amount,
                              initialDescription: f.description,
                              initialMandatory: f.isMandatory,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesMasterTable(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
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
              Text('School Invoices Master Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('${state.invoicesList.length} Generated Invoices', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.invoicesList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final inv = state.invoicesList[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
                  ),
                  title: Text('${inv.invoiceNumber} - ${inv.studentName ?? "Student"} (${inv.className})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('Due: ${inv.dueDate} | Fee Plan: ${inv.feePlan} | ${inv.title}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inv.totalBilledFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          _buildStatusBadge(inv.status),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.payment_rounded, size: 18, color: Color(0xFF16A34A)),
                        tooltip: 'Collect Payment for this Invoice',
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
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        tooltip: 'Void / Delete Invoice',
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsMasterTable(BuildContext context, WidgetRef ref, StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
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
              Text('School Payment Receipts Registry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text('${state.paymentsList.length} Receipts Issued', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: state.paymentsList.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (ctx, idx) {
                final p = state.paymentsList[idx];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A)),
                  ),
                  title: Text('${p.receiptNumber} - ${p.studentName ?? "Student"} (${p.className})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${p.paymentMethod} | ${p.paymentDate} | Txn: ${p.transactionReference ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.amountPaidFormatted, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF16A34A))),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF2563EB)),
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
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        tooltip: 'Void / Refund Receipt',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Void Receipt'),
                              content: Text('Are you sure you want to void receipt ${p.receiptNumber}? This will revert the paid balance on the invoice.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Void Receipt'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await PaymentManagementApiService.instance.voidStudentPayment(p.id);
                            ref.read(studentFeeProvider.notifier).loadAllData();
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
