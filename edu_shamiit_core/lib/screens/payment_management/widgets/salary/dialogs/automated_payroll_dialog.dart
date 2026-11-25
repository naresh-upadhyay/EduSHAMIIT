import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/staff_salary_provider.dart';

class AutomatedPayrollDialog extends ConsumerStatefulWidget {
  const AutomatedPayrollDialog({super.key});

  @override
  ConsumerState<AutomatedPayrollDialog> createState() => _AutomatedPayrollDialogState();
}

class _AutomatedPayrollDialogState extends ConsumerState<AutomatedPayrollDialog> {
  bool _sendEmail = true;
  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  bool _executing = false;
  Map<String, dynamic>? _lastResult;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalEligible = state.structuresTotal > 0 ? state.structuresTotal : state.salaryStructures.length;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_mode_rounded, color: Color(0xFF16A34A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automated Monthly Payroll Run',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Batch generate payslips & dispatch email advice',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
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

              if (_lastResult != null) ...[
                // Execution Result View
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                          SizedBox(width: 8),
                          Text('Payroll Run Executed Successfully', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF166534))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '• Period: ${_lastResult!['month_str']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '• New Payslips Generated: ${_lastResult!['generated_count']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '• Already Processed: ${_lastResult!['already_processed_count']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (_sendEmail)
                        const Text(
                          '• Email pay advice dispatched to all registered staff in background.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ] else ...[
                // Settings Form
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Target Pay Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state.selectedMonthStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Eligible Staff Structures', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('$totalEligible Configured', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Mode Selection
                Text('Default Payment Disbursal Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: _paymentMode,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Direct Bank Transfer (NEFT/RTGS)', child: Text('Direct Bank Transfer (NEFT/RTGS)')),
                        DropdownMenuItem(value: 'UPI Direct', child: Text('UPI Direct')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _paymentMode = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Email Notification Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send Email Salary Advice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Automatically dispatches detailed payslip statements to staff email addresses', style: TextStyle(fontSize: 11)),
                  value: _sendEmail,
                  activeThumbColor: const Color(0xFF16A34A),
                  activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.5),
                  onChanged: (val) => setState(() => _sendEmail = val),
                ),
                const SizedBox(height: 12),

                // Info Callout
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Idempotent: Staff who already have a payslip for this period will NOT be duplicated. Outstanding advance EMIs are auto-deducted.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _executing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_circle_filled_rounded, size: 18),
                      label: Text(_executing ? 'Executing...' : 'Run Automated Disbursal', style: const TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: _executing
                          ? null
                          : () async {
                              setState(() => _executing = true);
                              final res = await notifier.runAutomatedPayroll(sendEmail: _sendEmail);
                              if (mounted) {
                                setState(() {
                                  _executing = false;
                                  _lastResult = res;
                                });
                              }
                            },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
