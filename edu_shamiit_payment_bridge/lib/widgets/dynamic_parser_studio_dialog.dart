import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

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

  // Onboarded / Monitored Apps list
  List<Map<String, String>> _availableApps = [];
  bool _isLoadingApps = false;

  // Extracted Results State
  bool _hasTested = false;
  String _extractedAmount = '';
  String _extractedSender = '';
  String _extractedRef = '';
  String _extractedBank = '';
  String _extractedType = '';
  bool _isSuccess = false;
  String? _parseError;

  // Rule state (CRUD tracking)
  bool _hasCustomRulesActive = false;
  bool _isSaving = false;
  bool _isDeleting = false;

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

    // Auto-run test and load dynamic apps on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDynamicApps();
      _loadExistingFormatsForPackage(widget.initialPackage);
    });
  }

  Future<void> _loadDynamicApps() async {
    setState(() => _isLoadingApps = true);
    final List<Map<String, String>> appsList = [
      {'name': 'PhonePe', 'pkg': 'com.phonepe.app'},
      {'name': 'Google Pay', 'pkg': 'com.google.android.apps.nbu.paisa.user'},
      {'name': 'Paytm', 'pkg': 'net.one97.paytm'},
      {'name': 'BHIM UPI', 'pkg': 'in.org.npci.upiapp'},
      {'name': 'Cred', 'pkg': 'com.dreamplug.androidapp'},
    ];

    try {
      final remoteApps = await ApiService().getMonitoredApps();
      for (final app in remoteApps) {
        if (!appsList.any((a) => a['pkg'] == app.packageName)) {
          appsList.add({'name': app.name, 'pkg': app.packageName});
        }
      }
    } catch (_) {}

    // Universal fallback
    if (!appsList.any((a) => a['pkg'] == '*')) {
      appsList.add({'name': 'All Other Apps (*)', 'pkg': '*'});
    }

    if (mounted) {
      setState(() {
        _availableApps = appsList;
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _loadExistingFormatsForPackage(String pkg) async {
    final formats = await PlatformBridge.getCustomFormats();
    final cleanPkg = pkg.trim();
    bool found = false;

    if (formats.containsKey('${cleanPkg}_amount')) {
      _amountRegexCtrl.text = formats['${cleanPkg}_amount']!;
      found = true;
    }
    if (formats.containsKey('${cleanPkg}_sender')) {
      _senderRegexCtrl.text = formats['${cleanPkg}_sender']!;
      found = true;
    }
    if (formats.containsKey('${cleanPkg}_reference')) {
      _refRegexCtrl.text = formats['${cleanPkg}_reference']!;
      found = true;
    }
    if (formats.containsKey('${cleanPkg}_masked')) {
      _bankRegexCtrl.text = formats['${cleanPkg}_masked']!;
      found = true;
    }

    // Also check backend custom parsers in DB
    if (!found) {
      try {
        final serverParsers = await ApiService().getCustomParsers();
        final match = serverParsers.firstWhere(
          (p) => p['package_name'] == cleanPkg,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          if (match['amount_regex'] != null && match['amount_regex'].toString().isNotEmpty) {
            _amountRegexCtrl.text = match['amount_regex'].toString();
            found = true;
          }
          if (match['sender_regex'] != null && match['sender_regex'].toString().isNotEmpty) {
            _senderRegexCtrl.text = match['sender_regex'].toString();
            found = true;
          }
          if (match['reference_regex'] != null && match['reference_regex'].toString().isNotEmpty) {
            _refRegexCtrl.text = match['reference_regex'].toString();
            found = true;
          }
          if (match['bank_regex'] != null && match['bank_regex'].toString().isNotEmpty) {
            _bankRegexCtrl.text = match['bank_regex'].toString();
            found = true;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _hasCustomRulesActive = found;
      });
      _runParserTest();
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
      } else if (appName == 'Cred') {
        _packageCtrl.text = 'com.dreamplug.androidapp';
        _titleCtrl.text = 'CRED';
        _descriptionCtrl.text = 'Payment of ₹2 received from KM NEHA GOSWAMI on CRED to State Bank of India account. UTR: 432109876543';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+on|\s+to|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:UTR:?|Ref(?:erence)?:?|Txn(?:Id)?:?)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:to|on)\s+([A-Za-z0-9\s-]+?)\s+account|(\*+\s*\d{3,4})';
      } else if (appName == 'BHIM UPI') {
        _packageCtrl.text = 'in.org.npci.upiapp';
        _titleCtrl.text = 'BHIM';
        _descriptionCtrl.text = 'You have received ₹100.00 from Naresh King UPI Ref 9876543210';
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref|UTR)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(\*+\s*\d{3,4})';
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
    _loadExistingFormatsForPackage(_packageCtrl.text.trim());
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

    setState(() => _isSaving = true);

    try {
      // 1. Save to Android Local SharedPreferences
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

      // 2. Persist to Backend DB for cloud sync
      final appName = _availableApps.firstWhere(
        (a) => a['pkg'] == pkg,
        orElse: () => {'name': 'Custom App', 'pkg': pkg},
      )['name'];

      await ApiService().saveCustomParser(
        packageName: pkg,
        appName: appName,
        amountRegex: _amountRegexCtrl.text.trim(),
        senderRegex: _senderRegexCtrl.text.trim(),
        referenceRegex: _refRegexCtrl.text.trim(),
        bankRegex: _bankRegexCtrl.text.trim(),
      );

      setState(() {
        _hasCustomRulesActive = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parser formats saved & activated for $pkg!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving rules: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _deleteRules() async {
    final pkg = _packageCtrl.text.trim();
    if (pkg.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Custom Rules?'),
        content: Text('Delete custom parser rules for $pkg and revert to universal default matching?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete Rules'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await PlatformBridge.deleteCustomFormat(package: pkg);
      await ApiService().deleteCustomParser(pkg);

      // Restore default regexes
      _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
      _senderRegexCtrl.text = r'(?:Money received\s+)?([A-Za-z0-9\s.*]+?)\s+has sent|(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+Ref|\s+UPI|\s+to|\s*\(|$)';
      _refRegexCtrl.text = r'(?:Ref(?:erence)?:?|UTR:?|Txn(?:Id)?:?|UPI/)\s*([A-Za-z0-9/_-]+)';
      _bankRegexCtrl.text = r'bank account\s+([A-Za-z0-9\s-]+)|(\*+\s*\d{3,4})';

      setState(() {
        _hasCustomRulesActive = false;
        _isDeleting = false;
      });

      _runParserTest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom rules deleted for $pkg. Default parser restored.'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting rules: $e'), backgroundColor: AppColors.errorRed),
        );
      }
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        bottomInset + (bottomSafe > 0 ? bottomSafe + 16 : 24),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
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
                          'Configure & test live notification pattern matching for any UPI app',
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
                    // Dynamic App Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select App to Configure:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                        ),
                        if (_isLoadingApps)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _availableApps.map((a) {
                          final isSelected = _packageCtrl.text.trim() == a['pkg'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(a['name']!, style: const TextStyle(fontSize: 12)),
                              selected: isSelected,
                              selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                              avatar: Icon(
                                isSelected ? Icons.check_circle : Icons.apps,
                                size: 16,
                                color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  _applyTemplate(a['name']!);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Sample Presets Picker
                    const Text(
                      'Sample Format Templates:',
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
                          _buildPresetChip('Cred'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Google Pay'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Paytm'),
                          const SizedBox(width: 8),
                          _buildPresetChip('BHIM UPI'),
                          const SizedBox(width: 8),
                          _buildPresetChip('Bank SMS'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: Monitored Package with Active Rules Status
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _packageCtrl,
                            decoration: InputDecoration(
                              labelText: 'Application Package Name',
                              hintText: 'e.g. com.dreamplug.androidapp, com.phonepe.app, or *',
                              prefixIcon: const Icon(Icons.apps, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onChanged: (val) => _loadExistingFormatsForPackage(val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: _hasCustomRulesActive
                                ? AppColors.successGreen.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasCustomRulesActive
                                  ? AppColors.successGreen.withOpacity(0.4)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasCustomRulesActive ? 'CUSTOM RULES' : 'DEFAULT RULES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _hasCustomRulesActive ? AppColors.successGreen : AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                _hasCustomRulesActive ? 'Active in DB' : 'Universal Matcher',
                                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              hintText: 'e.g. Money received, CRED, Google Pay',
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
                      'Extraction Regex Rules (Customizable & Database Persisted):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(height: 10),
                    _buildRegexField('Amount Extraction Regex', _amountRegexCtrl, 'Captures amount in group 1'),
                    const SizedBox(height: 10),
                    _buildRegexField('Sender Name Regex', _senderRegexCtrl, 'Captures sender name'),
                    const SizedBox(height: 10),
                    _buildRegexField('Bank Account / Masked Identifier', _bankRegexCtrl, 'Captures destination bank or masked number'),
                    const SizedBox(height: 10),
                    _buildRegexField('Reference / UTR Regex', _refRegexCtrl, 'Captures transaction reference / UTR'),
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

                    // Section 4: Live Extraction Result (Fixed Overflow Bug)
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
                            // Responsive wrap to prevent 31px overflow on narrow screens
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                        fontSize: 13,
                                        color: _isSuccess ? AppColors.successGreen : AppColors.errorRed,
                                      ),
                                    ),
                                  ],
                                ),
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

            // Modal Footer Actions (Full CRUD: Reset/Delete + Save/Update + Cancel)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  if (_hasCustomRulesActive)
                    OutlinedButton.icon(
                      onPressed: _isDeleting ? null : _deleteRules,
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed),
                      label: Text(
                        _isDeleting ? 'Resetting...' : 'Reset Rules',
                        style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.errorRed),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveRules,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_isSaving ? 'Saving...' : 'Save & Activate Rules'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
