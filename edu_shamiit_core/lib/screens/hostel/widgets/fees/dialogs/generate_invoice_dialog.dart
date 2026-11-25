import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';
import '../../../models/hostel_fee_models.dart';

class _StudentBillingOption {
  final String studentId;
  final String name;
  final String rollNumber;
  final String roomNumber;
  final String hostelName;

  _StudentBillingOption({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.roomNumber,
    required this.hostelName,
  });
}

class GenerateInvoiceDialog extends ConsumerStatefulWidget {
  final HostelStudentFeeItem? student;
  const GenerateInvoiceDialog({super.key, this.student});

  @override
  ConsumerState<GenerateInvoiceDialog> createState() => _GenerateInvoiceDialogState();
}

class _GenerateInvoiceDialogState extends ConsumerState<GenerateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  String? _selectedStudentId;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _heads = [
    {'head_name': 'Room Rent', 'amount': 35000.0},
    {'head_name': 'Mess & Food Charges', 'amount': 25000.0},
    {'head_name': 'Amenities & Electricity', 'amount': 8000.0},
    {'head_name': 'Laundry & Maintenance', 'amount': 4000.0},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.student?.studentId;
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  double get _totalAmount => _heads.fold(0.0, (acc, item) => acc + ((item['amount'] as num?)?.toDouble() ?? 0.0));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }
    if (_heads.isEmpty || _totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one fee head with amount > 0')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentAcademicYear = ref.read(hostelProvider).selectedAcademicYear;

    final payload = {
      'student_id': _selectedStudentId,
      'academic_year': currentAcademicYear,
      'billing_period': _titleController.text.trim(),
      'title': _titleController.text.trim(),
      'due_date': _dueDate.toIso8601String().split('T')[0],
      'items': _heads.map((h) => {
        'head_name': h['head_name'],
        'amount': (h['amount'] as num).toDouble(),
      }).toList(),
    };

    final success = await ref.read(hostelProvider.notifier).generateSingleInvoice(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_titleController.text.isEmpty || _titleController.text == 'Term 2 Hostel & Mess Fee (2024-2025)') {
      _titleController.text = 'Term 1 Hostel & Mess Fee (${state.selectedAcademicYear})';
    }

    // Combine studentFeesRoster and studentsRoster
    final Map<String, _StudentBillingOption> optionsMap = {};
    for (final s in state.studentFeesRoster) {
      if (s.studentId.isNotEmpty) {
        optionsMap[s.studentId] = _StudentBillingOption(
          studentId: s.studentId,
          name: s.studentName,
          rollNumber: s.admissionNumber.isNotEmpty ? s.admissionNumber : s.rollNumber,
          roomNumber: s.roomNumber,
          hostelName: s.hostelName,
        );
      }
    }
    for (final r in state.studentsRoster) {
      if (r.studentId.isNotEmpty && !optionsMap.containsKey(r.studentId)) {
        optionsMap[r.studentId] = _StudentBillingOption(
          studentId: r.studentId,
          name: r.studentName,
          rollNumber: r.rollNo.isNotEmpty ? r.rollNo : r.admissionId,
          roomNumber: r.roomNumber.isNotEmpty ? r.roomNumber : 'Unassigned',
          hostelName: r.hostelName,
        );
      }
    }
    final availableOptions = optionsMap.values.toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generate Hostel Invoice',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Create itemized billing statement for student',
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

                // Student Selector
                Text(
                  'Select Student *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.student != null)
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
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            widget.student!.studentName.isNotEmpty ? widget.student!.studentName[0] : 'S',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${widget.student!.studentName} (${widget.student!.admissionNumber}) • ${widget.student!.roomNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppSearchableDropdownFormField<String>.fromMenuItems(
                    isExpanded: true,
                    initialValue: availableOptions.any((o) => o.studentId == _selectedStudentId) ? _selectedStudentId : null,
                    decoration: _inputDecoration(isDark, hint: 'Select Student'),
                    items: availableOptions.map((s) {
                      return DropdownMenuItem(
                        value: s.studentId,
                        child: Text(
                          '${s.name} (${s.rollNumber}) • ${s.roomNumber}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedStudentId = val),
                    validator: (v) => v == null ? 'Please select a student' : null,
                  ),
                const SizedBox(height: 16),

                // Invoice Title & Due Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Billing Title *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _titleController,
                            decoration: _inputDecoration(isDark, hint: 'e.g. Term 2 Hostel Fee'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
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
                                lastDate: DateTime.now().add(const Duration(days: 180)),
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
                const SizedBox(height: 20),

                // Itemized Fee Heads Table
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fee Breakdown Items',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _heads.add({'head_name': 'Custom Fee Head', 'amount': 1000.0});
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Head', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ..._heads.asMap().entries.map((entry) {
                        final index = entry.key;
                        final head = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: head['head_name'] as String,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Fee Head Name',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (val) => head['head_name'] = val,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: (head['amount'] as num).toInt().toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      head['amount'] = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 18),
                                onPressed: _heads.length > 1
                                    ? () {
                                        setState(() => _heads.removeAt(index));
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Invoice Amount:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '₹ ${_totalAmount.toInt()}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Generating...' : 'Issue Invoice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
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
