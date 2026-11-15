import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class AddStudentPenaltyDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String invoiceId;

  const AddStudentPenaltyDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.invoiceId,
  });

  @override
  ConsumerState<AddStudentPenaltyDialog> createState() => _AddStudentPenaltyDialogState();
}

class _AddStudentPenaltyDialogState extends ConsumerState<AddStudentPenaltyDialog> {
  final TextEditingController _amountController = TextEditingController(text: '500');
  final TextEditingController _reasonController = TextEditingController(text: 'Late Fee Surcharge');
  String _penaltyType = 'Late Payment Fine';
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Fee Penalty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text(widget.studentName, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              Text('Penalty Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _penaltyType,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'Late Payment Fine', child: Text('Late Payment Fine')),
                      DropdownMenuItem(value: 'Cheque Bounce Charge', child: Text('Cheque Bounce Charge')),
                      DropdownMenuItem(value: 'Administrative Surcharge', child: Text('Administrative Surcharge')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _penaltyType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Penalty Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              Text('Reason & Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add Penalty', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    setState(() => _submitting = true);
    final ok = await PaymentManagementApiService.instance.addStudentPenalty({
      'student_id': widget.studentId,
      'invoice_id': widget.invoiceId.trim().isEmpty ? null : widget.invoiceId.trim(),
      'penalty_type': _penaltyType,
      'amount': amt,
      'reason': _reasonController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Penalty added successfully!'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    }
  }
}
