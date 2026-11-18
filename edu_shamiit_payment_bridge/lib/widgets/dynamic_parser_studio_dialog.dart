import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/platform_bridge.dart';
import '../services/api_service.dart';

class QueryConditionClause {
  String logicalOp; // 'AND', 'OR'
  String field; // 'title', 'body', 'title_or_body'
  String operator; // 'CONTAINS', 'NOT_CONTAINS', 'EQUALS', 'NOT_EQUALS', 'STARTS_WITH', 'ENDS_WITH', 'REGEX'
  String value;
  late TextEditingController valueController;

  QueryConditionClause({
    this.logicalOp = 'AND',
    this.field = 'body',
    this.operator = 'CONTAINS',
    this.value = '',
  }) {
    valueController = TextEditingController(text: value);
  }

  Map<String, dynamic> toJson() => {
    'logical_op': logicalOp,
    'field': field,
    'operator': operator,
    'value': valueController.text.trim(),
  };

  factory QueryConditionClause.fromJson(Map<String, dynamic> j) {
    return QueryConditionClause(
      logicalOp: j['logical_op']?.toString() ?? 'AND',
      field: j['field']?.toString() ?? 'body',
      operator: j['operator']?.toString() ?? 'CONTAINS',
      value: j['value']?.toString() ?? '',
    );
  }

  void dispose() {
    valueController.dispose();
  }
}

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

  // Azure DevOps Style Multi-Condition Rule Engine State
  String _ruleAction = 'ACCEPT_AND_PARSE'; // 'ACCEPT_AND_PARSE' or 'REJECT_AND_IGNORE'
  final List<QueryConditionClause> _queryClauses = [];
  bool _caseSensitive = false;

  // Regex Extraction Controllers
  late TextEditingController _amountRegexCtrl;
  late TextEditingController _senderRegexCtrl;
  late TextEditingController _refRegexCtrl;
  late TextEditingController _bankRegexCtrl;

  // Onboarded / Monitored Apps list
  List<Map<String, String>> _availableApps = [];
  bool _isLoadingApps = false;

  // Test Results State
  bool _hasTested = false;
  bool _queryRulesPassed = true;
  List<String> _clauseTestSteps = [];
  String _overallQueryVerdict = '';

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

    // Initial smart Azure-DevOps style rules
    _queryClauses.addAll([
      QueryConditionClause(
        logicalOp: 'AND',
        field: 'title_or_body',
        operator: 'NOT_CONTAINS',
        value: 'hold',
      ),
      QueryConditionClause(
        logicalOp: 'AND',
        field: 'title_or_body',
        operator: 'NOT_CONTAINS',
        value: 'offer',
      ),
      QueryConditionClause(
        logicalOp: 'AND',
        field: 'title_or_body',
        operator: 'NOT_CONTAINS',
        value: 'failed',
      ),
    ]);

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

  void _addClause({String logicalOp = 'AND', String field = 'body', String op = 'CONTAINS', String value = ''}) {
    setState(() {
      _queryClauses.add(QueryConditionClause(
        logicalOp: logicalOp,
        field: field,
        operator: op,
        value: value,
      ));
    });
    _runParserTest();
  }

  void _removeClause(int index) {
    if (index >= 0 && index < _queryClauses.length) {
      setState(() {
        _queryClauses[index].dispose();
        _queryClauses.removeAt(index);
      });
      _runParserTest();
    }
  }

  Future<void> _loadDynamicApps() async {
    setState(() => _isLoadingApps = true);
    final List<Map<String, String>> appsList = [
      {'name': 'PhonePe', 'pkg': 'com.phonepe.app'},
      {'name': 'Google Pay', 'pkg': 'com.google.android.apps.nbu.paisa.user'},
      {'name': 'Paytm', 'pkg': 'net.one97.paytm'},
      {'name': 'BHIM UPI', 'pkg': 'in.org.npci.upiapp'},
      {'name': 'Cred', 'pkg': 'com.dreamplug.androidapp'},
      {'name': 'Canara Bank SMS', 'pkg': 'com.android.mms'},
    ];

    try {
      final remoteApps = await ApiService().getMonitoredApps();
      for (final app in remoteApps) {
        if (!appsList.any((a) => a['pkg'] == app.packageName)) {
          appsList.add({'name': app.name, 'pkg': app.packageName});
        }
      }
    } catch (_) {}

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
    final cleanPkg = pkg.trim();
    bool found = false;

    // Load from local Android SharedPreferences
    final ruleMap = await PlatformBridge.getCustomRule(cleanPkg);
    if (ruleMap.isNotEmpty && ruleMap['amount_regex'] != null) {
      if (ruleMap['amount_regex'] != null) _amountRegexCtrl.text = ruleMap['amount_regex'].toString();
      if (ruleMap['sender_regex'] != null) _senderRegexCtrl.text = ruleMap['sender_regex'].toString();
      if (ruleMap['reference_regex'] != null) _refRegexCtrl.text = ruleMap['reference_regex'].toString();
      if (ruleMap['bank_regex'] != null) _bankRegexCtrl.text = ruleMap['bank_regex'].toString();
      if (ruleMap['case_sensitive'] != null) _caseSensitive = ruleMap['case_sensitive'] == true;

      if (ruleMap['rules_json'] != null && ruleMap['rules_json'].toString().isNotEmpty) {
        try {
          final decoded = json.decode(ruleMap['rules_json'].toString());
          _ruleAction = decoded['action'] ?? 'ACCEPT_AND_PARSE';
          final conds = decoded['conditions'] as List<dynamic>? ?? [];
          for (var c in _queryClauses) {
            c.dispose();
          }
          _queryClauses.clear();
          for (var c in conds) {
            _queryClauses.add(QueryConditionClause.fromJson(Map<String, dynamic>.from(c)));
          }
        } catch (_) {}
      }
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
          if (match['rules_json'] != null && match['rules_json'].toString().isNotEmpty) {
            try {
              final decoded = json.decode(match['rules_json'].toString());
              _ruleAction = decoded['action'] ?? 'ACCEPT_AND_PARSE';
              final conds = decoded['conditions'] as List<dynamic>? ?? [];
              for (var c in _queryClauses) {
                c.dispose();
              }
              _queryClauses.clear();
              for (var c in conds) {
                _queryClauses.add(QueryConditionClause.fromJson(Map<String, dynamic>.from(c)));
              }
            } catch (_) {}
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
      for (var c in _queryClauses) {
        c.dispose();
      }
      _queryClauses.clear();

      if (appName == 'PhonePe ("has sent")') {
        _packageCtrl.text = 'com.phonepe.app';
        _titleCtrl.text = 'Money received';
        _descriptionCtrl.text = 'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title', operator: 'CONTAINS', value: 'Money received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:Money received\s+)?([A-Za-z0-9\s.*]+?)\s+has sent';
        _bankRegexCtrl.text = r'bank account\s+([A-Za-z0-9\s-]+)';
        _refRegexCtrl.text = r'(?:Ref|UTR|UPI/)\s*([A-Za-z0-9/_-]+)';
      } else if (appName == 'Cred') {
        _packageCtrl.text = 'com.dreamplug.androidapp';
        _titleCtrl.text = 'CRED';
        _descriptionCtrl.text = 'Payment of ₹2 received from KM NEHA GOSWAMI on CRED to State Bank of India account. UTR: 432109876543';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'CONTAINS', value: 'CRED'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+on|\s+to|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:UTR:?|Ref(?:erence)?:?|Txn(?:Id)?:?)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:to|on)\s+([A-Za-z0-9\s-]+?)\s+account|(\*+\s*\d{3,4})';
      } else if (appName.contains('Canara') || appName == 'Bank SMS') {
        _packageCtrl.text = 'com.android.mms';
        _titleCtrl.text = 'AX-CANBNK-S';
        _descriptionCtrl.text = 'Dear Customer, your Canara Bank A/c ending XXXX2887 is credited by Rs 1,500.00 on 18-Nov-26 by Naresh King UPI Ref 432109876543.';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'credited'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:credited by|credit of|cr by|credited with)\s+(?:Rs\.?|INR|₹|\u20B9)?\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:by|from)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?|UTR)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:A/c|Account)\s*([*A-Za-z0-9]+)';
      } else {
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
      }
    });
    _runParserTest();
  }

  bool _evaluateSingleClause(String targetText, String op, String val) {
    if (val.isEmpty) return true;
    final t = _caseSensitive ? targetText : targetText.toLowerCase();
    final v = _caseSensitive ? val : val.toLowerCase();

    switch (op.toUpperCase()) {
      case 'EQUALS':
      case '=':
        return t.trim() == v.trim();
      case 'NOT_EQUALS':
      case '!=':
        return t.trim() != v.trim();
      case 'CONTAINS':
        return t.contains(v);
      case 'NOT_CONTAINS':
      case 'DOES_NOT_CONTAIN':
        return !t.contains(v);
      case 'STARTS_WITH':
        return t.startsWith(v);
      case 'ENDS_WITH':
        return t.endsWith(v);
      case 'REGEX':
        try {
          return RegExp(val, caseSensitive: _caseSensitive).hasMatch(targetText);
        } catch (_) {
          return false;
        }
      case 'NOT_REGEX':
        try {
          return !RegExp(val, caseSensitive: _caseSensitive).hasMatch(targetText);
        } catch (_) {
          return true;
        }
      default:
        return t.contains(v);
    }
  }

  void _runParserTest() {
    final title = _titleCtrl.text.trim();
    final desc = _descriptionCtrl.text.trim();
    final fullText = '$title $desc'.trim();

    try {
      // 1. Evaluate Azure-DevOps Style Multi-Condition Rule Engine
      final steps = <String>[];
      bool overallQueryMatch = false;

      if (_queryClauses.isEmpty) {
        overallQueryMatch = true;
        steps.add('No condition rules defined. Defaulting to MATCH.');
      } else {
        for (int i = 0; i < _queryClauses.length; i++) {
          final clause = _queryClauses[i];
          final val = clause.valueController.text.trim();
          final fieldStr = clause.field;
          final target = fieldStr == 'title' ? title : (fieldStr == 'body' ? desc : fullText);

          final clauseResult = _evaluateSingleClause(target, clause.operator, val);
          final statusBadge = clauseResult ? 'PASS' : 'FAIL';
          final opPrefix = i == 0 ? 'IF' : clause.logicalOp;

          steps.add('$opPrefix [$fieldStr] ${clause.operator} "$val" -> $statusBadge');

          if (i == 0) {
            overallQueryMatch = clauseResult;
          } else {
            if (clause.logicalOp == 'OR') {
              overallQueryMatch = overallQueryMatch || clauseResult;
            } else {
              overallQueryMatch = overallQueryMatch && clauseResult;
            }
          }
        }
      }

      final shouldAcceptAndParse = _ruleAction == 'REJECT_AND_IGNORE' ? !overallQueryMatch : overallQueryMatch;

      // 2. Regex Extraction
      final isDebit = fullText.contains(RegExp(r'\b(paid to|payment sent to|you sent|you have sent|transferred to|debited from)\b', caseSensitive: false));
      final detectedType = isDebit ? 'PAYMENT_SENT (Debit)' : 'PAYMENT_RECEIVED (Credit)';

      String amt = 'Not detected';
      final amtReg = RegExp(_amountRegexCtrl.text.trim(), caseSensitive: _caseSensitive);
      final amtMatch = amtReg.firstMatch(fullText);
      if (amtMatch != null) {
        amt = '₹${amtMatch.group(1)?.replaceAll(',', '') ?? ''}';
      }

      String sender = 'Not detected';
      final senderReg = RegExp(_senderRegexCtrl.text.trim(), caseSensitive: _caseSensitive);
      final senderMatch = senderReg.firstMatch(fullText);
      if (senderMatch != null) {
        sender = (senderMatch.group(1) ?? senderMatch.group(2) ?? senderMatch.group(0) ?? '').trim();
      }

      String ref = 'Not in notification (Lockscreen format)';
      final refReg = RegExp(_refRegexCtrl.text.trim(), caseSensitive: _caseSensitive);
      final refMatch = refReg.firstMatch(fullText);
      if (refMatch != null) {
        ref = refMatch.group(1) ?? refMatch.group(0) ?? '';
      }

      String bank = 'Not detected';
      final bankReg = RegExp(_bankRegexCtrl.text.trim(), caseSensitive: _caseSensitive);
      final bankMatch = bankReg.firstMatch(fullText);
      if (bankMatch != null) {
        bank = (bankMatch.group(1) ?? bankMatch.group(2) ?? bankMatch.group(0) ?? '').trim();
      }

      final isSuccess = shouldAcceptAndParse && amt != 'Not detected';
      final verdict = shouldAcceptAndParse
          ? (amt != 'Not detected' ? 'VALID PAYMENT DETECTED (Rules Passed & Extracted)' : 'RULES PASSED but Amount Regex did not match')
          : 'IGNORED / FILTERED OUT BY AZURE DEVOPS QUERY RULES';

      setState(() {
        _hasTested = true;
        _queryRulesPassed = shouldAcceptAndParse;
        _clauseTestSteps = steps;
        _overallQueryVerdict = verdict;
        _extractedType = detectedType;
        _extractedAmount = amt;
        _extractedSender = sender;
        _extractedRef = ref;
        _extractedBank = bank;
        _isSuccess = isSuccess;
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
      // Serialize Azure-DevOps style query rules to JSON
      final rulesData = {
        'action': _ruleAction,
        'conditions': _queryClauses.map((c) => c.toJson()).toList(),
      };
      final rulesJsonStr = json.encode(rulesData);

      // 1. Save all rules to Android Local SharedPreferences
      await PlatformBridge.saveCustomFormatFull(
        package: pkg,
        rulesJson: rulesJsonStr,
        amountRegex: _amountRegexCtrl.text.trim(),
        senderRegex: _senderRegexCtrl.text.trim(),
        referenceRegex: _refRegexCtrl.text.trim(),
        bankRegex: _bankRegexCtrl.text.trim(),
        caseSensitive: _caseSensitive,
      );

      // 2. Persist to Backend DB for cloud sync
      final appName = _availableApps.firstWhere(
        (a) => a['pkg'] == pkg,
        orElse: () => {'name': 'Custom App', 'pkg': pkg},
      )['name'];

      await ApiService().saveCustomParser(
        packageName: pkg,
        appName: appName,
        rulesJson: rulesJsonStr,
        amountRegex: _amountRegexCtrl.text.trim(),
        senderRegex: _senderRegexCtrl.text.trim(),
        referenceRegex: _refRegexCtrl.text.trim(),
        bankRegex: _bankRegexCtrl.text.trim(),
        caseSensitive: _caseSensitive,
      );

      setState(() {
        _hasCustomRulesActive = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Custom Azure-style query rules activated for $pkg!'),
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

      for (var c in _queryClauses) {
        c.dispose();
      }
      _queryClauses.clear();
      _ruleAction = 'ACCEPT_AND_PARSE';
      _caseSensitive = false;
      _queryClauses.addAll([
        QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'hold'),
        QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'offer'),
      ]);

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
    for (var c in _queryClauses) {
      c.dispose();
    }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // 1. Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.primaryNavy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dynamic Message Parser Studio',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Multi-Step Query & Quality Rule Engine (Azure DevOps style)',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
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

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Selector
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
                                label: Text(a['name']!, style: const TextStyle(fontSize: 11)),
                                selected: isSelected,
                                selectedColor: const Color(0xFFE0E7FF),
                                avatar: Icon(
                                  isSelected ? Icons.check_circle : Icons.apps,
                                  size: 15,
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
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('PhonePe ("has sent")'),
                            const SizedBox(width: 6),
                            _buildPresetChip('Cred'),
                            const SizedBox(width: 6),
                            _buildPresetChip('Canara Bank SMS'),
                            const SizedBox(width: 6),
                            _buildPresetChip('Google Pay'),
                            const SizedBox(width: 6),
                            _buildPresetChip('Paytm'),
                            const SizedBox(width: 6),
                            _buildPresetChip('BHIM UPI'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 1: Monitored Package
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _packageCtrl,
                              decoration: InputDecoration(
                                labelText: 'Application Package Name',
                                hintText: 'e.g. com.dreamplug.androidapp, com.phonepe.app, or *',
                                prefixIcon: const Icon(Icons.apps, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                              onChanged: (val) => _loadExistingFormatsForPackage(val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _hasCustomRulesActive
                                  ? const Color(0xFFDCFCE7)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasCustomRulesActive
                                    ? const Color(0xFF86EFAC)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasCustomRulesActive ? 'CUSTOM ACTIVE' : 'DEFAULT RULES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _hasCustomRulesActive ? AppColors.successGreen : AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  _hasCustomRulesActive ? 'Stored in DB' : 'Universal Matcher',
                                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Input Title & Message
                      Container(
                        padding: const EdgeInsets.all(12),
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
                                  'Live Incoming Notification Sample (To Test)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _titleCtrl,
                              decoration: InputDecoration(
                                labelText: 'Notification Title',
                                hintText: 'e.g. Money received, AX-CANBNK-S, Google Pay',
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
                                labelText: 'Notification Body / Description',
                                hintText: 'e.g. KM NEHA GOSWAMI has sent ₹2 or An amount of INR 26,700 kept on hold...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (_) => _runParserTest(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // =======================================================
                      // SECTION 3: AZURE DEVOPS STYLE MULTI-CONDITION RULE ENGINE
                      // =======================================================
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.rule_rounded, size: 18, color: AppColors.primaryBlue),
                                    SizedBox(width: 6),
                                    Text(
                                      'Query Condition Rules (Azure DevOps Style)',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppColors.primaryBlue, size: 22),
                                  tooltip: 'Add Condition Clause',
                                  onPressed: () => _addClause(),
                                ),
                              ],
                            ),
                            const Text(
                              'Combine AND / OR / NOT conditions on Title & Body to filter on-hold bank SMS, loan offers & failed payments',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),

                            // Action Selector
                            Row(
                              children: [
                                const Text('Action when matched:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _ruleAction,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'ACCEPT_AND_PARSE',
                                        child: Text('ACCEPT & Extract Payment', style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.bold)),
                                      ),
                                      DropdownMenuItem(
                                        value: 'REJECT_AND_IGNORE',
                                        child: Text('REJECT & Ignore Message', style: TextStyle(fontSize: 11, color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _ruleAction = val ?? 'ACCEPT_AND_PARSE');
                                      _runParserTest();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Clause Rows
                            ..._queryClauses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final clause = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Logical Operator (AND / OR) for clauses after the first
                                        if (index > 0) ...[
                                          SizedBox(
                                            width: 70,
                                            child: DropdownButtonFormField<String>(
                                              value: clause.logicalOp,
                                              isDense: true,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              ),
                                              items: const [
                                                DropdownMenuItem(value: 'AND', child: Text('AND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue))),
                                                DropdownMenuItem(value: 'OR', child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple))),
                                              ],
                                              onChanged: (val) {
                                                setState(() => clause.logicalOp = val ?? 'AND');
                                                _runParserTest();
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ] else ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('WHERE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                                          ),
                                          const SizedBox(width: 6),
                                        ],

                                        // Field Dropdown
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<String>(
                                            value: clause.field,
                                            isDense: true,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'title', child: Text('Title', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'body', child: Text('Body / Text', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'title_or_body', child: Text('Title OR Body', style: TextStyle(fontSize: 11))),
                                            ],
                                            onChanged: (val) {
                                              setState(() => clause.field = val ?? 'body');
                                              _runParserTest();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Operator Dropdown
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String>(
                                            value: clause.operator,
                                            isDense: true,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'CONTAINS', child: Text('Contains', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'NOT_CONTAINS', child: Text('Does Not Contain (NOT)', style: TextStyle(fontSize: 11, color: AppColors.errorRed))),
                                              DropdownMenuItem(value: 'EQUALS', child: Text('Equals (=)', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'NOT_EQUALS', child: Text('Does Not Equal (!=)', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'STARTS_WITH', child: Text('Starts With', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'ENDS_WITH', child: Text('Ends With', style: TextStyle(fontSize: 11))),
                                              DropdownMenuItem(value: 'REGEX', child: Text('Matches Regex', style: TextStyle(fontSize: 11))),
                                            ],
                                            onChanged: (val) {
                                              setState(() => clause.operator = val ?? 'CONTAINS');
                                              _runParserTest();
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _removeClause(index),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: clause.valueController,
                                      decoration: InputDecoration(
                                        hintText: 'Keyword or pattern (e.g. hold, Money received, offer, credited)',
                                        hintStyle: const TextStyle(fontSize: 11),
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => _runParserTest(),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Add Clause & Quick Presets
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _addClause(),
                                  icon: const Icon(Icons.add, size: 15),
                                  label: const Text('Add Condition (+)', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    const Text('Case-Sensitive:', style: TextStyle(fontSize: 10)),
                                    Switch(
                                      value: _caseSensitive,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) {
                                        setState(() => _caseSensitive = val);
                                        _runParserTest();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 4: Regex Extraction Rules
                      const Text(
                        'Extraction Regex Rules (Customizable & Database Persisted):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                      ),
                      const SizedBox(height: 8),
                      _buildRegexField('Amount Extraction Regex', _amountRegexCtrl, 'Captures amount in group 1'),
                      const SizedBox(height: 8),
                      _buildRegexField('Sender Name Regex', _senderRegexCtrl, 'Captures sender name'),
                      const SizedBox(height: 8),
                      _buildRegexField('Bank Account / Masked Identifier', _bankRegexCtrl, 'Captures destination bank or masked number'),
                      const SizedBox(height: 8),
                      _buildRegexField('Reference / UTR Regex', _refRegexCtrl, 'Captures transaction reference / UTR'),
                      const SizedBox(height: 14),

                      // Test Action Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _runParserTest,
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('Evaluate Query Rules & Test Parser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),

                      // Test Results Card
                      if (_hasTested) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isSuccess
                                ? const Color(0xFFF0FDF4)
                                : (_queryRulesPassed ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isSuccess
                                  ? const Color(0xFF86EFAC)
                                  : (_queryRulesPassed ? const Color(0xFFFDE68A) : const Color(0xFFFCA5A5)),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isSuccess
                                        ? Icons.check_circle_rounded
                                        : (_queryRulesPassed ? Icons.warning_amber_rounded : Icons.block),
                                    size: 18,
                                    color: _isSuccess
                                        ? AppColors.successGreen
                                        : (_queryRulesPassed ? const Color(0xFFD97706) : AppColors.errorRed),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _overallQueryVerdict,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _isSuccess
                                            ? AppColors.successGreen
                                            : (_queryRulesPassed ? const Color(0xFFB45309) : AppColors.errorRed),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 14),

                              // Clause By Clause Breakdown
                              const Text('Clause Evaluation Breakdown:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              ..._clauseTestSteps.map((step) {
                                final isPass = step.endsWith('PASS');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                                  child: Row(
                                    children: [
                                      Icon(isPass ? Icons.check : Icons.close, size: 12, color: isPass ? AppColors.successGreen : AppColors.errorRed),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          step,
                                          style: TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: isPass ? const Color(0xFF14532D) : AppColors.errorRed),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const Divider(height: 14),
                              _buildResultRow('Action Decision', _queryRulesPassed ? 'ACCEPT & PARSE' : 'IGNORE / DISCARD', isHighlight: _isSuccess),
                              _buildResultRow('Detected Status', _isSuccess ? 'ACCEPTED (Credit)' : 'REJECTED / IGNORED', isHighlight: _isSuccess),
                              _buildResultRow('Event Classification', _extractedType),
                              _buildResultRow('Detected Amount', _extractedAmount, isHighlight: _isSuccess),
                              _buildResultRow('Sender Name', _extractedSender),
                              _buildResultRow('Bank Account', _extractedBank),
                              _buildResultRow('Reference / UTR', _extractedRef),
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

              // 3. Responsive Modal Footer Actions (No horizontal overflow!)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Save Button (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveRules,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_isSaving ? 'Saving Rules...' : 'Save & Activate Rules'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Secondary Buttons Row (Reset + Cancel)
                    Row(
                      children: [
                        if (_hasCustomRulesActive)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isDeleting ? null : _deleteRules,
                              icon: const Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed),
                              label: Text(
                                _isDeleting ? 'Resetting...' : 'Reset Rules',
                                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.errorRed),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        if (_hasCustomRulesActive) const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
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
