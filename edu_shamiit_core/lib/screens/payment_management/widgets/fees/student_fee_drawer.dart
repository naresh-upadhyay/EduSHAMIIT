import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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

    final studentName = profile['full_name']?.toString() ?? 'Student';
    final studentId = profile['id']?.toString() ?? '';
    final rollNumber = profile['roll_number']?.toString() ?? '101';
    final className = profile['class']?.toString() ?? 'Class 10';
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
                      Text(
                        '$className | Roll: $rollNumber | $admissionNumber',
                        style: TextStyle(
                          fontSize: 11,
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
                        _buildMetricCard('Total Billed', '₹ ${NumberFormat('#,##,###').format(totalBilled.toInt())}', const Color(0xFF2563EB), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Total Paid', '₹ ${NumberFormat('#,##,###').format(totalPaid.toInt())}', const Color(0xFF16A34A), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Outstanding Dues', '₹ ${NumberFormat('#,##,###').format(balance.toInt())}', const Color(0xFFDC2626), isDark),
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
                                Text('₹ ${NumberFormat('#,##,###').format(invBilled.toInt())}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final pay = payments[idx] as Map<String, dynamic>;
                    final amt = (pay['amount_paid'] as num?)?.toDouble() ?? 0.0;
                    final rNum = pay['receipt_number']?.toString() ?? 'REC';
                    final method = pay['payment_method']?.toString() ?? 'UPI';
                    final date = DateTime.tryParse(pay['payment_date']?.toString() ?? '') ?? DateTime.now();

                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (c) => StudentFeeReceiptDialog(
                            studentName: studentName,
                            className: className,
                            rollNumber: rollNumber,
                            amount: amt,
                            paymentMethod: method,
                            receiptNumber: rNum,
                            transactionRef: pay['transaction_reference']?.toString(),
                            date: date,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                Text('$method | ${DateFormat('dd MMM yyyy').format(date)}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '₹ ${NumberFormat('#,##,###').format(amt.toInt())}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF2563EB)),
                                tooltip: 'Print 80mm Receipt',
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
                                      transactionRef: pay['transaction_reference']?.toString(),
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
              ],
            ),
          ),
        ],
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
