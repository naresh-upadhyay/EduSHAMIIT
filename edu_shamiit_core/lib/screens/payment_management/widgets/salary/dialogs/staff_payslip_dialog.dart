import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';

class StaffPayslipDialog extends StatelessWidget {
  final Map<String, dynamic> payslip;

  const StaffPayslipDialog({super.key, required this.payslip});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final staffName = payslip['staff_name']?.toString() ?? 'Faculty Member';
    final empId = payslip['employee_id']?.toString() ?? 'EMP-001';
    final designation = payslip['designation']?.toString() ?? 'Senior Faculty';
    final department = payslip['department']?.toString() ?? 'Academic & Teaching';
    final payslipNum = payslip['payslip_number']?.toString() ?? 'PS-2026-10-0001';
    final monthStr = payslip['month_str']?.toString() ?? '2026-10';
    final bpay = (payslip['basic_pay'] as num?)?.toDouble() ?? 45000.0;
    final hra = (payslip['hra'] as num?)?.toDouble() ?? 18000.0;
    final da = (payslip['da'] as num?)?.toDouble() ?? 7000.0;
    final ta = (payslip['ta'] as num?)?.toDouble() ?? 4000.0;
    final special = (payslip['special_allowance'] as num?)?.toDouble() ?? 3000.0;
    final bonus = (payslip['bonus'] as num?)?.toDouble() ?? 0.0;
    final gross = (payslip['gross_earnings'] as num?)?.toDouble() ?? (bpay + hra + da + ta + special + bonus);

    final pf = (payslip['pf_deduction'] as num?)?.toDouble() ?? 5400.0;
    final tds = (payslip['tds'] as num?)?.toDouble() ?? 3850.0;
    final ptax = (payslip['professional_tax'] as num?)?.toDouble() ?? 200.0;
    final otherDed = (payslip['other_deductions'] as num?)?.toDouble() ?? 0.0;
    final totalDed = (payslip['total_deductions'] as num?)?.toDouble() ?? (pf + tds + ptax + otherDed);
    final net = (payslip['net_pay'] as num?)?.toDouble() ?? (gross - totalDed);
    final pMode = payslip['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)';
    final txnRef = payslip['transaction_reference']?.toString() ?? 'UTR-AUTO-DISBURSED';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
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
                        child: const Icon(Icons.receipt_rounded, color: Color(0xFF16A34A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Salary Payslip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text('Period: $monthStr | $payslipNum', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              // Staff Details Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staffName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('$designation ($department)', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                    Text('EMP: $empId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tables of Earnings vs Deductions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Earnings Column
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EARNINGS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF16A34A))),
                          const SizedBox(height: 6),
                          _buildRow('Basic Pay', bpay, isDark),
                          _buildRow('HRA', hra, isDark),
                          _buildRow('DA', da, isDark),
                          _buildRow('TA', ta, isDark),
                          _buildRow('Special', special, isDark),
                          _buildRow('Bonus', bonus, isDark),
                          const Divider(height: 10),
                          _buildRow('Total Gross', gross, isDark, bold: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Deductions Column
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEDUCTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFFDC2626))),
                          const SizedBox(height: 6),
                          _buildRow('PF', pf, isDark),
                          _buildRow('TDS', tds, isDark),
                          _buildRow('Prof. Tax', ptax, isDark),
                          if (otherDed > 0) _buildRow('Advance', otherDed, isDark),
                          const Divider(height: 10),
                          _buildRow('Total Ded.', totalDed, isDark, bold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Net Take-Home Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NET SALARY TRANSFERRED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                        Text('$pMode | Ref: $txnRef', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                    Text(
                      '₹ ${NumberFormat('#,##,###').format(net.toInt())}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons (Print, Download, Close)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download HTML'),
                    onPressed: () {
                      downloadStaffPayslipHtml(payslip: payslip);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payslip downloaded successfully!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Payslip'),
                    onPressed: () {
                      printStaffPayslipHtml(payslip: payslip);
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, double val, bool isDark, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(
            '₹ ${NumberFormat('#,##,###').format(val.toInt())}',
            style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
