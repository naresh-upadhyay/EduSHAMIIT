import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';

class EduSHAMIITPayTransactionDrawer extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onRefresh;

  const EduSHAMIITPayTransactionDrawer({
    super.key,
    required this.transaction,
    this.onRefresh,
  });

  @override
  State<EduSHAMIITPayTransactionDrawer> createState() => _EduSHAMIITPayTransactionDrawerState();
}

class _EduSHAMIITPayTransactionDrawerState extends State<EduSHAMIITPayTransactionDrawer> {
  bool _isVerifying = false;

  Future<void> _verifyAgain() async {
    setState(() => _isVerifying = true);
    final txnId = widget.transaction['transaction_id'] ?? widget.transaction['id'];
    try {
      final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$txnId/verify'));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verified successfully! Status: SUCCESS')),
          );
          widget.onRefresh?.call();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isVerifying = false);
  }

  void _showRefundDialog() {
    final amountCtrl = TextEditingController(text: '${widget.transaction['amount'] ?? 0}');
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Initiate Payment Refund', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction: ${widget.transaction['transaction_id']}', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Refund Amount (₹)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for Refund', hintText: 'e.g. Excess payment, Admission withdrawal', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              final txnId = widget.transaction['id'] ?? widget.transaction['transaction_id'];
              try {
                final res = await http.post(
                  Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$txnId/refund'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'amount': amt, 'reason': reasonCtrl.text}),
                );
                if (res.statusCode == 200 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refund processed successfully.')),
                  );
                  widget.onRefresh?.call();
                }
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isSuccess = t['status'] == 'SUCCESS';

    return Drawer(
      width: 480,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Transaction Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          actions: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge & Amount Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paid Amount', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          '₹${((t['amount'] ?? 0.0) as num).toInt()}',
                          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: isSuccess ? const Color(0xFF059669) : const Color(0xFFD97706)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t['status'] ?? 'PENDING',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Metadata Grid
              _buildSectionTitle('TRANSACTION METADATA'),
              _buildDetailRow('Transaction ID', t['transaction_id'] ?? 'TXN'),
              _buildDetailRow('Ecosystem', t['ecosystem'] ?? 'SCHOOL_FEE'),
              _buildDetailRow('Student Name', t['customer_name'] ?? 'Student'),
              _buildDetailRow('Purpose', t['purpose'] ?? 'School Fee'),
              _buildDetailRow('Payment Mode', t['payment_mode'] ?? 'UPI (Dynamic QR)'),
              _buildDetailRow('Settlement Status', t['settlement_status'] ?? 'SETTLED'),
              _buildDetailRow('Bank Settlement', 'Direct School Bank Account (100%)'),
              _buildDetailRow('Date & Time', t['created_at'] ?? 'Today'),
              const Divider(height: 32),

              // 6-Step Visual Lifecycle Timeline
              _buildSectionTitle('LIFECYCLE TIMELINE'),
              const SizedBox(height: 8),
              _buildTimelineStep('1. Invoice Demand Generated', 'School fee ledger recorded demand', true),
              _buildTimelineStep('2. Payment Session Initiated', 'Transaction-specific NPCI UPI payload generated', true),
              _buildTimelineStep('3. Dynamic QR / UPI Intent Presented', 'Parent scanned QR via PhonePe / GPay', true),
              _buildTimelineStep('4. Bank Acquiring Confirmation', 'Interbank UPI clearance verified', isSuccess),
              _buildTimelineStep('5. Server Verified & Invoice Paid', 'Invoice balance deducted, receipt issued', isSuccess),
              _buildTimelineStep('6. Settle to School Bank Account', 'Disbursed to School account directly', isSuccess),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isVerifying ? null : _verifyAgain,
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: Text(_isVerifying ? 'Checking...' : 'Verify with Bank'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRefundDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                      icon: const Icon(Icons.reply_rounded, size: 16),
                      label: const Text('Initiate Refund'),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
