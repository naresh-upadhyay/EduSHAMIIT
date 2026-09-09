import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/utils/payu_checkout_helper.dart';
import '../providers/finance_provider.dart';
import '../services/finance_api_service.dart';

class CollectPaymentDialog extends ConsumerStatefulWidget {
  final String? studentId;
  final String? invoiceId;

  const CollectPaymentDialog({
    super.key,
    this.studentId,
    this.invoiceId,
  });

  @override
  ConsumerState<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends ConsumerState<CollectPaymentDialog> {
  String _paymentMode = 'payu';
  final _amountController = TextEditingController(text: '20000');
  final _bankNameController = TextEditingController();
  final _refNoController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _receiptResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _receiptResult != null ? 'Payment Receipt' : 'Collect Student Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_receiptResult != null)
              _buildReceiptStep(isDark)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Field
                  const Text('Payment Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Mode Dropdown
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _paymentMode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'payu', child: Text('PayU Online (UPI / Card / NetBanking)')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI / QR Code')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash Counter')),
                      DropdownMenuItem(value: 'card', child: Text('Credit / Debit Card')),
                      DropdownMenuItem(value: 'netbanking', child: Text('Net Banking')),
                      DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'dd', child: Text('Demand Draft (DD)')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer (NEFT/RTGS)')),
                    ],
                    onChanged: (val) => setState(() => _paymentMode = val ?? 'payu'),
                  ),
                  const SizedBox(height: 16),

                  if (_paymentMode == 'cheque' || _paymentMode == 'dd' || _paymentMode == 'bank_transfer') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bankNameController,
                            decoration: InputDecoration(
                              labelText: 'Bank Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _refNoController,
                            decoration: InputDecoration(
                              labelText: 'Ref / Cheque No.',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Remarks Field
                  TextField(
                    controller: _remarksController,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Internal Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_paymentMode == 'payu' ? 'Launch PayU Checkout' : 'Process Payment & Generate Receipt'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptStep(bool isDark) {
    final res = _receiptResult!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment processed successfully! Digital receipt generated.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Receipt Card Preview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EduSHAMIIT ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
                  Text('Receipt #${res['receipt_number']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                ],
              ),
              const Divider(height: 24),
              _receiptRow('Transaction ID', res['transaction_id'] ?? 'TXN-99'),
              _receiptRow('Amount Paid', '₹${res['amount_paid']}', isBold: true),
              _receiptRow('Payment Mode', res['payment_mode'].toString().toUpperCase()),
              _receiptRow('Paid At', res['paid_at'] ?? ''),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Receipt'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _submitPayment() async {
    final amt = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amt <= 0) return;

    setState(() => _isSubmitting = true);

    if (_paymentMode == 'payu') {
      try {
        final res = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/v1/payments'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'gateway': 'PAYU',
            'amount': amt,
            'currency': 'INR',
            'student_id': widget.studentId,
            'invoice_id': widget.invoiceId,
            'customer_name': 'Student',
            'customer_email': 'student@edushamiit.org',
            'product_info': 'School Fee Collection',
            'payment_type': 'SCHOOL_FEE',
          }),
        );

        final body = json.decode(res.body);
        if (res.statusCode == 200 && body['success'] == true) {
          final data = body['data'] ?? {};
          final txnId = data['transaction_id'] ?? data['id'];
          final checkoutUrl = data['checkout_url'];
          final params = data['params'] != null ? Map<String, dynamic>.from(data['params']) : <String, dynamic>{};

          if (checkoutUrl != null && params.isNotEmpty) {
            submitPayUHostedCheckout(checkoutUrl: checkoutUrl, params: params);
          }

          setState(() {
            _isSubmitting = false;
            _receiptResult = {
              'receipt_number': 'PENDING-PAYU-CLEARANCE',
              'transaction_id': txnId,
              'amount_paid': amt,
              'payment_mode': 'PayU Hosted Checkout',
              'paid_at': 'PayU Checkout Redirected',
            };
          });
          ref.read(financeProvider.notifier).loadAll();
          return;
        } else {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(body['detail'] ?? body['message'] ?? 'Failed to initiate PayU payment.')),
            );
          }
          return;
        }
      } catch (e) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initiating PayU checkout: $e')),
          );
        }
        return;
      }
    }

    final payload = {
      'student_id': widget.studentId ?? 'fd07808f-0e55-4247-8b65-5d352f33d501',
      'payment_mode': _paymentMode,
      'total_amount': amt,
      'allocations': widget.invoiceId != null
          ? [{'invoice_id': widget.invoiceId, 'allocated_amount': amt}]
          : [],
      'bank_name': _bankNameController.text.trim(),
      'cheque_dd_no': _refNoController.text.trim(),
      'remarks': _remarksController.text.trim(),
    };

    final api = FinanceApiService();
    final result = await api.collectPayment(payload);

    setState(() {
      _isSubmitting = false;
      if (result != null) {
        _receiptResult = result;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment collection failed on server. Please verify data.')),
          );
        }
      }
    });

    ref.read(financeProvider.notifier).loadAll();
  }
}
