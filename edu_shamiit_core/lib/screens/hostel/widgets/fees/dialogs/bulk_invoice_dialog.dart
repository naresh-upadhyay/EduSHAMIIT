import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';

class BulkInvoiceDialog extends ConsumerStatefulWidget {
  const BulkInvoiceDialog({super.key});

  @override
  ConsumerState<BulkInvoiceDialog> createState() => _BulkInvoiceDialogState();
}

class _BulkInvoiceDialogState extends ConsumerState<BulkInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedHostel = 'All Hostels';
  String? _selectedFeePlanId;
  late TextEditingController _titleController;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;
  Set<String> _selectedStudentIds = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student to invoice')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentAcademicYear = ref.read(hostelProvider).selectedAcademicYear;

    final payload = {
      'academic_year': currentAcademicYear,
      'title': _titleController.text.trim(),
      'due_date': _dueDate.toIso8601String().split('T')[0],
      'student_ids': _selectedStudentIds.toList(),
      if (_selectedHostel != 'All Hostels') 'hostel_name': _selectedHostel,
      if (_selectedFeePlanId != null) 'fee_plan_id': _selectedFeePlanId,
    };

    final success = await ref.read(hostelProvider.notifier).generateBulkInvoices(payload);

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
    final plans = state.feePlans;

    if (_titleController.text.isEmpty || _titleController.text.contains('(2024-2025)')) {
      _titleController.text = 'Term 2 Hostel Fee Batch Billing (${state.selectedAcademicYear})';
    }

    // Filter eligible students from visible grid roster matching selected hostel
    final eligibleStudents = state.studentFeesRoster.where((s) {
      if (_selectedHostel == 'All Hostels') return true;
      return s.hostelName.toLowerCase().contains(_selectedHostel.toLowerCase()) ||
          _selectedHostel.toLowerCase().contains(s.hostelName.toLowerCase());
    }).toList();

    if (!_isInitialized) {
      _isInitialized = true;
      if (state.selectedFeeAccountIds.isNotEmpty) {
        _selectedStudentIds = state.studentFeesRoster
            .where((s) => state.selectedFeeAccountIds.contains(s.id) || state.selectedFeeAccountIds.contains(s.studentId))
            .map((s) => s.studentId)
            .toSet();
      } else {
        _selectedStudentIds = eligibleStudents.map((s) => s.studentId).toSet();
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.dynamic_feed_rounded, color: Color(0xFF7C3AED), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bulk Invoice Generation',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Academic Year: ${state.selectedAcademicYear} • Scoped to Visible Roster',
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

                // Target Hostel
                Text(
                  'Target Hostel Cohort *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  isExpanded: true,
                  initialValue: _selectedHostel,
                  decoration: _inputDecoration(isDark),
                  items: const [
                    DropdownMenuItem(value: 'All Hostels', child: Text('All Hostels (All Enrolled Students)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Boys Hostel A', child: Text('Boys Hostel A', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Girls Hostel A', child: Text('Girls Hostel A', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Boys Hostel B', child: Text('Boys Hostel B', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedHostel = val;
                        final filtered = state.studentFeesRoster.where((s) {
                          if (val == 'All Hostels') return true;
                          return s.hostelName.toLowerCase().contains(val.toLowerCase()) ||
                              val.toLowerCase().contains(s.hostelName.toLowerCase());
                        }).map((s) => s.studentId).toSet();
                        _selectedStudentIds = filtered;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Target Students Selection Box
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Target Students (${_selectedStudentIds.length}/${eligibleStudents.length} Selected)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: eligibleStudents.isEmpty
                          ? null
                          : () {
                              setState(() {
                                if (_selectedStudentIds.length == eligibleStudents.length) {
                                  _selectedStudentIds.clear();
                                } else {
                                  _selectedStudentIds = eligibleStudents.map((s) => s.studentId).toSet();
                                }
                              });
                            },
                      child: Text(
                        _selectedStudentIds.length == eligibleStudents.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Material(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: eligibleStudents.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No enrolled hostel students found for selected criteria',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: eligibleStudents.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                            itemBuilder: (context, index) {
                              final student = eligibleStudents[index];
                              final isChecked = _selectedStudentIds.contains(student.studentId);
                              return CheckboxListTile(
                                dense: true,
                                value: isChecked,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                activeColor: const Color(0xFF7C3AED),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        student.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        student.className,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${student.hostelName} • Room ${student.roomNumber} • ${student.feePlan}',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: Text(
                                  '₹${student.totalFee.toInt()}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStudentIds.add(student.studentId);
                                    } else {
                                      _selectedStudentIds.remove(student.studentId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 16),

                // Fee Plan
                Text(
                  'Fee Structure / Plan Template',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                AppSearchableDropdownFormField<String?>.fromMenuItems(
                  isExpanded: true,
                  initialValue: _selectedFeePlanId,
                  decoration: _inputDecoration(isDark, hint: 'Use Student Assigned Plans (Default)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Use Student Assigned Plans (Default)', overflow: TextOverflow.ellipsis),
                    ),
                    ...plans.map((p) {
                      return DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text('${p.planName} (${p.formattedTotal})', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedFeePlanId = val),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Invoice Title *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration(isDark),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Title required' : null,
                ),
                const SizedBox(height: 16),

                // Due Date
                Text(
                  'Payment Due Date *',
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
                const SizedBox(height: 20),

                // Summary Notice Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Invoices will be auto-generated with student fee plans and parents will receive instant notifications.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6D28D9)),
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
                      onPressed: (_isSubmitting || _selectedStudentIds.isEmpty) ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Processing Batch...' : 'Generate Bulk Invoices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
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

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
      ),
    );
  }
}
