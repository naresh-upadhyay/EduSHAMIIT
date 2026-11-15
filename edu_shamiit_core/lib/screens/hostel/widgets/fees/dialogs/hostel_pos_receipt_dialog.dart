import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/hostel_fee_models.dart';
import '../../leave/scannable_hostel_qr_widget.dart';
import '../../../../../utils/js_helper.dart';

class HostelPosReceiptDialog extends StatelessWidget {
  final HostelPaymentReceiptModel? receipt;
  final String? studentName;
  final String? roomNumber;
  final String? hostelName;
  final String? receiptNumber;
  final double? amount;
  final String? paymentMethod;
  final String? transactionRef;
  final String? paymentDate;
  final String? notes;

  const HostelPosReceiptDialog({
    super.key,
    this.receipt,
    this.studentName,
    this.roomNumber,
    this.hostelName,
    this.receiptNumber,
    this.amount,
    this.paymentMethod,
    this.transactionRef,
    this.paymentDate,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final rNum = receipt?.receiptNumber ?? receiptNumber ?? 'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final sName = receipt?.studentName ?? studentName ?? 'Hostel Resident';
    final rRoom = receipt?.roomNumber ?? roomNumber ?? 'Room Assigned';
    final rHostel = receipt?.hostelName ?? hostelName ?? 'EduSHAMIIT Hostels';
    final rAmt = receipt?.amount ?? amount ?? 0.0;
    final rMethod = receipt?.paymentMethod ?? paymentMethod ?? 'Cash / Online';
    final rRef = receipt?.transactionReference ?? transactionRef ?? 'TXN-ONLINE-SUCCESS';
    final rDate = receipt?.paymentDate ?? paymentDate ?? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final rNotes = receipt?.notes ?? notes;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thermal Receipt Container (80mm simulated card)
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
                    // Institution Brand Header
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
                      'HOSTEL RESIDENCE MANAGEMENT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '80mm POS Thermal Fee Slip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Receipt Info
                    _buildReceiptRow('RECEIPT NO:', rNum, isBold: true),
                    const SizedBox(height: 6),
                    _buildReceiptRow('DATE & TIME:', rDate),
                    const SizedBox(height: 6),
                    _buildReceiptRow('PAYMENT MODE:', rMethod),
                    if (rRef.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildReceiptRow('REF / TXN ID:', rRef),
                    ],
                    const SizedBox(height: 12),
                    _buildDashedLine(),
                    const SizedBox(height: 12),

                    // Student Details
                    _buildReceiptRow('STUDENT:', sName, isBold: true),
                    const SizedBox(height: 6),
                    _buildReceiptRow('HOSTEL BLOCK:', rHostel),
                    const SizedBox(height: 6),
                    _buildReceiptRow('ROOM & BED:', rRoom),
                    if (rNotes != null && rNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildReceiptRow('REMARKS:', rNotes),
                    ],
                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 14),

                    // Amount breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL PAID:',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '₹ ${NumberFormat('#,##,###').format(rAmt.toInt())}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'STATUS: TRANSACTION SUCCESSFUL (PAID)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildDashedLine(),
                    const SizedBox(height: 14),

                    // Authentic Scannable QR Verification Code
                    Column(
                      children: [
                        Center(
                          child: ScannableHostelQrWidget(
                            passNumber: rNum,
                            size: 96,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '* $rNum *',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Thank you for your payment.\nKeep this slip for hostel exit & records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        color: Color(0xFF94A3B8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons (Print & Dismiss)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        printStudentFeeReceiptHtml(
                          receiptNumber: rNum,
                          studentName: sName,
                          className: 'Hostel Room $rRoom',
                          rollNumber: rHostel,
                          amount: rAmt,
                          paymentMethod: rMethod,
                          transactionRef: rRef,
                          paymentDate: rDate,
                          institutionName: 'EduSHAMIIT HOSTEL RESIDENCE',
                          campusName: '$rHostel • Room $rRoom',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('Thermal receipt $rNum sent to printer!'),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text(
                        'Print Slip (80mm)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
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
            fontSize: 11,
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
              fontSize: 11.5,
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
