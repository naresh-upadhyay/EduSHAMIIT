import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';
import '../../../models/hostel_fee_models.dart';

class AddPenaltyDialog extends ConsumerStatefulWidget {
  final HostelStudentFeeItem student;
  const AddPenaltyDialog({super.key, required this.student});

  @override
  ConsumerState<AddPenaltyDialog> createState() => _AddPenaltyDialogState();
}

class _AddPenaltyDialogState extends ConsumerState<AddPenaltyDialog> {
  final _formKey = GlobalKey<FormState>();
  String _penaltyType = 'Late Fee Payment';
  late TextEditingController _amountController;
  late TextEditingController _reasonController;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  final List<String> _types = [
    'Late Fee Payment',
    'Room Property Damage',
    'Disciplinary Fine',
    'Room Key Replacement',
    'Unauthorized Appliances',
    'Mess Rule Violation',
    'Lost Hostel Asset',
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1000');
    _reasonController = TextEditingController(text: 'Fee dues overdue beyond grace period');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penalty amount must be > 0')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'student_id': widget.student.studentId,
      'penalty_type': _penaltyType,
      'charge_type': _penaltyType,
      'amount': amt,
      'reason': _reasonController.text.trim(),
      'description': _reasonController.text.trim(),
      'due_date': _dueDate.toIso8601String().split('T')[0],
    };

    final success = await ref.read(hostelProvider.notifier).addPenalty(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Hostel Penalty / Fine',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Assess late fee or disciplinary charge',
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
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),

                // Student Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFDC2626),
                        child: Text(
                          widget.student.studentName.isNotEmpty ? widget.student.studentName[0] : 'S',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.student.studentName} (${widget.student.admissionNumber}) • Room ${widget.student.roomNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Penalty Category
                Text(
                  'Violation / Penalty Category *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _penaltyType,
                  decoration: _inputDecoration(isDark),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _penaltyType = val);
                  },
                ),
                const SizedBox(height: 16),

                // Amount & Due Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fine Amount (₹) *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(isDark, prefixIcon: Icons.currency_rupee_rounded),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Amount required' : null,
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
                            'Due Date *',
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
                                initialDate: _dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) setState(() => _dueDate = picked);
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
                                    '${_dueDate.day.toString().padLeft(2, '0')}/${_dueDate.month.toString().padLeft(2, '0')}/${_dueDate.year}',
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

                // Reason
                Text(
                  'Reason / Incident Description *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: _inputDecoration(isDark, hint: 'Details regarding this penalty'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Reason required' : null,
                ),
                const SizedBox(height: 24),

                // Buttons
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
                          : const Icon(Icons.gavel_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Assessing...' : 'Assess Fine'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
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
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}
