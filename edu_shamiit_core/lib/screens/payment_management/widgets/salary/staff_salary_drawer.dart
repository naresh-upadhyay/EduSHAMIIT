import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/staff_salary_models.dart';
import '../../providers/staff_salary_provider.dart';
import 'dialogs/process_staff_payout_dialog.dart';
import 'dialogs/edit_staff_salary_structure_dialog.dart';
import 'dialogs/request_salary_advance_dialog.dart';
import 'dialogs/staff_payslip_dialog.dart';
import 'dialogs/change_staff_payout_status_dialog.dart';

class StaffSalaryDrawer extends ConsumerStatefulWidget {
  const StaffSalaryDrawer({super.key});

  @override
  ConsumerState<StaffSalaryDrawer> createState() => _StaffSalaryDrawerState();
}

class _StaffSalaryDrawerState extends ConsumerState<StaffSalaryDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detail = state.selectedStaffDetail;
    if (detail == null) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = detail['profile'] as Map<String, dynamic>? ?? {};
    final structure = detail['structure'] as Map<String, dynamic>? ?? {};
    final payouts = detail['payouts'] as List? ?? [];
    final advances = detail['advances'] as List? ?? [];

    final staffName = profile['full_name']?.toString() ?? 'Faculty Member';
    final staffId = profile['id']?.toString() ?? '';
    final dept = profile['department']?.toString() ?? 'Academic & Teaching';
    final designation = profile['designation']?.toString() ?? 'Senior Faculty';
    final empId = profile['employee_id']?.toString() ?? 'EMP-001';

    final gross = (structure['gross_salary'] as num?)?.toDouble() ?? 63000.0;
    final totalDed = (structure['total_deductions'] as num?)?.toDouble() ?? 7900.0;
    final net = (structure['net_salary'] as num?)?.toDouble() ?? 55100.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header with Close Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF16A34A),
                  child: Text(
                    staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$designation • $dept | $empId',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: notifier.closeStaffDrawer,
                  tooltip: 'Close Drawer',
                ),
              ],
            ),
          ),

          // 2. Quick Action Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                    label: const Text('Disburse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ProcessStaffPayoutDialog(preselectedStaffId: staffId),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 14),
                    label: const Text('Structure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => EditStaffSalaryStructureDialog(
                          initialStructure: StaffSalaryStructureItem(
                            staffId: staffId,
                            staffName: staffName,
                            employeeId: empId,
                            department: dept,
                            designation: designation,
                            basicPay: (structure['basic_pay'] as num?)?.toDouble() ?? 35000.0,
                            hra: (structure['hra'] as num?)?.toDouble() ?? 14000.0,
                            da: (structure['da'] as num?)?.toDouble() ?? 5000.0,
                            ta: (structure['ta'] as num?)?.toDouble() ?? 2500.0,
                            specialAllowance: (structure['special_allowance'] as num?)?.toDouble() ?? 3000.0,
                            medicalAllowance: (structure['medical_allowance'] as num?)?.toDouble() ?? 0.0,
                            pfDeduction: (structure['pf_deduction'] as num?)?.toDouble() ?? 4200.0,
                            tds: (structure['tds'] as num?)?.toDouble() ?? 2500.0,
                            professionalTax: (structure['professional_tax'] as num?)?.toDouble() ?? 200.0,
                            insuranceDeduction: (structure['insurance_deduction'] as num?)?.toDouble() ?? 1000.0,
                            bankName: structure['bank_name']?.toString() ?? 'HDFC Bank',
                            accountNumber: structure['account_number']?.toString() ?? '',
                            ifscCode: structure['ifsc_code']?.toString() ?? '',
                            panNumber: structure['pan_number']?.toString() ?? '',
                            paymentMode: structure['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)',
                          ),
                          staffId: staffId,
                          staffName: staffName,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.rule_folder_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  tooltip: 'Status & Approvals',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ChangeStaffPayoutStatusDialog(
                        staffId: staffId,
                        staffName: staffName,
                        currentStatus: (payouts.isNotEmpty ? payouts.first['payment_status']?.toString() : null) ?? 'Pending',
                        payoutId: payouts.isNotEmpty ? payouts.first['id']?.toString() : null,
                        currentPaymentMode: payouts.isNotEmpty ? payouts.first['payment_mode']?.toString() : null,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.request_quote_rounded, size: 18, color: Color(0xFF059669)),
                  tooltip: 'Request Advance',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => RequestSalaryAdvanceDialog(staffId: staffId, staffName: staffName),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_rounded, size: 18, color: Color(0xFF2563EB)),
                  tooltip: 'View Latest Payslip',
                  onPressed: payouts.isNotEmpty
                      ? () {
                          final firstPay = Map<String, dynamic>.from(payouts.first as Map);
                          firstPay['staff_name'] = staffName;
                          firstPay['employee_id'] = empId;
                          firstPay['designation'] = designation;
                          firstPay['department'] = dept;
                          showDialog(
                            context: context,
                            builder: (ctx) => StaffPayslipDialog(payslip: firstPay),
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),

          // 3. Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF16A34A),
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF16A34A),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Payslips'),
              Tab(text: 'Bank & Tax'),
              Tab(text: 'Advances'),
            ],
          ),

          // 4. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Overview
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMetricCard('Gross Monthly CTC', '₹ ${NumberFormat('#,##,###').format(gross.toInt())}', const Color(0xFF2563EB), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Total Statutory Deductions', '- ₹ ${NumberFormat('#,##,###').format(totalDed.toInt())}', const Color(0xFFDC2626), isDark),
                        const SizedBox(height: 8),
                        _buildMetricCard('Net Take-Home Salary', '₹ ${NumberFormat('#,##,###').format(net.toInt())}', const Color(0xFF16A34A), isDark),
                        const SizedBox(height: 16),
                        Text('Earnings Components', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        _buildDetailRow('Basic Pay', '₹ ${NumberFormat('#,##,###').format((structure['basic_pay'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('HRA', '₹ ${NumberFormat('#,##,###').format((structure['hra'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('DA', '₹ ${NumberFormat('#,##,###').format((structure['da'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('TA', '₹ ${NumberFormat('#,##,###').format((structure['ta'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('Special Allowance', '₹ ${NumberFormat('#,##,###').format((structure['special_allowance'] as num?)?.toInt() ?? 0)}', isDark),
                        const Divider(height: 16),
                        Text('Deductions Components', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        _buildDetailRow('Provident Fund (12%)', '₹ ${NumberFormat('#,##,###').format((structure['pf_deduction'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('TDS / Income Tax', '₹ ${NumberFormat('#,##,###').format((structure['tds'] as num?)?.toInt() ?? 0)}', isDark),
                        _buildDetailRow('Professional Tax', '₹ ${NumberFormat('#,##,###').format((structure['professional_tax'] as num?)?.toInt() ?? 0)}', isDark),
                      ],
                    ),
                  ),
                ),

                // Tab 2: Payslips
                ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: payouts.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final pay = payouts[idx] as Map<String, dynamic>;
                    return InkWell(
                      onTap: () {
                        final p = Map<String, dynamic>.from(pay);
                        p['staff_name'] = staffName;
                        p['employee_id'] = empId;
                        p['designation'] = designation;
                        p['department'] = dept;
                        showDialog(context: context, builder: (ctx) => StaffPayslipDialog(payslip: p));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pay['payslip_number']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              Text('Period: ${pay['month_str']}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹ ${NumberFormat('#,##,###').format((pay['net_pay'] as num?)?.toInt() ?? 0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                              Text(pay['payment_status']?.toString() ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pay['payment_status'] == 'Paid' ? const Color(0xFF16A34A) : const Color(0xFFD97706))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Tab 3: Bank & Tax
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildDetailRow('Bank Name', structure['bank_name']?.toString() ?? 'HDFC Bank', isDark),
                      _buildDetailRow('Account No.', structure['account_number']?.toString() ?? '501002341234', isDark),
                      _buildDetailRow('IFSC Code', structure['ifsc_code']?.toString() ?? 'HDFC0001824', isDark),
                      _buildDetailRow('PAN Number', structure['pan_number']?.toString() ?? 'ABCDE1234F', isDark),
                      _buildDetailRow('Disbursal Channel', structure['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)', isDark),
                    ],
                  ),
                ),

                // Tab 4: Advances
                ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: advances.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, idx) {
                    final adv = advances[idx] as Map<String, dynamic>;
                    final amt = (adv['amount'] as num?)?.toDouble() ?? 0.0;
                    final repaid = (adv['amount_repaid'] as num?)?.toDouble() ?? 0.0;
                    final advStatus = adv['status']?.toString() ?? 'Approved';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(adv['purpose_type']?.toString() ?? 'Emergency', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  Text('${adv['repayment_months']} mo EMI (₹ ${adv['monthly_deduction']}/mo) | Repaid: ₹ ${repaid.toInt()} / ₹ ${amt.toInt()}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: advStatus == 'Settled' ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                advStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: advStatus == 'Settled' ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: amt > 0 ? (repaid / amt).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF059669)),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
