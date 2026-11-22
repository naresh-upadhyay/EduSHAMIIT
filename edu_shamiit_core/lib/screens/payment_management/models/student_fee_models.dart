import 'package:intl/intl.dart';

/// Formats currency preserving paise precision whenever paise exist.
/// Example:
///   1.53 -> ₹ 1.53
///   15001.53 -> ₹ 15,001.53
///   8998.47 -> ₹ 8,998.47
///   24000.0 -> ₹ 24,000
///   0.0 -> ₹ 0
String formatIndianCurrency(num amount) {
  final d = amount.toDouble();
  final hasPaise = (d * 100).round() % 100 != 0;
  if (hasPaise) {
    return '₹ ${NumberFormat('#,##,##0.00').format(d)}';
  }
  return '₹ ${NumberFormat('#,##,###').format(d.toInt())}';
}

class StudentFeeKPIs {
  final double totalBilled;
  final double totalCollected;
  final double pendingDues;
  final double overdueAmount;
  final double advanceAmount;
  final double collectionRate;
  final int totalStudents;
  final int paidStudentsCount;
  final int partialStudentsCount;
  final int pendingStudentsCount;
  final int overdueStudentsCount;
  final int overpaidStudentsCount;
  final int unbilledStudentsCount;
  final int feeStructuresCount;
  final int invoicesCount;
  final int paymentsCount;

  StudentFeeKPIs({
    this.totalBilled = 0.0,
    this.totalCollected = 0.0,
    this.pendingDues = 0.0,
    this.overdueAmount = 0.0,
    this.advanceAmount = 0.0,
    this.collectionRate = 0.0,
    this.totalStudents = 0,
    this.paidStudentsCount = 0,
    this.partialStudentsCount = 0,
    this.pendingStudentsCount = 0,
    this.overdueStudentsCount = 0,
    this.overpaidStudentsCount = 0,
    this.unbilledStudentsCount = 0,
    this.feeStructuresCount = 0,
    this.invoicesCount = 0,
    this.paymentsCount = 0,
  });

  String get totalBilledFormatted => formatIndianCurrency(totalBilled);
  String get totalCollectedFormatted => formatIndianCurrency(totalCollected);
  String get pendingDuesFormatted => formatIndianCurrency(pendingDues);
  String get overdueAmountFormatted => formatIndianCurrency(overdueAmount);
  String get advanceAmountFormatted => formatIndianCurrency(advanceAmount);
  String get collectionRateFormatted => '${collectionRate.toStringAsFixed(1)}% Collection';

  factory StudentFeeKPIs.fromJson(Map<String, dynamic> json) {
    return StudentFeeKPIs(
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      pendingDues: (json['pending_dues'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (json['collection_rate'] as num?)?.toDouble() ?? 0.0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      paidStudentsCount: (json['paid_students_count'] as num?)?.toInt() ?? 0,
      partialStudentsCount: (json['partial_students_count'] as num?)?.toInt() ?? 0,
      pendingStudentsCount: (json['pending_students_count'] as num?)?.toInt() ?? 0,
      overdueStudentsCount: (json['overdue_students_count'] as num?)?.toInt() ?? 0,
      overpaidStudentsCount: (json['overpaid_students_count'] as num?)?.toInt() ?? 0,
      unbilledStudentsCount: (json['unbilled_students_count'] as num?)?.toInt() ?? 0,
      feeStructuresCount: (json['fee_structures_count'] as num?)?.toInt() ?? 0,
      invoicesCount: (json['invoices_count'] as num?)?.toInt() ?? 0,
      paymentsCount: (json['payments_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentFeeRosterItem {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final String className;
  final String rollNumber;
  final String admissionNumber;
  final String? avatarUrl;
  final String feePlan;
  final double totalBilled;
  final double paidAmount;
  final double balanceAmount;
  final double advanceAmount;
  final String status;
  final String? latestInvoiceId;
  final String? latestInvoiceNumber;
  final String? dueDate;
  final int invoicesCount;

  StudentFeeRosterItem({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.studentPhone = '',
    required this.className,
    required this.rollNumber,
    required this.admissionNumber,
    this.avatarUrl,
    required this.feePlan,
    this.totalBilled = 0.0,
    this.paidAmount = 0.0,
    this.balanceAmount = 0.0,
    this.advanceAmount = 0.0,
    this.status = 'Pending',
    this.latestInvoiceId,
    this.latestInvoiceNumber,
    this.dueDate,
    this.invoicesCount = 0,
  });

  String get totalBilledFormatted => formatIndianCurrency(totalBilled);
  String get paidAmountFormatted => formatIndianCurrency(paidAmount);
  String get balanceAmountFormatted => formatIndianCurrency(balanceAmount);
  String get advanceAmountFormatted => advanceAmount > 0 ? '+${formatIndianCurrency(advanceAmount)} (Advance)' : '₹ 0';

  factory StudentFeeRosterItem.fromJson(Map<String, dynamic> json) {
    return StudentFeeRosterItem(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      studentEmail: json['student_email']?.toString() ?? '',
      studentPhone: json['student_phone']?.toString() ?? '',
      className: json['class_name']?.toString() ?? 'Class 10',
      rollNumber: json['roll_number']?.toString() ?? '',
      admissionNumber: json['admission_number']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      feePlan: json['fee_plan']?.toString() ?? 'Monthly',
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      advanceAmount: (json['advance_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Pending',
      latestInvoiceId: json['latest_invoice_id']?.toString(),
      latestInvoiceNumber: json['latest_invoice_number']?.toString(),
      dueDate: json['due_date']?.toString(),
      invoicesCount: (json['invoices_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentFeeInvoiceItem {
  final String id;
  final String invoiceNumber;
  final String title;
  final String feeType;
  final String feePlan;
  final String academicYear;
  final String? billingDate;
  final String dueDate;
  final double subtotal;
  final double concessionAmount;
  final double penaltyAmount;
  final double totalBilled;
  final double paidAmount;
  final double balanceAmount;
  final String status;
  final String? notes;
  final String? studentId;
  final String? studentName;
  final String? rollNumber;
  final String? className;
  final double studentAdvanceBalance;

  StudentFeeInvoiceItem({
    required this.id,
    required this.invoiceNumber,
    required this.title,
    required this.feeType,
    required this.feePlan,
    this.academicYear = '2026 - 2027',
    this.billingDate,
    required this.dueDate,
    this.subtotal = 0.0,
    this.concessionAmount = 0.0,
    this.penaltyAmount = 0.0,
    this.totalBilled = 0.0,
    this.paidAmount = 0.0,
    this.balanceAmount = 0.0,
    this.status = 'Pending',
    this.notes,
    this.studentId,
    this.studentName,
    this.rollNumber,
    this.className,
    this.studentAdvanceBalance = 0.0,
  });

  String get totalBilledFormatted => formatIndianCurrency(totalBilled);
  String get paidAmountFormatted => formatIndianCurrency(paidAmount);
  String get balanceAmountFormatted => formatIndianCurrency(balanceAmount);
  String get studentAdvanceFormatted => formatIndianCurrency(studentAdvanceBalance);

  factory StudentFeeInvoiceItem.fromJson(Map<String, dynamic> json) {
    return StudentFeeInvoiceItem(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Tuition Fee Invoice',
      feeType: json['fee_type']?.toString() ?? 'Tuition Fee',
      feePlan: json['fee_plan']?.toString() ?? 'Monthly',
      academicYear: json['academic_year']?.toString() ?? '2026 - 2027',
      billingDate: json['billing_date']?.toString(),
      dueDate: json['due_date']?.toString() ?? '',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      concessionAmount: (json['concession_amount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0.0,
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Pending',
      notes: json['notes']?.toString(),
      studentId: json['student_id']?.toString(),
      studentName: json['student_name']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      className: json['class_name']?.toString(),
      studentAdvanceBalance: (json['student_advance_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StudentFeePaymentItem {
  final String id;
  final String receiptNumber;
  final double amountPaid;
  final String paymentMethod;
  final String? transactionReference;
  final String paymentDate;
  final String status;
  final String? remarks;
  final String? studentId;
  final String? studentName;
  final String? rollNumber;
  final String? className;
  final String? invoiceNumber;

  StudentFeePaymentItem({
    required this.id,
    required this.receiptNumber,
    required this.amountPaid,
    required this.paymentMethod,
    this.transactionReference,
    required this.paymentDate,
    this.status = 'COMPLETED',
    this.remarks,
    this.studentId,
    this.studentName,
    this.rollNumber,
    this.className,
    this.invoiceNumber,
  });

  String get amountPaidFormatted => formatIndianCurrency(amountPaid);

  factory StudentFeePaymentItem.fromJson(Map<String, dynamic> json) {
    return StudentFeePaymentItem(
      id: json['id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'UPI',
      transactionReference: json['transaction_reference']?.toString(),
      paymentDate: json['payment_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      remarks: json['remarks']?.toString(),
      studentId: json['student_id']?.toString(),
      studentName: json['student_name']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      className: json['class_name']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
    );
  }
}

class StudentFeeStructureItem {
  final String id;
  final String feeName;
  final String feeType;
  final String classGrade;
  final String sectionName;
  final String billingCycle;
  final String frequencyType;
  final double amount;
  final double annualLiability;
  final int dueDayOfCycle;
  final int gracePeriodDays;
  final double lateFineAmount;
  final String lateFineType;
  final bool isMandatory;
  final bool isRefundable;
  final String? description;
  final String status;
  final String academicYear;

  StudentFeeStructureItem({
    required this.id,
    required this.feeName,
    required this.feeType,
    this.classGrade = 'All Classes',
    this.sectionName = 'All Sections',
    this.billingCycle = 'Monthly',
    this.frequencyType = 'Monthly',
    this.amount = 0.0,
    this.annualLiability = 0.0,
    this.dueDayOfCycle = 10,
    this.gracePeriodDays = 5,
    this.lateFineAmount = 0.0,
    this.lateFineType = 'FLAT',
    this.isMandatory = true,
    this.isRefundable = false,
    this.description,
    this.status = 'ACTIVE',
    this.academicYear = '2026 - 2027',
  });

  String get amountFormatted => formatIndianCurrency(amount);
  String get annualLiabilityFormatted => formatIndianCurrency(annualLiability > 0 ? annualLiability : (frequencyType == 'Monthly' ? amount * 12 : (frequencyType == 'Quarterly' ? amount * 4 : (frequencyType == 'Half-Yearly' ? amount * 2 : amount))));
  String get lateFineFormatted => lateFineAmount > 0
      ? (lateFineType == 'PER_DAY' ? '₹${lateFineAmount.toStringAsFixed(0)}/day' : '₹${lateFineAmount.toStringAsFixed(0)} flat')
      : 'No fine';

  factory StudentFeeStructureItem.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final freq = json['frequency_type']?.toString() ?? 'Monthly';
    double annual = (json['annual_liability'] as num?)?.toDouble() ?? 0.0;
    if (annual <= 0) {
      if (freq == 'One-Time' || freq == 'Annual') {
        annual = amt;
      } else if (freq == 'Quarterly') {
        annual = amt * 4;
      } else if (freq == 'Half-Yearly') {
        annual = amt * 2;
      } else {
        annual = amt * 12;
      }
    }

    return StudentFeeStructureItem(
      id: json['id']?.toString() ?? '',
      feeName: json['fee_name']?.toString() ?? '',
      feeType: json['fee_type']?.toString() ?? '',
      classGrade: json['class_grade']?.toString() ?? 'All Classes',
      sectionName: json['section_name']?.toString() ?? 'All Sections',
      billingCycle: json['billing_cycle']?.toString() ?? 'Monthly',
      frequencyType: freq,
      amount: amt,
      annualLiability: annual,
      dueDayOfCycle: (json['due_day_of_cycle'] as num?)?.toInt() ?? 10,
      gracePeriodDays: (json['grace_period_days'] as num?)?.toInt() ?? 5,
      lateFineAmount: (json['late_fine_amount'] as num?)?.toDouble() ?? 0.0,
      lateFineType: json['late_fine_type']?.toString() ?? 'FLAT',
      isMandatory: json['is_mandatory'] != false,
      isRefundable: json['is_refundable'] == true,
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      academicYear: json['academic_year']?.toString() ?? '2026 - 2027',
    );
  }
}

class FeeStructureCohortSummary {
  final String cohortClass;
  final String cohortSection;
  final int totalFeeHeads;
  final double totalAnnualLiability;
  final double monthlyAnnualTotal;
  final double monthlyRate;
  final double quarterlyAnnualTotal;
  final double quarterlyRate;
  final double halfYearlyAnnualTotal;
  final double annualChargesTotal;
  final double oneTimeAdmissionTotal;

  FeeStructureCohortSummary({
    this.cohortClass = 'All Classes',
    this.cohortSection = 'All Sections',
    this.totalFeeHeads = 0,
    this.totalAnnualLiability = 0.0,
    this.monthlyAnnualTotal = 0.0,
    this.monthlyRate = 0.0,
    this.quarterlyAnnualTotal = 0.0,
    this.quarterlyRate = 0.0,
    this.halfYearlyAnnualTotal = 0.0,
    this.annualChargesTotal = 0.0,
    this.oneTimeAdmissionTotal = 0.0,
  });

  String get totalAnnualLiabilityFormatted => formatIndianCurrency(totalAnnualLiability);
  String get monthlyRateFormatted => formatIndianCurrency(monthlyRate);
  String get quarterlyRateFormatted => formatIndianCurrency(quarterlyRate);

  factory FeeStructureCohortSummary.fromJson(Map<String, dynamic> json) {
    return FeeStructureCohortSummary(
      cohortClass: json['cohort_class']?.toString() ?? 'All Classes',
      cohortSection: json['cohort_section']?.toString() ?? 'All Sections',
      totalFeeHeads: (json['total_fee_heads'] as num?)?.toInt() ?? 0,
      totalAnnualLiability: (json['total_annual_liability'] as num?)?.toDouble() ?? 0.0,
      monthlyAnnualTotal: (json['monthly_annual_total'] as num?)?.toDouble() ?? 0.0,
      monthlyRate: (json['monthly_rate'] as num?)?.toDouble() ?? 0.0,
      quarterlyAnnualTotal: (json['quarterly_annual_total'] as num?)?.toDouble() ?? 0.0,
      quarterlyRate: (json['quarterly_rate'] as num?)?.toDouble() ?? 0.0,
      halfYearlyAnnualTotal: (json['half_yearly_annual_total'] as num?)?.toDouble() ?? 0.0,
      annualChargesTotal: (json['annual_charges_total'] as num?)?.toDouble() ?? 0.0,
      oneTimeAdmissionTotal: (json['one_time_admission_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
