import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/staff_salary_provider.dart';

class BulkStaffPayrollDialog extends ConsumerStatefulWidget {
  const BulkStaffPayrollDialog({super.key});

  @override
  ConsumerState<BulkStaffPayrollDialog> createState() => _BulkStaffPayrollDialogState();
}

class _BulkStaffPayrollDialogState extends ConsumerState<BulkStaffPayrollDialog> {
  String _department = 'All Departments';
  final String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffSalaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
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
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.done_all_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Bulk Disburse Payroll',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              Text('Disbursal Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.selectedMonthStr,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),

              Text('Department Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                    final Map<String, String> deptMap = {
                      'All Departments': 'All Departments (Entire Staff)',
                      'Academic & Teaching': 'Academic & Teaching',
                      'Administration': 'Administration',
                      'Hostel': 'Hostel',
                      'Human Resources': 'Human Resources',
                      'IT & Systems': 'IT & Systems',
                      'Library': 'Library',
                      'Security': 'Security',
                    };
                    String effectiveDept = _department;
                    if (!deptMap.containsKey(effectiveDept)) {
                      deptMap[effectiveDept] = effectiveDept;
                    }
                    return DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        key: ValueKey('bulk_dept_$effectiveDept'),
                        value: effectiveDept,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: deptMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _department = val);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Execute Payroll Disbursal', style: TextStyle(fontWeight: FontWeight.w600)),
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
    setState(() => _submitting = true);
    final monthStr = ref.read(staffSalaryProvider).selectedMonthStr;
    final parts = monthStr.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 10;

    final ok = await PaymentManagementApiService.instance.bulkProcessStaffPayroll({
      'month': month,
      'year': year,
      'month_str': monthStr,
      'department': _department,
      'payment_mode': _paymentMode,
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk payroll disbursed successfully!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
