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
  final String? initialAcademicStartDate;
  final List<dynamic>? initialInstallmentDates;
  final Map<String, dynamic>? initialReminderStages;

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
    this.initialAcademicStartDate,
    this.initialInstallmentDates,
    this.initialReminderStages,
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
  DateTime _academicStartDate = DateTime(2026, 4, 1);
  bool _submitting = false;

  List<Map<String, dynamic>> _installmentDates = [];
  final Map<String, bool> _reminderStages = {
    'd_10': true,
    'd_5': true,
    'd_2': true,
    'd_1': true,
    'd_due': true,
    'd_overdue': true,
  };

  List<PaymentLookupItem> _feeTypes = [];
  final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<Map<String, String>> _frequencyOptions = [
    {'type': 'Monthly', 'label': 'Monthly (12 Installments / Year)', 'cycle': 'Monthly'},
    {'type': 'Quarterly', 'label': 'Quarterly (4 Installments / Year)', 'cycle': 'Quarterly'},
    {'type': 'Half-Yearly', 'label': 'Half-Yearly (2 Installments / Year)', 'cycle': 'Half-Yearly'},
    {'type': 'Annual', 'label': 'Annual (1 Installment / Year)', 'cycle': 'Annual'},
    {'type': 'One-Time', 'label': 'One-Time / Admission (1 Installment)', 'cycle': 'One-Time'},
    {'type': 'Custom', 'label': 'Custom Installment Schedule', 'cycle': 'Custom'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? 'Tuition Fee - Academic');
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount!.toInt().toString() : '4500',
    );
    _descController = TextEditingController(
      text: widget.initialDescription ?? 'Mandatory academic & learning facility charge',
    );
    _dueDayController = TextEditingController(text: (widget.initialDueDay ?? 10).toString());
    _gracePeriodController = TextEditingController(text: (widget.initialGracePeriod ?? 5).toString());
    _lateFineAmountController = TextEditingController(
      text: (widget.initialLateFine ?? 50.0).toInt().toString(),
    );

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

    if (widget.initialAcademicStartDate != null && widget.initialAcademicStartDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.initialAcademicStartDate!);
      if (parsed != null) _academicStartDate = parsed;
    }

    if (widget.initialReminderStages != null) {
      widget.initialReminderStages!.forEach((k, v) {
        _reminderStages[k] = v == true;
      });
    }

    if (widget.initialInstallmentDates != null && widget.initialInstallmentDates!.isNotEmpty) {
      _installmentDates = widget.initialInstallmentDates!
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else {
      _generateDefaultInstallments();
    }

    _loadLookups();
  }

  void _generateDefaultInstallments() {
    final amt = _currentAmount;
    final List<Map<String, dynamic>> dates = [];
    final startYear = _academicStartDate.year;
    final startMonth = _academicStartDate.month;

    if (_frequencyType == 'Monthly') {
      for (int i = 0; i < 12; i++) {
        final totalMonth = startMonth - 1 + i;
        final curYear = startYear + (totalMonth ~/ 12);
        final curMonth = (totalMonth % 12) + 1;
        final lastDay = DateTime(curYear, curMonth + 1, 0).day;
        final d = DateTime(curYear, curMonth, lastDay);
        final label = DateFormat('MMM yyyy').format(DateTime(curYear, curMonth, 1));
        dates.add({
          'seq': i + 1,
          'label': label,
          'date': DateFormat('yyyy-MM-dd').format(d),
          'amount': amt,
        });
      }
    } else if (_frequencyType == 'Quarterly') {
      final quarterOffsets = [2, 5, 8, 11]; // End of Q1, Q2, Q3, Q4
      for (int q = 0; q < quarterOffsets.length; q++) {
        final totalMonth = startMonth - 1 + quarterOffsets[q];
        final curYear = startYear + (totalMonth ~/ 12);
        final curMonth = (totalMonth % 12) + 1;
        final lastDay = DateTime(curYear, curMonth + 1, 0).day;
        final d = DateTime(curYear, curMonth, lastDay);
        final qNames = ['Q1 (Apr-Jun)', 'Q2 (Jul-Sep)', 'Q3 (Oct-Dec)', 'Q4 (Jan-Mar)'];
        dates.add({
          'seq': q + 1,
          'label': q < qNames.length ? qNames[q] : 'Quarter ${q + 1}',
          'date': DateFormat('yyyy-MM-dd').format(d),
          'amount': amt,
        });
      }
    } else if (_frequencyType == 'Half-Yearly') {
      final hOffsets = [5, 11]; // End of Sem 1, Sem 2
      final hNames = ['Term 1 / Mid-Year', 'Term 2 / Final Year'];
      for (int h = 0; h < hOffsets.length; h++) {
        final totalMonth = startMonth - 1 + hOffsets[h];
        final curYear = startYear + (totalMonth ~/ 12);
        final curMonth = (totalMonth % 12) + 1;
        final lastDay = DateTime(curYear, curMonth + 1, 0).day;
        final d = DateTime(curYear, curMonth, lastDay);
        dates.add({
          'seq': h + 1,
          'label': h < hNames.length ? hNames[h] : 'Half-Year ${h + 1}',
          'date': DateFormat('yyyy-MM-dd').format(d),
          'amount': amt,
        });
      }
    } else if (_frequencyType == 'Annual') {
      final lastDay = DateTime(startYear, startMonth + 1, 0).day;
      dates.add({
        'seq': 1,
        'label': 'Academic Year $startYear-${startYear + 1}',
        'date': DateFormat('yyyy-MM-dd').format(DateTime(startYear, startMonth, lastDay)),
        'amount': amt,
      });
    } else if (_frequencyType == 'One-Time') {
      dates.add({
        'seq': 1,
        'label': 'Admission Enrollment',
        'date': DateFormat('yyyy-MM-dd').format(_academicStartDate),
        'amount': amt,
      });
    }

    setState(() {
      _installmentDates = dates;
    });
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
    if (_installmentDates.isNotEmpty) {
      return _installmentDates.fold(
        0.0,
        (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? _currentAmount),
      );
    }
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

  Future<void> _pickAcademicStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _academicStartDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'SELECT ACADEMIC SESSION START DATE',
      confirmText: 'SET START DATE',
    );
    if (picked != null && picked != _academicStartDate) {
      setState(() {
        _academicStartDate = picked;
      });
      _generateDefaultInstallments();
    }
  }

  Future<void> _editInstallmentDate(int index) async {
    final item = _installmentDates[index];
    DateTime currentDate = DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'SELECT DUE DATE FOR ${item['label']}',
      confirmText: 'UPDATE DATE',
    );

    if (picked != null) {
      setState(() {
        item['date'] = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addCustomInstallment() {
    final nextSeq = _installmentDates.length + 1;
    final lastDateStr = _installmentDates.isNotEmpty ? _installmentDates.last['date']?.toString() : null;
    DateTime nextDate = lastDateStr != null
        ? (DateTime.tryParse(lastDateStr)?.add(const Duration(days: 30)) ?? DateTime.now())
        : DateTime.now();

    setState(() {
      _installmentDates.add({
        'seq': nextSeq,
        'label': 'Inst #$nextSeq (${DateFormat('MMM yyyy').format(nextDate)})',
        'date': DateFormat('yyyy-MM-dd').format(nextDate),
        'amount': _currentAmount,
      });
      _frequencyType = 'Custom';
    });
  }

  void _removeInstallment(int index) {
    if (_installmentDates.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one installment date is required for a fee structure.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _installmentDates.removeAt(index);
      for (int i = 0; i < _installmentDates.length; i++) {
        _installmentDates[i]['seq'] = i + 1;
      }
      _frequencyType = 'Custom';
    });
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
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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
                              'Standardize school fee heads, flexible installment dates & automated parent notice rules',
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

                // SECTION 1: IDENTIFICATION & ACADEMIC SESSION
                Text(
                  '1. FEE HEAD IDENTIFICATION & ACADEMIC SESSION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),

                Text('Fee Head Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a fee head name' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Standard Tuition Fee, Science Lab & Practical, Exam Fee',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fee Category Type
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

                    // Academic Year & Start Date
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Academic Session & Start Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickAcademicStartDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_academicYear, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                          Text(
                                            'Starts: ${DateFormat('dd MMM yyyy').format(_academicStartDate)}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Change', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
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

                // SECTION 3: BILLING FREQUENCY & INSTALLMENT SCHEDULE DATES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. BILLING FREQUENCY & INSTALLMENT SCHEDULE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    ),
                    InkWell(
                      onTap: _addCustomInstallment,
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            '+ Add Custom Date',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Frequency Dropdown
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collection Frequency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                                value: _frequencyOptions.any((f) => f['type'] == _frequencyType) ? _frequencyType : 'Custom',
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: _frequencyOptions.map((f) {
                                  return DropdownMenuItem<String>(
                                    value: f['type'],
                                    child: Text(f['label']!, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _frequencyType = val;
                                      final match = _frequencyOptions.firstWhere((f) => f['type'] == val, orElse: () => {'cycle': 'Monthly'});
                                      _billingCycle = match['cycle'] ?? 'Monthly';
                                    });
                                    if (val != 'Custom') {
                                      _generateDefaultInstallments();
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount Per Installment
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount Per Installment (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final amt = double.tryParse(val.trim()) ?? 0.0;
                              setState(() {
                                for (var inst in _installmentDates) {
                                  inst['amount'] = amt;
                                }
                              });
                            },
                            validator: (v) {
                              final amt = double.tryParse(v ?? '');
                              if (amt == null || amt <= 0) return 'Enter amount > 0';
                              return null;
                            },
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              hintText: '4500',
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

                // Annual Commitment Summary Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1329) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined, size: 20, color: Color(0xFF16A34A)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ANNUAL LIABILITY COMMITMENT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF16A34A))),
                              const SizedBox(height: 2),
                              Text(
                                '${currencyFmt.format(_currentAmount)} × ${_installmentDates.length} scheduled installment(s)',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        currencyFmt.format(_annualLiability),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Interactive Installment Schedule List
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SCHEDULED INSTALLMENT DATES (${_installmentDates.length})',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          Text(
                            'Tap any date to customize (e.g. Feb 20th)',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _installmentDates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final inst = _installmentDates[idx];
                            final dateStr = inst['date']?.toString() ?? '';
                            final parsedDate = DateTime.tryParse(dateStr);
                            final formattedDate = parsedDate != null ? DateFormat('dd MMM yyyy').format(parsedDate) : dateStr;
                            final instAmount = (inst['amount'] as num?)?.toDouble() ?? _currentAmount;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      inst['label']?.toString() ?? 'Installment ${idx + 1}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _editInstallmentDate(idx),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.edit_calendar_rounded, size: 13, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 5),
                                          Text(
                                            formattedDate,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    currencyFmt.format(instAmount),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Remove Installment',
                                    onPressed: () => _removeInstallment(idx),
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
                const SizedBox(height: 20),

                // SECTION 4: DUE DATE WINDOW, LATE FINES & AUTOMATED REMINDERS
                Text(
                  '4. DUE DATE WINDOW, LATE FINES & AUTOMATED NOTICES',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Default Due Day of Cycle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                const SizedBox(height: 12),

                // Multi-Stage Automated Parent Reminder Notice Milestones
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.mark_email_read_rounded, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Automated Multi-Stage Parent Email Notices', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text('Sends notifications with dynamic UPI QR code, advance wallet balance & late fine warnings', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildReminderChip('d_10', '10 Days Before', isDark),
                          _buildReminderChip('d_5', '5 Days Before', isDark),
                          _buildReminderChip('d_2', '2 Days Before', isDark),
                          _buildReminderChip('d_1', '1 Day Before (Final)', isDark),
                          _buildReminderChip('d_due', 'On Due Date', isDark),
                          _buildReminderChip('d_overdue', 'Overdue Alert', isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 5: POLICIES & DESCRIPTIONS
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

  Widget _buildReminderChip(String key, String label, bool isDark) {
    final active = _reminderStages[key] == true;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      selected: active,
      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
      checkmarkColor: const Color(0xFF2563EB),
      onSelected: (val) {
        setState(() {
          _reminderStages[key] = val;
        });
      },
    );
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
      'academic_start_date': DateFormat('yyyy-MM-dd').format(_academicStartDate),
      'installment_dates': _installmentDates,
      'reminder_stages': _reminderStages,
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
