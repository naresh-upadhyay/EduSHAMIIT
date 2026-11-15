import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/staff_salary_provider.dart';

class ChangeStaffPayoutStatusDialog extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;
  final String currentStatus;
  final String? payoutId;
  final String? currentRemarks;
  final String? currentPaymentMode;

  const ChangeStaffPayoutStatusDialog({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.currentStatus,
    this.payoutId,
    this.currentRemarks,
    this.currentPaymentMode,
  });

  @override
  ConsumerState<ChangeStaffPayoutStatusDialog> createState() => _ChangeStaffPayoutStatusDialogState();
}

class _ChangeStaffPayoutStatusDialogState extends ConsumerState<ChangeStaffPayoutStatusDialog> {
  late String _selectedStatus;
  late TextEditingController _commentsController;
  late TextEditingController _approverController;
  late TextEditingController _txnRefController;
  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  bool _submitting = false;

  final List<String> _statuses = ['Paid', 'Approved', 'Pending', 'On Hold', 'Processing'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = _statuses.contains(widget.currentStatus) ? widget.currentStatus : 'Pending';
    _commentsController = TextEditingController(text: widget.currentRemarks ?? '');
    _approverController = TextEditingController(text: 'Admin / Director');
    _txnRefController = TextEditingController(text: 'UTR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    _paymentMode = widget.currentPaymentMode ?? 'Direct Bank Transfer (NEFT/RTGS)';
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _approverController.dispose();
    _txnRefController.dispose();
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
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.rule_folder_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Status & Approvals',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            widget.staffName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Status Dropdown
              Text('Approval / Disbursal Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                    value: _selectedStatus,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: _statuses.map((s) {
                      Color color = const Color(0xFF16A34A);
                      if (s == 'Pending') color = const Color(0xFFD97706);
                      if (s == 'On Hold') color = const Color(0xFFDC2626);
                      if (s == 'Approved') color = const Color(0xFF2563EB);
                      if (s == 'Processing') color = const Color(0xFF8B5CF6);

                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(s, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // If status is Paid, show payment details
              if (_selectedStatus == 'Paid') ...[
                Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                      value: _paymentMode,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Direct Bank Transfer (NEFT/RTGS)', child: Text('Direct Bank Transfer (NEFT/RTGS)')),
                        DropdownMenuItem(value: 'UPI / Corporate IMPS', child: Text('UPI / Corporate IMPS')),
                        DropdownMenuItem(value: 'Corporate Cheque', child: Text('Corporate Cheque')),
                        DropdownMenuItem(value: 'Cash Voucher', child: Text('Cash Voucher')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMode = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Transaction Reference / UTR Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _txnRefController,
                  decoration: InputDecoration(
                    hintText: 'e.g. UTR-202610-8912',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Approver Name
              Text('Approver / Reviewer Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _approverController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Comments & Notes
              Text('Approver Comments / Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _commentsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Approved by Director for Diwali disbursal. Biometric hours verified.',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update Status & Log', style: TextStyle(fontWeight: FontWeight.w600)),
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
    setState(() => _submitting = true);
    final monthStr = ref.read(staffSalaryProvider).selectedMonthStr;

    final ok = await PaymentManagementApiService.instance.updateStaffPayoutStatus({
      'staff_id': widget.staffId,
      'month_str': monthStr,
      'payout_id': widget.payoutId,
      'status': _selectedStatus,
      'approver_name': _approverController.text.trim(),
      'comments': _commentsController.text.trim(),
      'payment_mode': _paymentMode,
      'transaction_reference': _txnRefController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Staff salary status updated to $_selectedStatus successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }
}
