import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';
import '../../../models/hostel_fee_models.dart';
import 'hostel_pos_receipt_dialog.dart';

class CollectPaymentDialog extends ConsumerStatefulWidget {
  final HostelStudentFeeItem? student;
  const CollectPaymentDialog({super.key, this.student});

  @override
  ConsumerState<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends ConsumerState<CollectPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _remarksController;
  String _paymentMode = 'Online - UPI';
  DateTime _paymentDate = DateTime.now();
  bool _sendReceipt = true;
  bool _isSubmitting = false;
  String? _selectedStudentId;
  String? _selectedInvoiceId;

  final List<String> _modes = [
    'Online - UPI',
    'Bank Transfer',
    'Cash',
    'Credit/Debit Card',
    'Cheque',
    'Demand Draft',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.student?.studentId;
    final initialAmount = widget.student != null && widget.student!.balanceDue > 0
        ? widget.student!.balanceDue.toInt().toString()
        : '25000';
    _amountController = TextEditingController(text: initialAmount);
    _referenceController = TextEditingController();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'student_id': _selectedStudentId,
      'amount': amount,
      'payment_mode': _paymentMode,
      'payment_method': _paymentMode,
      'payment_date': _paymentDate.toIso8601String().split('T')[0],
      if (_selectedInvoiceId != null) 'invoice_id': _selectedInvoiceId,
      if (_referenceController.text.trim().isNotEmpty) ...{
        'reference_number': _referenceController.text.trim(),
        'transaction_ref': _referenceController.text.trim(),
      },
      if (_remarksController.text.trim().isNotEmpty) ...{
        'remarks': _remarksController.text.trim(),
        'notes': _remarksController.text.trim(),
      },
      'send_receipt': _sendReceipt,
    };

    final success = await ref.read(hostelProvider.notifier).collectPayment(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        final allStudents = ref.read(hostelProvider).studentFeesRoster;
        HostelStudentFeeItem? studentObj = widget.student;
        if (studentObj == null) {
          for (final s in allStudents) {
            if (s.studentId == _selectedStudentId) {
              studentObj = s;
              break;
            }
          }
        }
        Navigator.of(context).pop(true);
        showDialog(
          context: context,
          builder: (ctx) => HostelPosReceiptDialog(
            studentName: studentObj?.studentName,
            roomNumber: studentObj?.roomNumber,
            hostelName: studentObj?.hostelName,
            amount: amount,
            paymentMethod: _paymentMode,
            transactionRef: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
            notes: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = state.studentFeesRoster;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Collect Hostel Fee',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Record fee receipt with instant voucher generation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 18),

                // Student Selector
                Text(
                  'Student *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.student != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            widget.student!.studentName.isNotEmpty ? widget.student!.studentName[0] : 'S',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.student!.studentName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${widget.student!.admissionNumber} • ${widget.student!.roomNumber} • Due: ${widget.student!.balanceDueFormatted}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppSearchableDropdownFormField<String>.fromMenuItems(
                    isExpanded: true,
                    initialValue: _selectedStudentId,
                    decoration: _inputDecoration(isDark, hint: 'Select Student'),
                    items: students.map((s) {
                      return DropdownMenuItem(
                        value: s.studentId,
                        child: Text(
                          '${s.studentName} (${s.admissionNumber}) - Due: ${s.balanceDueFormatted}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedStudentId = val;
                        final found = students.firstWhere((s) => s.studentId == val, orElse: () => students.first);
                        if (found.balanceDue > 0) {
                          _amountController.text = found.balanceDue.toInt().toString();
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Student is required' : null,
                  ),
                const SizedBox(height: 16),

                // Amount Row + Quick Selectors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Amount (₹) *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    if (widget.student != null && widget.student!.balanceDue > 0)
                      InkWell(
                        onTap: () {
                          _amountController.text = widget.student!.balanceDue.toInt().toString();
                        },
                        child: const Text(
                          'Fill Full Balance',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration(isDark, prefixIcon: Icons.currency_rupee_rounded),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Valid positive amount required';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Quick Amount Chips
                Wrap(
                  spacing: 8,
                  children: [5000, 10000, 15000, 25000, 40000].map((amt) {
                    return ActionChip(
                      label: Text('₹ $amt', style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() {
                          _amountController.text = amt.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Payment Mode & Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Mode *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppSearchableDropdownFormField<String>.fromMenuItems(
                            isExpanded: true,
                            initialValue: _paymentMode,
                            decoration: _inputDecoration(isDark),
                            items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMode = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Date *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _paymentDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) setState(() => _paymentDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transaction Reference
                Text(
                  'Transaction / Ref / Cheque No.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _referenceController,
                  decoration: _inputDecoration(isDark, hint: 'e.g. UPI-TXN-98234 / CHQ-10492'),
                ),
                const SizedBox(height: 16),

                // Remarks
                Text(
                  'Remarks / Notes',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: _inputDecoration(isDark, hint: 'Optional remarks or receipt notes'),
                ),
                const SizedBox(height: 16),

                // Receipt Notification Checkbox
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _sendReceipt,
                        activeColor: const Color(0xFF16A34A),
                        onChanged: (val) => setState(() => _sendReceipt = val ?? true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Dispatch digital receipt voucher to parent WhatsApp & Email',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Recording...' : 'Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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

  InputDecoration _inputDecoration(bool isDark, {String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}
