import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/platform_bridge.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailsScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  late Future<TransactionItem?> _transactionFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    setState(() {
      _transactionFuture =
          ApiService().getTransactionDetails(widget.transactionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            AppHeader(
              title: 'Transaction Details',
              showBackButton: true,
              onBackPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: FutureBuilder<TransactionItem?>(
                future: _transactionFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tx = snapshot.data ??
                      TransactionItem.getMockItems().firstWhere(
                        (e) => e.id == widget.transactionId,
                        orElse: () => TransactionItem.getMockItems().first,
                      );

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      bottomSafePadding > 0 ? bottomSafePadding + 36 : 40,
                    ),
                    child: Column(
                      children: [
                        // 1. Hero Status Card (matching Image 4)
                        _buildHeroCard(tx),
                        const SizedBox(height: 14),

                        // 2. Details Card
                        _buildDetailsCard(context, tx),
                        const SizedBox(height: 14),

                        // 3. Amount Breakdown Card
                        _buildBreakdownCard(tx),
                        const SizedBox(height: 20),

                        // 4. Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showStudentReceipt(context, tx),
                            icon: const Icon(Icons.receipt_long_outlined,
                                size: 18, color: AppColors.primaryBlue),
                            label: const Text(
                              'View Student Receipt',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.primaryBlue),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showReconciliationHistory(context, tx),
                            icon: const Icon(Icons.history,
                                size: 18, color: AppColors.primaryNavy),
                            label: const Text(
                              'Reconciliation History',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(TransactionItem tx) {
    Color iconBg;
    IconData icon;
    String statusTitle;
    Color statusColor;
    String statusSubtitle;

    final st = tx.paymentStatus.toUpperCase();
    if (st == 'VERIFIED_SUCCESS') {
      iconBg = AppColors.successGreen;
      icon = Icons.check;
      statusTitle = 'Payment Successful';
      statusColor = AppColors.successGreen;
      statusSubtitle = 'Matched and allocated to student fees';
    } else if (st == 'PENDING' || st == 'AWAITING_VERIFICATION') {
      iconBg = AppColors.pendingBlue;
      icon = Icons.schedule;
      statusTitle = 'Awaiting Verification';
      statusColor = AppColors.pendingBlue;
      statusSubtitle =
          'Payment candidate created • Bank verification in progress';
    } else if (st == 'UNMATCHED' || st == 'REVIEW_REQUIRED') {
      iconBg = AppColors.warningOrange;
      icon = Icons.priority_high;
      statusTitle = 'Review Required';
      statusColor = AppColors.warningOrange;
      statusSubtitle = 'No matching ERP payment intent found';
    } else if (st.contains('REFUND')) {
      iconBg = AppColors.refundPurple;
      icon = Icons.sync;
      statusTitle = 'Refund Processed';
      statusColor = AppColors.refundPurple;
      statusSubtitle = 'Reversal issued for student invoice';
    } else {
      iconBg = AppColors.ignoredGrey;
      icon = Icons.help_outline;
      statusTitle = 'Payment Record';
      statusColor = AppColors.textPrimary;
      statusSubtitle = 'Notification candidate under inspection';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 12),
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tx.formattedAmount,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, TransactionItem tx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'Student',
            value: tx.studentName ?? 'Unassigned',
            hasChevron: true,
            onTap: () => _showStudentDetails(context, tx),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.receipt_outlined,
            label: 'Invoice',
            value: tx.invoiceNumber ?? 'N/A',
            subValue: tx.invoiceTitle ?? 'Annual Tuition Fee',
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.credit_card_outlined,
            label: 'Payment Mode',
            value: tx.paymentMode,
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.tag,
            label: 'UTR / Reference',
            value: tx.transactionReference ?? 'N/A',
            showCopy: tx.transactionReference != null,
            onCopy: () => _copyToClipboard(
              context,
              tx.transactionReference ?? '',
              'UTR Reference copied to clipboard',
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Received At',
            value: tx.formattedReceivedAt,
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'Matched At',
            value: tx.formattedMatchedAt,
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildDetailRow(
            icon: Icons.link,
            label: 'Payment Intent',
            value: tx.intentReference ?? 'N/A',
            showCopy: tx.intentReference != null,
            onCopy: () => _copyToClipboard(
              context,
              tx.intentReference ?? '',
              'Payment Intent copied to clipboard',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    bool hasChevron = false,
    bool showCopy = false,
    VoidCallback? onTap,
    VoidCallback? onCopy,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subValue != null)
                          Text(
                            subValue,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (hasChevron) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 16, color: AppColors.textSecondary),
                  ],
                  if (showCopy) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onCopy,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.copy,
                            size: 15, color: AppColors.primaryBlue),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(TransactionItem tx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: AppColors.primaryNavy, size: 20),
              SizedBox(width: 8),
              Text(
                'Amount Breakdown',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBreakdownItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Base Fee Amount',
            amount: tx.formattedBaseFee,
          ),
          const SizedBox(height: 10),
          _buildBreakdownItem(
            icon: Icons.add_circle_outline,
            label: 'Reconciliation Excess',
            amount: tx.formattedExcess,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.currency_rupee,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Total Received',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                tx.formattedAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({
    required IconData icon,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryNavy,
      ),
    );
  }

  void _showStudentDetails(BuildContext context, TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 16
                    : 24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.primaryBlueLight,
                        child: Icon(Icons.person, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.studentName ?? 'Student Profile',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Invoice: ${tx.invoiceNumber ?? "N/A"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.school_outlined, color: AppColors.primaryNavy),
                    title: const Text('Institution'),
                    subtitle: Text(ApiService().institutionName.isNotEmpty ? ApiService().institutionName : 'Shami Innovation Academy'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long,
                        color: AppColors.primaryNavy),
                    title: const Text('Fee Head'),
                    subtitle: Text(tx.invoiceTitle ?? 'Annual Tuition Fee'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.verified, color: AppColors.successGreen),
                    title: const Text('Status'),
                    subtitle: Text(tx.paymentStatus),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStudentReceipt(BuildContext context, TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 16
                    : 24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fee Payment Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'VERIFIED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _receiptRow('Receipt No.',
                            tx.receiptNumber ?? 'RCP-${DateTime.now().year}-1042'),
                        _receiptRow('Student Name', tx.studentName ?? 'Seema'),
                        _receiptRow('Invoice Ref', tx.invoiceNumber ?? 'INV-1042'),
                        _receiptRow(
                            'Fee Head', tx.invoiceTitle ?? 'Annual Tuition Fee'),
                        _receiptRow('Payment Mode', tx.paymentMode),
                        _receiptRow('Bank UTR',
                            tx.transactionReference ?? 'UPI/438729106731'),
                        _receiptRow('Date & Time', tx.formattedReceivedAt),
                        const Divider(height: 16),
                        _receiptRow('Base Fee Paid', tx.formattedBaseFee),
                        _receiptRow('Excess Paid', tx.formattedExcess),
                        _receiptRow('Total Amount', tx.formattedAmount,
                            isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Generating official PDF receipt...'),
                                duration: Duration(seconds: 1),
                                backgroundColor: AppColors.primaryNavy,
                              ),
                            );
                            final success = await PlatformBridge.shareReceiptPdf(
                              receiptNo: tx.receiptNumber ?? 'RCP-${tx.id.length >= 8 ? tx.id.substring(0, 8).toUpperCase() : "2026-D95D7F"}',
                              studentName: tx.studentName ?? 'Aditya Gupta',
                              invoiceRef: tx.invoiceNumber ?? 'INV-2026-01058',
                              feeHead: tx.invoiceTitle ?? 'Term Tuition & Academic Amenities - Quarterly',
                              paymentMode: tx.paymentMode,
                              bankUtr: tx.transactionReference ?? 'N/A',
                              dateTime: tx.formattedReceivedAt,
                              amount: tx.formattedAmount,
                              baseAmount: tx.formattedBaseFee,
                              excessAmount: tx.formattedExcess,
                              status: tx.paymentStatus,
                            );
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open share menu on this device'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.primaryBlue : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showReconciliationHistory(BuildContext context, TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 16
                    : 24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Reconciliation Audit Trail',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Immutable timeline of notification capture and verification',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAuditStep(
                    title: 'Notification Ingested',
                    desc:
                        'Captured from ${tx.upiApp ?? "PhonePe"} on Android device PB-AND-001',
                    time: tx.formattedReceivedAt,
                    isCompleted: true,
                  ),
                  _buildAuditStep(
                    title: 'Candidate Matched',
                    desc:
                        'Matched with Payment Intent ${tx.intentReference ?? "EDU202611140042"}',
                    time: tx.formattedMatchedAt,
                    isCompleted: true,
                  ),
                  _buildAuditStep(
                    title: 'Authoritative Bank Verification',
                    desc:
                        'Verified via Bank Statement UTR match (${tx.transactionReference ?? "UPI/438729106731"})',
                    time: tx.verifiedAt != null
                        ? tx.formattedReceivedAt
                        : 'Verified by ERP',
                    isCompleted: tx.paymentStatus == 'VERIFIED_SUCCESS',
                  ),
                  _buildAuditStep(
                    title: 'ERP Ledger & Fee Receipt',
                    desc:
                        'Invoice ${tx.invoiceNumber ?? "INV-1042"} balance settled. Receipt generated.',
                    time: tx.formattedReceivedAt,
                    isCompleted: tx.paymentStatus == 'VERIFIED_SUCCESS',
                    isLast: true,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close Audit Trail'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditStep({
    required String title,
    required String desc,
    required String time,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.successGreen
                    : AppColors.ignoredGreyBg,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.successGreen
                      : AppColors.textMuted,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppColors.successGreen : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
