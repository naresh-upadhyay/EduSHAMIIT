import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class BulkAndScheduledInvoiceDialog extends ConsumerStatefulWidget {
  final int initialTab;
  const BulkAndScheduledInvoiceDialog({super.key, this.initialTab = 0});

  @override
  ConsumerState<BulkAndScheduledInvoiceDialog> createState() => _BulkAndScheduledInvoiceDialogState();
}

class _BulkAndScheduledInvoiceDialogState extends ConsumerState<BulkAndScheduledInvoiceDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- TAB 1: IMMEDIATE BULK GENERATION STATE ---
  String _bulkTargetType = 'CLASS'; // 'ALL', 'CLASS', 'INDIVIDUALS'
  String _bulkSelectedClass = 'Class 10';
  String _bulkSelectedSection = 'All Sections';
  final TextEditingController _bulkTitleController =
      TextEditingController(text: 'Tuition & Academic Facilities');
  String _bulkBillingPeriod = 'NEXT_MONTH'; // 'CURRENT_MONTH', 'NEXT_MONTH', 'NEXT_QUARTER'
  String _bulkFeeType = 'Tuition Fee';
  String _bulkFeePlan = 'Monthly';
  final TextEditingController _bulkAmountController = TextEditingController(text: '4500');
  final TextEditingController _bulkNotesController = TextEditingController();
  int _bulkDueOffsetDays = 10; // Default 10 days notice window
  DateTime? _bulkCustomDueDate;
  bool _bulkSkipDuplicates = true;
  bool _bulkAutoDeductAdvanceCredit = true;
  bool _bulkSendParentEmail = true;
  bool _bulkExecuting = false;
  bool _isManualParticulars = false;

  // Intelligent Due Fee Heads State
  List<Map<String, dynamic>> _cohortDueHeads = [];
  List<Map<String, dynamic>> _cohortFutureHeads = [];
  List<Map<String, dynamic>> _cohortCompletedHeads = [];
  final Set<String> _selectedDueHeadIds = {};
  bool _loadingDueHeads = false;
  bool _showFutureHeads = true;

  // Cohort-Linked Fee Structures State
  List<Map<String, dynamic>> _cohortFeeStructures = [];
  String? _selectedFeeStructureId;
  bool _loadingFeeStructures = false;

  // Live Preview Students & Financial Forecast State
  bool _loadingPreview = false;
  int _previewCount = 0;
  double _previewGrossTotal = 0.0;
  double _previewAdvanceApplied = 0.0;
  double _previewNetPayable = 0.0;
  int _previewFullySettledCount = 0;
  int _previewPendingCount = 0;
  List<Map<String, dynamic>> _previewStudents = [];
  final Set<String> _selectedIndividualIds = {};
  String _studentSearchQuery = '';

  // Lookups
  List<PaymentLookupItem> _feeTypes = [];
  List<PaymentLookupItem> _billingCycles = [];

  // --- TAB 2: AUTOMATION RULES STATE ---
  bool _showCreateRuleForm = false;
  String? _editingRuleId;
  final TextEditingController _ruleNameController = TextEditingController();
  String _ruleTargetType = 'CLASS';
  String _ruleSelectedClass = 'Class 10';
  String _ruleSelectedSection = 'All Sections';
  String _ruleFrequency = 'MONTHLY';
  int _ruleDayOfMonth = 25;
  int _ruleDueOffset = 10;
  String _ruleBillingPeriod = 'NEXT_MONTH';
  String _ruleFeeType = 'Tuition Fee';
  String _ruleFeePlan = 'Monthly';
  final TextEditingController _ruleAmountController = TextEditingController(text: '4500');
  final TextEditingController _ruleTitleTemplateController =
      TextEditingController(text: 'Tuition Fee - {MONTH} {YEAR}');
  final TextEditingController _ruleNotesController = TextEditingController();
  bool _ruleIsActive = true;
  bool _ruleAutoDeductAdvanceCredit = true;
  bool _ruleSendParentEmail = true;
  String? _ruleFeeStructureId;
  bool _savingRule = false;
  bool _loadingRuleCohortHeads = false;
  List<Map<String, dynamic>> _ruleCohortFeeStructures = [];
  bool _showStudentInspectorInline = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
      if (_tabController.index == 1) {
        _fetchRuleCohortFeeStructures();
        ref.read(studentFeeProvider.notifier).loadScheduleRules();
      } else if (_tabController.index == 2) {
        ref.read(studentFeeProvider.notifier).loadScheduleRuns();
      }
    });

    _loadLookups();
    _fetchPreview();
    _fetchCohortFeeStructures();
    _fetchCohortDueHeads();
    _fetchRuleCohortFeeStructures();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentFeeProvider.notifier).loadScheduleRules();
      ref.read(studentFeeProvider.notifier).loadScheduleRuns();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bulkTitleController.dispose();
    _bulkAmountController.dispose();
    _bulkNotesController.dispose();
    _ruleNameController.dispose();
    _ruleAmountController.dispose();
    _ruleTitleTemplateController.dispose();
    _ruleNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    final types = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_TYPE');
    final cycles = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_BILLING_CYCLE');
    if (mounted) {
      setState(() {
        _feeTypes = types;
        _billingCycles = cycles;
        if (types.isNotEmpty) {
          _bulkFeeType = types.first.label;
          _ruleFeeType = types.first.label;
        }
        if (cycles.isNotEmpty) {
          _bulkFeePlan = cycles.first.label;
          _ruleFeePlan = cycles.first.label;
        }
      });
    }
  }

  List<String> _getSectionsForClass(String className, Map<String, List<String>> classesWithSections) {
    if (className == 'All Classes' || className == 'All') {
      return ['All Sections'];
    }
    if (classesWithSections.containsKey(className)) {
      return ['All Sections', ...classesWithSections[className]!];
    }
    final numOnly = RegExp(r'\d+').firstMatch(className)?.group(0);
    for (final entry in classesWithSections.entries) {
      if (numOnly != null && entry.key.contains(numOnly)) {
        return ['All Sections', ...entry.value];
      }
    }
    final numPrefix = numOnly ?? '10';
    return ['All Sections', '$numPrefix-A', '$numPrefix-B', '$numPrefix-C', '$numPrefix-D'];
  }

  Future<void> _fetchPreview() async {
    setState(() => _loadingPreview = true);
    final amt = double.tryParse(_bulkAmountController.text.trim()) ?? 4500.0;
    final res = await PaymentManagementApiService.instance.getTargetStudentsPreview(
      targetType: _bulkTargetType,
      targetClass: _bulkSelectedClass,
      targetSection: _bulkSelectedSection,
      amount: amt,
    );
    if (mounted) {
      setState(() {
        _loadingPreview = false;
        _previewCount = (res['count'] as num?)?.toInt() ?? 0;
        _previewGrossTotal = (res['total_gross_invoicing'] as num?)?.toDouble() ?? (_previewCount * amt);
        _previewAdvanceApplied = (res['total_advance_applied'] as num?)?.toDouble() ?? 0.0;
        _previewNetPayable = (res['total_net_payable'] as num?)?.toDouble() ?? (_previewGrossTotal - _previewAdvanceApplied);
        _previewFullySettledCount = (res['fully_settled_count'] as num?)?.toInt() ?? 0;
        _previewPendingCount = (res['pending_collection_count'] as num?)?.toInt() ?? _previewCount;
        _previewStudents = (res['students'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      });
    }
  }

  Future<void> _fetchCohortFeeStructures() async {
    if (_bulkTargetType != 'CLASS') {
      if (mounted) {
        setState(() {
          _cohortFeeStructures = [];
          _selectedFeeStructureId = null;
        });
      }
      return;
    }
    setState(() => _loadingFeeStructures = true);
    final heads = await PaymentManagementApiService.instance.getCohortMatchingFeeStructures(
      classGrade: _bulkSelectedClass,
      sectionName: _bulkSelectedSection,
    );
    if (mounted) {
      setState(() {
        _loadingFeeStructures = false;
        _cohortFeeStructures = heads;
        if (_selectedFeeStructureId != null && !heads.any((h) => h['id'] == _selectedFeeStructureId)) {
          _selectedFeeStructureId = null;
        }
      });
    }
  }

  Future<void> _fetchRuleCohortFeeStructures() async {
    setState(() => _loadingRuleCohortHeads = true);
    try {
      final heads = await PaymentManagementApiService.instance.getCohortMatchingFeeStructures(
        classGrade: _ruleSelectedClass,
        sectionName: _ruleSelectedSection,
        academicYear: ref.read(studentFeeProvider).selectedAcademicYear,
      );
      if (mounted) {
        setState(() {
          _loadingRuleCohortHeads = false;
          _ruleCohortFeeStructures = heads;
          _cohortFeeStructures = heads;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRuleCohortHeads = false);
    }
  }

  void _selectFeeStructureForAutomation(Map<String, dynamic> head) {
    final fid = head['id']?.toString();
    final feeName = head['fee_name'] ?? head['name'] ?? 'Fee Head';
    final feeType = head['fee_type'] ?? 'Tuition Fee';
    final amt = (head['amount'] as num?)?.toDouble() ?? 0.0;
    final cycle = (head['billing_cycle'] ?? head['frequency_type'] ?? 'Monthly').toString();
    final dueDay = (head['due_day_of_cycle'] as num?)?.toInt() ?? 10;

    setState(() {
      _ruleFeeStructureId = fid;
      _editingRuleId = null;
      _showCreateRuleForm = true;
      _ruleTargetType = 'CLASS';
      _ruleFeeType = feeType;
      _ruleFeePlan = cycle;
      final secLabel = _ruleSelectedSection != 'All Sections' ? ' - $_ruleSelectedSection' : '';
      _ruleNameController.text = '[$_ruleSelectedClass$secLabel] $feeName ($cycle)';
      _ruleTitleTemplateController.text = '$feeName - {MONTH} {YEAR}';
      _ruleAmountController.text = amt > 0 ? amt.toStringAsFixed(0) : '0';
      _ruleAutoDeductAdvanceCredit = true;
      _ruleSendParentEmail = true;
      _ruleIsActive = true;

      final cycleUpper = cycle.toUpperCase();
      if (cycleUpper.contains('QUART') || cycleUpper.contains('TERM')) {
        _ruleFrequency = 'QUARTERLY';
        _ruleDayOfMonth = 1;
        _ruleDueOffset = dueDay > 0 ? dueDay : 10;
        _ruleBillingPeriod = 'NEXT_QUARTER';
        _ruleTitleTemplateController.text = '$feeName - {QUARTER} {YEAR}';
      } else if (cycleUpper.contains('ANNUAL') || cycleUpper.contains('YEAR')) {
        _ruleFrequency = 'ANNUALLY';
        _ruleDayOfMonth = 1;
        _ruleDueOffset = dueDay > 0 ? dueDay : 15;
        _ruleBillingPeriod = 'CURRENT_MONTH';
        _ruleTitleTemplateController.text = '$feeName - Academic Year {YEAR}';
      } else if (cycleUpper.contains('HALF') || cycleUpper.contains('SEM')) {
        _ruleFrequency = 'HALF_YEARLY';
        _ruleDayOfMonth = 1;
        _ruleDueOffset = dueDay > 0 ? dueDay : 10;
        _ruleBillingPeriod = 'CURRENT_MONTH';
        _ruleTitleTemplateController.text = '$feeName - Semester {YEAR}';
      } else {
        _ruleFrequency = 'MONTHLY';
        _ruleDayOfMonth = 25;
        _ruleDueOffset = 15;
        _ruleBillingPeriod = 'NEXT_MONTH';
        _ruleTitleTemplateController.text = '$feeName - {MONTH} {YEAR}';
      }
    });
  }

  void _editExistingRule(Map<String, dynamic> r) {
    setState(() {
      _editingRuleId = r['id']?.toString();
      _ruleFeeStructureId = r['fee_structure_id']?.toString();
      _showCreateRuleForm = true;
      _ruleNameController.text = r['rule_name']?.toString() ?? '';
      _ruleTargetType = r['target_type']?.toString() ?? 'CLASS';
      _ruleSelectedClass = r['target_class']?.toString() ?? _ruleSelectedClass;
      _ruleSelectedSection = r['target_section']?.toString() ?? _ruleSelectedSection;
      _ruleFrequency = r['frequency']?.toString() ?? 'MONTHLY';
      _ruleDayOfMonth = (r['schedule_day_of_month'] as num?)?.toInt() ?? 25;
      _ruleDueOffset = (r['due_days_offset'] as num?)?.toInt() ?? 10;
      _ruleBillingPeriod = r['billing_period_target']?.toString() ?? 'NEXT_MONTH';
      _ruleFeeType = r['fee_type']?.toString() ?? 'Tuition Fee';
      _ruleFeePlan = r['fee_plan']?.toString() ?? 'Monthly';
      _ruleAmountController.text = ((r['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
      _ruleTitleTemplateController.text = r['title_template']?.toString() ?? '';
      _ruleNotesController.text = r['notes']?.toString() ?? '';
      _ruleIsActive = r['is_active'] == true;
      _ruleAutoDeductAdvanceCredit = r['auto_deduct_advance_credit'] ?? true;
      _ruleSendParentEmail = r['send_parent_email'] ?? true;
    });
  }

  IconData _getFeeTypeIcon(String feeType) {
    final ft = feeType.toLowerCase();
    if (ft.contains('tuit') || ft.contains('acad')) return Icons.school_rounded;
    if (ft.contains('sport') || ft.contains('fit') || ft.contains('game')) return Icons.sports_soccer_rounded;
    if (ft.contains('lab') || ft.contains('comput') || ft.contains('sci')) return Icons.biotech_rounded;
    if (ft.contains('lib') || ft.contains('digit') || ft.contains('book')) return Icons.menu_book_rounded;
    if (ft.contains('bus') || ft.contains('trans') || ft.contains('transit')) return Icons.directions_bus_rounded;
    if (ft.contains('exam') || ft.contains('test') || ft.contains('assess')) return Icons.assignment_turned_in_rounded;
    if (ft.contains('admis') || ft.contains('reg')) return Icons.how_to_reg_rounded;
    return Icons.receipt_long_rounded;
  }

  Future<void> _fetchCohortDueHeads() async {
    if (_bulkTargetType != 'CLASS') {
      if (mounted) {
        setState(() {
          _cohortDueHeads = [];
          _cohortFutureHeads = [];
          _cohortCompletedHeads = [];
          _selectedDueHeadIds.clear();
        });
      }
      return;
    }
    setState(() => _loadingDueHeads = true);
    final res = await PaymentManagementApiService.instance.getCohortDueFeeHeads(
      classGrade: _bulkSelectedClass,
      sectionName: _bulkSelectedSection,
      academicYear: ref.read(studentFeeProvider).selectedAcademicYear,
    );
    if (mounted) {
      setState(() {
        _loadingDueHeads = false;
        _cohortDueHeads = (res['due_heads'] as List?)?.map((e) => _cleanMapStrings(Map<String, dynamic>.from(e as Map))).toList() ?? [];
        _cohortFutureHeads = (res['future_heads'] as List?)?.map((e) => _cleanMapStrings(Map<String, dynamic>.from(e as Map))).toList() ?? [];
        _cohortCompletedHeads = (res['completed_heads'] as List?)?.map((e) => _cleanMapStrings(Map<String, dynamic>.from(e as Map))).toList() ?? [];

        _selectedDueHeadIds.clear();
        for (final h in _cohortDueHeads) {
          final sid = h['fee_structure_id']?.toString();
          if (sid != null) _selectedDueHeadIds.add(sid);
        }
      });
      _fetchPreview();
    }
  }

  void _applyFeeStructureHead(Map<String, dynamic> head) {
    setState(() {
      _selectedFeeStructureId = head['id']?.toString();
      _bulkTitleController.text = head['fee_name'] ?? 'Tuition Fee';
      if (head['fee_type'] != null) {
        _bulkFeeType = head['fee_type'];
      }
      if (head['billing_cycle'] != null) {
        _bulkFeePlan = head['billing_cycle'];
      }
      final amt = (head['amount'] as num?)?.toDouble() ?? 4500.0;
      _bulkAmountController.text = amt.toStringAsFixed(0);

      // Dynamically calculate due date from due_day_of_cycle
      final dueDay = (head['due_day_of_cycle'] as num?)?.toInt() ?? 10;
      final now = DateTime.now();
      DateTime targetDate;
      if (now.day <= dueDay) {
        targetDate = DateTime(now.year, now.month, dueDay);
      } else {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        targetDate = DateTime(nextYear, nextMonth, dueDay);
      }
      final daysDiff = targetDate.difference(now).inDays;
      _bulkDueOffsetDays = daysDiff > 0 ? daysDiff : 10;
      _bulkCustomDueDate = null;
    });
    _fetchPreview();
  }

  DateTime _calculateBulkDueDate() {
    if (_bulkCustomDueDate != null) return _bulkCustomDueDate!;
    return DateTime.now().add(Duration(days: _bulkDueOffsetDays));
  }

  String _formatCurrency(num val) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
    return formatter.format(val);
  }

  String _cleanSpecialChars(String? text) {
    if (text == null) return '';
    return text
        .replaceAll('â€”', ' - ')
        .replaceAll('â€“', ' - ')
        .replaceAll('â‚¹', '₹')
        .replaceAll('â€¢', ' • ')
        .replaceAll('â€™', "'")
        .replaceAll('â€˜', "'")
        .replaceAll('â€œ', '"')
        .replaceAll('â€', '"')
        .replaceAll('â€¦', '...')
        .replaceAll('—', ' - ')
        .replaceAll('–', ' - ');
  }

  Map<String, dynamic> _cleanMapStrings(Map<String, dynamic> map) {
    final cleaned = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value is String) {
        cleaned[entry.key] = _cleanSpecialChars(entry.value as String);
      } else if (entry.value is Map) {
        cleaned[entry.key] = _cleanMapStrings(Map<String, dynamic>.from(entry.value as Map));
      } else if (entry.value is List) {
        cleaned[entry.key] = (entry.value as List).map((i) {
          if (i is String) return _cleanSpecialChars(i);
          if (i is Map) return _cleanMapStrings(Map<String, dynamic>.from(i));
          return i;
        }).toList();
      } else {
        cleaned[entry.key] = entry.value;
      }
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: size.height * 0.92,
          minHeight: 560,
        ),
        child: Column(
          children: [
            // DIALOG TOP HEADER
            _buildDialogHeader(isDark),

            // TABS NAVIGATION BAR (FLUSH LEFT ALIGNMENT)
            _buildTabsHeader(isDark),

            // TAB VIEWS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInstantBulkTab(isDark),
                  _buildAutomationRulesTab(isDark),
                  _buildExecutionHistoryTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Bulk Invoicing & Automated Scheduling',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text(
                              'Smart Wallet & Multi-Section Active',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Multi-section cohort targeting, automatic advance credit wallet deduction & executive parent email notifications',
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
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// Top navigation tabs starting flush from the left side with sleek styling
  Widget _buildTabsHeader(bool isDark) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        indicator: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: const [
          Tab(
            icon: Icon(Icons.flash_on_rounded, size: 16),
            text: 'Instant Bulk Generate',
            iconMargin: EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.schedule_send_rounded, size: 16),
            text: 'Automation & Recurring Rules',
            iconMargin: EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.history_rounded, size: 16),
            text: 'Execution History & Runs',
            iconMargin: EdgeInsets.only(bottom: 3),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: INSTANT BULK GENERATE
  // ============================================================================
  Widget _buildInstantBulkTab(bool isDark) {
    final state = ref.watch(studentFeeProvider);
    final targetStudentsCount = _bulkTargetType == 'INDIVIDUALS'
        ? _selectedIndividualIds.length
        : _previewCount;
    final unitAmt = double.tryParse(_bulkAmountController.text.trim()) ?? 0.0;

    double combinedHeadAmount = 0.0;
    if (_bulkTargetType == 'CLASS' && !_isManualParticulars) {
      for (final h in _cohortDueHeads) {
        final sid = h['fee_structure_id']?.toString();
        if (sid != null && _selectedDueHeadIds.contains(sid)) {
          combinedHeadAmount += (h['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } else {
      combinedHeadAmount = unitAmt;
    }

    final estimatedGross = targetStudentsCount * combinedHeadAmount;
    final dueDate = _calculateBulkDueDate();

    // Exact Advance Deductions calculation per student
    double calculatedAdvance = 0.0;
    int fullySettledCount = 0;
    for (final s in _previewStudents) {
      final bal = (s['advance_balance'] as num?)?.toDouble() ?? 0.0;
      final charge = combinedHeadAmount;
      if (bal >= charge && charge > 0) {
        fullySettledCount++;
        calculatedAdvance += charge;
      } else {
        calculatedAdvance += bal;
      }
    }
    final effectiveAdvance = _bulkAutoDeductAdvanceCredit ? calculatedAdvance : 0.0;
    final effectiveNet = (estimatedGross - effectiveAdvance) > 0 ? (estimatedGross - effectiveAdvance) : 0.0;
    final pendingCount = (targetStudentsCount - fullySettledCount) > 0 ? (targetStudentsCount - fullySettledCount) : 0;

    final availableSections = _getSectionsForClass(_bulkSelectedClass, state.classesWithSections);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TARGET COHORT SELECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. TARGET COHORT & MULTI-SECTION SELECTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF2563EB),
                ),
              ),
              if (_previewCount > 0)
                InkWell(
                  onTap: () => _showStudentCohortBreakdown(isDark),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Inspect Target Students ($_previewCount)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildTargetTypeChip('CLASS', 'Specific Class / Section', Icons.class_rounded, isDark),
              const SizedBox(width: 8),
              _buildTargetTypeChip('ALL', 'All Enrolled Students (Entire School)', Icons.school_rounded, isDark),
              const SizedBox(width: 8),
              _buildTargetTypeChip('INDIVIDUALS', 'Select Individual Students', Icons.group_rounded, isDark),
            ],
          ),
          const SizedBox(height: 12),

          if (_bulkTargetType == 'CLASS') ...[
            Row(
              children: [
                // Class Selector
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Class',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: state.classesList.contains(_bulkSelectedClass)
                                ? _bulkSelectedClass
                                : (state.classesList.isNotEmpty ? state.classesList.first : 'All Classes'),
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: state.classesList
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _bulkSelectedClass = val;
                                  _bulkSelectedSection = 'All Sections';
                                });
                                _fetchPreview();
                                _fetchCohortFeeStructures();
                                _fetchCohortDueHeads();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Section Selector
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Section',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: availableSections.contains(_bulkSelectedSection)
                                ? _bulkSelectedSection
                                : 'All Sections',
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: availableSections
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _bulkSelectedSection = val);
                                _fetchPreview();
                                _fetchCohortFeeStructures();
                                _fetchCohortDueHeads();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Cohort Info Indicator
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _loadingPreview
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  'Targeting $_previewCount enrolled student(s) in $_bulkSelectedClass ($_bulkSelectedSection)',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_previewCount > 0) ...[
              const SizedBox(height: 12),
              _buildInlineStudentAdvanceInspector(isDark, combinedHeadAmount),
            ],
          ] else if (_bulkTargetType == 'ALL') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.domain_rounded, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'School-Wide Billing: Targeting all $_previewCount active students across all classes and sections',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_bulkTargetType == 'INDIVIDUALS') ...[
            _buildIndividualStudentsSelector(isDark),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // 2. INTELLIGENT COHORT DUE HEADS EVALUATION OR MANUAL OVERRIDE
          if (_bulkTargetType == 'CLASS' && !_isManualParticulars) ...[
            _buildIntelligentCohortDueHeadsSection(isDark),
          ] else ...[
            _buildManualParticularsForm(isDark),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // 3. PAYMENT DUE DATE WINDOW (PARENT NOTICE - MANUAL MODE)
            const Text(
              '3. PAYMENT DUE DATE WINDOW (PARENT NOTICE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildDueOffsetChip(10, '10 Days Notice (Recommended)', isDark),
                const SizedBox(width: 8),
                _buildDueOffsetChip(15, '15 Days Notice', isDark),
                const SizedBox(width: 8),
                _buildDueOffsetChip(30, '30 Days / Month End', isDark),
                const SizedBox(width: 8),
                _buildCustomDateChip(isDark),
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Calculated Invoice Due Date: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy (EEEE)').format(dueDate),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_bulkDueOffsetDays days from generation date',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // 4. POWERFUL ADVANCE WALLET & PARENT EMAIL TOGGLES
          const Text(
            '4. ADVANCE CREDIT DEDUCTION & PARENT EMAIL DISPATCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 10),

          // ADVANCE CREDIT WALLET AUTO-DEDUCTION TOGGLE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _bulkAutoDeductAdvanceCredit
                    ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Auto-Deduct Student Advance Credit Wallet',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Smart Overpayment Settlement',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Automatically applies existing student overpayments/credits to this invoice. If credit covers the entire fee, status is marked Paid immediately with zero dues.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _bulkAutoDeductAdvanceCredit,
                  activeTrackColor: const Color(0xFF16A34A),
                  onChanged: (val) {
                    setState(() => _bulkAutoDeductAdvanceCredit = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // SEND EMAIL TO PARENTS TOGGLE
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _bulkSendParentEmail
                    ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Dispatch Invoice Statement Emails to Parents',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Interactive UPI & Statement',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sends parents a responsive HTML email statement detailing itemized charges, wallet credit deduction receipts, and dynamic UPI QR code + 1-Click Pay link.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 14),
                  label: const Text('Preview Parent Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  onPressed: () => _showEmailPreviewDialog(isDark),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _bulkSendParentEmail,
                  activeTrackColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() => _bulkSendParentEmail = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // DUPLICATE PREVENTION TOGGLE
          Row(
            children: [
              Checkbox(
                value: _bulkSkipDuplicates,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) {
                  if (val != null) setState(() => _bulkSkipDuplicates = val);
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _bulkSkipDuplicates = !_bulkSkipDuplicates),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prevent Duplicate Invoicing (Recommended)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Automatically skip students who already have an active invoice for this fee type and period',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 5. LIVE FINANCIAL FORECAST & CREDIT IMPACT CARDS
          _buildFinancialForecastBanner(
            isDark,
            targetStudentsCount,
            combinedHeadAmount,
            estimatedGross,
            effectiveAdvanceOverride: effectiveAdvance,
            effectiveNetOverride: effectiveNet,
            fullySettledOverride: fullySettledCount,
            pendingOverride: pendingCount,
            actionButtonText: (!_isManualParticulars && _bulkTargetType == 'CLASS')
                ? '⚡ Generate Invoices for ${_selectedDueHeadIds.length} Due Heads ($targetStudentsCount Students)'
                : null,
          ),
        ],
      ),
    );
  }

  /// Live financial forecast showing gross billed, advance credit deduction, and net dues
  Widget _buildFinancialForecastBanner(
    bool isDark,
    int count,
    double unitAmt,
    double grossTotal, {
    double? effectiveAdvanceOverride,
    double? effectiveNetOverride,
    int? fullySettledOverride,
    int? pendingOverride,
    String? actionButtonText,
  }) {
    final effectiveAdvance = effectiveAdvanceOverride ?? (_bulkAutoDeductAdvanceCredit ? _previewAdvanceApplied : 0.0);
    final effectiveNet = effectiveNetOverride ?? (_bulkAutoDeductAdvanceCredit ? _previewNetPayable : grossTotal);
    final settledCount = fullySettledOverride ?? _previewFullySettledCount;
    final remainingPendingCount = pendingOverride ?? _previewPendingCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'FINANCIAL FORECAST & WALLET SETTLEMENT SUMMARY',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.table_rows_rounded, size: 14),
                label: Text('View Students Breakdown ($count)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: () => _showStudentCohortBreakdown(isDark),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Metric Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricMiniCard(
                  'TARGET COHORT',
                  '$count Students',
                  '$_bulkSelectedClass ($_bulkSelectedSection)',
                  Icons.groups_rounded,
                  const Color(0xFF2563EB),
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard(
                  'GROSS BILLING',
                  _formatCurrency(grossTotal),
                  !_isManualParticulars && _bulkTargetType == 'CLASS'
                      ? '${_selectedDueHeadIds.length} Active Due Heads'
                      : '$count × ${_formatCurrency(unitAmt)}',
                  Icons.receipt_long_rounded,
                  const Color(0xFF4F46E5),
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard(
                  'WALLET CREDIT DEDUCTED',
                  '- ${_formatCurrency(effectiveAdvance)}',
                  _bulkAutoDeductAdvanceCredit ? 'Auto-applied from overpayments' : 'Feature disabled',
                  Icons.savings_rounded,
                  const Color(0xFF16A34A),
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricMiniCard(
                  'NET DUES TO COLLECT',
                  _formatCurrency(effectiveNet),
                  'Net amount pending collection',
                  Icons.account_balance_rounded,
                  const Color(0xFF0284C7),
                  isDark,
                  isPrimary: true,
                ),
              ),
            ],
          ),

          if (_bulkAutoDeductAdvanceCredit && settledCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✨ $settledCount student(s) have sufficient advance credit to be fully settled (₹0 Due). Remaining $remainingPendingCount student(s) will have net pending dues.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: _bulkExecuting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 20),
                label: Text(
                  _bulkExecuting ? 'Processing Batch Invoicing...' : (actionButtonText ?? 'Generate Invoices & Dispatch ($count Students)'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                onPressed: _bulkExecuting ? null : _executeBulkInvoicing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark, {
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isPrimary ? color : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeChip(String type, String label, IconData icon, bool isDark) {
    final isSelected = _bulkTargetType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _bulkTargetType = type;
            if (type == 'ALL' || type == 'INDIVIDUALS') {
              _bulkSelectedClass = 'All Classes';
              _bulkSelectedSection = 'All Sections';
            }
          });
          _fetchPreview();
          _fetchCohortFeeStructures();
          _fetchCohortDueHeads();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntelligentCohortDueHeadsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. INTELLIGENT FEE SCHEDULE EVALUATION (CATALOG-DRIVEN)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        'Auto-detects active due heads for $_bulkSelectedClass and protects future scheduled fees',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 14),
                label: const Text('Switch to Manual Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: () => setState(() => _isManualParticulars = true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingDueHeads)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Evaluating cohort fee schedules and due dates...', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            )
          else ...[
            _buildActiveDueHeadsList(isDark),
            if (_cohortFutureHeads.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildProtectedFutureHeadsSection(isDark),
            ],
            if (_cohortCompletedHeads.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildCompletedHeadsSection(isDark),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActiveDueHeadsList(bool isDark) {
    if (_cohortDueHeads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All fee structure heads for $_bulkSelectedClass are up to date! No unbilled installments are due for the current billing cycle.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE DUE FEE HEADS (${_selectedDueHeadIds.length}/${_cohortDueHeads.length} Selected to Bill)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  if (_selectedDueHeadIds.length == _cohortDueHeads.length) {
                    _selectedDueHeadIds.clear();
                  } else {
                    _selectedDueHeadIds.clear();
                    for (final h in _cohortDueHeads) {
                      final sid = h['fee_structure_id']?.toString();
                      if (sid != null) _selectedDueHeadIds.add(sid);
                    }
                  }
                });
              },
              child: Text(
                _selectedDueHeadIds.length == _cohortDueHeads.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._cohortDueHeads.map((head) {
          final sid = head['fee_structure_id']?.toString() ?? '';
          final isSelected = _selectedDueHeadIds.contains(sid);
          final feeName = head['fee_name'] ?? 'Fee Head';
          final feeType = head['fee_type'] ?? 'Tuition Fee';
          final cycle = head['billing_cycle'] ?? 'Monthly';
          final amt = (head['amount'] as num?)?.toDouble() ?? 0.0;
          final dueDate = head['due_date']?.toString() ?? '';
          final lateFee = (head['late_fee'] as num?)?.toDouble() ?? 0.0;
          final lateFeeType = head['late_fee_type'] ?? 'FLAT';
          final grace = head['grace_period'] ?? 0;
          final unbilledCount = head['unbilled_students_count'] ?? 0;
          final totalStudents = head['total_cohort_students'] ?? unbilledCount;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: CheckboxListTile(
              value: isSelected,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              activeColor: const Color(0xFF2563EB),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedDueHeadIds.add(sid);
                  } else {
                    _selectedDueHeadIds.remove(sid);
                  }
                });
              },
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      feeName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '₹${amt.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildHeadChip(feeType, const Color(0xFF2563EB)),
                    _buildHeadChip(cycle, const Color(0xFF7C3AED)),
                    if (dueDate.isNotEmpty)
                      _buildHeadChip('Due: $dueDate', const Color(0xFF0284C7), icon: Icons.event_rounded),
                    if (lateFee > 0)
                      _buildHeadChip('Late Fine: ₹${lateFee.toStringAsFixed(0)} ($lateFeeType) after ${grace}d', const Color(0xFFDC2626), icon: Icons.warning_amber_rounded),
                    _buildHeadChip('$unbilledCount / $totalStudents Pending', const Color(0xFF059669)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProtectedFutureHeadsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    'PROTECTED FROM PREMATURE BILLING (${_cohortFutureHeads.length} Future Heads Skipped)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showFutureHeads = !_showFutureHeads),
                child: Row(
                  children: [
                    Text(
                      _showFutureHeads ? 'Hide' : 'Show',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                    ),
                    Icon(_showFutureHeads ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF0D9488)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Installments scheduled in future months (e.g. Exams 3 months away) are automatically protected and won\'t be invoiced early.',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          if (_showFutureHeads) ...[
            const SizedBox(height: 8),
            ..._cohortFutureHeads.map((f) {
              final name = _cleanSpecialChars(f['fee_name']?.toString() ?? 'Fee Head');
              final amt = (f['amount'] as num?)?.toDouble() ?? 0.0;
              final reason = _cleanSpecialChars(f['skip_reason']?.toString() ?? 'Scheduled in future cycle');
              final cycle = _cleanSpecialChars(f['billing_cycle']?.toString() ?? 'Term-Wise');

              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, size: 15, color: Color(0xFF0D9488)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          Text(reason, style: const TextStyle(fontSize: 10.5, color: Color(0xFF0D9488), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${amt.toStringAsFixed(0)} ($cycle)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedHeadsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_cohortCompletedHeads.length} Fee Head(s) already fully billed for this cohort: ${_cohortCompletedHeads.map((c) => c['fee_name']?.toString() ?? '').join(', ')}',
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadChip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildManualParticularsForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_bulkTargetType == 'CLASS') ...[
          _buildCohortFeeStructureSelector(isDark),
          const SizedBox(height: 16),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '2. BILLING PARTICULARS & PERIOD (MANUAL MODE)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF2563EB),
              ),
            ),
            if (_bulkTargetType == 'CLASS')
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Use Intelligent Catalog Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                onPressed: () => setState(() => _isManualParticulars = false),
              ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Title / Purpose',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bulkTitleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Tuition & Academic Facilities',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing Period Target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _bulkBillingPeriod,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'NEXT_MONTH', child: Text('Next Month (Advance Collection)')),
                          DropdownMenuItem(value: 'CURRENT_MONTH', child: Text('Current Month')),
                          DropdownMenuItem(value: 'NEXT_QUARTER', child: Text('Next Quarter')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _bulkBillingPeriod = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _feeTypes.any((t) => t.label == _bulkFeeType)
                            ? _bulkFeeType
                            : (_feeTypes.isNotEmpty ? _feeTypes.first.label : 'Tuition Fee'),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: _feeTypes
                            .map((t) => DropdownMenuItem(value: t.label, child: Text(t.label)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _bulkFeeType = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Billing Cycle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _billingCycles.any((b) => b.label == _bulkFeePlan)
                            ? _bulkFeePlan
                            : (_billingCycles.isNotEmpty ? _billingCycles.first.label : 'Monthly'),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: _billingCycles
                            .map((b) => DropdownMenuItem(value: b.label, child: Text(b.label)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _bulkFeePlan = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount Per Student (₹)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bulkAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _fetchPreview();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCohortFeeStructureSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _selectedFeeStructureId != null
              ? const Color(0xFF2563EB).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'COHORT FEE STRUCTURE CATALOG ($_bulkSelectedClass - $_bulkSelectedSection)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              if (_loadingFeeStructures)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${_cohortFeeStructures.length} active head(s)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_cohortFeeStructures.isEmpty && !_loadingFeeStructures)
            Text(
              'No cohort-specific fee structure head found. You can enter particulars manually below.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._cohortFeeStructures.map((head) {
                  final isSelected = _selectedFeeStructureId == head['id']?.toString();
                  final name = head['fee_name'] ?? 'Fee';
                  final cycle = head['billing_cycle'] ?? 'Monthly';
                  final amt = (head['amount'] as num?)?.toDouble() ?? 0.0;
                  final dueDay = head['due_day_of_cycle'] ?? 10;
                  final isRank1 = (head['cohort_rank'] as num?)?.toInt() == 1;

                  return InkWell(
                    onTap: () => _applyFeeStructureHead(head),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF0F172A) : Colors.white),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isRank1
                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          width: isSelected || isRank1 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.label_rounded,
                            size: 15,
                            color: isSelected ? Colors.white : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$cycle · ₹${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          if (dueDay != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${dueDay}th due)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isSelected
                                    ? Colors.white70
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                // Custom / Manual Entry chip
                InkWell(
                  onTap: () {
                    setState(() => _selectedFeeStructureId = null);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedFeeStructureId == null
                          ? const Color(0xFF64748B)
                          : (isDark ? const Color(0xFF0F172A) : Colors.white),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedFeeStructureId == null
                            ? const Color(0xFF64748B)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedFeeStructureId == null ? Icons.edit_note_rounded : Icons.edit_outlined,
                          size: 15,
                          color: _selectedFeeStructureId == null ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Manual Particulars',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedFeeStructureId == null
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDueOffsetChip(int days, String label, bool isDark) {
    final isSelected = _bulkCustomDueDate == null && _bulkDueOffsetDays == days;
    return InkWell(
      onTap: () {
        setState(() {
          _bulkDueOffsetDays = days;
          _bulkCustomDueDate = null;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(bool isDark) {
    final isSelected = _bulkCustomDueDate != null;
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _bulkCustomDueDate ?? DateTime.now().add(const Duration(days: 10)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) {
          setState(() {
            _bulkCustomDueDate = d;
            _bulkDueOffsetDays = d.difference(DateTime.now()).inDays;
          });
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_rounded, size: 14, color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 5),
            Text(
              isSelected ? DateFormat('dd MMM yyyy').format(_bulkCustomDueDate!) : 'Custom Calendar Date',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualStudentsSelector(bool isDark) {
    if (_loadingPreview) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 10),
            Text(
              'Loading enrolled students...',
              style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final filtered = _previewStudents.where((s) {
      final q = _studentSearchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? '').toString().toLowerCase();
      final cls = (s['class'] ?? '').toString().toLowerCase();
      final adm = (s['admission_number'] ?? '').toString().toLowerCase();
      final sec = (s['section'] ?? '').toString().toLowerCase();
      return name.contains(q) || roll.contains(q) || cls.contains(q) || adm.contains(q) || sec.contains(q);
    }).toList();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 16),
                      hintText: 'Search student name, roll number, admission no, or class...',
                      hintStyle: const TextStyle(fontSize: 11.5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (val) => setState(() => _studentSearchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedIndividualIds.length} Selected',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndividualIds.length == _previewStudents.length) {
                      _selectedIndividualIds.clear();
                    } else {
                      _selectedIndividualIds.addAll(_previewStudents.map((s) => s['id'].toString()));
                    }
                  });
                },
                child: Text(_selectedIndividualIds.length == _previewStudents.length ? 'Deselect All' : 'Select All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _previewStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No enrolled students found in school',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No students matching "$_studentSearchQuery"',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final s = filtered[i];
                          final sid = s['id'].toString();
                          final name = s['full_name']?.toString() ?? 'Student';
                          final cls = s['class']?.toString() ?? '';
                          final sec = s['section']?.toString() ?? '';
                          final roll = s['roll_number']?.toString() ?? '';
                          final adm = s['admission_number']?.toString() ?? '';
                          final adv = (s['advance_wallet_balance'] as num?)?.toDouble() ?? 0.0;
                          final isChecked = _selectedIndividualIds.contains(sid);

                          final classDisplay = sec.isNotEmpty ? (cls.isNotEmpty ? '$cls ($sec)' : sec) : cls;

                          return CheckboxListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIndividualIds.add(sid);
                                } else {
                                  _selectedIndividualIds.remove(sid);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (classDisplay.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            classDisplay,
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                      if (adm.isNotEmpty && adm != '-') ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          adm,
                                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                      if (roll.isNotEmpty && roll != '-') ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          'Roll: $roll',
                                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (adv > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_formatCurrency(adv)} Advance Held',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Collapsible Inline Student Ledger & Advance Deductions Inspector
  Widget _buildInlineStudentAdvanceInspector(bool isDark, double combinedHeadAmount) {
    final studentsWithCredit = _previewStudents.where((s) {
      final bal = ((s['advance_balance'] ?? s['advance_wallet_balance'] ?? 0) as num).toDouble();
      return bal > 0;
    }).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _showStudentInspectorInline
              ? const Color(0xFF16A34A).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: _showStudentInspectorInline ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showStudentInspectorInline = !_showStudentInspectorInline),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Cohort Students & Smart Wallet Deduction Inspector ($_previewCount Students)',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$studentsWithCredit with Advance Credits',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _showStudentInspectorInline
                                ? 'Review individual ledger balances, deducted credits, and net dues before invoicing'
                                : 'Click to inspect individual student balances, deducted credits, and settlement statuses',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _showStudentInspectorInline ? 'Collapse' : 'Inspect Deductions',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                      ),
                      Icon(
                        _showStudentInspectorInline ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_showStudentInspectorInline) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('STUDENT & ROLL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('CLASS / SEC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('WALLET CREDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('DEDUCTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('NET DUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('SETTLEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _previewStudents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final s = _previewStudents[idx];
                        final name = s['full_name']?.toString() ?? 'Student';
                        final roll = s['roll_number']?.toString() ?? '-';
                        final cls = s['class']?.toString() ?? _bulkSelectedClass;
                        final sec = s['section']?.toString() ?? '';
                        final clsSec = sec.isNotEmpty ? '$cls ($sec)' : cls;
                        final bal = ((s['advance_balance'] ?? s['advance_wallet_balance'] ?? 0) as num).toDouble();
                        final charge = combinedHeadAmount;
                        final deducted = _bulkAutoDeductAdvanceCredit ? (bal >= charge ? charge : bal) : 0.0;
                        final net = (charge - deducted) > 0 ? (charge - deducted) : 0.0;
                        final isFullySettled = _bulkAutoDeductAdvanceCredit && (bal >= charge && charge > 0);
                        final isPartial = _bulkAutoDeductAdvanceCredit && (bal > 0 && bal < charge);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                    Text('Roll: $roll', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text(clsSec, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  bal > 0 ? _formatCurrency(bal) : '₹ 0',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: bal > 0 ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  deducted > 0 ? '- ${_formatCurrency(deducted)}' : '₹ 0',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: deducted > 0 ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatCurrency(net),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: net == 0 ? const Color(0xFF16A34A) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: isFullySettled
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('✨ FULLY SETTLED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                                      )
                                    : isPartial
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('PARTIAL DEDUCT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('BALANCE DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                                          ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeBulkInvoicing() async {
    // 1. INTELLIGENT COHORT DUE HEADS GENERATION
    if (!_isManualParticulars && _bulkTargetType == 'CLASS') {
      if (_selectedDueHeadIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one active due fee head to bill, or switch to manual entry.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      setState(() => _bulkExecuting = true);
      final res = await PaymentManagementApiService.instance.bulkGenerateCohortDueHeads(
        targetClass: _bulkSelectedClass,
        targetSection: _bulkSelectedSection,
        academicYear: ref.read(studentFeeProvider).selectedAcademicYear,
        selectedHeadIds: _selectedDueHeadIds.toList(),
        autoDeductAdvanceCredit: _bulkAutoDeductAdvanceCredit,
        sendParentEmail: _bulkSendParentEmail,
      );

      if (mounted) {
        setState(() => _bulkExecuting = false);
        if (res['success'] == true) {
          final created = res['invoices_created'] ?? 0;
          final headsBilled = res['heads_billed_count'] ?? _selectedDueHeadIds.length;
          final totalBilled = (res['total_amount_billed'] as num?)?.toDouble() ?? 0.0;
          final advDeducted = (res['advance_credits_applied'] as num?)?.toDouble() ?? 0.0;
          final netDue = (res['net_amount_due'] as num?)?.toDouble() ?? (totalBilled - advDeducted);
          final emails = res['emails_sent'] ?? 0;

          await ref.read(studentFeeProvider.notifier).loadAllData();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚡ Generated $created invoices across $headsBilled due heads (Gross: ₹${totalBilled.toStringAsFixed(0)})! Auto-deducted ₹${advDeducted.toStringAsFixed(0)} advance credit. Net to collect: ₹${netDue.toStringAsFixed(0)}. Queued $emails parent emails with late fee notices.',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Bulk invoicing failed'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
      return;
    }

    final amt = double.tryParse(_bulkAmountController.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount per student'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    if (_bulkTargetType == 'INDIVIDUALS' && _selectedIndividualIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _bulkExecuting = true);
    final dueDate = _calculateBulkDueDate();

    final payload = {
      'target_type': _bulkTargetType,
      'target_class': _bulkSelectedClass,
      'target_section': _bulkSelectedSection,
      'student_ids': _selectedIndividualIds.toList(),
      'fee_type': _bulkFeeType,
      'fee_plan': _bulkFeePlan,
      'academic_year': ref.read(studentFeeProvider).selectedAcademicYear,
      'amount': amt,
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'due_days_offset': _bulkDueOffsetDays,
      'title': _bulkTitleController.text.trim(),
      'notes': _bulkNotesController.text.trim(),
      'skip_duplicates': _bulkSkipDuplicates,
      'auto_deduct_advance_credit': _bulkAutoDeductAdvanceCredit,
      'send_parent_email': _bulkSendParentEmail,
      'fee_structure_id': _selectedFeeStructureId,
    };

    final res = await ref.read(studentFeeProvider.notifier).enhancedBulkGenerate(payload);
    if (mounted) {
      setState(() => _bulkExecuting = false);
      if (res['success'] == true) {
        final created = res['invoices_created'] ?? 0;
        final skipped = res['duplicates_skipped'] ?? 0;
        final totalBilled = (res['total_amount_billed'] as num?)?.toDouble() ?? 0.0;
        final advanceDeducted = (res['advance_credits_applied'] as num?)?.toDouble() ?? 0.0;
        final netDue = (res['net_amount_due'] as num?)?.toDouble() ?? (totalBilled - advanceDeducted);
        final emailsSent = res['emails_sent'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully generated $created invoices (₹${totalBilled.toStringAsFixed(0)})! Auto-deducted ₹${advanceDeducted.toStringAsFixed(0)} advance credit. Net pending: ₹${netDue.toStringAsFixed(0)}. Dispatched $emailsSent parent emails. Skipped $skipped duplicates.',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Bulk invoicing failed'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ============================================================================
  // TAB 2: AUTOMATION & SCHEDULING RULES
  // ============================================================================
  // ============================================================================
  // TAB 2: AUTOMATION & SCHEDULING RULES
  // ============================================================================
  Widget _buildAutomationRulesTab(bool isDark) {
    final state = ref.watch(studentFeeProvider);
    final rules = state.scheduleRules;
    final availableSections = _getSectionsForClass(_ruleSelectedClass, state.classesWithSections);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner explaining automation engine
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF1E293B)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Intelligent Fee Structure Automation Engine',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Directly synchronized with your Cohort Fee Catalog. Select a class cohort below to inspect active vs un-scheduled fee heads. One-click schedule all heads or configure individual trigger days.',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    elevation: 1,
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: Text(
                    'Auto-Schedule All ${_ruleCohortFeeStructures.length} Heads',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _ruleCohortFeeStructures.isEmpty
                      ? null
                      : () async {
                          final conf = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Auto-Schedule Entire Cohort Catalog?'),
                              content: Text(
                                'This will automatically provision background recurring rules for all ${_ruleCohortFeeStructures.length} fee structures in $_ruleSelectedClass ($_ruleSelectedSection).\n\n• Monthly heads will trigger on the 25th with 10-day payment notice\n• Term/Quarterly heads will trigger at term commencement\n• Students\' advance wallet credits will be automatically deducted\n• Itemized payment statements with dynamic UPI QR will be emailed to parents',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Confirm & Schedule All'),
                                ),
                              ],
                            ),
                          );
                          if (conf == true) {
                            final res = await ref.read(studentFeeProvider.notifier).createBatchCohortSchedules(
                              targetClass: _ruleSelectedClass,
                              targetSection: _ruleSelectedSection,
                              academicYear: ref.read(studentFeeProvider).selectedAcademicYear,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message']?.toString() ?? 'Cohort fee heads scheduled successfully!'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                              _fetchRuleCohortFeeStructures();
                              ref.read(studentFeeProvider.notifier).loadScheduleRules();
                            }
                          }
                        },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  icon: Icon(_showCreateRuleForm ? Icons.close_rounded : Icons.add_rounded, size: 16),
                  label: Text(_showCreateRuleForm ? 'Close Form' : 'Custom Rule', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  onPressed: () {
                    setState(() {
                      _showCreateRuleForm = !_showCreateRuleForm;
                      if (_showCreateRuleForm) {
                        _editingRuleId = null;
                        _ruleFeeStructureId = null;
                        _ruleNameController.text = 'Custom School Rule';
                        _ruleTitleTemplateController.text = 'Tuition Fee - {MONTH} {YEAR}';
                        _ruleAmountController.text = '4500';
                        _ruleDayOfMonth = 25;
                        _ruleDueOffset = 10;
                        _ruleFrequency = 'MONTHLY';
                        _ruleBillingPeriod = 'NEXT_MONTH';
                        _ruleAutoDeductAdvanceCredit = true;
                        _ruleSendParentEmail = true;
                        _ruleIsActive = true;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // TARGET COHORT SELECTOR BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                const Text('Select Target Cohort:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 14),

                // Class Dropdown
                SizedBox(
                  width: 170,
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: state.classesList.contains(_ruleSelectedClass)
                            ? _ruleSelectedClass
                            : (state.classesList.isNotEmpty ? state.classesList.first : 'Class 10'),
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: state.classesList
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _ruleSelectedClass = val;
                              _ruleSelectedSection = 'All Sections';
                            });
                            _fetchRuleCohortFeeStructures();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Section Dropdown
                SizedBox(
                  width: 150,
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: availableSections.contains(_ruleSelectedSection)
                            ? _ruleSelectedSection
                            : 'All Sections',
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: availableSections
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _ruleSelectedSection = val);
                            _fetchRuleCohortFeeStructures();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info pill
                Expanded(
                  child: _loadingRuleCohortHeads
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : Text(
                          '${_ruleCohortFeeStructures.length} Fee Structure(s) defined for $_ruleSelectedClass ($_ruleSelectedSection)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // INLINE FORM IF OPEN
          if (_showCreateRuleForm) ...[
            _buildCreateOrEditRuleCard(isDark),
            const SizedBox(height: 20),
          ],

          // COHORT FEE STRUCTURE AUTOMATION MATRIX
          _buildFeeStructureAutomationMatrix(isDark, state, rules),
          const SizedBox(height: 24),

          // OTHER CONFIGURED RULES
          _buildOtherConfiguredRules(isDark, rules),
        ],
      ),
    );
  }

  /// Interactive Cohort Fee Structure Automation Matrix
  Widget _buildFeeStructureAutomationMatrix(bool isDark, StudentFeeState state, List<Map<String, dynamic>> rules) {
    if (_loadingRuleCohortHeads) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 10),
            Text('Loading fee structure catalog for selected cohort...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    if (_ruleCohortFeeStructures.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No Fee Structures Defined for $_ruleSelectedClass ($_ruleSelectedSection)',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Define fee heads in the Fee Structure Catalog to enable intelligent auto-scheduling, or click "Custom Rule" above.',
              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  'COHORT FEE STRUCTURE AUTOMATION MATRIX ($_ruleSelectedClass · $_ruleSelectedSection)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_ruleCohortFeeStructures.length} Catalog Heads',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ruleCohortFeeStructures.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final head = _ruleCohortFeeStructures[i];
            final headId = head['id']?.toString() ?? '';
            final headName = (head['fee_name'] ?? head['name'] ?? 'Fee Head').toString();

            final matchingRule = rules.firstWhere(
              (r) {
                if (r['fee_structure_id']?.toString() == headId && headId.isNotEmpty) return true;
                final rName = (r['rule_name']?.toString() ?? '').toLowerCase();
                final rTargetCls = r['target_class']?.toString() ?? '';
                if (rTargetCls == _ruleSelectedClass && rName.contains(headName.toLowerCase())) return true;
                return false;
              },
              orElse: () => {},
            );

            return _buildCohortFeeStructureAutomationCard(head, matchingRule.isNotEmpty ? matchingRule : null, isDark);
          },
        ),
      ],
    );
  }

  /// Individual Cohort Fee Structure Head Automation Card
  Widget _buildCohortFeeStructureAutomationCard(
    Map<String, dynamic> head,
    Map<String, dynamic>? matchingRule,
    bool isDark,
  ) {
    final headName = (head['fee_name'] ?? head['name'] ?? 'Fee Head').toString();
    final category = (head['fee_type'] ?? 'Tuition Fee').toString();
    final cycle = (head['billing_cycle'] ?? head['frequency_type'] ?? 'Monthly').toString();
    final amt = (head['amount'] as num?)?.toDouble() ?? 0.0;
    final cycleUpper = cycle.toUpperCase();
    final mult = cycleUpper.contains('QUART') ? 4 : cycleUpper.contains('HALF') ? 2 : cycleUpper.contains('ANNUAL') || cycleUpper.contains('YEAR') ? 1 : 12;
    final annualCommitment = (head['annual_total'] as num?)?.toDouble() ?? (amt * mult);
    final dueDay = (head['due_day_of_cycle'] as num?)?.toInt() ?? 10;
    final grace = (head['grace_period_days'] as num?)?.toInt() ?? 5;
    final isMandatory = head['is_mandatory'] == true;

    final hasRule = matchingRule != null && matchingRule.isNotEmpty;
    final isRuleActive = hasRule && matchingRule['is_active'] == true;
    final ruleId = hasRule ? matchingRule['id']?.toString() ?? '' : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasRule
              ? (isRuleActive ? const Color(0xFF16A34A).withValues(alpha: 0.5) : const Color(0xFFD97706).withValues(alpha: 0.5))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: hasRule ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category Icon, Name, and Status Badge / Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getFeeTypeIcon(category), color: const Color(0xFF4F46E5), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            headName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isMandatory)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Mandatory', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$category • Cohort: $_ruleSelectedClass ($_ruleSelectedSection)',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),

              // Status indicator
              if (hasRule) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRuleActive ? const Color(0xFF16A34A).withValues(alpha: 0.15) : const Color(0xFFD97706).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isRuleActive ? const Color(0xFF16A34A).withValues(alpha: 0.3) : const Color(0xFFD97706).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(isRuleActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded, size: 12, color: isRuleActive ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            isRuleActive ? 'AUTO-BILLING ACTIVE' : 'PAUSED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isRuleActive ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isRuleActive,
                      activeTrackColor: const Color(0xFF16A34A),
                      onChanged: (val) async {
                        await ref.read(studentFeeProvider.notifier).toggleScheduleRule(ruleId);
                        ref.read(studentFeeProvider.notifier).loadScheduleRules();
                      },
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.radio_button_unchecked_rounded, size: 12, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('NOT SCHEDULED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Specs Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(Icons.currency_rupee_rounded, '${_formatCurrency(amt)} / $cycle', isDark, color: const Color(0xFF4F46E5)),
              _buildBadge(Icons.calendar_today_rounded, '${_formatCurrency(annualCommitment)} / year', isDark),
              _buildBadge(Icons.timer_outlined, 'Due: ${dueDay}th of cycle (${grace}d grace)', isDark),
              if (hasRule) ...[
                _buildBadge(Icons.bolt_rounded, 'Triggers ${matchingRule['schedule_day_of_month'] ?? 25}${_getOrdinal((matchingRule['schedule_day_of_month'] as num?)?.toInt() ?? 25)} of month', isDark, isHighlight: true),
                _buildBadge(Icons.account_balance_wallet_rounded, 'Smart Wallet: ${matchingRule['auto_deduct_advance_credit'] == true ? 'Auto-Deduct' : 'Off'}', isDark, color: const Color(0xFF16A34A)),
                _buildBadge(Icons.email_outlined, 'Parent Notice: ${matchingRule['send_parent_email'] == true ? 'Dispatch' : 'Off'}', isDark, color: const Color(0xFF2563EB)),
              ],
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action & Telemetry Row
          if (hasRule) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Execution Telemetry: ${matchingRule['total_runs'] ?? 0} run(s) • ${matchingRule['total_invoices_generated'] ?? 0} invoice(s) generated (₹${((matchingRule['total_amount_generated'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)})',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 14),
                      label: const Text('Edit Schedule Preferences', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => _editExistingRule(matchingRule),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 15),
                      label: const Text('Run Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => _triggerRuleNow(ruleId, matchingRule['rule_name']?.toString() ?? headName),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      tooltip: 'Delete Rule',
                      onPressed: () => _confirmDeleteRule(ruleId, matchingRule['rule_name']?.toString() ?? headName),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'No recurring auto-billing rule active for this fee head. Invoices will not be generated automatically.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Activate Auto-Billing Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _selectFeeStructureForAutomation(head),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Configuration Card: Pre-filled from Catalog with Zero Manual Typing
  Widget _buildCreateOrEditRuleCard(bool isDark) {
    final isLinkedToCatalog = _ruleFeeStructureId != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isLinkedToCatalog ? Icons.lock_clock_rounded : Icons.tune_rounded,
                      color: const Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingRuleId != null
                            ? 'Edit Recurring Schedule Preferences'
                            : (isLinkedToCatalog
                                ? 'Configure Auto-Billing for Catalog Fee Head'
                                : 'Create Custom / Ad-hoc Recurring Rule'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLinkedToCatalog
                            ? 'All financial terms are locked from your Fee Structure Catalog. Set your trigger timing preferences below.'
                            : 'Configure custom recurring rule parameters for this cohort.',
                        style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Active on Save', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  Switch(
                    value: _ruleIsActive,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) => setState(() => _ruleIsActive = val),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),

          // CATALOG SYNCHRONIZED HERO BANNER (When linked to catalog)
          if (isLinkedToCatalog) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'CATALOG SYNCHRONIZED - CORE FINANCIALS LOCKED',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Zero Manual Typing Needed', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          children: [
                            Text('Rate: ₹${_ruleAmountController.text} / installment', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('Frequency: $_ruleFrequency', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('Target: $_ruleSelectedClass ($_ruleSelectedSection)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            Text('Title: ${_ruleTitleTemplateController.text}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // If NOT linked, show manual cohort, rate, and frequency inputs
          if (!isLinkedToCatalog) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rule Name', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _ruleNameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Class 10 Tuition Monthly Rule',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Class Cohort', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        initialValue: _ruleSelectedClass,
                        enabled: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Section', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        initialValue: _ruleSelectedSection,
                        enabled: false,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount (₹)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _ruleAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // SCHEDULE TIMING PREFERENCES (Always configurable)
          const Text(
            'SCHEDULE TIMING & BILLING PREFERENCES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trigger Day of Month', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _ruleDayOfMonth,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: [1, 5, 10, 15, 20, 25, 28, 30]
                              .map((d) => DropdownMenuItem(value: d, child: Text('$d${_getOrdinal(d)} of month (Billing Trigger)')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _ruleDayOfMonth = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Due Date Window', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _ruleDueOffset,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 7, child: Text('Due in 7 days')),
                            DropdownMenuItem(value: 10, child: Text('Due in 10 days (Default)')),
                            DropdownMenuItem(value: 15, child: Text('Due in 15 days')),
                            DropdownMenuItem(value: 20, child: Text('Due in 20 days')),
                            DropdownMenuItem(value: 30, child: Text('Due in 30 days / Month End')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _ruleDueOffset = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Billing Period Target', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _ruleBillingPeriod,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 'NEXT_MONTH', child: Text('Next Month (Advance Collection)')),
                            DropdownMenuItem(value: 'CURRENT_MONTH', child: Text('Current Month')),
                            DropdownMenuItem(value: 'NEXT_QUARTER', child: Text('Next Quarter / Term')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _ruleBillingPeriod = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // AUTOMATIONS & EXECUTIVE DELIVERY TOGGLES
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF16A34A)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Auto-Apply Advance Wallet Credits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text('Auto-deducts ledger overpayment balance to settle invoices', style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _ruleAutoDeductAdvanceCredit,
                        activeTrackColor: const Color(0xFF16A34A),
                        onChanged: (val) => setState(() => _ruleAutoDeductAdvanceCredit = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read_rounded, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dispatch Notice Emails to Parents', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text('Sends itemized statement with dynamic UPI QR & 1-Click Pay link', style: TextStyle(fontSize: 10.5, color: Color(0xFF2563EB))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _ruleSendParentEmail,
                        activeTrackColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _ruleSendParentEmail = val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showCreateRuleForm = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                icon: _savingRule
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(
                  _editingRuleId != null ? 'Update Recurring Rule' : 'Save & Activate Recurring Rule',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: _savingRule ? null : _saveRule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Section displaying any other configured rules not tied to current cohort
  Widget _buildOtherConfiguredRules(bool isDark, List<Map<String, dynamic>> rules) {
    // Filter rules that are for other classes or unlinked
    final otherRules = rules.where((r) {
      final tClass = r['target_class']?.toString() ?? '';
      return tClass != _ruleSelectedClass;
    }).toList();

    if (otherRules.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OTHER CONFIGURED AUTOMATION RULES (${otherRules.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: otherRules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) => _buildRuleCard(otherRules[i], isDark),
        ),
      ],
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> r, bool isDark) {
    final rid = r['id'].toString();
    final name = r['rule_name']?.toString() ?? 'Automation Rule';
    final isActive = r['is_active'] == true;
    final targetType = r['target_type']?.toString() ?? 'CLASS';
    final targetClass = r['target_class']?.toString() ?? 'All';
    final targetSection = r['target_section']?.toString();
    final freq = r['frequency']?.toString() ?? 'MONTHLY';
    final day = r['schedule_day_of_month'] ?? 25;
    final dueOffset = r['due_days_offset'] ?? 10;
    final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
    final nextRunStr = r['next_run_at']?.toString();
    final nextRun = nextRunStr != null ? DateTime.tryParse(nextRunStr) : null;
    final totalRuns = r['total_runs'] ?? 0;
    final totalGenerated = (r['total_amount_generated'] as num?)?.toDouble() ?? 0.0;
    final invoicesCount = r['total_invoices_generated'] ?? 0;
    final walletDeduct = r['auto_deduct_advance_credit'] ?? true;
    final sendEmail = r['send_parent_email'] ?? true;

    final targetLabel = targetType == 'ALL'
        ? 'All Classes'
        : (targetSection != null && targetSection != 'All Sections' && targetSection.isNotEmpty)
            ? '$targetClass ($targetSection)'
            : targetClass;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: isActive ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF16A34A).withValues(alpha: 0.12) : const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isActive ? 'ACTIVE' : 'PAUSED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    isActive ? 'Active' : 'Paused',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Switch(
                    value: isActive,
                    activeTrackColor: const Color(0xFF16A34A),
                    onChanged: (val) async {
                      await ref.read(studentFeeProvider.notifier).toggleScheduleRule(rid);
                      ref.read(studentFeeProvider.notifier).loadScheduleRules();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildBadge(Icons.group_rounded, targetLabel, isDark),
              _buildBadge(Icons.repeat_rounded, '$freq (on $day${_getOrdinal(day)})', isDark),
              _buildBadge(Icons.timer_outlined, 'Due in $dueOffset days', isDark),
              _buildBadge(Icons.currency_rupee_rounded, '${_formatCurrency(amt)} / student', isDark),
              if (r['fee_structure_id'] != null)
                _buildBadge(Icons.link_rounded, 'Catalog Synced', isDark, color: const Color(0xFF4F46E5)),
              if (walletDeduct)
                _buildBadge(Icons.account_balance_wallet_rounded, 'Auto-Wallet Settle', isDark, color: const Color(0xFF16A34A)),
              if (sendEmail)
                _buildBadge(Icons.email_outlined, 'Parent Email: ON', isDark, color: const Color(0xFF2563EB)),
              if (nextRun != null)
                _buildBadge(Icons.event_rounded, 'Next: ${DateFormat('dd MMM yyyy, hh:mm a').format(nextRun)}', isDark, isHighlight: true),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Telemetry: $totalRuns run(s) • $invoicesCount invoice(s) created (₹${totalGenerated.toStringAsFixed(0)})',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 14),
                    label: const Text('Edit Preferences', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () => _editExistingRule(r),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Run Rule Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () => _triggerRuleNow(rid, name),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    tooltip: 'Delete Rule',
                    onPressed: () => _confirmDeleteRule(rid, name),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, bool isDark, {bool isHighlight = false, Color? color}) {
    final effectiveColor = color ?? (isHighlight ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> _saveRule() async {
    final amt = double.tryParse(_ruleAmountController.text.trim()) ?? 0.0;
    if (_ruleNameController.text.trim().isEmpty || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid rule name and amount'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _savingRule = true);
    final payload = {
      'rule_name': _ruleNameController.text.trim(),
      'target_type': _ruleTargetType,
      'target_class': _ruleSelectedClass,
      'target_section': _ruleSelectedSection,
      'fee_type': _ruleFeeType,
      'fee_plan': _ruleFeePlan,
      'amount': amt,
      'title_template': _ruleTitleTemplateController.text.trim(),
      'notes': _ruleNotesController.text.trim(),
      'frequency': _ruleFrequency,
      'schedule_day_of_month': _ruleDayOfMonth,
      'due_days_offset': _ruleDueOffset,
      'billing_period_target': _ruleBillingPeriod,
      'academic_year': ref.read(studentFeeProvider).selectedAcademicYear,
      'is_active': _ruleIsActive,
      'auto_deduct_advance_credit': _ruleAutoDeductAdvanceCredit,
      'send_parent_email': _ruleSendParentEmail,
      if (_ruleFeeStructureId != null) 'fee_structure_id': _ruleFeeStructureId,
    };

    final res = _editingRuleId != null
        ? await ref.read(studentFeeProvider.notifier).updateScheduleRule(_editingRuleId!, payload)
        : await ref.read(studentFeeProvider.notifier).createScheduleRule(payload);
    if (mounted) {
      setState(() {
        _savingRule = false;
        if (res['success'] == true) {
          _showCreateRuleForm = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Rule saved successfully!'),
          backgroundColor: res['success'] == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _triggerRuleNow(String ruleId, String ruleName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run Automation Rule Now?'),
        content: Text('Do you want to immediately generate invoices for "$ruleName"?\nAny student who already has this invoice will be skipped automatically, and advance credit wallets will be settled.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Run Rule Now'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final res = await ref.read(studentFeeProvider.notifier).runScheduleRuleNow(ruleId);
      if (mounted) {
        final count = res['invoices_created'] ?? 0;
        final skipped = res['duplicates_skipped'] ?? 0;
        final creditsApplied = (res['advance_credits_applied'] as num?)?.toDouble() ?? 0.0;
        final emailsSent = res['emails_sent'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule completed: Generated $count invoices. Auto-deducted ₹${creditsApplied.toStringAsFixed(0)} credit. Dispatched $emailsSent parent emails. Skipped $skipped duplicates.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteRule(String ruleId, String ruleName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Automation Rule?'),
        content: Text('Are you sure you want to remove rule "$ruleName"? Existing invoices generated by this rule will remain intact.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      final success = await ref.read(studentFeeProvider.notifier).deleteScheduleRule(ruleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Rule deleted successfully' : 'Failed to delete rule'),
            backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ============================================================================
  // TAB 3: EXECUTION HISTORY & RUN LOGS
  // ============================================================================
  Widget _buildExecutionHistoryTab(bool isDark) {
    final state = ref.watch(studentFeeProvider);
    final runs = state.scheduleRuns;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AUTOMATION & BULK RUN TELEMETRY LOGS (${runs.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Run Logs',
                onPressed: () => ref.read(studentFeeProvider.notifier).loadScheduleRuns(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.loadingRuns)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (runs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),
                    const Text('No execution runs recorded yet.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Runs will appear here when bulk invoices or recurring rules are executed.', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: runs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final r = runs[i];
                final name = r['rule_name']?.toString() ?? 'Operation';
                final triggerType = r['trigger_type']?.toString() ?? 'SCHEDULED';
                final status = r['status']?.toString() ?? 'SUCCESS';
                final created = r['invoices_created'] ?? 0;
                final skipped = r['duplicates_skipped'] ?? 0;
                final totalAmt = (r['total_amount_billed'] as num?)?.toDouble() ?? 0.0;
                final advanceDeducted = (r['advance_credits_applied'] as num?)?.toDouble() ?? 0.0;
                final netDue = (r['net_amount_due'] as num?)?.toDouble() ?? (totalAmt - advanceDeducted);
                final emailsSent = r['emails_sent'] ?? 0;
                final targetSection = r['target_section']?.toString();
                final dueDateStr = r['due_date']?.toString();
                final executedAtStr = r['executed_at']?.toString();
                final executedAt = executedAtStr != null ? DateTime.tryParse(executedAtStr) : null;
                final actor = r['triggered_by_name']?.toString() ?? 'Automated System Scheduler';

                final isSuccess = status == 'SUCCESS';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                              : const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 18,
                          color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    triggerType.replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                if (targetSection != null && targetSection != 'All Sections') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Sec: $targetSection',
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Generated $created invoices (₹${totalAmt.toStringAsFixed(0)}) • Credit Deducted: ₹${advanceDeducted.toStringAsFixed(0)} • Net Pending: ₹${netDue.toStringAsFixed(0)} • Emails Sent: $emailsSent • Skipped $skipped duplicates${dueDateStr != null ? ' • Due: $dueDateStr' : ''} • by $actor',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (executedAt != null)
                        Text(
                          DateFormat('dd MMM, hh:mm a').format(executedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOG: STUDENT COHORT & DEDUCTIONS BREAKDOWN MODAL
  // ============================================================================
  void _showStudentCohortBreakdown(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _previewStudents.where((s) {
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              final name = (s['full_name'] ?? '').toString().toLowerCase();
              final roll = (s['roll_number'] ?? '').toString().toLowerCase();
              final adm = (s['admission_number'] ?? '').toString().toLowerCase();
              return name.contains(q) || roll.contains(q) || adm.contains(q);
            }).toList();

            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
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
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.people_alt_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target Student Cohort & Wallet Deductions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    _bulkTargetType == 'ALL'
                                        ? '${_previewStudents.length} enrolled student(s) across entire school'
                                        : (_bulkTargetType == 'INDIVIDUALS'
                                            ? '${_previewStudents.length} student(s) available for individual selection'
                                            : '${_previewStudents.length} student(s) matching $_bulkSelectedClass${_bulkSelectedSection != 'All Sections' ? ' ($_bulkSelectedSection)' : ''}'),
                                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Metrics summary row inside modal
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildModalStat('Gross Invoiced', _formatCurrency(_previewGrossTotal), const Color(0xFF2563EB)),
                            _buildModalStat('Advance Credit Auto-Deducted', '- ${_formatCurrency(_previewAdvanceApplied)}', const Color(0xFF16A34A)),
                            _buildModalStat('Net Collection Required', _formatCurrency(_previewNetPayable), const Color(0xFF0284C7)),
                            _buildModalStat('Fully Settled (₹0 Due)', '$_previewFullySettledCount', const Color(0xFF16A34A)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Box
                      SizedBox(
                        height: 38,
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 16),
                            hintText: 'Search by student name, roll number, admission number...',
                            hintStyle: const TextStyle(fontSize: 12),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) => setModalState(() => query = val),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Student List Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('STUDENT NAME & ID', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('CLASS & SECTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('GROSS INVOICE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('WALLET DEDUCTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('NET PAYABLE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                            Expanded(flex: 2, child: Text('SETTLEMENT STATUS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // List of Students
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text('No students match your query', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final s = filtered[idx];
                                  final name = s['full_name']?.toString() ?? 'Student';
                                  final roll = s['roll_number']?.toString() ?? '-';
                                  final adm = s['admission_number']?.toString() ?? '-';
                                  final rawCls = s['class']?.toString() ?? '';
                                  final cls = rawCls.isNotEmpty ? rawCls : (_bulkSelectedClass != 'All Classes' ? _bulkSelectedClass : '');
                                  final sec = s['section']?.toString() ?? '';
                                  final classSecDisplay = sec.isNotEmpty ? (cls.isNotEmpty ? '$cls ($sec)' : sec) : cls;
                                  final gross = (s['gross_amount'] as num?)?.toDouble() ?? 4500.0;
                                  final deducted = (s['advance_deducted'] as num?)?.toDouble() ?? 0.0;
                                  final net = (s['net_payable'] as num?)?.toDouble() ?? (gross - deducted);
                                  final isFullySettled = s['will_be_fully_settled'] == true || net <= 0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                              Text('Adm: $adm • Roll: $roll', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(classSecDisplay.isNotEmpty ? classSecDisplay : '-', style: const TextStyle(fontSize: 11.5)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(_formatCurrency(gross), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            deducted > 0 ? '- ${_formatCurrency(deducted)}' : '₹ 0',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: deducted > 0 ? const Color(0xFF16A34A) : null,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            _formatCurrency(net),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: net == 0 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isFullySettled
                                                  ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                                                  : const Color(0xFFD97706).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isFullySettled ? '100% Fully Paid' : 'Balance Pending',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isFullySettled ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // ============================================================================
  // DIALOG: EXECUTIVE PARENT EMAIL PREVIEW MODAL
  // ============================================================================
  void _showEmailPreviewDialog(bool isDark) {
    final dueDate = _calculateBulkDueDate();
    final unitAmt = double.tryParse(_bulkAmountController.text.trim()) ?? 4500.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
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
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Parent Statement Email Preview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Responsive HTML template sent to parents with dynamic UPI & breakdown',
                              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Simulated Email Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.school_rounded, color: Colors.white, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'EDUSHAMIIT INTERNATIONAL SCHOOL',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'OFFICIAL FEE INVOICE & TUITION STATEMENT',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Dear Parent / Guardian,',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please find the itemized tuition fee invoice generated for your ward. If you have an active advance credit wallet balance from prior overpayments, it has been deducted automatically as shown below.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 14),

                          // Student Info Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildEmailInfoRow('Student Name', 'Aarav Sharma'),
                                _buildEmailInfoRow('Class & Section', '$_bulkSelectedClass ($_bulkSelectedSection)'),
                                _buildEmailInfoRow('Roll / Adm Number', 'Roll: 1001 • ADM-2026-1001'),
                                _buildEmailInfoRow('Invoice Number', 'INV-2026-01048'),
                                _buildEmailInfoRow('Due Date', DateFormat('dd MMMM yyyy').format(dueDate), isHighlight: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Financial Breakdown Table
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  color: const Color(0xFFF1F5F9),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('PARTICULARS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                      Text('AMOUNT (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_bulkTitleController.text.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                                      Text(_formatCurrency(unitAmt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Gross Invoiced Subtotal', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                      Text('₹ 4,500', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                ),
                                if (_bulkAutoDeductAdvanceCredit) ...[
                                  const Divider(height: 1),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                            SizedBox(width: 4),
                                            Text('Less: Advance Credit Wallet Deducted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                                          ],
                                        ),
                                        Text('- ₹ 4,500', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  color: const Color(0xFFEFF6FF),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total Net Payable Amount', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                                      Text('₹ 0.00 (Fully Settled)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dynamic UPI QR Section inside simulated email
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Scan Dynamic UPI QR Code to Pay',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded, size: 90, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Payee VPA: kingupadhyay@axl • Instant Verification',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.payment_rounded, size: 14),
                                  label: const Text('1-Click Pay via UPI App (GPay / PhonePe / Paytm)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  onPressed: null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            'This is an automated statement from EduSHAMIIT School ERP. In case of discrepancies, contact accounts@edushamiit.com.',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
