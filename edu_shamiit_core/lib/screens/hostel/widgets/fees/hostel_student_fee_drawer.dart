import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import '../../models/hostel_fee_models.dart';
import 'dialogs/collect_payment_dialog.dart';
import 'dialogs/apply_concession_dialog.dart';
import 'dialogs/add_penalty_dialog.dart';
import 'dialogs/hostel_pos_receipt_dialog.dart';

class HostelStudentFeeDrawer extends ConsumerWidget {
  const HostelStudentFeeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = state.selectedFeeStudentDetail;

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
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: state.isFeeDetailLoading && detail == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Loading student 360° financial profile...', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                ],
              ),
            )
          : detail == null
              ? Center(
                  child: Text(
                    'No student selected',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    _buildHeader(context, detail, notifier, isDark),
                    const Divider(height: 1),

                    // Quick Financial KPI Metrics Strip
                    _buildKpiStrip(detail, isDark),
                    const Divider(height: 1),

                    // Navigation Tabs
                    _buildTabBar(state, notifier, isDark),
                    const Divider(height: 1),

                    // Tab Body
                    Expanded(
                      child: _buildTabBody(context, ref, detail, state.feeDrawerTab, isDark),
                    ),

                    // Footer Action Buttons
                    const Divider(height: 1),
                    _buildFooterActions(context, detail, notifier, isDark),
                  ],
                ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    HostelStudentFeeDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              detail.studentName.isNotEmpty ? detail.studentName[0] : 'S',
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        detail.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(detail.feeStatus, isDark),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${detail.admissionNumber} • ${detail.className} • ${detail.hostelName} (${detail.roomNumber})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => notifier.closeFeeDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = const Color(0xFF15803D);
    if (status == 'Over Paid' || status == 'Overpaid' || status == 'OVERPAID') {
      bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (status == 'Partial') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (status == 'Overdue') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildKpiStrip(HostelStudentFeeDetail360 detail, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildMiniMetric('Total Billed', detail.totalBilledFormatted, const Color(0xFF2563EB), isDark),
          ),
          Expanded(
            child: _buildMiniMetric('Paid', detail.totalPaidFormatted, const Color(0xFF16A34A), isDark),
          ),
          Expanded(
            child: _buildMiniMetric(
              'Balance Due',
              detail.balanceDueFormatted,
              detail.balanceDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
              isDark,
            ),
          ),
          Expanded(
            child: _buildMiniMetric('Deposit', detail.securityDepositFormatted, const Color(0xFF7C3AED), isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }

  Widget _buildTabBar(HostelState state, HostelNotifier notifier, bool isDark) {
    final tabs = ['Overview', 'Invoices', 'Payments', 'Ledger', 'Discounts'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSelected = state.feeDrawerTab == idx;
          return InkWell(
            onTap: () => notifier.setFeeDrawerTab(idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    WidgetRef ref,
    HostelStudentFeeDetail360 detail,
    int tab,
    bool isDark,
  ) {
    switch (tab) {
      case 0:
        return _buildOverviewTab(context, ref, detail, isDark);
      case 1:
        return _buildInvoicesTab(detail, isDark);
      case 2:
        return _buildPaymentsTab(detail, isDark);
      case 3:
        return _buildLedgerTab(detail, isDark);
      case 4:
        return _buildConcessionsTab(detail, isDark);
      default:
        return _buildOverviewTab(context, ref, detail, isDark);
    }
  }

  Widget _buildOverviewTab(
    BuildContext context,
    WidgetRef ref,
    HostelStudentFeeDetail360 detail,
    bool isDark,
  ) {
    final heads = detail.feeHeads;
    final totalAssigned = heads.fold<double>(0.0, (acc, h) => acc + ((h['amount'] as num?)?.toDouble() ?? 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Fee Structure: ${detail.planName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${heads.length} fee head${heads.length == 1 ? '' : 's'} assigned • Total: ₹ ${NumberFormat('#,##,###').format(totalAssigned.toInt())}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditFeeHeadDialog(context, ref, detail, null),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add Fee Head', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: heads.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 36, color: isDark ? Colors.white38 : Colors.black26),
                          const SizedBox(height: 8),
                          Text(
                            'No custom fee heads assigned.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _showAddEditFeeHeadDialog(context, ref, detail, null),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('Add First Fee Head', style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ...heads.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final head = entry.value;
                        final isMandatory = head['is_mandatory'] != false;
                        final isRefundable = head['is_refundable'] == true;
                        final amount = (head['amount'] as num?)?.toDouble() ?? 0.0;
                        final isLast = idx == heads.length - 1;

                        return Container(
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      width: 0.8,
                                    ),
                                  ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(
                            children: [
                              Icon(
                                isMandatory ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked,
                                size: 16,
                                color: isMandatory ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      head['head_name']?.toString() ?? 'Fee Head',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isRefundable || (head['frequency'] != null && head['frequency'] != 'MONTHLY'))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          isRefundable ? 'Refundable Deposit' : head['frequency'].toString(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹ ${NumberFormat('#,##,###').format(amount.toInt())}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                color: const Color(0xFF2563EB),
                                tooltip: 'Edit Fee Head',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                splashRadius: 14,
                                onPressed: () => _showAddEditFeeHeadDialog(context, ref, detail, head),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                                color: const Color(0xFFEF4444),
                                tooltip: 'Delete Fee Head',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                splashRadius: 14,
                                onPressed: () => _showDeleteFeeHeadDialog(context, ref, detail, head),
                              ),
                            ],
                          ),
                        );
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Assigned Fee',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            Text(
                              '₹ ${NumberFormat('#,##,###').format(totalAssigned.toInt())}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          // Student & Parent Contact Quick Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact Information', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      detail.emergencyPhone.isNotEmpty ? detail.emergencyPhone : '+91 98765 43210',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      detail.parentEmail.isNotEmpty ? detail.parentEmail : 'parent@edushamiit.edu',
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildInvoicesTab(HostelStudentFeeDetail360 detail, bool isDark) {
    if (detail.invoices.isEmpty) {
      return const Center(child: Text('No invoices issued yet', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: detail.invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final inv = detail.invoices[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    inv.invoiceNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                  _buildStatusPill(inv.status, isDark),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Due: ${inv.dueDateFormatted} • Total: ${inv.totalAmountFormatted}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              if (inv.balanceAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Outstanding Balance: ${inv.balanceAmountFormatted}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab(HostelStudentFeeDetail360 detail, bool isDark) {
    if (detail.payments.isEmpty) {
      return const Center(child: Text('No payments recorded yet', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: detail.payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = detail.payments[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.receiptNumber,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p.paymentMode} • ${p.paymentDateFormatted}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.amountFormatted,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.print_outlined, size: 18),
                    color: const Color(0xFF2563EB),
                    tooltip: 'Print 80mm POS Slip',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => HostelPosReceiptDialog(
                          receipt: p,
                          studentName: detail.studentName,
                          roomNumber: detail.roomNumber,
                          hostelName: detail.hostelName,
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
    );
  }

  Widget _buildLedgerTab(HostelStudentFeeDetail360 detail, bool isDark) {
    if (detail.ledger.isEmpty) {
      return const Center(child: Text('No ledger entries recorded', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(4),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
          4: FlexColumnWidth(2.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            children: const [
              Padding(padding: EdgeInsets.all(6), child: Text('DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              Padding(padding: EdgeInsets.all(6), child: Text('DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              Padding(padding: EdgeInsets.all(6), child: Text('DR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              Padding(padding: EdgeInsets.all(6), child: Text('CR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              Padding(padding: EdgeInsets.all(6), child: Text('BAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
            ],
          ),
          ...detail.ledger.map((l) {
            return TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(6), child: Text(l.dateFormatted, style: const TextStyle(fontSize: 10.5))),
                Padding(padding: const EdgeInsets.all(6), child: Text(l.description, style: const TextStyle(fontSize: 10.5))),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.debit > 0 ? '₹${l.debit.toInt()}' : '-',
                    style: TextStyle(fontSize: 10.5, color: l.debit > 0 ? const Color(0xFFDC2626) : null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    l.credit > 0 ? '₹${l.credit.toInt()}' : '-',
                    style: TextStyle(fontSize: 10.5, color: l.credit > 0 ? const Color(0xFF16A34A) : null),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(6), child: Text(l.runningBalanceFormatted, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConcessionsTab(HostelStudentFeeDetail360 detail, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Concessions & Scholarships', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (detail.concessions.isEmpty)
            const Text('No concessions applied', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          else
            ...detail.concessions.map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.concessionType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('Reason: ${c.reason}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    Text(c.amountFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          const Text('Assessed Penalties & Fines', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (detail.penalties.isEmpty)
            const Text('No penalties logged', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
          else
            ...detail.penalties.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.penaltyType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('Reason: ${p.reason}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    Text(p.amountFormatted, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFooterActions(
    BuildContext context,
    HostelStudentFeeDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    // Convert 360 detail to HostelStudentFeeItem for dialogs
    final studentItem = HostelStudentFeeItem(
      accountId: detail.studentId,
      studentId: detail.studentId,
      rowNum: 1,
      name: detail.fullName,
      className: detail.className,
      rollNumber: detail.rollNumber,
      studentIdentifier: detail.rollNumber,
      hostelName: detail.hostelName,
      roomNumber: detail.roomNumber,
      feePlan: detail.feePlan,
      totalFee: detail.totalFee,
      paid: detail.totalPaid,
      due: detail.balanceDue,
      overdue: detail.totalOverdue,
      status: detail.feeStatus,
      statusRaw: detail.feeStatus.toUpperCase(),
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CollectPaymentDialog(student: studentItem),
                );
              },
              icon: const Icon(Icons.payment_rounded, size: 16),
              label: const Text('Collect Fee', style: TextStyle(fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ApplyConcessionDialog(student: studentItem),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Icon(Icons.loyalty_rounded, size: 16, color: Color(0xFF0D9488)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AddPenaltyDialog(student: studentItem),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  void _showAddEditFeeHeadDialog(
    BuildContext context,
    WidgetRef ref,
    HostelStudentFeeDetail360 detail,
    Map<String, dynamic>? existingHead,
  ) {
    final isEditing = existingHead != null;
    final nameController = TextEditingController(text: existingHead?['head_name']?.toString() ?? '');
    final amountController = TextEditingController(
      text: existingHead != null ? ((existingHead['amount'] as num?)?.toInt().toString() ?? '') : '',
    );
    bool isMandatory = existingHead?['is_mandatory'] != false;
    bool isRefundable = existingHead?['is_refundable'] == true;
    String frequency = existingHead?['frequency']?.toString() ?? 'MONTHLY';
    bool isSaving = false;

    final commonPresets = [
      'Room Rent',
      'Mess & Food Charges',
      'Electricity & Water',
      'Laundry & Maintenance',
      'Security Deposit',
      'Maintenance Fee',
      'Gym Fee',
      'Library & Reading Room',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440, maxHeight: 650),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEditing ? 'Edit Fee Head' : 'Add Fee Head',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(ctx).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Student: ${detail.fullName} (${detail.className})',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),

                      // Quick preset chips
                      if (!isEditing) ...[
                        Text(
                          'Quick Suggestions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: commonPresets.map((preset) {
                            final isSelected = nameController.text == preset;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  nameController.text = preset;
                                  if (preset.toLowerCase().contains('deposit')) {
                                    isRefundable = true;
                                    frequency = 'ONE_TIME';
                                  } else {
                                    isRefundable = false;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                child: Text(
                                  preset,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Fee Head Name field
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Fee Head Name *',
                          hintText: 'e.g. Room Rent, Mess, Gym Fee',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Amount field
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Frequency dropdown
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: frequency,
                        decoration: InputDecoration(
                          labelText: 'Billing Frequency',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                          DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                          DropdownMenuItem(value: 'ANNUAL', child: Text('Annual')),
                          DropdownMenuItem(value: 'ONE_TIME', child: Text('One-time')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => frequency = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Toggles: Mandatory and Refundable
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: isMandatory,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Mandatory', style: TextStyle(fontSize: 12)),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) => setState(() => isMandatory = v ?? true),
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              value: isRefundable,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Refundable', style: TextStyle(fontSize: 12)),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) => setState(() => isRefundable = v ?? false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    final amt = double.tryParse(amountController.text.trim());
                                    if (name.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter fee head name')),
                                      );
                                      return;
                                    }
                                    if (amt == null || amt < 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a valid non-negative amount')),
                                      );
                                      return;
                                    }

                                    setState(() => isSaving = true);
                                    final notifier = ref.read(hostelProvider.notifier);
                                    bool ok = false;
                                    if (isEditing) {
                                      final headId = existingHead['id']?.toString() ?? '';
                                      ok = await notifier.updateStudentFeeHead(detail.studentId, headId, {
                                        'head_name': name,
                                        'amount': amt,
                                        'frequency': frequency,
                                        'is_mandatory': isMandatory,
                                        'is_refundable': isRefundable,
                                      });
                                    } else {
                                      ok = await notifier.addStudentFeeHead(detail.studentId, {
                                        'head_name': name,
                                        'amount': amt,
                                        'frequency': frequency,
                                        'is_mandatory': isMandatory,
                                        'is_refundable': isRefundable,
                                      });
                                    }
                                    if (ctx.mounted) {
                                      setState(() => isSaving = false);
                                      if (ok) {
                                        Navigator.of(ctx).pop();
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(isEditing ? 'Save Changes' : 'Add Fee Head'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteFeeHeadDialog(
    BuildContext context,
    WidgetRef ref,
    HostelStudentFeeDetail360 detail,
    Map<String, dynamic> head,
  ) {
    final headName = head['head_name']?.toString() ?? 'Fee Head';
    final amount = (head['amount'] as num?)?.toInt() ?? 0;
    final headId = head['id']?.toString() ?? '';
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380, maxHeight: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_rounded, size: 28, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Delete Fee Head',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to remove "$headName" (₹ ${NumberFormat('#,##,###').format(amount)}) from ${detail.fullName}\'s assigned fee structure?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isDeleting
                                  ? null
                                  : () async {
                                      setState(() => isDeleting = true);
                                      final notifier = ref.read(hostelProvider.notifier);
                                      final ok = await notifier.deleteStudentFeeHead(detail.studentId, headId);
                                      if (ctx.mounted) {
                                        setState(() => isDeleting = false);
                                        if (ok) {
                                          Navigator.of(ctx).pop();
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: isDeleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
