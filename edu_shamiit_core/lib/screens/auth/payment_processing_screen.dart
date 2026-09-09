import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final String? paymentId;
  final String? transactionId;
  final String? initialStatus;

  const PaymentProcessingScreen({
    super.key,
    this.paymentId,
    this.transactionId,
    this.initialStatus,
  });

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _isLoading = true;
  String _status = 'PROCESSING'; // 'PROCESSING', 'SUCCESS', 'FAILED', 'CANCELLED', 'PENDING'
  String? _errorMessage;
  Map<String, dynamic>? _paymentData;
  Map<String, dynamic>? _receiptData;

  @override
  void initState() {
    super.initState();
    _verifyPaymentStatus();
  }

  Future<void> _verifyPaymentStatus() async {
    final id = widget.paymentId ?? widget.transactionId;
    if (id == null || id.isEmpty) {
      setState(() {
        _isLoading = false;
        _status = 'FAILED';
        _errorMessage = 'Missing transaction or payment order reference.';
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$id/verify'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['verified'] == true) {
          setState(() {
            _status = 'SUCCESS';
            _paymentData = body;
            _isLoading = false;
          });
          _fetchReceipt(id);
        } else {
          setState(() {
            _status = body['status'] ?? 'FAILED';
            _errorMessage = body['message'] ?? body['failure_reason'] ?? 'Payment verification failed.';
            _isLoading = false;
          });
        }
      } else {
        // Fallback fetch payment order details
        _fetchPaymentDetails(id);
      }
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      _fetchPaymentDetails(id);
    }
  }

  Future<void> _fetchPaymentDetails(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$id'),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? {};
        final status = (data['status'] ?? 'PENDING').toString().toUpperCase();

        setState(() {
          _status = status;
          _paymentData = data;
          _isLoading = false;
          if (status == 'FAILED' || status == 'CANCELLED') {
            _errorMessage = data['failure_reason'] ?? 'Payment was cancelled or declined by user.';
          }
        });

        if (status == 'SUCCESS') {
          _fetchReceipt(id);
        }
      } else {
        setState(() {
          _status = 'FAILED';
          _errorMessage = 'Could not fetch transaction status.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'FAILED';
        _errorMessage = 'Network error while checking status.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchReceipt(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$id/receipt'),
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _receiptData = body['data'];
        });
      }
    } catch (e) {
      debugPrint('Receipt fetch error: $e');
    }
  }

  Future<void> _retryPayment() async {
    final id = widget.paymentId ?? _paymentData?['id'];
    if (id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$id/retry'),
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final checkoutUrl = body['data']?['checkout_url'];
        if (checkoutUrl != null) {
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initiate payment retry.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Payment Status',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(0xFF6366F1),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Confirming Your Payment',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while we verify transaction status with PayU servers...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    if (_status == 'SUCCESS') {
      final amount = _paymentData?['amount'] != null ? '₹${_paymentData!['amount']}' : (_receiptData?['amount'] != null ? '₹${_receiptData!['amount']}' : '₹0.00');
      final invoice = _paymentData?['invoice_id'] ?? _paymentData?['order_id'] ?? '-';
      final date = _paymentData?['created_at'] ?? _paymentData?['verified_at'] ?? DateTime.now().toIso8601String().substring(0, 10);
      final method = _paymentData?['payment_method'] ?? 'PayU Hosted Checkout';

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Successful!',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Status: Verified & Settled',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Transaction ID', widget.transactionId ?? _paymentData?['transaction_id'] ?? '-'),
          _buildInfoRow('Amount Paid', amount, isHighlight: true),
          _buildInfoRow('Invoice / Order', invoice),
          _buildInfoRow('Payment Method', method),
          _buildInfoRow('Date', date),
          _buildInfoRow('Receipt Number', _receiptData?['receipt_number'] ?? _paymentData?['receipt_number'] ?? 'Auto-Generated'),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viewing verified official payment receipt...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.receipt_rounded, size: 16),
                  label: Text('View Receipt', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go('/admin/payments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Back to Dashboard', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_status == 'PENDING' || _status == 'PROCESSING' || _status == 'AWAITING') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: Color(0xFF3B82F6),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Payment Processing',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We are waiting for confirmation from the payment gateway.\nIf your account has been debited, verification will complete shortly.',
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (widget.transactionId != null)
            _buildInfoRow('Transaction ID', widget.transactionId!),
          _buildInfoRow('Status', 'Gateway Verification Pending'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _verifyPaymentStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text('Check Payment Status', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // FAILED / CANCELLED State
    final isCancelled = _status == 'CANCELLED';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCancelled ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCancelled ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
            color: isCancelled ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isCancelled ? 'Payment Cancelled' : 'Payment Failed',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'The payment was declined or failed verification. No funds were debited.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (widget.transactionId != null)
          _buildInfoRow('Transaction ID', widget.transactionId!),
        _buildInfoRow('Status', _status),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.go('/admin/payments'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Back', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _retryPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Try Again', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF10B981) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
