import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';
import '../../models/student_fee_models.dart';
import '../../providers/student_fee_provider.dart';
import 'dialogs/collect_student_payment_dialog.dart';
import 'dialogs/generate_student_invoice_dialog.dart';
import 'dialogs/apply_student_concession_dialog.dart';
import 'dialogs/add_student_penalty_dialog.dart';
import 'dialogs/student_fee_receipt_dialog.dart';
import '../../services/payment_management_api_service.dart';

class StudentFeeDrawer extends ConsumerStatefulWidget {
  const StudentFeeDrawer({super.key});

  @override
  ConsumerState<StudentFeeDrawer> createState() => _StudentFeeDrawerState();
}

class _StudentFeeDrawerState extends ConsumerState<StudentFeeDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detail = state.selectedStudentDetail;
    if (detail == null) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = detail['profile'] as Map<String, dynamic>? ?? {};
    final summary = detail['summary'] as Map<String, dynamic>? ?? {};
    final invoices = detail['invoices'] as List? ?? [];
    final payments = detail['payments'] as List? ?? [];
    final concessions = detail['concessions'] as List? ?? [];
    final penalties = detail['penalties'] as List? ?? [];
    final history = detail['history'] as List? ?? [];

    final studentName = profile['full_name']?.toString() ?? 'Student';
    final studentEmail = profile['email']?.toString() ?? '';
    final studentId = profile['id']?.toString() ?? '';
    final rollNumber = profile['roll_number']?.toString() ?? '-';
    final className = profile['class']?.toString() ?? '10A';
    final admissionNumber = profile['admission_number']?.toString() ?? '';

    final totalBilled = (summary['total_billed'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (summary['total_paid'] as num?)?.toDouble() ?? 0.0;
    final balance = (summary['balance_amount'] as num?)?.toDouble() ?? 0.0;
    final progress = totalBilled > 0 ? (totalPaid / totalBilled).clamp(0.0, 1.0) : 0.0;

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
          // 1. Header with Close Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (studentEmail.isNotEmpty)
                        Text(
                          studentEmail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        '$className | Roll: $rollNumber${admissionNumber.isNotEmpty ? ' | $admissionNumber' : ''}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: notifier.closeStudentDrawer,
                  tooltip: 'Close Drawer',
                ),
              ],
            ),
          ),

          // 2. Quick Action Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.payment_rounded, size: 14),
                    label: const Text('Collect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => CollectStudentPaymentDialog(
                          studentId: studentId,
                          studentName: studentName,
                          defaultAmount: balance > 0 ? balance : 4500.0,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Invoice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => GenerateStudentInvoiceDialog(preselectedStudentId: studentId),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.local_offer_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  tooltip: 'Apply Concession',
                  onPressed: invoices.isNotEmpty
                      ? () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ApplyStudentConcessionDialog(
                              studentId: studentId,
                              studentName: studentName,
                              invoiceId: invoices.first['id'].toString(),
                            ),
                          );
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                  tooltip: 'Add Penalty',
                  onPressed: invoices.isNotEmpty
                      ? () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AddStudentPenaltyDialog(
                              studentId: studentId,
                              studentName: studentName,
                              invoiceId: invoices.first['id'].toString(),
                            ),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),

          // 3. Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Invoices'),
              Tab(text: 'Payments'),
              Tab(text: 'Concessions'),
              Tab(text: 'History'),
            ],
          ),

          // 4. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Overview
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMetricCard('Total Billed', formatIndianCurrency(totalBilled), const Color(0xFF2563EB), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Total Paid', formatIndianCurrency(totalPaid), const Color(0xFF16A34A), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Outstanding Dues', formatIndianCurrency(balance), const Color(0xFFDC2626), isDark),
                        const SizedBox(height: 16),
                        Text(
                          'Payment Clearance (${(progress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab 2: Invoices
                ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final inv = invoices[idx] as Map<String, dynamic>;
                    final invStatus = inv['status']?.toString() ?? 'Pending';
                    final invId = inv['id']?.toString() ?? '';
                    final invBilled = (inv['total_billed'] as num?)?.toDouble() ?? 0.0;
                    final invBal = (inv['balance_amount'] as num?)?.toDouble() ?? invBilled;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv['invoice_number']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('Due: ${inv['due_date']} | ${inv['title'] ?? ""}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatIndianCurrency(invBilled), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                Text(invStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: invStatus == 'Paid' ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
                              ],
                            ),
                            const SizedBox(width: 4),
                            if (invStatus != 'Paid')
                              IconButton(
                                icon: const Icon(Icons.payment_rounded, size: 16, color: Color(0xFF16A34A)),
                                tooltip: 'Collect Payment',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => CollectStudentPaymentDialog(
                                      studentId: studentId,
                                      studentName: studentName,
                                      className: className,
                                      rollNumber: rollNumber,
                                      invoiceId: invId,
                                      defaultAmount: invBal > 0 ? invBal : invBilled,
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                              tooltip: 'Void Invoice',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Void Invoice'),
                                    content: Text('Are you sure you want to void invoice ${inv['invoice_number']}?'),
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
                                  await PaymentManagementApiService.instance.voidStudentInvoice(invId);
                                  ref.read(studentFeeProvider.notifier).loadAllData();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                // Tab 3: Payments
                payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payment_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No payment receipts found',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final pay = payments[idx] as Map<String, dynamic>;
                          final amt = (pay['amount_paid'] as num?)?.toDouble() ?? 0.0;
                          final rNum = pay['receipt_number']?.toString() ?? 'REC';
                          final method = pay['payment_method']?.toString() ?? 'UPI';
                          final date = DateTime.tryParse(pay['payment_date']?.toString() ?? '') ?? DateTime.now();
                          final status = pay['status']?.toString() ?? 'SUCCESS';
                          final txnRef = pay['transaction_reference']?.toString() ?? 'TXN-ONLINE';
                          final remarks = pay['status_remarks']?.toString() ?? pay['remarks']?.toString() ?? '';

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rNum,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                    ),
                                    _buildPaymentStatusBadge(status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatIndianCurrency(amt),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        method,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ref / UTR: $txnRef',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                if (remarks.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Note: $remarks',
                                    style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFFD97706)),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.published_with_changes_rounded, size: 14),
                                      label: const Text('Update Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      onPressed: () => _showUpdatePaymentStatusDialog(context, pay, studentId),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF16A34A)),
                                      tooltip: 'Download Receipt Slip',
                                      onPressed: () {
                                        downloadStudentFeeReceiptHtml(
                                          receiptNumber: rNum,
                                          studentName: studentName,
                                          className: className,
                                          rollNumber: rollNumber,
                                          amount: amt,
                                          paymentMethod: method,
                                          transactionRef: txnRef,
                                          paymentDate: DateFormat('dd MMM yyyy, hh:mm a').format(date),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Receipt slip downloaded!'), backgroundColor: Color(0xFF16A34A)),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF2563EB)),
                                      tooltip: 'Print 80mm Slip',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (c) => StudentFeeReceiptDialog(
                                            studentName: studentName,
                                            className: className,
                                            rollNumber: rollNumber,
                                            amount: amt,
                                            paymentMethod: method,
                                            receiptNumber: rNum,
                                            transactionRef: txnRef,
                                            date: date,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Tab 4: Concessions & Penalties
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text('Concessions Applied', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    if (concessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('No concessions applied', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ...concessions.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(c['concession_type']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                          Text('- ₹ ${c['amount']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            tooltip: 'Reverse Concession',
                            onPressed: () async {
                              final ok = await notifier.deleteConcession(c['id'].toString());
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Concession reversed successfully!'), backgroundColor: Color(0xFF16A34A)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    )),
                    const Divider(height: 16),
                    Text('Penalties Applied', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    if (penalties.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text('No penalties applied', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                    ...penalties.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(p['penalty_type']?.toString() ?? '', style: const TextStyle(fontSize: 11))),
                          Text('+ ₹ ${p['amount']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            tooltip: 'Reverse Penalty',
                            onPressed: () async {
                              final ok = await notifier.deletePenalty(p['id'].toString());
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Penalty reversed successfully!'), backgroundColor: Color(0xFF16A34A)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    )),
                  ],
                ),

                // Tab 5: History / Activity Audit Trail
                history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No activity history logged yet',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final h = history[idx] as Map<String, dynamic>;
                          final action = h['action']?.toString() ?? 'ACTIVITY';
                          final desc = h['description']?.toString() ?? '';
                          final performer = '${h['performed_by_name'] ?? 'System'} (${h['performed_by_role'] ?? 'Registrar'})';
                          final createdAt = DateTime.tryParse(h['created_at']?.toString() ?? '') ?? DateTime.now();
                          final oldSt = h['old_status']?.toString();
                          final newSt = h['new_status']?.toString();
                          final amt = (h['amount'] as num?)?.toDouble() ?? 0.0;

                          IconData actIcon = Icons.history_rounded;
                          Color actColor = const Color(0xFF2563EB);
                          if (action.contains('COLLECTED') || action.contains('CONFIRMED')) {
                            actIcon = Icons.check_circle_rounded;
                            actColor = const Color(0xFF16A34A);
                          } else if (action.contains('STATUS_UPDATED')) {
                            actIcon = Icons.published_with_changes_rounded;
                            actColor = const Color(0xFF2563EB);
                          } else if (action.contains('QR')) {
                            actIcon = Icons.qr_code_2_rounded;
                            actColor = const Color(0xFFD97706);
                          } else if (action.contains('PENALTY')) {
                            actIcon = Icons.warning_amber_rounded;
                            actColor = const Color(0xFFDC2626);
                          } else if (action.contains('CONCESSION')) {
                            actIcon = Icons.local_offer_rounded;
                            actColor = const Color(0xFF8B5CF6);
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(actIcon, size: 15, color: actColor),
                                        const SizedBox(width: 5),
                                        Text(
                                          action.replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: actColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      DateFormat('dd MMM, hh:mm a').format(createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc.replaceAll('â‚¹', '\u20B9'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (oldSt != null && newSt != null && oldSt.isNotEmpty && newSt.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '$oldSt \u2192 $newSt',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    if (amt > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          formatIndianCurrency(amt),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                        ),
                                      ),
                                    Text(
                                      'by $performer',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String? rawStatus) {
    final status = (rawStatus ?? 'SUCCESS').toUpperCase().trim();
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'SUCCESS':
      case 'PAID':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'SUCCESS';
        break;
      case 'WAITING_CONFIRMATION':
      case 'WAITING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'WAITING CONFIRMATION';
        break;
      case 'FAILED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'FAILED';
        break;
      case 'REFUNDED':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        label = 'REFUNDED';
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        label = status;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  void _showUpdatePaymentStatusDialog(
    BuildContext context,
    Map<String, dynamic> pay,
    String studentId,
  ) {
    final payId = pay['id']?.toString() ?? '';
    final curStatus = (pay['status']?.toString() ?? 'SUCCESS').toUpperCase().trim();
    String selectedStatus = curStatus;
    if (!['SUCCESS', 'WAITING_CONFIRMATION', 'FAILED', 'REFUNDED'].contains(selectedStatus)) {
      selectedStatus = 'SUCCESS';
    }
    final remarksController = TextEditingController(text: pay['status_remarks']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.published_with_changes_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text('Update Payment Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt: ${pay['receipt_number']} | Amount: ${formatIndianCurrency((pay['amount_paid'] as num?)?.toDouble() ?? 0.0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select New Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'SUCCESS',
                        child: Text('Success / Cleared', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'WAITING_CONFIRMATION',
                        child: Text('Waiting Confirmation (UPI 48h)', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'FAILED',
                        child: Text('Failed / Rejected', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'REFUNDED',
                        child: Text('Refunded', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Reason / Remarks:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Bank confirmation UTR received or registrar approval...',
                      hintStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await ref.read(studentFeeProvider.notifier).updatePaymentStatus(
                    payId,
                    selectedStatus,
                    remarks: remarksController.text.trim(),
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Payment status updated to $selectedStatus!'),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                  }
                },
                child: const Text('Update Status'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
