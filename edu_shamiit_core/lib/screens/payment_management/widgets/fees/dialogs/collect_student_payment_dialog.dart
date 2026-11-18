import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';
import 'student_fee_receipt_dialog.dart';

enum CollectStep { form, dynamicQr, bankTransfer }

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
  CollectStep _step = CollectStep.form;

  String? _selectedStudentId;
  String? _selectedStudentName;
  late TextEditingController _amountController;
  final TextEditingController _refController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();
  String _paymentMethod = 'UPI / QR Code';
  bool _submitting = false;

  // Dynamic QR Intent State
  Map<String, dynamic>? _activeIntent;
  Timer? _countdownTimer;
  Timer? _statusPollTimer;
  int _secondsRemaining = 300; // 5 minutes QR validity
  bool _inGracePeriod = false;
  int _graceSecondsRemaining = 120; // 2 minutes grace
  bool _isTimedOut = false;
  bool _paymentConfirmed = false;
  String? _verifiedReceiptNumber;
  String? _statusMessage;

  List<PaymentLookupItem> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.studentId;
    _selectedStudentName = widget.studentName;
    _amountController = TextEditingController(
      text: widget.defaultAmount > 0 ? widget.defaultAmount.toInt().toString() : '4500',
    );
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
    _countdownTimer?.cancel();
    _statusPollTimer?.cancel();
    _amountController.dispose();
    _refController.dispose();
    _remarksController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  // =========================================================================
  // DYNAMIC QR INTENT GENERATION & POLLING
  // =========================================================================

  Future<void> _generateDynamicQr() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final targetStudentId = _selectedStudentId ?? widget.studentId;
    if (targetStudentId == null || targetStudentId.isEmpty) return;

    setState(() {
      _submitting = true;
      _statusMessage = 'Allocating unique paise within 10-minute window...';
    });

    final res = await PaymentManagementApiService.instance.createPaymentIntent(
      studentId: targetStudentId,
      invoiceId: widget.invoiceId,
      amount: amt,
      paymentMethod: 'UPI',
      notes: _remarksController.text.trim(),
    );

    if (!mounted) return;

    if (res != null && res['success'] == true) {
      setState(() {
        _submitting = false;
        _activeIntent = res;
        _step = CollectStep.dynamicQr;
        _secondsRemaining = res['qr_timer_seconds'] ?? 300;
        _graceSecondsRemaining = res['grace_timer_seconds'] ?? 120;
        _inGracePeriod = false;
        _isTimedOut = false;
        _paymentConfirmed = false;
        _statusMessage = 'Waiting for UPI payment... Scan QR with any UPI app';
      });

      _startTimerAndPolling();
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate Dynamic UPI QR. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  void _startTimerAndPolling() {
    _countdownTimer?.cancel();
    _statusPollTimer?.cancel();

    // 1-second countdown clock
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_inGracePeriod) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          // Switch to 2-minute Grace Period
          setState(() {
            _inGracePeriod = true;
            _statusMessage = 'QR validity period ended. Checking bank notification queue for in-flight transaction...';
          });
        }
      } else {
        if (_graceSecondsRemaining > 0) {
          setState(() => _graceSecondsRemaining--);
        } else {
          // Total 7 minutes expired
          timer.cancel();
          setState(() {
            _isTimedOut = true;
            _statusMessage = 'Payment timeout reached. If you have completed payment, please submit your UTR below.';
          });
        }
      }
    });

    // 2.5-second polling of Payment Bridge status
    final intentId = _activeIntent!['intent_id'] as String;
    _statusPollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted || _paymentConfirmed) return;
      final st = await PaymentManagementApiService.instance.getPaymentIntentStatus(intentId);
      if (!mounted || st == null) return;

      final status = st['status'] as String?;
      if (status == 'VERIFIED_SUCCESS' || status == 'COMPLETED') {
        _countdownTimer?.cancel();
        _statusPollTimer?.cancel();

        setState(() {
          _paymentConfirmed = true;
          _verifiedReceiptNumber = st['receipt_number']?.toString();
          _statusMessage = 'Payment Verified by Payment Bridge! Receipt issued.';
        });

        ref.read(studentFeeProvider.notifier).loadAllData();
        HapticFeedback.heavyImpact();

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (!mounted) return;
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (ctx) => StudentFeeReceiptDialog(
              studentName: _selectedStudentName ?? widget.studentName ?? 'Student',
              className: widget.className,
              rollNumber: widget.rollNumber,
              amount: (_activeIntent!['total_amount'] as num?)?.toDouble() ?? 0.0,
              paymentMethod: 'UPI (Payment Bridge)',
              receiptNumber: _verifiedReceiptNumber ?? 'REC-2026-LIVE',
              transactionRef: _activeIntent!['intent_reference'] ?? 'UPI-INTENT',
              date: DateTime.now(),
            ),
          );
        });
      } else if (status == 'PAYMENT_DETECTED') {
        setState(() {
          _statusMessage = 'Payment detected by Payment Bridge! Finalizing ledger & receipt...';
        });
      }
    });
  }

  Future<void> _submitUtrManually() async {
    final utr = _utrController.text.trim();
    if (utr.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 12-digit transaction UTR / Reference'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _submitting = true);
    final intentId = _activeIntent!['intent_id'] as String;
    final ok = await PaymentManagementApiService.instance.submitIntentUtr(intentId, utr);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      ref.read(studentFeeProvider.notifier).loadAllData();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('UTR Submitted Safely', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Your transaction reference has been registered with our accounts department for bank reconciliation.\n\n'
            'Please note: If any duplicate deduction occurred from your bank account, the full amount will be refunded back to your source account within 7 business days.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // =========================================================================
  // OFFLINE COLLECTION (CASH, CHEQUE, POS)
  // =========================================================================

  Future<void> _submitOfflinePayment() async {
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

  // =========================================================================
  // UI BUILDERS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == CollectStep.dynamicQr
              ? _buildDynamicQrView(isDark)
              : _step == CollectStep.bankTransfer
                  ? _buildBankTransferView(isDark)
                  : _buildCollectionForm(isDark),
        ),
      ),
    );
  }

  Widget _buildCollectionForm(bool isDark) {
    final state = ref.watch(studentFeeProvider);
    if (_selectedStudentId == null && state.studentFeesRoster.isNotEmpty) {
      _selectedStudentId = state.studentFeesRoster.first.studentId;
      _selectedStudentName = state.studentFeesRoster.first.studentName;
    }
    final displayName = _selectedStudentName ?? widget.studentName ?? 'Select Student';

    final isUpi = _paymentMethod.contains('UPI');
    final isDirectBank = _paymentMethod.contains('Net Banking') || _paymentMethod.contains('Direct Bank');

    return Form(
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Text(
                        displayName,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const Divider(height: 24),

          // Student selector if opened from global topbar
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
              child: Builder(
                builder: (context) {
                  final Map<String, String> studentMap = {};
                  for (final s in state.studentFeesRoster) {
                    if (s.studentId.isNotEmpty) {
                      studentMap[s.studentId] = '${s.studentName} (${s.className} - Roll: ${s.rollNumber})';
                    }
                  }
                  final effectiveStudentId = studentMap.containsKey(_selectedStudentId) ? _selectedStudentId : studentMap.keys.firstOrNull;
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: effectiveStudentId,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: studentMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Amount to Collect
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

          // Payment Tender Method
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
                value: _paymentMethod,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: (_paymentMethods.isNotEmpty
                        ? _paymentMethods.map((m) => m.label).toList()
                        : [
                            'UPI / QR Code',
                            'Cash at Counter',
                            'Net Banking / Direct Bank Transfer',
                            'Cheque / DD',
                            'POS Debit/Credit Card',
                          ])
                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!isUpi && !isDirectBank) ...[
            Text('Txn Ref / Cheque No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextFormField(
              controller: _refController,
              decoration: InputDecoration(
                hintText: 'e.g. CHQ-001292, CASH-RCPT',
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
          ],

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

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 12),
              if (isUpi)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Generate Dynamic UPI QR', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _submitting ? null : _generateDynamicQr,
                )
              else if (isDirectBank)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 18),
                  label: const Text('View Bank Transfer Info', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => setState(() => _step = CollectStep.bankTransfer),
                )
              else
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
                  onPressed: _submitting ? null : _submitOfflinePayment,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DYNAMIC UPI QR VIEW WITH 5-MINUTE TIMER & 2-MINUTE GRACE
  // =========================================================================

  Widget _buildDynamicQrView(bool isDark) {
    if (_activeIntent == null) return const SizedBox.shrink();

    final upiUri = _activeIntent!['upi_uri'] as String? ?? '';
    final totalAmt = (_activeIntent!['total_amount'] as num?)?.toDouble() ?? 0.0;
    final baseAmt = (_activeIntent!['base_amount'] as num?)?.toDouble() ?? totalAmt;
    final uniquePaise = _activeIntent!['unique_paise'] as int? ?? 0;
    final vpa = _activeIntent!['upi_vpa'] as String? ?? 'shami@okaxis';
    final payee = _activeIntent!['payee_name'] as String? ?? 'EduSHAMIIT Institution';
    final refCode = _activeIntent!['intent_reference'] as String? ?? '';

    final mins = _secondsRemaining ~/ 60;
    final secs = _secondsRemaining % 60;
    final timerStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final graceMins = _graceSecondsRemaining ~/ 60;
    final graceSecs = _graceSecondsRemaining % 60;
    final graceTimerStr = '${graceMins.toString().padLeft(2, '0')}:${graceSecs.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dynamic UPI Fee Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Text('Reference: $refCode', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                _countdownTimer?.cancel();
                _statusPollTimer?.cancel();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        const Divider(height: 20),

        if (_paymentConfirmed) ...[
          // Success State
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 60),
                const SizedBox(height: 12),
                const Text('Payment Confirmed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                const SizedBox(height: 6),
                Text('Receipt: ${_verifiedReceiptNumber ?? "REC-2026-LIVE"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text('₹ ${totalAmt.toStringAsFixed(2)} received into $payee account', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
        ] else if (!_isTimedOut) ...[
          // Active Timer Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _inGracePeriod ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFF2563EB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _inGracePeriod ? Colors.orange : const Color(0xFF2563EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_inGracePeriod ? Icons.access_time_filled_rounded : Icons.timer_outlined, size: 16, color: _inGracePeriod ? Colors.orange : const Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  _inGracePeriod ? 'Grace Period: $graceTimerStr' : 'Scan & Pay: $timerStr',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _inGracePeriod ? Colors.orange : const Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Real QR Code Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 16),

          // Unique Amount Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Payable Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text('₹ ${totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                  ],
                ),
                if (uniquePaise > 0) ...[
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Base Fee: ₹ ${baseAmt.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text('+ ₹ 0.${uniquePaise.toString().padLeft(2, '0')} Unique Paise ID', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // VPA details with copy
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: vpa));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VPA copied to clipboard!'), duration: Duration(seconds: 1)));
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Payee VPA: ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text(vpa, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status message with spinner
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage ?? 'Listening for Payment Bridge confirmation...',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ] else ...[
          // TIMEOUT / 7 MINUTES EXPIRED STATE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Payment Confirmation Pending', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'We haven\'t received payment confirmation yet. If you have not completed the payment, you can try again.\n\n'
                  'If you have already paid, please do not pay again immediately. Submit your UPI transaction reference (UTR) below so our fee department can verify your payment.\n\n'
                  'If any duplicate or excess payment occurred, it will be refunded back to your source account within 7 business days.',
                  style: TextStyle(fontSize: 12, height: 1.45),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _utrController,
                  decoration: InputDecoration(
                    labelText: '12-Digit UPI Transaction UTR / Ref',
                    hintText: 'e.g. 438729106731',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Submit UTR for Verification'),
                    onPressed: _submitting ? null : _submitUtrManually,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Form'),
                onPressed: () {
                  _countdownTimer?.cancel();
                  _statusPollTimer?.cancel();
                  setState(() => _step = CollectStep.form);
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry QR Payment'),
                onPressed: _generateDynamicQr,
              ),
            ],
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // DIRECT BANK TRANSFER INSTRUCTIONS VIEW
  // =========================================================================

  Widget _buildBankTransferView(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_rounded, color: Color(0xFF0D9488), size: 20),
                SizedBox(width: 8),
                Text('Direct Bank Transfer (NEFT/RTGS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        const Divider(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INSTITUTION RECEIVING ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
              const SizedBox(height: 8),
              _bankRow('Beneficiary', 'Shami Innovation Academy', isDark),
              _bankRow('Bank Name', 'State Bank of India', isDark),
              _bankRow('Account No.', '39871234567', isDark, copyable: true),
              _bankRow('IFSC Code', 'SBIN0001234', isDark, copyable: true),
              _bankRow('Account Type', 'Current Account', isDark),
              _bankRow('Branch', 'Main Campus Branch', isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text('Enter Transfer Reference / UTR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: _refController,
          decoration: InputDecoration(
            hintText: 'e.g. UTR-98218921892',
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = CollectStep.form),
              child: const Text('Back to Form'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Record Bank Transfer'),
              onPressed: _submitting ? null : _submitOfflinePayment,
            ),
          ],
        ),
      ],
    );
  }

  Widget _bankRow(String label, String value, bool isDark, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              if (copyable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!'), duration: const Duration(seconds: 1)));
                  },
                  child: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
