import 'package:intl/intl.dart';

class StudentFeeKPIs {
  final double totalBilled;
  final double totalCollected;
  final double pendingDues;
  final double overdueAmount;
  final double collectionRate;
  final int totalStudents;
  final int paidStudentsCount;
  final int pendingStudentsCount;
  final int overdueStudentsCount;

  StudentFeeKPIs({
    this.totalBilled = 0.0,
    this.totalCollected = 0.0,
    this.pendingDues = 0.0,
    this.overdueAmount = 0.0,
    this.collectionRate = 0.0,
    this.totalStudents = 0,
    this.paidStudentsCount = 0,
    this.pendingStudentsCount = 0,
    this.overdueStudentsCount = 0,
  });

  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalBilled.toInt())}';
  String get totalCollectedFormatted => '₹ ${NumberFormat('#,##,###').format(totalCollected.toInt())}';
  String get pendingDuesFormatted => '₹ ${NumberFormat('#,##,###').format(pendingDues.toInt())}';
  String get overdueAmountFormatted => '₹ ${NumberFormat('#,##,###').format(overdueAmount.toInt())}';
  String get collectionRateFormatted => '${collectionRate.toStringAsFixed(1)}% Collection';

  factory StudentFeeKPIs.fromJson(Map<String, dynamic> json) {
    return StudentFeeKPIs(
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      pendingDues: (json['pending_dues'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (json['collection_rate'] as num?)?.toDouble() ?? 0.0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      paidStudentsCount: (json['paid_students_count'] as num?)?.toInt() ?? 0,
      pendingStudentsCount: (json['pending_students_count'] as num?)?.toInt() ?? 0,
      overdueStudentsCount: (json['overdue_students_count'] as num?)?.toInt() ?? 0,
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
  final String status;
  final String? latestInvoiceId;
  final String? latestInvoiceNumber;
  final String? dueDate;

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
    this.status = 'Pending',
    this.latestInvoiceId,
    this.latestInvoiceNumber,
    this.dueDate,
  });

  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalBilled.toInt())}';
  String get paidAmountFormatted => '₹ ${NumberFormat('#,##,###').format(paidAmount.toInt())}';
  String get balanceAmountFormatted => '₹ ${NumberFormat('#,##,###').format(balanceAmount.toInt())}';

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
      status: json['status']?.toString() ?? 'Pending',
      latestInvoiceId: json['latest_invoice_id']?.toString(),
      latestInvoiceNumber: json['latest_invoice_number']?.toString(),
      dueDate: json['due_date']?.toString(),
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
  });

  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalBilled.toInt())}';
  String get paidAmountFormatted => '₹ ${NumberFormat('#,##,###').format(paidAmount.toInt())}';
  String get balanceAmountFormatted => '₹ ${NumberFormat('#,##,###').format(balanceAmount.toInt())}';

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

  String get amountPaidFormatted => '₹ ${NumberFormat('#,##,###').format(amountPaid.toInt())}';

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
  final String billingCycle;
  final double amount;
  final String? description;
  final bool isMandatory;
  final String status;

  StudentFeeStructureItem({
    required this.id,
    required this.feeName,
    required this.feeType,
    this.classGrade = 'All Classes',
    this.billingCycle = 'Monthly',
    this.amount = 0.0,
    this.description,
    this.isMandatory = true,
    this.status = 'ACTIVE',
  });

  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(amount.toInt())}';

  factory StudentFeeStructureItem.fromJson(Map<String, dynamic> json) {
    return StudentFeeStructureItem(
      id: json['id']?.toString() ?? '',
      feeName: json['fee_name']?.toString() ?? '',
      feeType: json['fee_type']?.toString() ?? '',
      classGrade: json['class_grade']?.toString() ?? 'All Classes',
      billingCycle: json['billing_cycle']?.toString() ?? 'Monthly',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      isMandatory: json['is_mandatory'] == true,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}
