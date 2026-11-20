import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/platform_bridge.dart';
import '../services/api_service.dart';

class QueryConditionClause {
  String logicalOp; // 'AND', 'OR'
  String field; // 'title', 'body', 'title_or_body'
  String operator; // 'CONTAINS', 'NOT_CONTAINS', 'EQUALS', 'NOT_EQUALS', 'STARTS_WITH', 'ENDS_WITH', 'REGEX', 'NOT_REGEX'
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

class _DynamicParserStudioDialogState extends State<DynamicParserStudioDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late TextEditingController _packageCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;

  // Multi-Condition Rule Engine State
  String _ruleAction = 'ACCEPT_AND_PARSE'; // 'ACCEPT_AND_PARSE' or 'REJECT_AND_IGNORE'
  final List<QueryConditionClause> _queryClauses = [];
  bool _caseSensitive = false;

  // Regex Extraction Controllers
  late TextEditingController _amountRegexCtrl;
  late TextEditingController _senderRegexCtrl;
  late TextEditingController _refRegexCtrl;
  late TextEditingController _bankRegexCtrl;

  // Monitored Apps list
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
    _tabController = TabController(length: 3, vsync: this);

    _packageCtrl = TextEditingController(text: widget.initialPackage);
    _titleCtrl = TextEditingController(
      text: (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty)
          ? widget.initialTitle!.trim()
          : 'Money received',
    );
    _descriptionCtrl = TextEditingController(
      text: (widget.initialDescription != null && widget.initialDescription!.trim().isNotEmpty)
          ? widget.initialDescription!.trim()
          : (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty
              ? ''
              : 'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686'),
    );

    // Initial smart quality rules
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDynamicApps();
      _loadExistingFormatsForPackage(widget.initialPackage);
      if (widget.initialTitle != null || widget.initialDescription != null) {
        _tabController.animateTo(2);
        _runParserTest();
      }
    });
  }

  void _addClause({
    String logicalOp = 'AND',
    String field = 'body',
    String op = 'CONTAINS',
    String value = '',
  }) {
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
      {'name': 'Canara ai1 (Canara Bank)', 'pkg': 'com.canarabank.mobility'},
      {'name': 'SMS / Messages', 'pkg': 'com.google.android.apps.messaging'},
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

      if (appName.contains('PhonePe')) {
        _packageCtrl.text = 'com.phonepe.app';
        _titleCtrl.text = 'Money received';
        _descriptionCtrl.text = 'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title', operator: 'CONTAINS', value: 'Money received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:Money received\s+)?([A-Za-z0-9\s.*]+?)\s+has sent';
        _bankRegexCtrl.text = r'bank account\s+([A-Za-z0-9\s-]+)';
        _refRegexCtrl.text = r'(?:Ref|UTR|UPI/)\s*([A-Za-z0-9/_-]+)';
      } else if (appName.contains('Google Pay') || appName.contains('paisa')) {
        _packageCtrl.text = 'com.google.android.apps.nbu.paisa.user';
        _titleCtrl.text = 'Google Pay';
        _descriptionCtrl.text = 'Received ₹1,500.00 from Rahul Sharma via Google Pay UPI Ref: 438729106731';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'Received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'paid to'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+via|\s+Ref|\s+to|\s*\(|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?:?|UTR:?|Txn(?:Id)?:?|UPI/)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:to|on)\s+([A-Za-z0-9\s-]+?)\s+account|(\*+\s*\d{3,4})';
      } else if (appName.contains('Paytm')) {
        _packageCtrl.text = 'net.one97.paytm';
        _titleCtrl.text = 'Paytm Payments Bank';
        _descriptionCtrl.text = 'Received ₹3,200.00 from Amit Kumar. UPI Ref 439812739182.';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'Received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'cashback'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s*\.|\s+UPI|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?|UTR|UPI Ref)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'bank account\s+([A-Za-z0-9\s-]+)|(\*+\s*\d{3,4})';
      } else if (appName.contains('Cred')) {
        _packageCtrl.text = 'com.dreamplug.androidapp';
        _titleCtrl.text = 'CRED';
        _descriptionCtrl.text = 'Payment of ₹2 received from KM NEHA GOSWAMI on CRED to State Bank of India account. UTR: 432109876543';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'CONTAINS', value: 'CRED'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
        ]);
        _amountRegexCtrl.text = r'(?:Rs\.?|INR|₹|\u20B9)\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+on|\s+to|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:UTR:?|Ref(?:erence)?:?|Txn(?:Id)?:?)\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:to|on)\s+([A-Za-z0-9\s-]+?)\s+account|(\*+\s*\d{3,4})';
      } else if (appName.contains('Canara')) {
        _packageCtrl.text = 'com.canarabank.mobility';
        _titleCtrl.text = 'Canara ai1';
        _descriptionCtrl.text = 'UPI Payment of ₹2,500.00 received from NARESH KING. UPI Ref: 432109876543. Available Bal: ₹45,210.00';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'received'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:₹|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:by|from)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?|UTR|TxnId)\s*:?\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:A/c|Account)\s*([*A-Za-z0-9]+)';
      } else if (appName.contains('SMS') || appName.contains('Messages') || appName.contains('mms') || appName.contains('messaging')) {
        _packageCtrl.text = 'com.google.android.apps.messaging';
        _titleCtrl.text = 'Bank SMS Alert';
        _descriptionCtrl.text = 'Dear Customer, your A/c ending XXXX2887 is credited by Rs 2,500.00 on 18-Nov-26 by Naresh King UPI Ref 432109876543.';
        _ruleAction = 'ACCEPT_AND_PARSE';
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'CONTAINS', value: 'credited'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'offer'),
          QueryConditionClause(logicalOp: 'AND', field: 'body', operator: 'NOT_CONTAINS', value: 'failed'),
        ]);
        _amountRegexCtrl.text = r'(?:credited by|credit of|cr by|credited with)\s+(?:Rs\.?|INR|₹|\u20B9)?\s*([0-9,]+(?:\.[0-9]{1,2})?)';
        _senderRegexCtrl.text = r'(?:by|from)\s+([A-Za-z0-9\s.*]+?)(?:\s+UPI|\s+Ref|$)';
        _refRegexCtrl.text = r'(?:Ref(?:erence)?|UTR)\s*:?\s*([A-Za-z0-9/_-]+)';
        _bankRegexCtrl.text = r'(?:A/c|Account)\s*([*A-Za-z0-9]+)';
      } else {
        _queryClauses.addAll([
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'hold'),
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'failed'),
          QueryConditionClause(logicalOp: 'AND', field: 'title_or_body', operator: 'NOT_CONTAINS', value: 'offer'),
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
      // 1. Evaluate Multi-Condition Rule Engine
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
      final isDebit = fullText.contains(RegExp(
        r'\b(paid to|payment sent to|you sent|you have sent|transferred to|debited from)\b',
        caseSensitive: false,
      ));
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

      String ref = 'Not in notification';
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
          ? (amt != 'Not detected'
              ? 'VALID PAYMENT DETECTED (Rules Passed & Extracted)'
              : 'RULES PASSED (Payment accepted, but Amount Regex did not match)')
          : 'FILTERED OUT: Notification matched exclusion condition';

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
            content: Text('Custom parser rules activated for $pkg!'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
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
    _tabController.dispose();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // 1. Executive Gradient Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0x2EFFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Dynamic Message Parser Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Multi-Clause Quality Gates & Field Extractors',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Persistent Live Status Indicator Bar
              _buildLiveStatusBar(),

              // 3. Tab Bar
              Container(
                color: const Color(0xFFF1F5F9),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryBlue,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.filter_alt_rounded, size: 18),
                      text: 'Filter Rules (${_queryClauses.length})',
                    ),
                    const Tab(
                      icon: Icon(Icons.code_rounded, size: 18),
                      text: 'Field Extractors',
                    ),
                    Tab(
                      icon: Icon(
                        _isSuccess ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded,
                        size: 18,
                        color: _isSuccess ? AppColors.successGreen : null,
                      ),
                      text: 'Live Simulator',
                    ),
                  ],
                ),
              ),

              // 4. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQualityRulesTab(),
                    _buildRegexExtractorsTab(),
                    _buildSimulatorTab(),
                  ],
                ),
              ),

              // 5. Sticky Bottom Action Bar
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // LIVE STATUS BAR (Always visible below header)
  // =========================================================================
  Widget _buildLiveStatusBar() {
    final isMatch = _queryRulesPassed;
    final hasAmount = _extractedAmount != 'Not detected' && _extractedAmount.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _isSuccess
            ? const Color(0xFFECFDF5)
            : (isMatch ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
        border: Border(
          bottom: BorderSide(
            color: _isSuccess
                ? const Color(0xFFA7F3D0)
                : (isMatch ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess
                ? Icons.check_circle_rounded
                : (isMatch ? Icons.info_outline_rounded : Icons.block_rounded),
            size: 16,
            color: _isSuccess
                ? AppColors.successGreen
                : (isMatch ? const Color(0xFFD97706) : AppColors.errorRed),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isSuccess
                  ? 'VERIFIED: $_extractedAmount payment detected'
                  : (isMatch
                      ? (hasAmount ? 'Rules passed' : 'Rules passed • Amount regex not matched')
                      : 'FILTERED OUT: Notification rejected by quality rules'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: _isSuccess
                    ? const Color(0xFF065F46)
                    : (isMatch ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _tabController.animateTo(2),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Debug', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.primaryNavy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: FILTER RULES (QUALITY GATES)
  // =========================================================================
  Widget _buildQualityRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Template Selector
          Row(
            children: [
              const Icon(Icons.apps_rounded, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              const Text(
                'Target Application:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
              ),
              const Spacer(),
              if (_isLoadingApps)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableApps.map((a) {
                final isSelected = _packageCtrl.text.trim() == a['pkg'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(a['name']!, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFDBEAFE),
                    checkmarkColor: AppColors.primaryBlue,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
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

          // Custom Package Override
          TextFormField(
            controller: _packageCtrl,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Target Package Name',
              hintText: 'e.g. com.phonepe.app or * for all apps',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => _loadExistingFormatsForPackage(val),
          ),
          const SizedBox(height: 14),

          // Action Selector Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Execution Action when conditions match:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _ruleAction = 'ACCEPT_AND_PARSE');
                          _runParserTest();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _ruleAction == 'ACCEPT_AND_PARSE' ? const Color(0xFFECFDF5) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _ruleAction == 'ACCEPT_AND_PARSE' ? AppColors.successGreen : const Color(0xFFCBD5E1),
                              width: _ruleAction == 'ACCEPT_AND_PARSE' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: _ruleAction == 'ACCEPT_AND_PARSE' ? AppColors.successGreen : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'ACCEPT & Extract',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _ruleAction == 'ACCEPT_AND_PARSE' ? AppColors.successGreen : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _ruleAction = 'REJECT_AND_IGNORE');
                          _runParserTest();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: _ruleAction == 'REJECT_AND_IGNORE' ? const Color(0xFFFEF2F2) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _ruleAction == 'REJECT_AND_IGNORE' ? AppColors.errorRed : const Color(0xFFCBD5E1),
                              width: _ruleAction == 'REJECT_AND_IGNORE' ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 16,
                                color: _ruleAction == 'REJECT_AND_IGNORE' ? AppColors.errorRed : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'REJECT & Discard',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _ruleAction == 'REJECT_AND_IGNORE' ? AppColors.errorRed : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Condition Clauses Header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quality Filter Conditions',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                    Text(
                      'Combined with AND / OR logic',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Case-Match', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _caseSensitive,
                      onChanged: (val) {
                        setState(() => _caseSensitive = val);
                        _runParserTest();
                      },
                    ),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addClause(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Rule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Clauses List (Card Layout - No Overflow)
          if (_queryClauses.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No rules defined. All notifications from this package will be accepted.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._queryClauses.asMap().entries.map((entry) {
              final index = entry.key;
              final clause = entry.value;
              return _buildClauseCard(index, clause);
            }),

          const SizedBox(height: 10),

          // Quick Preset Buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPresetAddChip('Exclude "hold" SMS', 'body', 'NOT_CONTAINS', 'hold'),
              _buildPresetAddChip('Exclude "offer" Spam', 'body', 'NOT_CONTAINS', 'offer'),
              _buildPresetAddChip('Exclude "failed" Pay', 'body', 'NOT_CONTAINS', 'failed'),
              _buildPresetAddChip('Require "credited"', 'body', 'CONTAINS', 'credited'),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RESPONSIVE CLAUSE CARD (Structured layout that NEVER overflows)
  // =========================================================================
  Widget _buildClauseCard(int index, QueryConditionClause clause) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Logic Operator (WHERE / AND / OR) + Clause Index + Delete
            Row(
              children: [
                if (index == 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'WHERE',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: clause.logicalOp == 'AND' ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: clause.logicalOp == 'AND' ? AppColors.primaryBlue : Colors.purple,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: clause.logicalOp,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: clause.logicalOp == 'AND' ? AppColors.primaryBlue : Colors.purple,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'AND', child: Text('AND')),
                          DropdownMenuItem(value: 'OR', child: Text('OR')),
                        ],
                        onChanged: (val) {
                          setState(() => clause.logicalOp = val ?? 'AND');
                          _runParserTest();
                        },
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  'Condition #${index + 1}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.errorRed),
                  tooltip: 'Remove Clause',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeClause(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Middle Row: Target Field + Evaluation Operator (2 equal columns)
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: clause.field,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Field',
                      labelStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'title_or_body', child: Text('Title or Body', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'body', child: Text('Body Only', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'title', child: Text('Title Only', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (val) {
                      setState(() => clause.field = val ?? 'body');
                      _runParserTest();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: DropdownButtonFormField<String>(
                    value: clause.operator,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Operator',
                      labelStyle: const TextStyle(fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CONTAINS', child: Text('Contains', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'NOT_CONTAINS', child: Text('Does Not Contain', style: TextStyle(fontSize: 11.5, color: AppColors.errorRed))),
                      DropdownMenuItem(value: 'EQUALS', child: Text('Equals', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'NOT_EQUALS', child: Text('Does Not Equal', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'STARTS_WITH', child: Text('Starts With', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'ENDS_WITH', child: Text('Ends With', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'REGEX', child: Text('Matches Regex', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'NOT_REGEX', child: Text('No Regex Match', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (val) {
                      setState(() => clause.operator = val ?? 'CONTAINS');
                      _runParserTest();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bottom: Value/Pattern Input Field (Full Width)
            TextFormField(
              controller: clause.valueController,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Keyword or regex pattern (e.g. hold, offer, ₹)',
                labelText: 'Match Keyword / Value',
                labelStyle: const TextStyle(fontSize: 11),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                suffixIcon: clause.valueController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          clause.valueController.clear();
                          _runParserTest();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _runParserTest(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetAddChip(String label, String field, String op, String val) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 14, color: AppColors.primaryBlue),
      label: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.primaryNavy)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      onPressed: () => _addClause(field: field, op: op, value: val),
    );
  }

  // =========================================================================
  // TAB 2: FIELD EXTRACTORS (REGEX ENGINE)
  // =========================================================================
  Widget _buildRegexExtractorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryBlue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Regular expressions capture payment fields from notification text. Group 1 is extracted as the value.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildRegexFieldCard(
            title: '1. Amount Extraction Regex',
            subtitle: 'Captures transaction amount in rupees',
            controller: _amountRegexCtrl,
            icon: Icons.currency_rupee_rounded,
            sampleToken: r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          ),
          const SizedBox(height: 10),

          _buildRegexFieldCard(
            title: '2. Sender Name Regex',
            subtitle: 'Captures student / parent / payer name',
            controller: _senderRegexCtrl,
            icon: Icons.person_outline_rounded,
            sampleToken: r'(?:from|by)\s+([A-Za-z0-9\s.*]+?)(?:\s+Ref|$)',
          ),
          const SizedBox(height: 10),

          _buildRegexFieldCard(
            title: '3. Reference / UTR Regex',
            subtitle: 'Captures bank reference or UPI UTR number',
            controller: _refRegexCtrl,
            icon: Icons.tag_rounded,
            sampleToken: r'(?:Ref(?:erence)?:?|UTR:?|UPI/)\s*([A-Za-z0-9/_-]+)',
          ),
          const SizedBox(height: 10),

          _buildRegexFieldCard(
            title: '4. Bank Account / Masked Identifier',
            subtitle: 'Captures receiving bank or masked account digits',
            controller: _bankRegexCtrl,
            icon: Icons.account_balance_outlined,
            sampleToken: r'bank account\s+([A-Za-z0-9\s-]+)|(\*+\s*\d{3,4})',
          ),
        ],
      ),
    );
  }

  Widget _buildRegexFieldCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required String sampleToken,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => _runParserTest(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: LIVE SIMULATOR & DEBUGGER
  // =========================================================================
  Widget _buildSimulatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Test Scenarios
          const Text(
            'Quick Test Scenarios (Tap to Simulate):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildScenarioChip(
                  'PhonePe (₹2.00)',
                  'Money received',
                  'KM NEHA GOSWAMI has sent ₹2 to your bank account State Bank of India-1686',
                ),
                _buildScenarioChip(
                  'GPay (₹1,500.00)',
                  'Google Pay',
                  'Received ₹1,500.00 from Rahul Sharma via Google Pay UPI Ref: 438729106731',
                ),
                _buildScenarioChip(
                  'Canara ai1 App',
                  'Canara ai1',
                  'UPI Payment of ₹2,500.00 received from NARESH KING. UPI Ref: 432109876543. Available Bal: ₹45,210.00',
                ),
                _buildScenarioChip(
                  'Bank SMS Alert',
                  'Bank SMS Alert',
                  'Dear Customer, your A/c ending XXXX2887 is credited by Rs 2,500.00 on 18-Nov-26 by Naresh King UPI Ref 432109876543.',
                ),
                _buildScenarioChip(
                  'On-Hold Alert (Should Reject)',
                  'Bank Notification',
                  'An amount of INR 26,700 is kept on hold in your account for verification.',
                ),
                _buildScenarioChip(
                  'Loan Spam (Should Reject)',
                  'Special Offer',
                  'Congratulations! Pre-approved personal loan offer of ₹5,00,000 available.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Test Inputs Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sample Incoming Notification:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _runParserTest(),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notification Body / Text',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _runParserTest(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live Evaluation Results Card
          if (_hasTested) ...[
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
                            : (_queryRulesPassed ? Icons.warning_amber_rounded : Icons.block_rounded),
                        size: 20,
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
                                ? const Color(0xFF14532D)
                                : (_queryRulesPassed ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Step by Step Trace
                  const Text(
                    'Rule Evaluation Trace:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  ..._clauseTestSteps.map((step) {
                    final isPass = step.endsWith('PASS');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(isPass ? Icons.check : Icons.close, size: 12, color: isPass ? AppColors.successGreen : AppColors.errorRed),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: isPass ? const Color(0xFF14532D) : AppColors.errorRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 16),

                  // Extracted Values Table
                  _buildResultRow('Action Decision', _queryRulesPassed ? 'ACCEPT & EXTRACT' : 'REJECT & IGNORE', isHighlight: _isSuccess),
                  _buildResultRow('Classification', _extractedType),
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
    );
  }

  Widget _buildScenarioChip(String label, String sampleTitle, String sampleBody) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primaryNavy)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        onPressed: () {
          setState(() {
            _titleCtrl.text = sampleTitle;
            _descriptionCtrl.text = sampleBody;
          });
          _runParserTest();
        },
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  // =========================================================================
  // STICKY BOTTOM ACTION BAR (Save & Activate Rules / Reset / Cancel)
  // =========================================================================
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRules,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                _isSaving ? 'Activating Rules...' : 'Save & Activate Rules',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (_hasCustomRulesActive)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _deleteRules,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.errorRed),
                    label: Text(
                      _isDeleting ? 'Resetting...' : 'Reset Rules',
                      style: const TextStyle(color: AppColors.errorRed, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (_hasCustomRulesActive) const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
