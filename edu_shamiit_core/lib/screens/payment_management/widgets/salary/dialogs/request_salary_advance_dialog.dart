import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/staff_salary_provider.dart';

class RequestSalaryAdvanceDialog extends ConsumerStatefulWidget {
  final String? staffId;
  final String? staffName;

  const RequestSalaryAdvanceDialog({
    super.key,
    this.staffId,
    this.staffName,
  });

  @override
  ConsumerState<RequestSalaryAdvanceDialog> createState() =>
      _RequestSalaryAdvanceDialogState();
}

class _RequestSalaryAdvanceDialogState
    extends ConsumerState<RequestSalaryAdvanceDialog> {
  final TextEditingController _amountController =
      TextEditingController(text: '15000');
  final TextEditingController _reasonController =
      TextEditingController(text: 'Medical Emergency');
  String _purposeType = 'Medical Emergency';
  int _repaymentMonths = 3;
  bool _submitting = false;
  String? _selectedStaffId;
  String? _selectedStaffName;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.staffId;
    _selectedStaffName = widget.staffName;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffSalaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final staffList = state.staffRoster;
    if (_selectedStaffId == null && staffList.isNotEmpty) {
      _selectedStaffId = staffList.first.staffId;
      _selectedStaffName = staffList.first.staffName;
    }

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
                          color:
                              const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.request_quote_rounded,
                            color: Color(0xFF059669), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Salary Advance Request',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))),
                          Text(_selectedStaffName ?? 'Staff Member',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              // Staff Selector Dropdown if not preselected
              if (widget.staffId == null && staffList.isNotEmpty) ...[
                Text('Select Staff Member',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: _selectedStaffId,
                      isExpanded: true,
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: staffList
                          .map((s) => DropdownMenuItem(
                              value: s.staffId,
                              child: Text(
                                  '${s.staffName} (${s.department} - ${s.employeeId})',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selected = staffList.firstWhere(
                              (e) => e.staffId == val,
                              orElse: () => staffList.first);
                          setState(() {
                            _selectedStaffId = val;
                            _selectedStaffName = selected.staffName;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text('Advance Amount (₹)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              Text('Purpose / Emergency Category',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                ),
                child: Builder(
                  builder: (context) {
                    final Map<String, String> purposeMap = {
                      'Medical Emergency': 'Medical Emergency',
                      'Family Event / Wedding': 'Family Event / Wedding',
                      'Home Repair / Relocation': 'Home Repair / Relocation',
                      'Educational Course': 'Educational Course',
                    };
                    String effectivePurpose = _purposeType;
                    if (!purposeMap.containsKey(effectivePurpose)) {
                      purposeMap[effectivePurpose] = effectivePurpose;
                    }
                    return DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        key: ValueKey('advance_purpose_$effectivePurpose'),
                        value: effectivePurpose,
                        isExpanded: true,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: purposeMap.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _purposeType = val);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text('Repayment Installment Plan (Months)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1, 2, 3, 4, 6].map((m) {
                  final isSel = _repaymentMonths == m;
                  return ChoiceChip(
                    label: Text('$m mo'),
                    selected: isSel,
                    onSelected: (_) => setState(() => _repaymentMonths = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Disburse Advance',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    final targetStaffId = _selectedStaffId ?? widget.staffId;
    if (targetStaffId == null || targetStaffId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a staff member'),
            backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok =
        await PaymentManagementApiService.instance.requestStaffSalaryAdvance({
      'staff_id': targetStaffId,
      'amount': amt,
      'purpose_type': _purposeType,
      'reason': _reasonController.text.trim(),
      'repayment_months': _repaymentMonths,
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Salary advance recorded successfully!'),
              backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
