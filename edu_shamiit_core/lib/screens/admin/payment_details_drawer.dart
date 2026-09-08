import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentDetailsDrawer extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onClose;
  final VoidCallback onVerify;

  const PaymentDetailsDrawer({
    super.key,
    required this.transaction,
    required this.onClose,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final status = (transaction['status'] ?? 'PENDING').toString().toUpperCase();
    final amount = transaction['amount'] ?? 0.0;
    final plan = transaction['plan_name'] ?? transaction['plan_code'] ?? 'Subscription';

    Color statusColor;
    if (status == 'SUCCESS') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'FAILED') {
      statusColor = const Color(0xFFEF4444);
    } else if (status == 'CANCELLED') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFF6366F1);
    }

    return Container(
      width: 440,
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Details',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                onPressed: onClose,
              ),
            ],
          ),
          const Divider(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUS: $status',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹$amount ${transaction['currency'] ?? 'INR'}',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Transaction Overview'),
                  _buildDetailRow('Transaction ID', transaction['transaction_id'] ?? '-'),
                  _buildDetailRow('Public Order ID', transaction['public_id'] ?? '-'),
                  _buildDetailRow('Provider', '${transaction['provider'] ?? 'PAYU'} (${transaction['provider_environment'] ?? 'TEST'})'),
                  _buildDetailRow('Created At', transaction['created_at'] ?? '-'),
                  _buildDetailRow('Completed At', transaction['completed_at'] ?? 'Pending'),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Customer & School'),
                  _buildDetailRow('School Name', transaction['customer_name'] ?? 'School'),
                  _buildDetailRow('Customer Email', transaction['customer_email'] ?? '-'),
                  _buildDetailRow('Customer Phone', transaction['customer_phone'] ?? '-'),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Plan & Subscription'),
                  _buildDetailRow('Plan', plan),
                  _buildDetailRow('Billing Cycle', (transaction['billing_cycle'] ?? 'monthly').toString().toUpperCase()),
                  _buildDetailRow('Purpose', transaction['purpose'] ?? 'SUBSCRIPTION'),

                  const SizedBox(height: 24),
                  _buildSectionHeader('PayU Gateway Response'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      transaction['provider_response'] != null
                          ? transaction['provider_response'].toString()
                          : 'No raw payload stored.',
                      style: GoogleFonts.firaCode(fontSize: 11, color: const Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: Text('Verify with PayU', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
