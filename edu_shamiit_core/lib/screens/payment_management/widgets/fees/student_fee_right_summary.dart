import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/student_fee_provider.dart';
import 'dialogs/generate_student_invoice_dialog.dart';
import 'dialogs/bulk_student_invoice_dialog.dart';

class StudentFeeRightSummary extends ConsumerWidget {
  const StudentFeeRightSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFeeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kpis = state.kpis;
    final collectionPct = kpis.collectionRate;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Fee Summary & Circular Indicator Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fee Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${collectionPct.toStringAsFixed(1)}% Collected',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Visual Indicator
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: (collectionPct / 100).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${collectionPct.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Collection',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Metrics List
                _buildSummaryRow('Total Billed', kpis.totalBilledFormatted, const Color(0xFF2563EB), isDark),
                const Divider(height: 14),
                _buildSummaryRow('Total Collected', kpis.totalCollectedFormatted, const Color(0xFF16A34A), isDark),
                const Divider(height: 14),
                _buildSummaryRow('Pending Dues', kpis.pendingDuesFormatted, const Color(0xFFD97706), isDark),
                const Divider(height: 14),
                _buildSummaryRow('Overdue Amount', kpis.overdueAmountFormatted, const Color(0xFFDC2626), isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Quick Operations Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Generate New Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      showDialog(context: context, builder: (ctx) => const GenerateStudentInvoiceDialog());
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.dynamic_feed_rounded, size: 16),
                    label: const Text('Bulk Invoicing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      showDialog(context: context, builder: (ctx) => const BulkStudentInvoiceDialog());
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }
}
