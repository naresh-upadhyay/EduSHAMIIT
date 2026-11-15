import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';
import 'student_fee_receipt_dialog.dart';

class CollectStudentPaymentDialog extends ConsumerStatefulWidget {
  final String? studentId;
  final String? studentName;
  final String? className;
  final String? rollNumber;
  final String? invoiceId;
  final double defaultAmount;

  const CollectStudentPaymentDialog({
    super.key,
    this.studentId,
    this.studentName,
    this.className,
    this.rollNumber,
    this.invoiceId,
    this.defaultAmount = 0.0,
  });

  @override
  ConsumerState<CollectStudentPaymentDialog> createState() => _CollectStudentPaymentDialogState();
}

class _CollectStudentPaymentDialogState extends ConsumerState<CollectStudentPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String? _selectedStudentName;
  late TextEditingController _amountController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String _paymentMethod = 'UPI / QR Code';
  bool _submitting = false;

  List<PaymentLookupItem> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.studentId;
    _selectedStudentName = widget.studentName;
    _amountController = TextEditingController(text: widget.defaultAmount > 0 ? widget.defaultAmount.toInt().toString() : '4500');
    _refController.text = 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final methods = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_PAYMENT_MODE');
    if (mounted) {
      setState(() {
        _paymentMethods = methods;
        if (methods.isNotEmpty) _paymentMethod = methods.first.label;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(studentFeeProvider);

    if (_selectedStudentId == null && state.studentFeesRoster.isNotEmpty) {
      _selectedStudentId = state.studentFeesRoster.first.studentId;
      _selectedStudentName = state.studentFeesRoster.first.studentName;
    }

    final displayName = _selectedStudentName ?? widget.studentName ?? 'Select Student';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Collect Fee Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const Divider(height: 24),

                if (widget.studentId == null && state.studentFeesRoster.isNotEmpty) ...[
                  Text('Select Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                        value: _selectedStudentId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: state.studentFeesRoster.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.studentId,
                            child: Text(
                              '${s.studentName} (${s.className} - Roll: ${s.rollNumber})',
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = state.studentFeesRoster.where((s) => s.studentId == val).firstOrNull;
                            setState(() {
                              _selectedStudentId = val;
                              _selectedStudentName = match?.studentName;
                              if (match != null && match.balanceAmount > 0) {
                                _amountController.text = match.balanceAmount.toInt().toString();
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text('Amount to Collect (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a valid payment amount';
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Payment Tender Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                      value: _paymentMethods.any((m) => m.label == _paymentMethod) ? _paymentMethod : (_paymentMethods.isNotEmpty ? _paymentMethods.first.label : _paymentMethod),
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'UPI / QR Code', child: Text('UPI / QR Code')),
                        DropdownMenuItem(value: 'Cash at Counter', child: Text('Cash at Counter')),
                        DropdownMenuItem(value: 'Net Banking / NEFT', child: Text('Net Banking / NEFT')),
                        DropdownMenuItem(value: 'Cheque / DD', child: Text('Cheque / DD')),
                        DropdownMenuItem(value: 'POS Debit/Credit Card', child: Text('POS Debit/Credit Card')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMethod = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Txn Ref / UTR / Cheque No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _refController,
                  decoration: InputDecoration(
                    hintText: 'e.g. UTR-9281928, CHQ-001292',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Remarks / Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Optional receipt remarks or fee period...',
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Receive & Print Slip', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final targetStudentId = _selectedStudentId ?? widget.studentId;
    if (targetStudentId == null || targetStudentId.isEmpty) return;

    setState(() => _submitting = true);
    final ok = await PaymentManagementApiService.instance.collectStudentPayment({
      'student_id': targetStudentId,
      'invoice_id': widget.invoiceId,
      'amount': amt,
      'payment_method': _paymentMethod,
      'transaction_reference': _refController.text.trim(),
      'remarks': _remarksController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded and receipt issued!'), backgroundColor: Color(0xFF16A34A)),
        );

        // Instantly display Thermal Receipt dialog
        showDialog(
          context: context,
          builder: (ctx) => StudentFeeReceiptDialog(
            studentName: _selectedStudentName ?? widget.studentName ?? 'Student',
            className: widget.className,
            rollNumber: widget.rollNumber,
            amount: amt,
            paymentMethod: _paymentMethod,
            receiptNumber: 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
            transactionRef: _refController.text.trim(),
            date: DateTime.now(),
          ),
        );
      }
    }
  }
}
