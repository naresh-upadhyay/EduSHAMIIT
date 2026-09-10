import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';

class FeesLedgerView extends ConsumerWidget {
  final Function(String studentId)? onSelectStudent;
  final Function(FeeLedgerItem item)? onCollectPayment;

  const FeesLedgerView({
    super.key,
    this.onSelectStudent,
    this.onCollectPayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading && state.ledgerItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.ledgerItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              Text(
                'No fee invoice records found.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search filters or academic year.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Table Data Header & Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 20,
              headingRowHeight: 48,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: state.selectedInvoiceIds.length == state.ledgerItems.length && state.ledgerItems.isNotEmpty,
                    onChanged: (val) => notifier.selectAllInvoices(val ?? false),
                  ),
                ),
                _buildHeader('Invoice No.'),
                _buildHeader('Student Name'),
                _buildHeader('Fee Type'),
                _buildHeader('Due Date'),
                _buildHeader('Amount (₹)'),
                _buildHeader('Paid (₹)'),
                _buildHeader('Balance (₹)'),
                _buildHeader('Status'),
                _buildHeader('Actions'),
              ],
              rows: state.ledgerItems.map((item) {
                final isSelected = state.selectedInvoiceIds.contains(item.id);
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => notifier.toggleInvoiceSelection(item.id),
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => notifier.toggleInvoiceSelection(item.id),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => onSelectStudent?.call(item.studentId),
                        child: Text(
                          item.invoiceNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      InkWell(
                        onTap: () => onSelectStudent?.call(item.studentId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.studentName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Class ${item.classSection} • Roll ${item.rollNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(item.feeHead, style: const TextStyle(fontSize: 13))),
                    DataCell(Text(item.dueDate, style: const TextStyle(fontSize: 13))),
                    DataCell(Text('₹${_formatAmt(item.amountPayable)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    DataCell(Text('₹${_formatAmt(item.amountPaid)}', style: const TextStyle(fontSize: 13, color: Color(0xFF10B981)))),
                    DataCell(Text('₹${_formatAmt(item.amountBalance)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: item.amountBalance > 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black87)))),
                    DataCell(_buildStatusBadge(item.status)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            tooltip: 'View Account',
                            onPressed: () => onSelectStudent?.call(item.studentId),
                          ),
                          if (item.amountBalance > 0)
                            IconButton(
                              icon: const Icon(Icons.payment_rounded, size: 18, color: Color(0xFF6366F1)),
                              tooltip: 'Collect Payment',
                              onPressed: () => onCollectPayment?.call(item),
                            ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onSelected: (val) {
                              if (val == 'reminder') {
                                notifier.sendReminders([item.studentId]);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Fee reminder dispatched successfully.')),
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'reminder',
                                child: Row(
                                  children: [
                                    Icon(Icons.notifications_active_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Send Reminder'),
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

          // Pagination Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${state.ledgerItems.length} of ${state.totalLedgerItems} invoices',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                    ),
                    Text(
                      'Page ${state.currentPage} of ${state.totalLedgerPages}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: state.currentPage < state.totalLedgerPages ? () => notifier.setPage(state.currentPage + 1) : null,
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

  DataColumn _buildHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status.toUpperCase()) {
      case 'PAID':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'PARTIAL':
      case 'PARTIALLY PAID':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'OVERDUE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'WAIVED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF374151);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatAmt(double val) {
    return val.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
