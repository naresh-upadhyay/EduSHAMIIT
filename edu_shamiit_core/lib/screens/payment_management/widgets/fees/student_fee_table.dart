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
                                  label: const Text('STUDENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  onSort: (_, __) => notifier.toggleSort('name'),
                                ),
                                DataColumn(
                                  label: const Text('TOTAL BILLED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  onSort: (_, __) => notifier.toggleSort('billed'),
                                ),
                                DataColumn(
                                  label: const Text('PAID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  onSort: (_, __) => notifier.toggleSort('paid'),
                                ),
                                DataColumn(
                                  label: const Text('BALANCE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  onSort: (_, __) => notifier.toggleSort('balance'),
                                ),
                                DataColumn(
                                  label: const Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  onSort: (_, __) => notifier.toggleSort('status'),
                                ),
                                const DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
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
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF2563EB),
                                              child: Text(
                                                s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : 'S',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (s.studentEmail.isNotEmpty)
                                                  Text(
                                                    s.studentEmail,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                Text(
                                                  '${s.className} | Roll: ${s.rollNumber}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
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

          // Pagination Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${students.length} students (Page ${state.currentPage} of ${state.totalPages})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                    ),
                    Text('${state.currentPage}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.currentPage + 1) : null,
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
