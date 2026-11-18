import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';

class DynamicParserStudioDialog extends StatefulWidget {
  final String initialPackage;
  final String? initialTitle;
  final String? initialDescription;
  final VoidCallback? onSaved;

  const DynamicParserStudioDialog({
    super.key,
    this.initialPackage = 'com.phonepe.app',
    this.initialTitle,
    this.initialDescription,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    String initialPackage = 'com.phonepe.app',
    String? initialTitle,
    String? initialDescription,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DynamicParserStudioDialog(
        initialPackage: initialPackage,
        initialTitle: initialTitle,
        initialDescription: initialDescription,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<DynamicParserStudioDialog> createState() => _DynamicParserStudioDialogState();
}

class _DynamicParserStudioDialogState extends State<DynamicParserStudioDialog> {
  late TextEditingController _packageCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _amountRegexCtrl;
  late TextEditingController _senderRegexCtrl;
  late TextEditingController _refRegexCtrl;
  late TextEditingController _bankRegexCtrl;

  // Extracted Results State
  bool _hasTested = false;
  String _extractedAmount = '';
  String _extractedSender = '';
  String _extractedRef = '';
  String _extractedBank = '';
  String _extractedType = '';
  bool _isSuccess = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _packageCtrl = TextEditingController(text: widget.initialPackage);
    _titleCtrl = TextEditingController(
      text: widget.initialTitle ?? 'Money received',
    );
    _descriptionCtrl = TextEditingController(
      text: widget.initialDescription ??
          'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686',
    );

    // Default universal robust regexes
    _amountRegexCtrl = TextEditingController(
      text: r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    );
    _senderRegexCtrl = TextEditingController(
      text: r'(?:Money received\s+)?([A-Za-z0-9\s.*]+?)\s+has sent|(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+Ref|\s+UPI|\s+to|\s*\(|$)',
    );
    _refRegexCtrl = TextEditingController(
      text: r'(?:Ref(?:erence)?:?|UTR:?|Txn(?:Id)?:?|UPI/)\s*([A-Za-z0-9/_-]+)',
    );
    _bankRegexCtrl = TextEditingController(
      text: r'bank account\s+([A-Za-z0-9\s-]+)|(\*+\s*\d{3,4})',
    );

    // Auto-run test on open if inputs are provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingFormats();
      _runParserTest();
    });
  }

  Future<void> _loadExistingFormats() async {
    final formats = await PlatformBridge.getCustomFormats();
    final pkg = _packageCtrl.text.trim();
    if (formats.containsKey('${pkg}_amount')) {
      _amountRegexCtrl.text = formats['${pkg}_amount']!;
    }
    if (formats.containsKey('${pkg}_sender')) {
      _senderRegexCtrl.text = formats['${pkg}_sender']!;
    }
    if (formats.containsKey('${pkg}_reference')) {
      _refRegexCtrl.text = formats['${pkg}_reference']!;
    }
    if (formats.containsKey('${pkg}_masked')) {
      _bankRegexCtrl.text = formats['${pkg}_masked']!;
    }
  }

  void _applyTemplate(String appName) {
    setState(() {
      if (appName == 'PhonePe ("has sent")') {
        _packageCtrl.text = 'com.phonepe.app';
        _titleCtrl.text = 'Money received';
        _descriptionCtrl.text = 'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:Money received\s+)?([A-Za-z0-9\s.*]+?)\s+has sent';
        _bankRegexCtrl.text = r'bank account\s+([A-Za-z0-9\s-]+)';
        _refRegexCtrl.text = r'(?:Ref|UTR|UPI/)\s*([A-Za-z0-9/_-]+)';
      } else if (appName == 'PhonePe ("received from")') {
        _packageCtrl.text = 'com.phonepe.app';
        _titleCtrl.text = 'Payment received';
        _descriptionCtrl.text = 'Payment received of ₹500.00 from Naresh King Ref: UPI/202611181234';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+Ref|\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?:?|UTR:?|Txn(?:Id)?:?|UPI/)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(\*+\s*\d{3,4})';
      } else if (appName == 'Google Pay') {
        _packageCtrl.text = 'com.google.android.apps.nbu.paisa.user';
        _titleCtrl.text = 'Google Pay';
        _descriptionCtrl.text = 'Received ₹1,500.00 from Aarav Sharma via UPI (UPI Ref: 432198765432)';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+via|\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?:?|UTR:?|UPI\s+Ref:?)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(\*+\s*\d{3,4})';
      } else if (appName == 'Paytm') {
        _packageCtrl.text = 'net.one97.paytm';
        _titleCtrl.text = 'Paytm Payments';
        _descriptionCtrl.text = 'Received ₹500 in your Paytm Payments Bank account from Rohan UPI Ref 987654321098';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref|UTR)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'Paytm Payments Bank|(\*+\s*\d{3,4})';
      } else if (appName == 'Bank SMS') {
        _packageCtrl.text = 'com.google.android.apps.messaging';
        _titleCtrl.text = 'SBI SMS (VM-SBIUPI)';
        _descriptionCtrl.text = 'Dear SBI User, your A/c ****1686 is credited by Rs 2.00 on 18-Nov-26 by KM NEHA GOSWAMI UPI Ref 432109876543.';
        _amountRegexCtrl.text = r'(?:credited by|credit of|cr by)\s+(?:Rs\.?|INR|₹|\u20B9)?\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:by|from)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?|UTR)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:A/c|Account)\s*([*A-Za-z0-9]+)';
      }
    });
    _runParserTest();
  }

  void _runParserTest() {
    final title = _titleCtrl.text.trim();
    final desc = _descriptionCtrl.text.trim();
    final fullText = '$title $desc'.trim();

    try {
      // 1. Debit/Credit Check
      final isDebit = fullText.contains(RegExp(r'\b(paid to|payment sent to|you sent|you have sent|transferred to|debited from)\b', caseSensitive: false));
      final detectedType = isDebit ? 'PAYMENT_SENT (Debit)' : 'PAYMENT_RECEIVED (Credit)';

      // 2. Amount Extraction
      String amt = 'Not detected';
      final amtReg = RegExp(_amountRegexCtrl.text.trim(), caseSensitive: false);
      final amtMatch = amtReg.firstMatch(fullText);
      if (amtMatch != null) {
        amt = '₹${amtMatch.group(1)?.replaceAll(',', '') ?? ''}';
      }

      // 3. Sender Extraction
      String sender = 'Not detected';
      final senderReg = RegExp(_senderRegexCtrl.text.trim(), caseSensitive: false);
      final senderMatch = senderReg.firstMatch(fullText);
      if (senderMatch != null) {
        sender = (senderMatch.group(1) ?? senderMatch.group(2) ?? senderMatch.group(0) ?? '').trim();
      }

      // 4. Reference Extraction
      String ref = 'Not in notification (Lockscreen format)';
      final refReg = RegExp(_refRegexCtrl.text.trim(), caseSensitive: false);
      final refMatch = refReg.firstMatch(fullText);
      if (refMatch != null) {
        ref = refMatch.group(1) ?? refMatch.group(0) ?? '';
      }

      // 5. Bank / Masked Identifier
      String bank = 'Not detected';
      final bankReg = RegExp(_bankRegexCtrl.text.trim(), caseSensitive: false);
      final bankMatch = bankReg.firstMatch(fullText);
      if (bankMatch != null) {
        bank = (bankMatch.group(1) ?? bankMatch.group(2) ?? bankMatch.group(0) ?? '').trim();
      }

      setState(() {
        _hasTested = true;
        _extractedType = detectedType;
        _extractedAmount = amt;
        _extractedSender = sender;
        _extractedRef = ref;
        _extractedBank = bank;
        _isSuccess = amt != 'Not detected';
        _parseError = null;
      });
    } catch (e) {
      setState(() {
        _hasTested = true;
        _isSuccess = false;
        _parseError = e.toString();
      });
    }
  }

  Future<void> _saveRules() async {
    final pkg = _packageCtrl.text.trim();
    if (pkg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a package name')),
      );
      return;
    }

    await PlatformBridge.setCustomFormat(
      package: pkg,
      type: 'amount',
      regex: _amountRegexCtrl.text.trim(),
    );
    await PlatformBridge.setCustomFormat(
      package: pkg,
      type: 'sender',
      regex: _senderRegexCtrl.text.trim(),
    );
    await PlatformBridge.setCustomFormat(
      package: pkg,
      type: 'reference',
      regex: _refRegexCtrl.text.trim(),
    );
    await PlatformBridge.setCustomFormat(
      package: pkg,
      type: 'masked',
      regex: _bankRegexCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parser formats saved for $pkg successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      widget.onSaved?.call();
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _packageCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountRegexCtrl.dispose();
    _senderRegexCtrl.dispose();
    _refRegexCtrl.dispose();
    _bankRegexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic Message Parser Studio',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Configure & test live notification pattern matching',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preset Quick Pickers
                    const Text(
                      'Quick Presets:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('PhonePe ("has sent")'),
                          const SizedBox(width: 8),
                          _buildPresetChip('PhonePe ("received from")'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Google Pay'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Paytm'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Bank SMS'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Monitored Package
                    TextFormField(
                      controller: _packageCtrl,
                      decoration: InputDecoration(
                        labelText: 'Application Package Name',
                        hintText: 'e.g. com.phonepe.app or * for all',
                        prefixIcon: const Icon(Icons.apps, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Input Title & Message
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mark_chat_unread_outlined, size: 16, color: AppColors.primaryBlue),
                              SizedBox(width: 6),
                              Text(
                                'Sample Incoming Notification',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleCtrl,
                            decoration: InputDecoration(
                              labelText: 'Notification Message Title',
                              hintText: 'e.g. Money received',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => _runParserTest(),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _descriptionCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Notification Message Description / Body',
                              hintText: 'e.g. KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (_) => _runParserTest(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Extraction Regex Rules
                    const Text(
                      'Extraction Regex Rules (Customizable):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(height: 10),
                    _buildRegexField('Amount Extraction Regex', _amountRegexCtrl, 'Captures amount in group 1'),
                    const SizedBox(height: 10),
                    _buildRegexField('Sender Name Regex', _senderRegexCtrl, 'Captures sender name'),
                    const SizedBox(height: 10),
                    _buildRegexField('Bank Account / Masked Identifier', _bankRegexCtrl, 'Captures destination bank'),
                    const SizedBox(height: 10),
                    _buildRegexField('Reference / UTR Regex', _refRegexCtrl, 'Captures transaction reference'),
                    const SizedBox(height: 16),

                    // Test Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _runParserTest,
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Apply Parser to Message & Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Live Extraction Result
                    if (_hasTested) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isSuccess ? AppColors.successGreen.withOpacity(0.08) : AppColors.errorRed.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isSuccess ? AppColors.successGreen.withOpacity(0.3) : AppColors.errorRed.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  color: _isSuccess ? AppColors.successGreen : AppColors.errorRed,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSuccess ? 'Extraction Successful' : 'Extraction Incomplete',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _isSuccess ? AppColors.successGreen : AppColors.errorRed,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _extractedType.contains('Credit') ? AppColors.successGreen : Colors.orange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _extractedType,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _buildResultRow('Detected Amount', _extractedAmount, isHighlight: true),
                            _buildResultRow('Sender Name', _extractedSender),
                            _buildResultRow('Bank Account', _extractedBank),
                            _buildResultRow('Transaction Ref / UTR', _extractedRef),
                            if (_parseError != null) ...[
                              const SizedBox(height: 8),
                              Text('Regex Error: $_parseError', style: const TextStyle(color: AppColors.errorRed, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveRules,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save & Activate Rules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String title) {
    return ActionChip(
      label: Text(title, style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () => _applyTemplate(title),
    );
  }

  Widget _buildRegexField(String label, TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperStyle: const TextStyle(fontSize: 10),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (_) => _runParserTest(),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? AppColors.successGreen : AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
