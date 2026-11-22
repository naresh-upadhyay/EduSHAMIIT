import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class EditStudentFeeStructureDialog extends ConsumerStatefulWidget {
  final bool isEditing;
  final String? structureId;
  final String? initialName;
  final String? initialType;
  final String? initialClass;
  final String? initialSection;
  final String? initialCycle;
  final String? initialFrequency;
  final double? initialAmount;
  final int? initialDueDay;
  final int? initialGracePeriod;
  final double? initialLateFine;
  final String? initialLateFineType;
  final bool? initialMandatory;
  final bool? initialRefundable;
  final String? initialDescription;
  final String? initialAcademicYear;

  const EditStudentFeeStructureDialog({
    super.key,
    this.isEditing = false,
    this.structureId,
    this.initialName,
    this.initialType,
    this.initialClass,
    this.initialSection,
    this.initialCycle,
    this.initialFrequency,
    this.initialAmount,
    this.initialDueDay,
    this.initialGracePeriod,
    this.initialLateFine,
    this.initialLateFineType,
    this.initialMandatory,
    this.initialRefundable,
    this.initialDescription,
    this.initialAcademicYear,
  });

  @override
  ConsumerState<EditStudentFeeStructureDialog> createState() => _EditStudentFeeStructureDialogState();
}

class _EditStudentFeeStructureDialogState extends ConsumerState<EditStudentFeeStructureDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descController;
  late TextEditingController _dueDayController;
  late TextEditingController _gracePeriodController;
  late TextEditingController _lateFineAmountController;

  String _feeType = 'Tuition Fee';
  String _classGrade = 'All Classes';
  String _sectionName = 'All Sections';
  String _billingCycle = 'Monthly';
  String _frequencyType = 'Monthly';
  String _lateFineType = 'FLAT';
  bool _enableLateFine = false;
  bool _isMandatory = true;
  bool _isRefundable = false;
  String _academicYear = '2026 - 2027';
  bool _submitting = false;

  List<PaymentLookupItem> _feeTypes = [];
  final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<Map<String, dynamic>> _frequencies = [
    {
      'type': 'Monthly',
      'label': 'Monthly (12x/yr)',
      'cycle': 'Monthly',
      'icon': Icons.calendar_month_rounded,
      'desc': 'Standard monthly academic tuition & services'
    },
    {
      'type': 'Quarterly',
      'label': 'Quarterly (4x/yr)',
      'cycle': 'Quarterly',
      'icon': Icons.view_agenda_outlined,
      'desc': 'Composite term charges & computer/science labs'
    },
    {
      'type': 'Half-Yearly',
      'label': 'Half-Yearly (2x/yr)',
      'cycle': 'Half-Yearly',
      'icon': Icons.pie_chart_outline_rounded,
      'desc': 'Mid-term and semestral examination fees'
    },
    {
      'type': 'Annual',
      'label': 'Annual (1x/yr)',
      'cycle': 'Annual',
      'icon': Icons.event_available_rounded,
      'desc': 'Development fee, sports & digital library access'
    },
    {
      'type': 'One-Time',
      'label': 'One-Time (Admission)',
      'cycle': 'One-Time',
      'icon': Icons.verified_user_outlined,
      'desc': 'Admission registration or refundable caution money'
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? 'Tuition Fee - Academic');
    _amountController = TextEditingController(text: widget.initialAmount != null ? widget.initialAmount!.toInt().toString() : '4500');
    _descController = TextEditingController(text: widget.initialDescription ?? 'Mandatory academic & learning facility charge');
    _dueDayController = TextEditingController(text: (widget.initialDueDay ?? 10).toString());
    _gracePeriodController = TextEditingController(text: (widget.initialGracePeriod ?? 5).toString());
    _lateFineAmountController = TextEditingController(text: (widget.initialLateFine ?? 50.0).toInt().toString());

    _feeType = widget.initialType ?? 'Tuition Fee';
    _classGrade = widget.initialClass ?? 'All Classes';
    _sectionName = widget.initialSection ?? 'All Sections';
    _billingCycle = widget.initialCycle ?? 'Monthly';
    _frequencyType = widget.initialFrequency ?? 'Monthly';
    _lateFineType = widget.initialLateFineType ?? 'FLAT';
    _enableLateFine = (widget.initialLateFine ?? 0.0) > 0;
    _isMandatory = widget.initialMandatory ?? true;
    _isRefundable = widget.initialRefundable ?? false;
    _academicYear = widget.initialAcademicYear ?? '2026 - 2027';

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final types = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_TYPE');
    if (mounted) {
      setState(() {
        _feeTypes = types;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _dueDayController.dispose();
    _gracePeriodController.dispose();
    _lateFineAmountController.dispose();
    super.dispose();
  }

  double get _currentAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _annualLiability {
    final amt = _currentAmount;
    switch (_frequencyType) {
      case 'One-Time':
      case 'Annual':
        return amt;
      case 'Monthly':
        return amt * 12.0;
      case 'Quarterly':
        return amt * 4.0;
      case 'Half-Yearly':
        return amt * 2.0;
      default:
        return amt;
    }
  }

  List<String> _getAvailableSections(StudentFeeState state) {
    if (_classGrade == 'All Classes') {
      return ['All Sections'];
    }
    final classSecs = state.classesWithSections[_classGrade];
    if (classSecs != null && classSecs.isNotEmpty) {
      return ['All Sections', ...classSecs];
    }
    return ['All Sections', 'Section A', 'Section B', 'Section C', 'Section D'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(studentFeeProvider);

    final availableClasses = <String>{'All Classes'};
    for (final c in state.classesList) {
      if (c.isNotEmpty) availableClasses.add(c);
    }
    for (final c in state.classesWithSections.keys) {
      if (c.isNotEmpty) availableClasses.add(c);
    }

    final availableSections = _getAvailableSections(state);
    if (!availableSections.contains(_sectionName)) {
      _sectionName = availableSections.first;
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEditing ? 'Edit Fee Structure Head' : 'Add Dedicated Fee Structure Head',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Standardize school fee heads, collection frequencies & due date rules',
                              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

                // SECTION 1: IDENTIFICATION & CATEGORY
                Text(
                  '1. FEE HEAD IDENTIFICATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),

                Text('Fee Head Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a fee head name' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Standard Tuition Fee, Science Lab & Practical',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fee Category Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _feeType,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: _getCategoryItems(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _feeType = val);
                                },
                              ),
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
                          Text('Academic Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school_outlined, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(_academicYear, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SECTION 2: CLASS & SECTION COHORT TARGETING
                Text(
                  '2. TARGET CLASS & SECTION COHORT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Applicable Class / Grade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: availableClasses.contains(_classGrade) ? _classGrade : 'All Classes',
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _classGrade = val;
                                      final newSections = _getAvailableSections(state);
                                      _sectionName = newSections.first;
                                    });
                                  }
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
                          Text('Dedicated Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sectionName,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: availableSections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _sectionName = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _classGrade == 'All Classes'
                      ? '✓ Universal Fee Head: Applies across all classes and cohorts'
                      : '✓ Dedicated Cohort: Applies to $_classGrade ($_sectionName)',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),

                // SECTION 3: BILLING FREQUENCY & TIMING
                Text(
                  '3. BILLING FREQUENCY & TIMING',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _frequencies.map((f) {
                    final isSel = _frequencyType == f['type'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _frequencyType = f['type'] as String;
                          _billingCycle = f['cycle'] as String;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? (isDark ? const Color(0xFF1D4ED8).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSel ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(f['icon'] as IconData, size: 15, color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              f['label'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // SECTION 4: AMOUNT & REAL-TIME COMMITMENT
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard Amount Per Cycle (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final amt = double.tryParse(v ?? '');
                              if (amt == null || amt <= 0) return 'Enter valid amount > 0';
                              return null;
                            },
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              hintText: '4500',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B1329) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate_outlined, size: 14, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text('ANNUAL COMMITMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF16A34A))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFmt.format(_annualLiability),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                            ),
                            Text(
                              _getAnnualCommitmentFormula(),
                              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SECTION 5: DUE DATE SCHEDULE & LATE FINE RULES
                Text(
                  '4. DUE DATE WINDOW & LATE FINE RULES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due Day of Cycle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dueDayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: 'th of cycle',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          Text('Grace Period Window', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _gracePeriodController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              suffixText: 'days',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Late fine toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.gavel_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Enforce Late Payment Fine Policy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  Text('Auto-assess penalty if unpaid after due date + grace period', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _enableLateFine,
                            activeTrackColor: const Color(0xFFEF4444),
                            onChanged: (val) => setState(() => _enableLateFine = val),
                          ),
                        ],
                      ),
                      if (_enableLateFine) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fine Amount (₹)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _lateFineAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Calculation Mode', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Flat Surcharge', style: TextStyle(fontSize: 11)),
                                        selected: _lateFineType == 'FLAT',
                                        onSelected: (s) => setState(() => _lateFineType = 'FLAT'),
                                      ),
                                      const SizedBox(width: 6),
                                      ChoiceChip(
                                        label: const Text('Daily Accrual', style: TextStyle(fontSize: 11)),
                                        selected: _lateFineType == 'PER_DAY',
                                        onSelected: (s) => setState(() => _lateFineType = 'PER_DAY'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 6: POLICIES & DESCRIPTIONS
                Text(
                  '5. POLICIES & DESCRIPTION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Mandatory Head', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Auto-included in default class bills', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        value: _isMandatory,
                        activeTrackColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _isMandatory = val),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Refundable Deposit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        subtitle: const Text('E.g. Caution money refundable on TC', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        value: _isRefundable,
                        activeTrackColor: const Color(0xFF16A34A),
                        onChanged: (val) => setState(() => _isRefundable = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text('Description / Policy Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Brief description shown on parent portal and fee slips',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 24),

                // ACTION BUTTONS
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(widget.isEditing ? 'Save Changes' : 'Create Dedicated Fee Head', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getAnnualCommitmentFormula() {
    final amt = currencyFmt.format(_currentAmount);
    switch (_frequencyType) {
      case 'Monthly':
        return '$amt/month × 12 months';
      case 'Quarterly':
        return '$amt/quarter × 4 quarters';
      case 'Half-Yearly':
        return '$amt/term × 2 terms';
      case 'Annual':
        return '$amt once per academic year';
      case 'One-Time':
        return '$amt one-time enrollment charge';
      default:
        return '$amt/cycle';
    }
  }

  List<DropdownMenuItem<String>> _getCategoryItems() {
    final Map<String, String> catMap = {
      'Tuition Fee': 'Tuition Fee (Core Academic)',
      'Admission Fee': 'Admission & Registration Fee',
      'Examination Fee': 'Examination & Assessment Fee',
      'Science & Computer Lab Fee': 'Science & Computer Lab Fee',
      'Library & Digital Resources Fee': 'Library & Digital Resources Fee',
      'Sports & Fitness Fee': 'Sports & Fitness Fee',
      'Transportation Fee': 'Transportation / Bus Transit',
      'Hostel Fee': 'Hostel & Boarding Fee',
      'Security Deposit': 'Security / Caution Deposit (Refundable)',
      'Miscellaneous': 'Miscellaneous & Campus Amenities',
    };

    for (final t in _feeTypes) {
      if (t.label.isNotEmpty && !catMap.containsKey(t.label)) {
        catMap[t.label] = t.label;
      }
    }

    if (!catMap.containsKey(_feeType)) {
      catMap[_feeType] = _feeType;
    }

    return catMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amt = _currentAmount;
    if (amt <= 0 || _nameController.text.trim().isEmpty) return;

    setState(() => _submitting = true);

    final dueDay = int.tryParse(_dueDayController.text.trim()) ?? 10;
    final graceDays = int.tryParse(_gracePeriodController.text.trim()) ?? 5;
    final lateFine = _enableLateFine ? (double.tryParse(_lateFineAmountController.text.trim()) ?? 0.0) : 0.0;

    final payload = {
      'fee_name': _nameController.text.trim(),
      'fee_type': _feeType,
      'class_grade': _classGrade,
      'section_name': _sectionName,
      'billing_cycle': _billingCycle,
      'frequency_type': _frequencyType,
      'amount': amt,
      'due_day_of_cycle': dueDay,
      'grace_period_days': graceDays,
      'late_fine_amount': lateFine,
      'late_fine_type': _lateFineType,
      'is_mandatory': _isMandatory,
      'is_refundable': _isRefundable,
      'description': _descController.text.trim(),
      'academic_year': _academicYear,
    };

    bool ok = false;
    if (widget.isEditing && widget.structureId != null) {
      ok = await PaymentManagementApiService.instance.updateStudentFeeStructure(widget.structureId!, payload);
    } else {
      ok = await PaymentManagementApiService.instance.createStudentFeeStructure(payload);
    }

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Fee structure head updated successfully!' : 'Dedicated fee structure head created successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }
}
