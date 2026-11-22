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
    final advDed = (payslip['advance_deduction'] as num?)?.toDouble() ??
        (payslip['active_advance_deduction'] as num?)?.toDouble() ??
        (payslip['other_deductions'] as num?)?.toDouble() ?? 0.0;
    final otherDed = (payslip['other_deductions'] as num?)?.toDouble() ?? 0.0;
    final totalDed = (payslip['total_deductions'] as num?)?.toDouble() ?? (pf + tds + ptax + advDed);
    final net = (payslip['net_pay'] as num?)?.toDouble() ?? (gross - totalDed);

    final pMode = payslip['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)';
    final txnRef = payslip['transaction_reference']?.toString() ?? 'UTR-AUTO-DISBURSED';
    final pDate = payslip['payment_date']?.toString().split('T')[0] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());
    final bankName = payslip['bank_name']?.toString() ?? 'State Bank of India';
    final accNum = payslip['account_number']?.toString() ?? '•••• •••• 0400';
    final ifsc = payslip['ifsc_code']?.toString() ?? 'SBIN0001234';
    final pan = payslip['pan_number']?.toString() ?? 'ABCDE1234F';
    final instName = payslip['institution_name']?.toString() ?? 'EduSHAMIIT International Institute';
    final status = payslip['payment_status']?.toString() ?? payslip['status']?.toString() ?? 'Paid';

    final netInWords = _numberToIndianWords(net);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Institutional Brand Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Salary Pay Voucher & Certificate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                monthStr,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Employee Info Grid Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.person_rounded,
                                  label: 'EMPLOYEE NAME',
                                  value: staffName,
                                  subValue: '$designation | $department',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.badge_outlined,
                                  label: 'EMPLOYEE ID / PAN',
                                  value: empId,
                                  subValue: 'PAN: $pan',
                                  isDark: isDark,
                                  isMonospace: true,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.account_balance_rounded,
                                  label: 'BANK DISBURSAL DETAILS',
                                  value: bankName,
                                  subValue: 'A/C: $accNum • IFSC: $ifsc',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoItem(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'PAYSLIP & TRANSACTION REF',
                                  value: payslipNum,
                                  subValue: '$pMode | Ref: $txnRef',
                                  isDark: isDark,
                                  isMonospace: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Earnings vs Deductions Dual Table
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Earnings Column (Green Theme)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.3 : 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                                      SizedBox(width: 6),
                                      Text(
                                        'EARNINGS BREAKDOWN',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: Color(0xFF16A34A),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      _buildAmountRow('Basic Pay', bpay, isDark),
                                      _buildAmountRow('House Rent Allowance (HRA)', hra, isDark),
                                      _buildAmountRow('Dearness Allowance (DA)', da, isDark),
                                      _buildAmountRow('Travel Allowance (TA)', ta, isDark),
                                      _buildAmountRow('Special Allowance', special, isDark),
                                      if (bonus > 0) _buildAmountRow('Performance / Bonus', bonus, isDark),
                                      const Divider(height: 14),
                                      _buildAmountRow('Gross Earnings', gross, isDark, isBold: true, highlightColor: const Color(0xFF16A34A)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Deductions Column (Red Theme)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.3 : 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                                      SizedBox(width: 6),
                                      Text(
                                        'DEDUCTIONS BREAKDOWN',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: Color(0xFFDC2626),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      _buildAmountRow('Provident Fund (PF)', pf, isDark),
                                      _buildAmountRow('TDS / Income Tax', tds, isDark),
                                      _buildAmountRow('Professional Tax (PT)', ptax, isDark),
                                      if (advDed > 0)
                                        _buildAmountRow('Salary Advance EMI Recovery', advDed, isDark, isWarning: true),
                                      if (otherDed > 0 && otherDed != advDed)
                                        _buildAmountRow('Other Deductions', otherDed, isDark),
                                      const Divider(height: 14),
                                      _buildAmountRow('Total Deductions', totalDed, isDark, isBold: true, highlightColor: const Color(0xFFDC2626)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Net Pay Take-Home Hero Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF064E3B).withValues(alpha: 0.4), const Color(0xFF0F172A)]
                              : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'NET SALARY CREDITED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: Color(0xFF16A34A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  netInWords,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹ ${NumberFormat('#,##,###').format(net.toInt())}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF16A34A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Date: $pDate',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Action Toolbar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    'Digitally generated & tamper-sealed',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download HTML', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      downloadStaffPayslipHtml(payslip: payslip);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payslip HTML downloaded successfully!'),
                          backgroundColor: Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Payslip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      printStaffPayslipHtml(payslip: payslip);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.print_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Payslip print preview launched!'),
                            ],
                          ),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'paid':
      case 'approved':
        bg = const Color(0xFF16A34A).withValues(alpha: 0.15);
        fg = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        break;
      case 'pending':
        bg = const Color(0xFFD97706).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        icon = Icons.schedule_rounded;
        break;
      case 'on hold':
      case 'hold':
        bg = const Color(0xFFDC2626).withValues(alpha: 0.15);
        fg = const Color(0xFFDC2626);
        icon = Icons.pause_circle_rounded;
        break;
      default:
        bg = const Color(0xFF64748B).withValues(alpha: 0.15);
        fg = const Color(0xFF64748B);
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required bool isDark,
    bool isMonospace = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: isMonospace ? 'monospace' : null,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subValue,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount,
    bool isDark, {
    bool isBold = false,
    bool isWarning = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
                color: isWarning
                    ? const Color(0xFFDC2626)
                    : isDark
                        ? (isBold ? Colors.white : const Color(0xFFCBD5E1))
                        : (isBold ? const Color(0xFF0F172A) : const Color(0xFF475569)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹ ${NumberFormat('#,##,###').format(amount.toInt())}',
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontFamily: 'monospace',
              color: highlightColor ??
                  (isWarning
                      ? const Color(0xFFDC2626)
                      : isDark
                          ? Colors.white
                          : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  String _numberToIndianWords(double amount) {
    if (amount <= 0) return 'Zero Rupees Only';

    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertChunk(int n) {
      if (n == 0) return '';
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
      return '${units[n ~/ 100]} Hundred ${convertChunk(n % 100)}'.trim();
    }

    int totalPaise = (amount * 100).round();
    int rupees = totalPaise ~/ 100;
    int paise = totalPaise % 100;

    if (rupees == 0 && paise > 0) {
      return '${convertChunk(paise)} Paise Only';
    }

    String result = '';
    if (rupees >= 10000000) {
      int cr = rupees ~/ 10000000;
      result += '${convertChunk(cr)} Crore ';
      rupees %= 10000000;
    }
    if (rupees >= 100000) {
      int lk = rupees ~/ 100000;
      result += '${convertChunk(lk)} Lakh ';
      rupees %= 100000;
    }
    if (rupees >= 1000) {
      int th = rupees ~/ 1000;
      result += '${convertChunk(th)} Thousand ';
      rupees %= 1000;
    }
    if (rupees > 0) {
      result += convertChunk(rupees);
    }

    result = '${result.trim()} Rupees';
    if (paise > 0) {
      result += ' and ${convertChunk(paise)} Paise';
    }

    return '$result Only';
  }
}
