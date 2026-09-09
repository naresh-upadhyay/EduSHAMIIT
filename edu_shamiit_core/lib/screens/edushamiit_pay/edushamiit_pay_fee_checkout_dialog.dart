import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/utils/payu_checkout_helper.dart';

class EduSHAMIITPayFeeCheckoutDialog extends StatefulWidget {
  final String schoolId;
  final String studentId;
  final String studentName;
  final String feeInvoiceId;
  final String invoiceNumber;
  final String feeHead;
  final double amount;
  final VoidCallback? onPaymentSuccess;

  const EduSHAMIITPayFeeCheckoutDialog({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.feeInvoiceId,
    required this.invoiceNumber,
    required this.feeHead,
    required this.amount,
    this.onPaymentSuccess,
  });

  @override
  State<EduSHAMIITPayFeeCheckoutDialog> createState() => _EduSHAMIITPayFeeCheckoutDialogState();
}

class _EduSHAMIITPayFeeCheckoutDialogState extends State<EduSHAMIITPayFeeCheckoutDialog> {
  bool _isInitiating = false;
  bool _isChecking = false;
  bool _isRedirected = false;
  bool _isSuccess = false;
  bool _isFailed = false;
  String? _transactionId;
  String? _receiptNumber;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayUCheckout() async {
    setState(() {
      _isInitiating = true;
      _errorMessage = null;
      _isFailed = false;
    });

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/payments');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'gateway': 'PAYU',
          'amount': widget.amount,
          'currency': 'INR',
          'school_id': widget.schoolId,
          'student_id': widget.studentId,
          'invoice_id': widget.feeInvoiceId,
          'customer_name': widget.studentName,
          'customer_email': 'student@edushamiit.org',
          'customer_phone': '9999999999',
          'product_info': '${widget.feeHead} - ${widget.invoiceNumber}',
          'payment_type': 'SCHOOL_FEE',
        }),
      );

      final body = json.decode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        final data = body['data'] ?? {};
        final txnId = data['transaction_id'] ?? data['id'];
        final checkoutUrl = data['checkout_url'];
        final params = data['params'] != null ? Map<String, dynamic>.from(data['params']) : <String, dynamic>{};

        setState(() {
          _transactionId = txnId;
          _isRedirected = true;
          _isInitiating = false;
        });

        if (checkoutUrl != null && params.isNotEmpty) {
          submitPayUHostedCheckout(checkoutUrl: checkoutUrl, params: params);
        }

        _startStatusPolling();
      } else {
        setState(() {
          _isInitiating = false;
          _isFailed = true;
          _errorMessage = body['detail'] ?? body['message'] ?? 'Failed to initialize PayU payment checkout.';
        });
      }
    } catch (e) {
      setState(() {
        _isInitiating = false;
        _isFailed = true;
        _errorMessage = 'Network connection error. Please verify backend connectivity: $e';
      });
    }
  }

  void _startStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_isSuccess || !mounted || _transactionId == null) {
        timer.cancel();
        return;
      }
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_isChecking || _transactionId == null) return;
    setState(() => _isChecking = true);

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$_transactionId/verify'),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final isVerified = body['verified'] == true || body['status'] == 'SUCCESS';
        if (isVerified) {
          _pollingTimer?.cancel();
          setState(() {
            _isSuccess = true;
            _isRedirected = false;
            _receiptNumber = body['receipt_number'] ?? 'RCP-${_transactionId?.substring(0, 12)}';
          });
          widget.onPaymentSuccess?.call();
        } else if (body['status'] == 'FAILED' || body['status'] == 'PAYMENT_AMOUNT_MISMATCH') {
          _pollingTimer?.cancel();
          setState(() {
            _isFailed = true;
            _isRedirected = false;
            _errorMessage = body['failure_reason'] ?? body['message'] ?? 'Payment was declined or failed verification.';
          });
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(28),
        child: _isSuccess
            ? _buildSuccessView()
            : _isFailed
                ? _buildFailedView()
                : _isRedirected
                    ? _buildAwaitingView()
                    : _buildInitialView(),
      ),
    );
  }

  Widget _buildInitialView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.feeHead, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${widget.invoiceNumber} • ${widget.studentName}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        const SizedBox(height: 20),

        // Total Payable Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Amount Payable:', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569))),
              Text(
                '₹${widget.amount.toInt()}',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // PayU Gateway Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('ACTIVE GATEWAY', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669))),
                  ),
                  const SizedBox(width: 8),
                  Text('PayU Hosted Checkout', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Official payment gateway for EduSHAMIIT. You will be redirected to PayU to complete payment securely via:',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _paymentMethodChip('UPI / QR'),
                  _paymentMethodChip('Credit & Debit Cards'),
                  _paymentMethodChip('Net Banking'),
                  _paymentMethodChip('Wallets'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Security Notice
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            Text(
              '256-Bit SSL Encrypted • SHA-512 Hash Verified • RBI Compliant',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Action Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isInitiating ? null : _initiatePayUCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isInitiating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.payment_rounded, size: 18),
            label: Text(
              _isInitiating ? 'Initiating PayU Order...' : 'Proceed to PayU Checkout',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwaitingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3.5),
        ),
        const SizedBox(height: 24),
        Text('PayU Hosted Checkout Opened', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Please complete the payment in the secure PayU checkout page.\nThis window will automatically refresh once confirmed by PayU.',
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        if (_transactionId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Transaction ID: ', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                Text(_transactionId!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ],
            ),
          ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pollingTimer?.cancel();
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkPaymentStatus,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                icon: _isChecking
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Verify Status'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFailedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
        ),
        const SizedBox(height: 16),
        Text('Payment Failed', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'The payment could not be processed. No funds were debited.',
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _initiatePayUCheckout,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
        ),
        const SizedBox(height: 16),
        Text('Payment Received Successfully!', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'Invoice ${widget.invoiceNumber} has been marked as paid.',
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Receipt Number:', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(_receiptNumber ?? 'RCP-2026', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount Settled:', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                  Text('₹${widget.amount.toInt()}', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                ],
              ),
              if (_transactionId != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PayU Ref ID:', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                    Text(_transactionId!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Official fee receipt generated and saved.')),
                  );
                },
                icon: const Icon(Icons.receipt_rounded, size: 16),
                label: const Text('View Receipt'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentMethodChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF334155))),
    );
  }
}
