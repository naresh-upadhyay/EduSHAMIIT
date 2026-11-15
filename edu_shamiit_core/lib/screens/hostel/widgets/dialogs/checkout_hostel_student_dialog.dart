import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class CheckoutHostelStudentDialog extends ConsumerStatefulWidget {
  final HostelStudentRosterItem student;

  const CheckoutHostelStudentDialog({super.key, required this.student});

  @override
  ConsumerState<CheckoutHostelStudentDialog> createState() => _CheckoutHostelStudentDialogState();
}

class _CheckoutHostelStudentDialogState extends ConsumerState<CheckoutHostelStudentDialog> {
  final DateTime _checkoutDate = DateTime.now();
  bool _keysReturned = true;
  bool _noDamages = true;
  bool _depositRefunded = false;
  final TextEditingController _reasonController = TextEditingController(text: 'Academic Session Completed');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final hasPendingDues = widget.student.feeStatus == 'Pending';
    if (hasPendingDues) {
      final proceedWithDues = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Pending Fees Override'),
            ],
          ),
          content: Text('${widget.student.studentName} has pending fee dues. Completing check-out without payment requires administrative clearance override.\n\nDo you wish to proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Override & Check-Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (proceedWithDues != true) return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(hostelProvider.notifier);
    final payload = {
      'admission_id': widget.student.admissionId,
      'student_id': widget.student.studentId,
      'checkout_date': DateFormat('yyyy-MM-dd').format(_checkoutDate),
      'dues_cleared': widget.student.feeStatus == 'Paid',
      'key_returned': _keysReturned,
      'security_deposit_refunded': _depositRefunded,
      'reason': _reasonController.text.trim(),
    };

    final ok = await notifier.checkoutStudent(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        if (_depositRefunded) {
          try {
            await notifier.feeService.requestRefund({
              'student_id': widget.student.studentId,
              'refund_type': 'SECURITY_DEPOSIT',
              'amount': 10000.0,
              'reason': 'Hostel clearance check-out completed',
              'payment_mode': 'BANK_TRANSFER',
            });
            await notifier.loadFeesData();
          } catch (_) {}
        }
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPendingDues = widget.student.feeStatus == 'Pending';

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Hostel Check-Out Clearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Process permanent hostel check-out for ${widget.student.studentName} (${widget.student.className}).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Warning if dues pending
            if (hasPendingDues)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student has pending hostel fees. Please clear invoices before issuing final gate pass.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ),

            // Checkbox clearances
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Room keys and inventory returned', style: TextStyle(fontSize: 13)),
              value: _keysReturned,
              onChanged: (v) => setState(() => _keysReturned = v ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Room inspected — no physical damages', style: TextStyle(fontSize: 13)),
              value: _noDamages,
              onChanged: (v) => setState(() => _noDamages = v ?? true),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Security deposit refund initiated (₹10,000)', style: TextStyle(fontSize: 13)),
              value: _depositRefunded,
              onChanged: (v) => setState(() => _depositRefunded = v ?? false),
            ),
            const SizedBox(height: 10),

            const Text('Check-Out Reason & Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          child: Text(
            _isSubmitting ? 'Checking Out...' : 'Complete Check-Out',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
