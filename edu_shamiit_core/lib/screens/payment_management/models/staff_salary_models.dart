import 'package:intl/intl.dart';

class StaffSalaryKPIs {
  final double totalMonthlyBudget;
  final double totalDisbursed;
  final double pendingDisbursal;
  final double onHoldAmount;
  final double disbursalRate;
  final int totalStaff;
  final int paidStaffCount;
  final int pendingStaffCount;
  final int onHoldStaffCount;

  StaffSalaryKPIs({
    this.totalMonthlyBudget = 0.0,
    this.totalDisbursed = 0.0,
    this.pendingDisbursal = 0.0,
    this.onHoldAmount = 0.0,
    this.disbursalRate = 0.0,
    this.totalStaff = 0,
    this.paidStaffCount = 0,
    this.pendingStaffCount = 0,
    this.onHoldStaffCount = 0,
  });

  String get totalBudgetFormatted => '₹ ${NumberFormat('#,##,###').format(totalMonthlyBudget.toInt())}';
  String get totalDisbursedFormatted => '₹ ${NumberFormat('#,##,###').format(totalDisbursed.toInt())}';
  String get pendingDisbursalFormatted => '₹ ${NumberFormat('#,##,###').format(pendingDisbursal.toInt())}';
  String get onHoldAmountFormatted => '₹ ${NumberFormat('#,##,###').format(onHoldAmount.toInt())}';
  String get disbursalRateFormatted => '${disbursalRate.toStringAsFixed(1)}% Disbursed';

  factory StaffSalaryKPIs.fromJson(Map<String, dynamic> json) {
    return StaffSalaryKPIs(
      totalMonthlyBudget: (json['total_monthly_budget'] as num?)?.toDouble() ?? 0.0,
      totalDisbursed: (json['total_disbursed'] as num?)?.toDouble() ?? 0.0,
      pendingDisbursal: (json['pending_disbursal'] as num?)?.toDouble() ?? 0.0,
      onHoldAmount: (json['on_hold_amount'] as num?)?.toDouble() ?? 0.0,
      disbursalRate: (json['disbursal_rate'] as num?)?.toDouble() ?? 0.0,
      totalStaff: (json['total_staff'] as num?)?.toInt() ?? 0,
      paidStaffCount: (json['paid_staff_count'] as num?)?.toInt() ?? 0,
      pendingStaffCount: (json['pending_staff_count'] as num?)?.toInt() ?? 0,
      onHoldStaffCount: (json['on_hold_staff_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StaffSalaryRosterItem {
  final String staffId;
  final String staffName;
  final String staffEmail;
  final String staffPhone;
  final String role;
  final String department;
  final String designation;
  final String employeeId;
  final String? avatarUrl;
  final double basicPay;
  final double hra;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final double actualNetPay;
  final String status; // Paid, Pending, On Hold
  final String? payoutId;
  final String? payslipNumber;
  final String? paymentDate;
  final String paymentMode;
  final String? transactionReference;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? panNumber;
  final double da;
  final double ta;
  final double specialAllowance;
  final double medicalAllowance;
  final double bonus;
  final double pfDeduction;
  final double tds;
  final double professionalTax;
  final double insuranceDeduction;
  final double activeAdvanceDeduction;

  StaffSalaryRosterItem({
    required this.staffId,
    required this.staffName,
    required this.staffEmail,
    this.staffPhone = '',
    required this.role,
    required this.department,
    required this.designation,
    required this.employeeId,
    this.avatarUrl,
    this.basicPay = 35000.0,
    this.hra = 14000.0,
    this.da = 5000.0,
    this.ta = 2500.0,
    this.specialAllowance = 3000.0,
    this.medicalAllowance = 0.0,
    this.bonus = 0.0,
    this.pfDeduction = 4200.0,
    this.tds = 2500.0,
    this.professionalTax = 200.0,
    this.insuranceDeduction = 0.0,
    this.grossSalary = 63000.0,
    this.totalDeductions = 7900.0,
    this.netSalary = 55100.0,
    this.actualNetPay = 55100.0,
    this.status = 'Pending',
    this.payoutId,
    this.payslipNumber,
    this.paymentDate,
    this.paymentMode = 'Direct Bank Transfer (NEFT/RTGS)',
    this.transactionReference,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.panNumber,
    this.activeAdvanceDeduction = 0.0,
  });

  String get grossSalaryFormatted => '₹ ${NumberFormat('#,##,###').format(grossSalary.toInt())}';
  String get totalDeductionsFormatted => '₹ ${NumberFormat('#,##,###').format(totalDeductions.toInt())}';
  String get netSalaryFormatted => '₹ ${NumberFormat('#,##,###').format(actualNetPay.toInt())}';

  factory StaffSalaryRosterItem.fromJson(Map<String, dynamic> json) {
    final double basic = (json['basic_pay'] as num?)?.toDouble() ?? 35000.0;
    final double hraVal = (json['hra'] as num?)?.toDouble() ?? 14000.0;
    final double daVal = (json['da'] as num?)?.toDouble() ?? 5000.0;
    final double taVal = (json['ta'] as num?)?.toDouble() ?? 2500.0;
    final double specVal = (json['special_allowance'] as num?)?.toDouble() ?? 3000.0;
    final double medVal = (json['medical_allowance'] as num?)?.toDouble() ?? 0.0;
    final double bonusVal = (json['bonus'] as num?)?.toDouble() ?? 0.0;
    final double gross = (json['gross_salary'] as num?)?.toDouble() ?? (basic + hraVal + daVal + taVal + specVal + medVal + bonusVal);
    final double pfVal = (json['pf_deduction'] as num?)?.toDouble() ?? 4200.0;
    final double tdsVal = (json['tds'] as num?)?.toDouble() ?? 2500.0;
    final double ptaxVal = (json['professional_tax'] as num?)?.toDouble() ?? 200.0;
    final double insVal = (json['insurance_deduction'] as num?)?.toDouble() ?? 0.0;
    final double deductions = (json['total_deductions'] as num?)?.toDouble() ?? (pfVal + tdsVal + ptaxVal + insVal);
    final double computedNet = (gross > deductions) ? (gross - deductions) : 0.0;
    final double finalNet = (json['actual_net_pay'] ?? json['net_pay'] ?? json['net_salary'] as num?)?.toDouble() ?? computedNet;

    return StaffSalaryRosterItem(
      staffId: json['staff_id']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? 'Faculty Member',
      staffEmail: json['staff_email']?.toString() ?? '',
      staffPhone: json['staff_phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'teacher',
      department: json['department']?.toString() ?? 'Academic & Teaching',
      designation: json['designation']?.toString() ?? json['role_title']?.toString() ?? 'Faculty Member',
      employeeId: json['employee_id']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      basicPay: basic,
      hra: hraVal,
      da: daVal,
      ta: taVal,
      specialAllowance: specVal,
      medicalAllowance: medVal,
      bonus: bonusVal,
      pfDeduction: pfVal,
      tds: tdsVal,
      professionalTax: ptaxVal,
      insuranceDeduction: insVal,
      grossSalary: gross,
      totalDeductions: deductions,
      netSalary: finalNet,
      actualNetPay: finalNet,
      status: json['status']?.toString() ?? 'Pending',
      payoutId: json['payout_id']?.toString(),
      payslipNumber: json['payslip_number']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)',
      transactionReference: json['transaction_reference']?.toString(),
      bankName: json['bank_name']?.toString(),
      accountNumber: json['account_number']?.toString(),
      ifscCode: json['ifsc_code']?.toString(),
      panNumber: json['pan_number']?.toString(),
      activeAdvanceDeduction: (json['active_advance_deduction'] as num?)?.toDouble() ?? 0.0,
    );
  }

  StaffSalaryStructureItem toStructureItem() {
    return StaffSalaryStructureItem(
      staffId: staffId,
      staffName: staffName,
      employeeId: employeeId,
      department: department,
      designation: designation,
      basicPay: basicPay,
      hra: hra,
      da: da,
      ta: ta,
      specialAllowance: specialAllowance,
      medicalAllowance: medicalAllowance,
      grossSalary: grossSalary,
      pfDeduction: pfDeduction,
      tds: tds,
      professionalTax: professionalTax,
      insuranceDeduction: insuranceDeduction,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
      paymentMode: paymentMode,
      bankName: bankName ?? 'HDFC Bank',
      accountNumber: accountNumber ?? '',
      ifscCode: ifscCode ?? '',
      panNumber: panNumber ?? '',
    );
  }
}

class StaffSalaryStructureItem {
  final String staffId;
  final String staffName;
  final String employeeId;
  final String department;
  final String designation;
  final double basicPay;
  final double hra;
  final double da;
  final double ta;
  final double specialAllowance;
  final double medicalAllowance;
  final double grossSalary;
  final double pfDeduction;
  final double tds;
  final double professionalTax;
  final double insuranceDeduction;
  final double totalDeductions;
  final double netSalary;
  final String paymentMode;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String panNumber;

  StaffSalaryStructureItem({
    required this.staffId,
    required this.staffName,
    required this.employeeId,
    required this.department,
    required this.designation,
    this.basicPay = 35000.0,
    this.hra = 14000.0,
    this.da = 5000.0,
    this.ta = 3000.0,
    this.specialAllowance = 4000.0,
    this.medicalAllowance = 2000.0,
    this.grossSalary = 63000.0,
    this.pfDeduction = 4200.0,
    this.tds = 2500.0,
    this.professionalTax = 200.0,
    this.insuranceDeduction = 1000.0,
    this.totalDeductions = 7900.0,
    this.netSalary = 55100.0,
    this.paymentMode = 'Direct Bank Transfer (NEFT/RTGS)',
    this.bankName = 'HDFC Bank',
    this.accountNumber = '',
    this.ifscCode = '',
    this.panNumber = '',
  });

  String get grossFormatted => '₹ ${NumberFormat('#,##,###').format(grossSalary.toInt())}';
  String get netFormatted => '₹ ${NumberFormat('#,##,###').format(netSalary.toInt())}';

  factory StaffSalaryStructureItem.fromJson(Map<String, dynamic> json) {
    return StaffSalaryStructureItem(
      staffId: json['staff_id']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      department: json['department']?.toString() ?? 'Academic',
      designation: json['designation']?.toString() ?? '',
      basicPay: (json['basic_pay'] as num?)?.toDouble() ?? 35000.0,
      hra: (json['hra'] as num?)?.toDouble() ?? 14000.0,
      da: (json['da'] as num?)?.toDouble() ?? 5000.0,
      ta: (json['ta'] as num?)?.toDouble() ?? 3000.0,
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 0.0,
      medicalAllowance: (json['medical_allowance'] as num?)?.toDouble() ?? 0.0,
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? 63000.0,
      pfDeduction: (json['pf_deduction'] as num?)?.toDouble() ?? 4200.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 2500.0,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 200.0,
      insuranceDeduction: (json['insurance_deduction'] as num?)?.toDouble() ?? 1000.0,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 7900.0,
      netSalary: (json['net_salary'] as num?)?.toDouble() ??
          (((json['gross_salary'] as num?)?.toDouble() ?? 63000.0) -
              ((json['total_deductions'] as num?)?.toDouble() ?? 7900.0)),
      paymentMode: json['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)',
      bankName: json['bank_name']?.toString() ?? 'HDFC Bank',
      accountNumber: json['account_number']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? '',
      panNumber: json['pan_number']?.toString() ?? '',
    );
  }
}

class StaffPayslipItem {
  final String id;
  final String payslipNumber;
  final String staffName;
  final String employeeId;
  final String department;
  final String designation;
  final String role;
  final String email;
  final String phone;
  final int month;
  final int year;
  final String monthStr;
  final double basicPay;
  final double hra;
  final double da;
  final double ta;
  final double specialAllowance;
  final double bonus;
  final double grossEarnings;
  final double pfDeduction;
  final double tds;
  final double professionalTax;
  final double advanceDeduction;
  final double otherDeductions;
  final double totalDeductions;
  final double netPay;
  final String paymentStatus;
  final String? paymentDate;
  final String paymentMode;
  final String? transactionReference;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String panNumber;
  final Map<String, dynamic> rawJson;

  StaffPayslipItem({
    required this.id,
    required this.payslipNumber,
    required this.staffName,
    required this.employeeId,
    required this.department,
    required this.designation,
    this.role = 'teacher',
    this.email = '',
    this.phone = '',
    required this.month,
    required this.year,
    required this.monthStr,
    this.basicPay = 35000.0,
    this.hra = 14000.0,
    this.da = 7000.0,
    this.ta = 4000.0,
    this.specialAllowance = 3000.0,
    this.medicalAllowance = 0.0,
    this.bonus = 0.0,
    this.grossEarnings = 0.0,
    this.pfDeduction = 4200.0,
    this.tds = 3500.0,
    this.professionalTax = 200.0,
    this.insuranceDeduction = 0.0,
    this.advanceDeduction = 0.0,
    this.otherDeductions = 0.0,
    this.totalDeductions = 0.0,
    this.netPay = 0.0,
    this.paymentStatus = 'Paid',
    this.paymentDate,
    this.paymentMode = 'Direct Bank Transfer (NEFT/RTGS)',
    this.transactionReference,
    this.bankName = 'HDFC Bank',
    this.accountNumber = '',
    this.ifscCode = '',
    this.panNumber = '',
    this.rawJson = const {},
  });

  final double medicalAllowance;
  final double insuranceDeduction;

  String get grossFormatted => '₹ ${NumberFormat('#,##,###').format(grossEarnings.toInt())}';
  String get netFormatted => '₹ ${NumberFormat('#,##,###').format(netPay.toInt())}';

  factory StaffPayslipItem.fromJson(Map<String, dynamic> json) {
    return StaffPayslipItem(
      id: json['id']?.toString() ?? '',
      payslipNumber: json['payslip_number']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      role: json['role']?.toString() ?? 'teacher',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 10,
      year: (json['year'] as num?)?.toInt() ?? 2026,
      monthStr: json['month_str']?.toString() ?? '2026-10',
      basicPay: (json['basic_pay'] as num?)?.toDouble() ?? 35000.0,
      hra: (json['hra'] as num?)?.toDouble() ?? 14000.0,
      da: (json['da'] as num?)?.toDouble() ?? 7000.0,
      ta: (json['ta'] as num?)?.toDouble() ?? 4000.0,
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 3000.0,
      medicalAllowance: (json['medical_allowance'] as num?)?.toDouble() ?? 0.0,
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0.0,
      grossEarnings: (json['gross_earnings'] as num?)?.toDouble() ?? 0.0,
      pfDeduction: (json['pf_deduction'] as num?)?.toDouble() ?? 4200.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 3500.0,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 200.0,
      insuranceDeduction: (json['insurance_deduction'] as num?)?.toDouble() ?? 0.0,
      advanceDeduction: (json['advance_deduction'] as num?)?.toDouble() ?? 0.0,
      otherDeductions: (json['other_deductions'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 0.0,
      netPay: (json['net_pay'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status']?.toString() ?? 'Paid',
      paymentDate: json['payment_date']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)',
      transactionReference: json['transaction_reference']?.toString(),
      bankName: json['bank_name']?.toString() ?? 'HDFC Bank',
      accountNumber: json['account_number']?.toString() ?? '',
      ifscCode: json['ifsc_code']?.toString() ?? '',
      panNumber: json['pan_number']?.toString() ?? '',
      rawJson: json,
    );
  }
}

class StaffSalaryAdvanceItem {
  final String id;
  final String staffName;
  final String employeeId;
  final String department;
  final double amount;
  final String purposeType;
  final String? reason;
  final int repaymentMonths;
  final double monthlyDeduction;
  final double amountRepaid;
  final double outstandingBalance;
  final double progressPct;
  final String status;
  final String? disbursedAt;

  StaffSalaryAdvanceItem({
    required this.id,
    required this.staffName,
    required this.employeeId,
    required this.department,
    required this.amount,
    this.purposeType = 'Medical Emergency',
    this.reason,
    this.repaymentMonths = 3,
    this.monthlyDeduction = 0.0,
    this.amountRepaid = 0.0,
    this.outstandingBalance = 0.0,
    this.progressPct = 0.0,
    this.status = 'Approved',
    this.disbursedAt,
  });

  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(amount.toInt())}';
  String get amountRepaidFormatted => '₹ ${NumberFormat('#,##,###').format(amountRepaid.toInt())}';
  String get outstandingBalanceFormatted => '₹ ${NumberFormat('#,##,###').format(outstandingBalance.toInt())}';
  String get progressPctFormatted => '${progressPct.toStringAsFixed(1)}%';

  factory StaffSalaryAdvanceItem.fromJson(Map<String, dynamic> json) {
    final double amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final double repaid = (json['amount_repaid'] as num?)?.toDouble() ?? 0.0;
    final double balance = (json['outstanding_balance'] as num?)?.toDouble() ?? (amt > repaid ? amt - repaid : 0.0);
    final double pct = (json['progress_pct'] as num?)?.toDouble() ?? (amt > 0 ? (repaid / amt * 100.0) : 0.0);

    return StaffSalaryAdvanceItem(
      id: json['id']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      amount: amt,
      purposeType: json['purpose_type']?.toString() ?? 'Medical Emergency',
      reason: json['reason']?.toString(),
      repaymentMonths: (json['repayment_months'] as num?)?.toInt() ?? 3,
      monthlyDeduction: (json['monthly_deduction'] as num?)?.toDouble() ?? 0.0,
      amountRepaid: repaid,
      outstandingBalance: balance,
      progressPct: pct,
      status: json['status']?.toString() ?? 'Approved',
      disbursedAt: json['disbursed_at']?.toString(),
    );
  }
}
