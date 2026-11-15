import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class EditStudentFeeStructureDialog extends ConsumerStatefulWidget {
  final bool isEditing;
  final String? structureId;
  final String? initialName;
  final String? initialType;
  final String? initialClass;
  final String? initialCycle;
  final double? initialAmount;
  final String? initialDescription;
  final bool? initialMandatory;

  const EditStudentFeeStructureDialog({
    super.key,
    this.isEditing = false,
    this.structureId,
    this.initialName,
    this.initialType,
    this.initialClass,
    this.initialCycle,
    this.initialAmount,
    this.initialDescription,
    this.initialMandatory,
  });

  @override
  ConsumerState<EditStudentFeeStructureDialog> createState() => _EditStudentFeeStructureDialogState();
}

class _EditStudentFeeStructureDialogState extends ConsumerState<EditStudentFeeStructureDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _descController;

  String _feeType = 'Tuition Fee';
  String _classGrade = 'All Classes';
  String _billingCycle = 'Monthly';
  bool _isMandatory = true;
  bool _submitting = false;

  List<PaymentLookupItem> _feeTypes = [];
  List<PaymentLookupItem> _cycles = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? 'Tuition Fee - Academic');
    _amountController = TextEditingController(text: widget.initialAmount != null ? widget.initialAmount!.toInt().toString() : '4500');
    _descController = TextEditingController(text: widget.initialDescription ?? 'Mandatory academic & learning facility charge');
    _feeType = widget.initialType ?? 'Tuition Fee';
    _classGrade = widget.initialClass ?? 'All Classes';
    _billingCycle = widget.initialCycle ?? 'Monthly';
    _isMandatory = widget.initialMandatory ?? true;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final types = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_TYPE');
    final cycles = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_BILLING_CYCLE');
    if (mounted) {
      setState(() {
        _feeTypes = types;
        _cycles = cycles;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEditing ? 'Edit Fee Structure Head' : 'Add New Fee Structure Head',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Standardize school fees & auto-invoicing rules',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const Divider(height: 24),

                Text('Fee Head Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Science Laboratory & Practical Fee',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
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
                                value: _feeTypes.any((t) => t.label == _feeType) ? _feeType : (_feeTypes.isNotEmpty ? _feeTypes.first.label : _feeType),
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: (_feeTypes.isNotEmpty
                                    ? _feeTypes.map((t) => DropdownMenuItem(value: t.label, child: Text(t.label, style: const TextStyle(fontSize: 12)))).toList()
                                    : const [
                                        DropdownMenuItem(value: 'Tuition Fee', child: Text('Tuition Fee')),
                                        DropdownMenuItem(value: 'Laboratory Fee', child: Text('Laboratory Fee')),
                                        DropdownMenuItem(value: 'Transport Fee', child: Text('Transport Fee')),
                                        DropdownMenuItem(value: 'Hostel Fee', child: Text('Hostel Fee')),
                                      ]),
                                onChanged: (val) {
                                  if (val != null) setState(() => _feeType = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Billing Cycle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                                value: _cycles.any((c) => c.label == _billingCycle) ? _billingCycle : (_cycles.isNotEmpty ? _cycles.first.label : _billingCycle),
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: (_cycles.isNotEmpty
                                    ? _cycles.map((c) => DropdownMenuItem(value: c.label, child: Text(c.label, style: const TextStyle(fontSize: 12)))).toList()
                                    : const [
                                        DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                                        DropdownMenuItem(value: 'Quarterly', child: Text('Quarterly')),
                                        DropdownMenuItem(value: 'Half-Yearly', child: Text('Half-Yearly')),
                                        DropdownMenuItem(value: 'Annually', child: Text('Annually')),
                                      ]),
                                onChanged: (val) {
                                  if (val != null) setState(() => _billingCycle = val);
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
                                value: _classGrade,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: const [
                                  DropdownMenuItem(value: 'All Classes', child: Text('All Enrolled Classes', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Class 5', child: Text('Class 5', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Class 9', child: Text('Class 9', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Class 10', child: Text('Class 10', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Class 11', child: Text('Class 11', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Class 12', child: Text('Class 12', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _classGrade = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '₹ ',
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
                const SizedBox(height: 14),

                Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mandatory Fee Head', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Auto-included in default student invoices', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: _isMandatory,
                  activeTrackColor: const Color(0xFF2563EB),
                  onChanged: (val) => setState(() => _isMandatory = val),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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
                          : Text(widget.isEditing ? 'Save Changes' : 'Create Fee Head', style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0 || _nameController.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    final payload = {
      'fee_name': _nameController.text.trim(),
      'fee_type': _feeType,
      'class_grade': _classGrade,
      'billing_cycle': _billingCycle,
      'amount': amt,
      'description': _descController.text.trim(),
      'is_mandatory': _isMandatory,
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
            content: Text(widget.isEditing ? 'Fee head updated successfully!' : 'New fee head created successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }
}
