import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class GenerateStudentInvoiceDialog extends ConsumerStatefulWidget {
  final String? preselectedStudentId;
  const GenerateStudentInvoiceDialog({super.key, this.preselectedStudentId});

  @override
  ConsumerState<GenerateStudentInvoiceDialog> createState() => _GenerateStudentInvoiceDialogState();
}

class _GenerateStudentInvoiceDialogState extends ConsumerState<GenerateStudentInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _title = 'Tuition & Academic Term Fee';
  String _feeType = 'Tuition Fee';
  String _feePlan = 'Monthly';
  final TextEditingController _amountController = TextEditingController(text: '4500');
  final TextEditingController _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  bool _submitting = false;

  List<PaymentLookupItem> _feeTypes = [];
  List<PaymentLookupItem> _billingCycles = [];

  List<Map<String, dynamic>> _applicableHeads = [];
  Map<String, dynamic>? _studentFeeStructureDetail;
  bool _loadingApplicableHeads = false;

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.preselectedStudentId;
    _loadLookups();
  }

  Future<void> _loadStudentApplicableHeads(String studentId) async {
    setState(() => _loadingApplicableHeads = true);
    final data = await PaymentManagementApiService.instance.getStudentApplicableFeeStructure(studentId);
    if (mounted) {
      setState(() {
        _loadingApplicableHeads = false;
        _studentFeeStructureDetail = data;
        if (data != null && data['applicable_heads'] is List) {
          _applicableHeads = List<Map<String, dynamic>>.from(data['applicable_heads'] as List);
        } else {
          _applicableHeads = [];
        }
      });
    }
  }

  Future<void> _loadLookups() async {
    final types = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_TYPE');
    final cycles = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_BILLING_CYCLE');
    if (mounted) {
      setState(() {
        _feeTypes = types;
        _billingCycles = cycles;
        if (types.isNotEmpty) _feeType = types.first.label;
        if (cycles.isNotEmpty) _feePlan = cycles.first.label;
      });
      if (_selectedStudentId != null) {
        _loadStudentApplicableHeads(_selectedStudentId!);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentFeeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedStudentId == null && state.studentFeesRoster.isNotEmpty) {
      _selectedStudentId = state.studentFeesRoster.first.studentId;
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Generate Student Invoice',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
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

                  // Student Dropdown
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
                            studentMap[s.studentId] = '${s.studentName} (${s.className} | Roll: ${s.rollNumber})';
                          }
                        }
                        if (_selectedStudentId != null && _selectedStudentId!.isNotEmpty && !studentMap.containsKey(_selectedStudentId)) {
                          studentMap[_selectedStudentId!] = 'Selected Student';
                        }
                        final effectiveStudentId = studentMap.containsKey(_selectedStudentId)
                            ? _selectedStudentId
                            : (studentMap.isNotEmpty ? studentMap.keys.first : null);

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: ValueKey('invoice_student_${effectiveStudentId ?? "none"}'),
                            value: effectiveStudentId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: studentMap.entries.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedStudentId = val);
                                _loadStudentApplicableHeads(val);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final selectedStudent = state.studentFeesRoster.where((s) => s.studentId == _selectedStudentId).firstOrNull;
                      if (selectedStudent != null && selectedStudent.advanceAmount > 0) {
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF047857), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Student has ₹ ${NumberFormat('#,##,###.##').format(selectedStudent.advanceAmount)} advance credit. This invoice will be auto-settled up to this amount upon creation.',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Applicable Fee Schedule Heads
                  if (_loadingApplicableHeads)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (_applicableHeads.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF2563EB)),
                                  SizedBox(width: 6),
                                  Text('APPLICABLE CLASS FEE HEADS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF2563EB))),
                                ],
                              ),
                              if (_studentFeeStructureDetail != null && _studentFeeStructureDetail!['totals'] is Map)
                                Text(
                                  'Total Ann: ₹${NumberFormat('#,##,###').format((_studentFeeStructureDetail!['totals']['total_annual_commitment'] as num?)?.toDouble() ?? 0)}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _applicableHeads.map((head) {
                              final headName = head['fee_name']?.toString() ?? '';
                              final amt = (head['amount'] as num?)?.toDouble() ?? 0.0;
                              final freq = head['frequency_type']?.toString() ?? 'Monthly';
                              final isSel = _title.startsWith(headName);

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _title = '$headName - $freq';
                                    _feeType = head['fee_type']?.toString() ?? _feeType;
                                    _feePlan = freq;
                                    _amountController.text = amt.toInt().toString();

                                    final dueDay = (head['due_day_of_cycle'] as num?)?.toInt() ?? 10;
                                    final now = DateTime.now();
                                    DateTime calculated = DateTime(now.year, now.month, dueDay);
                                    if (calculated.isBefore(now)) {
                                      calculated = DateTime(now.year, now.month + 1, dueDay);
                                    }
                                    _dueDate = calculated;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  child: Text(
                                    '$headName (₹${amt.toInt()})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Title
                  Text('Invoice Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
                    key: ValueKey('invoice_title_field_$_title'),
                    initialValue: _title,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => _title = val,
                  ),
                  const SizedBox(height: 16),

                  // Fee Type & Plan Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fee Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                                  final Map<String, String> typeMap = {};
                                  for (final t in _feeTypes) {
                                    if (t.label.isNotEmpty) typeMap[t.label] = t.label;
                                  }
                                  if (typeMap.isEmpty) {
                                    typeMap['Tuition Fee'] = 'Tuition Fee';
                                    typeMap['Exam Fee'] = 'Exam Fee';
                                    typeMap['Lab Fee'] = 'Lab Fee';
                                    typeMap['Library Fee'] = 'Library Fee';
                                    typeMap['Transport Fee'] = 'Transport Fee';
                                  }
                                  String effectiveType = _feeType;
                                  if (!typeMap.containsKey(effectiveType)) {
                                    final match = typeMap.keys.firstWhere(
                                      (k) => k.toLowerCase() == effectiveType.toLowerCase(),
                                      orElse: () => '',
                                    );
                                    if (match.isNotEmpty) {
                                      effectiveType = match;
                                    } else {
                                      typeMap[effectiveType] = effectiveType;
                                    }
                                  }

                                  return DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      key: ValueKey('fee_type_$effectiveType'),
                                      value: effectiveType,
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      items: typeMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _feeType = val);
                                      },
                                    ),
                                  );
                                },
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
                            Text('Billing Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                                  final Map<String, String> cycleMap = {};
                                  for (final c in _billingCycles) {
                                    if (c.label.isNotEmpty) cycleMap[c.label] = c.label;
                                  }
                                  if (cycleMap.isEmpty) {
                                    cycleMap['Monthly'] = 'Monthly';
                                    cycleMap['Quarterly'] = 'Quarterly';
                                    cycleMap['Annual'] = 'Annual';
                                    cycleMap['One-Time'] = 'One-Time';
                                  }
                                  String effectivePlan = _feePlan;
                                  if (!cycleMap.containsKey(effectivePlan)) {
                                    final match = cycleMap.keys.firstWhere(
                                      (k) => k.toLowerCase() == effectivePlan.toLowerCase(),
                                      orElse: () => '',
                                    );
                                    if (match.isNotEmpty) {
                                      effectivePlan = match;
                                    } else {
                                      cycleMap[effectivePlan] = effectivePlan;
                                    }
                                  }

                                  return DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      key: ValueKey('fee_plan_$effectivePlan'),
                                      value: effectivePlan,
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      items: cycleMap.entries.map((c) => DropdownMenuItem(value: c.key, child: Text(c.value))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _feePlan = val);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount & Due Date Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subtotal Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
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
                            Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => _dueDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(DateFormat('dd MMM yyyy').format(_dueDate), style: const TextStyle(fontSize: 13)),
                                    const Icon(Icons.calendar_today_rounded, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions
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
                            : const Text('Generate Invoice', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _submit() async {
    if (_selectedStudentId == null) return;
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    setState(() => _submitting = true);
    final ok = await PaymentManagementApiService.instance.generateStudentInvoice({
      'student_id': _selectedStudentId,
      'title': _title,
      'fee_type': _feeType,
      'fee_plan': _feePlan,
      'academic_year': ref.read(studentFeeProvider).selectedAcademicYear,
      'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
      'subtotal': amt,
      'concession_amount': 0.0,
      'penalty_amount': 0.0,
      'notes': _notesController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated successfully!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
