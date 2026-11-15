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

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.preselectedStudentId;
    _loadLookups();
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
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStudentId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: state.studentFeesRoster.map((s) {
                          return DropdownMenuItem(
                            value: s.studentId,
                            child: Text('${s.studentName} (${s.className} | Roll: ${s.rollNumber})'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedStudentId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text('Invoice Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextFormField(
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
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _feeTypes.any((t) => t.label == _feeType) ? _feeType : (_feeTypes.isNotEmpty ? _feeTypes.first.label : _feeType),
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  items: _feeTypes.map((t) => DropdownMenuItem(value: t.label, child: Text(t.label, overflow: TextOverflow.ellipsis))).toList(),
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
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _billingCycles.any((c) => c.label == _feePlan) ? _feePlan : (_billingCycles.isNotEmpty ? _billingCycles.first.label : _feePlan),
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  items: _billingCycles.map((c) => DropdownMenuItem(value: c.label, child: Text(c.label))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _feePlan = val);
                                  },
                                ),
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
