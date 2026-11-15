import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';

class StudentFeeReceiptDialog extends StatelessWidget {
  final String studentName;
  final String? className;
  final String? rollNumber;
  final double amount;
  final String paymentMethod;
  final String receiptNumber;
  final String? transactionRef;
  final DateTime date;

  const StudentFeeReceiptDialog({
    super.key,
    required this.studentName,
    this.className,
    this.rollNumber,
    required this.amount,
    required this.paymentMethod,
    required this.receiptNumber,
    this.transactionRef,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cName = className ?? 'Enrolled Student';
    final rNumber = rollNumber ?? '101';
    final txnRef = transactionRef ?? 'TXN-ONLINE-CLEARED';
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simulated 80mm Thermal Receipt Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'EduSHAMIIT CAMPUS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'STUDENT ACCOUNTS & FEE ADMINISTRATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Text(
                      'OFFICIAL RECEIPT (STUDENT COPY)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Metadata
                    _buildReceiptRow('Receipt No:', receiptNumber, isBold: true),
                    const SizedBox(height: 5),
                    _buildReceiptRow('Date & Time:', dateStr),
                    const SizedBox(height: 5),
                    _buildReceiptRow('Student:', studentName, isBold: true),
                    const SizedBox(height: 5),
                    _buildReceiptRow('Class / Roll:', '$cName | Roll: $rNumber'),
                    const SizedBox(height: 12),

                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Line Items
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DESCRIPTION', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text('AMOUNT (₹)', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildReceiptRow('Tuition & Campus Fees', '₹ ${NumberFormat('#,##,###').format(amount.toInt())}.00'),
                    const SizedBox(height: 12),

                    // Total Highlight Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border.symmetric(horizontal: BorderSide(color: Color(0xFF0F172A), width: 1.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PAID:',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '₹ ${NumberFormat('#,##,###').format(amount.toInt())}.00',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment details
                    _buildReceiptRow('Payment Mode:', paymentMethod, isBold: true),
                    const SizedBox(height: 4),
                    _buildReceiptRow('Txn Reference:', txnRef),
                    const SizedBox(height: 4),
                    _buildReceiptRow('Payment Status:', 'SUCCESS / CLEARED', isBold: true),
                    const SizedBox(height: 14),

                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Thermal Barcode Simulation
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '*$receiptNumber*',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Computer generated digital receipt.',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: Color(0xFF64748B)),
                          ),
                          const Text(
                            'Verified by EduSHAMIIT Financial Subsystem',
                            style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action buttons (Print, Download, Done)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        downloadStudentFeeReceiptHtml(
                          receiptNumber: receiptNumber,
                          studentName: studentName,
                          className: cName,
                          rollNumber: rNumber,
                          amount: amount,
                          paymentMethod: paymentMethod,
                          transactionRef: txnRef,
                          paymentDate: dateStr,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt downloaded successfully!'), backgroundColor: Color(0xFF16A34A)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Slip (80mm)', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        printStudentFeeReceiptHtml(
                          receiptNumber: receiptNumber,
                          studentName: studentName,
                          className: cName,
                          rollNumber: rNumber,
                          amount: amount,
                          paymentMethod: paymentMethod,
                          transactionRef: txnRef,
                          paymentDate: dateStr,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            );
          }),
        );
      },
    );
  }
}
