import 'package:intl/intl.dart';

class HostelFeeKPIs {
  final double totalBilled;
  final double totalCollected;
  final double pendingDues;
  final double overdueAmount;
  final int collectionRate;
  final int totalStudentsCount;
  final int pendingStudentsCount;
  final int overdueStudentsCount;
  final int upcomingInvoicesCount;
  final String academicYear;

  HostelFeeKPIs({
    this.totalBilled = 0.0,
    this.totalCollected = 0.0,
    this.pendingDues = 0.0,
    this.overdueAmount = 0.0,
    this.collectionRate = 0,
    this.totalStudentsCount = 0,
    this.pendingStudentsCount = 0,
    this.overdueStudentsCount = 0,
    this.upcomingInvoicesCount = 0,
    this.academicYear = '2026 - 2027',
  });

  int get totalStudents => totalStudentsCount;
  int get paidStudentsCount => (totalStudentsCount - pendingStudentsCount - overdueStudentsCount).clamp(0, totalStudentsCount);
  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalBilled.toInt())}';
  String get totalCollectedFormatted => '₹ ${NumberFormat('#,##,###').format(totalCollected.toInt())}';
  String get pendingDuesFormatted => '₹ ${NumberFormat('#,##,###').format(pendingDues.toInt())}';
  String get overdueAmountFormatted => '₹ ${NumberFormat('#,##,###').format(overdueAmount.toInt())}';
  String get collectionRateFormatted => '$collectionRate% Collection';

  factory HostelFeeKPIs.fromJson(Map<String, dynamic> json) {
    return HostelFeeKPIs(
      totalBilled: (json['total_billed'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      pendingDues: (json['pending_dues'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (json['collection_rate'] as num?)?.toInt() ?? 0,
      totalStudentsCount: (json['total_students_count'] as num?)?.toInt() ?? 0,
      pendingStudentsCount: (json['pending_students_count'] as num?)?.toInt() ?? 0,
      overdueStudentsCount: (json['overdue_students_count'] as num?)?.toInt() ?? 0,
      upcomingInvoicesCount: (json['upcoming_invoices_count'] as num?)?.toInt() ?? 0,
      academicYear: json['academic_year'] as String? ?? '2026 - 2027',
    );
  }
}

class HostelFeeSummaryDonut {
  final int collectionRate;
  final double total;
  final double collected;
  final double pending;
  final double overdue;
  final String academicYear;

  HostelFeeSummaryDonut({
    this.collectionRate = 0,
    this.total = 0.0,
    this.collected = 0.0,
    this.pending = 0.0,
    this.overdue = 0.0,
    this.academicYear = '2026 - 2027',
  });

  double get collectionPercentage => total > 0 ? (collected / total) * 100.0 : 0.0;
  double get pendingPercentage => total > 0 ? (pending / total) * 100.0 : 0.0;
  double get overduePercentage => total > 0 ? (overdue / total) * 100.0 : 0.0;
  String get collectedFormatted => '₹ ${NumberFormat('#,##,###').format(collected.toInt())}';
  String get pendingFormatted => '₹ ${NumberFormat('#,##,###').format(pending.toInt())}';
  String get overdueFormatted => '₹ ${NumberFormat('#,##,###').format(overdue.toInt())}';
  String get totalFormatted => '₹ ${NumberFormat('#,##,###').format(total.toInt())}';

  factory HostelFeeSummaryDonut.fromJson(Map<String, dynamic> json) {
    return HostelFeeSummaryDonut(
      collectionRate: (json['collection_rate'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      collected: (json['collected'] as num?)?.toDouble() ?? 0.0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0.0,
      overdue: (json['overdue'] as num?)?.toDouble() ?? 0.0,
      academicYear: json['academic_year'] as String? ?? '2026 - 2027',
    );
  }
}

class HostelUpcomingInvoiceItem {
  final String id;
  final String day;
  final String month;
  final String hostelName;
  final int studentsCount;
  final double amount;
  final String status;
  final bool isScheduled;

  HostelUpcomingInvoiceItem({
    required this.id,
    required this.day,
    required this.month,
    required this.hostelName,
    required this.studentsCount,
    required this.amount,
    required this.status,
    this.isScheduled = false,
  });

  String get dateDay => day;
  String get dateMonth => month;
  int get studentCount => studentsCount;
  String get batchTitle => 'Term 2 Billing';

  factory HostelUpcomingInvoiceItem.fromJson(Map<String, dynamic> json) {
    return HostelUpcomingInvoiceItem(
      id: json['id']?.toString() ?? '',
      day: json['day']?.toString() ?? '15',
      month: json['month']?.toString() ?? 'MAY',
      hostelName: json['hostel_name']?.toString() ?? 'Boys Hostel A',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Generate',
      isScheduled: json['is_scheduled'] == true,
    );
  }
}

class HostelRecentPaymentItem {
  final String id;
  final String studentName;
  final String? avatarUrl;
  final String roomInfo;
  final String receiptNo;
  final double amount;
  final String timeAgo;
  final String paymentMethod;

  HostelRecentPaymentItem({
    required this.id,
    required this.studentName,
    this.avatarUrl,
    required this.roomInfo,
    required this.receiptNo,
    required this.amount,
    required this.timeAgo,
    this.paymentMethod = 'CASH',
  });

  String get paymentMode => paymentMethod;
  String get relativeTime => timeAgo;
  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(amount.toInt())}';

  factory HostelRecentPaymentItem.fromJson(Map<String, dynamic> json) {
    return HostelRecentPaymentItem(
      id: json['id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      avatarUrl: json['avatar_url'] as String?,
      roomInfo: json['room_info']?.toString() ?? '',
      receiptNo: json['receipt_no']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      timeAgo: json['time_ago']?.toString() ?? 'Recently',
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
    );
  }
}

class HostelStudentFeeItem {
  final String accountId;
  final String studentId;
  final String? admissionId;
  final int rowNum;
  final String name;
  final String? avatarUrl;
  final String className;
  final String rollNumber;
  final String studentIdentifier;
  final String? hostelId;
  final String hostelName;
  final String? roomId;
  final String roomNumber;
  final String? bedId;
  final String feePlan;
  final double totalFee;
  final double paid;
  final double due;
  final double overdue;
  final String status;
  final String statusRaw;
  final String? nextDueDate;
  final String? lastPaymentDate;

  HostelStudentFeeItem({
    required this.accountId,
    required this.studentId,
    this.admissionId,
    required this.rowNum,
    required this.name,
    this.avatarUrl,
    required this.className,
    required this.rollNumber,
    required this.studentIdentifier,
    this.hostelId,
    required this.hostelName,
    this.roomId,
    required this.roomNumber,
    this.bedId,
    required this.feePlan,
    required this.totalFee,
    required this.paid,
    required this.due,
    required this.overdue,
    required this.status,
    required this.statusRaw,
    this.nextDueDate,
    this.lastPaymentDate,
  });

  String get id => accountId;
  String get studentName => name;
  String get admissionNumber => studentIdentifier.isNotEmpty ? studentIdentifier : rollNumber;
  String get planName => feePlan;
  double get totalBilled => totalFee;
  double get totalPaid => paid;
  double get balanceDue => (paid >= totalFee) ? 0.0 : (due > 0 ? due : (totalFee - paid));
  String get feeStatus {
    if (paid > totalFee) return 'Over Paid';
    if (paid == totalFee && totalFee > 0) return 'Paid';
    if (status.toLowerCase() == 'overpaid' || status.toLowerCase() == 'over paid') return 'Over Paid';
    return status;
  }
  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalFee.toInt())}';
  String get totalPaidFormatted => '₹ ${NumberFormat('#,##,###').format(paid.toInt())}';
  String get balanceDueFormatted => '₹ ${NumberFormat('#,##,###').format(balanceDue.toInt())}';

  factory HostelStudentFeeItem.fromJson(Map<String, dynamic> json) {
    final totalFeeVal = (json['total_fee'] as num?)?.toDouble() ?? 0.0;
    final paidVal = (json['paid'] as num?)?.toDouble() ?? 0.0;
    final rawDueVal = (json['due'] as num?)?.toDouble() ?? 0.0;
    final computedDue = paidVal >= totalFeeVal ? 0.0 : (rawDueVal > 0 ? rawDueVal : (totalFeeVal - paidVal));
    final rawStatus = json['status']?.toString() ?? 'Pending';
    final computedStatus = paidVal > totalFeeVal
        ? 'Over Paid'
        : (paidVal == totalFeeVal && totalFeeVal > 0
            ? 'Paid'
            : (rawStatus.toLowerCase() == 'overpaid' || rawStatus.toLowerCase() == 'over paid' ? 'Over Paid' : rawStatus));

    return HostelStudentFeeItem(
      accountId: json['account_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      admissionId: json['admission_id']?.toString(),
      rowNum: (json['row_num'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatar_url'] as String?,
      className: json['class_name']?.toString() ?? '10 A',
      rollNumber: json['roll_number']?.toString() ?? '0101',
      studentIdentifier: json['student_identifier']?.toString() ?? '',
      hostelId: json['hostel_id']?.toString(),
      hostelName: json['hostel_name']?.toString() ?? 'Boys Hostel A',
      roomId: json['room_id']?.toString(),
      roomNumber: json['room_number']?.toString() ?? 'A-101',
      bedId: json['bed_id']?.toString(),
      feePlan: json['fee_plan']?.toString() ?? 'Standard',
      totalFee: totalFeeVal,
      paid: paidVal,
      due: computedDue,
      overdue: (json['overdue'] as num?)?.toDouble() ?? 0.0,
      status: computedStatus,
      statusRaw: json['status_raw']?.toString() ?? (paidVal > totalFeeVal ? 'OVERPAID' : 'PENDING'),
      nextDueDate: json['next_due_date']?.toString(),
      lastPaymentDate: json['last_payment_date']?.toString(),
    );
  }
}

class HostelFeeRosterPagination {
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  HostelFeeRosterPagination({
    this.page = 1,
    this.pageSize = 10,
    this.totalRecords = 356,
    this.totalPages = 36,
  });

  int get total => totalRecords;

  factory HostelFeeRosterPagination.fromJson(Map<String, dynamic> json) {
    return HostelFeeRosterPagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 10,
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

class HostelStudentFeeDetail360 {
  final String studentId;
  final String fullName;
  final String? avatarUrl;
  final String className;
  final String rollNumber;
  final String hostelName;
  final String roomNumber;
  final String bedNumber;
  final String feePlan;
  final double totalFee;
  final double totalPaid;
  final double totalDue;
  final double totalOverdue;
  final double totalConcession;
  final double advanceCredit;
  final double securityDepositExpected;
  final double securityDepositPaid;
  final double securityDepositRefunded;
  final String status;
  final String? nextDueDate;
  final String? lastPaymentDate;
  final List<HostelInvoiceItemModel> invoices;
  final List<HostelPaymentReceiptModel> payments;
  final List<HostelLedgerEntryModel> ledger;
  final List<HostelConcessionItemModel> concessions;
  final List<HostelPenaltyItemModel> penalties;
  final List<HostelFeeHeadBreakdownItem> breakdown;

  HostelStudentFeeDetail360({
    required this.studentId,
    required this.fullName,
    this.avatarUrl,
    required this.className,
    required this.rollNumber,
    required this.hostelName,
    required this.roomNumber,
    required this.bedNumber,
    required this.feePlan,
    required this.totalFee,
    required this.totalPaid,
    required this.totalDue,
    required this.totalOverdue,
    this.totalConcession = 0.0,
    this.advanceCredit = 0.0,
    this.securityDepositExpected = 0.0,
    this.securityDepositPaid = 0.0,
    this.securityDepositRefunded = 0.0,
    required this.status,
    this.nextDueDate,
    this.lastPaymentDate,
    this.invoices = const [],
    this.payments = const [],
    this.ledger = const [],
    this.concessions = const [],
    this.penalties = const [],
    this.breakdown = const [],
  });

  String get studentName => fullName;
  String get admissionNumber => rollNumber;
  String get planName => feePlan;
  double get totalBilled => totalFee;
  double get balanceDue => (totalPaid >= totalFee) ? 0.0 : totalDue;
  String get feeStatus {
    if (totalPaid > totalFee) return 'Over Paid';
    if (totalPaid == totalFee && totalFee > 0) return 'Paid';
    if (status.toLowerCase() == 'overpaid' || status.toLowerCase() == 'over paid') return 'Over Paid';
    return status;
  }
  String get emergencyPhone => '+91 98765 43210';
  String get parentEmail => 'parent@edushamiit.edu';
  double get securityDeposit => securityDepositPaid > 0 ? securityDepositPaid : securityDepositExpected;
  List<Map<String, dynamic>> get feeHeads => breakdown
      .map((b) => {
            'id': b.id,
            'head_name': b.headName,
            'head_code': b.headCode,
            'amount': b.amount,
            'is_mandatory': b.isMandatory,
            'is_refundable': b.isRefundable,
            'frequency': b.frequency,
            'charge_type': b.chargeType,
          })
      .toList();
  String get totalBilledFormatted => '₹ ${NumberFormat('#,##,###').format(totalFee.toInt())}';
  String get totalPaidFormatted => '₹ ${NumberFormat('#,##,###').format(totalPaid.toInt())}';
  String get balanceDueFormatted => '₹ ${NumberFormat('#,##,###').format(balanceDue.toInt())}';
  String get securityDepositFormatted => '₹ ${NumberFormat('#,##,###').format(securityDeposit.toInt())}';

  factory HostelStudentFeeDetail360.fromJson(Map<String, dynamic> json) {
    final totalFeeVal = (json['total_fee'] as num?)?.toDouble() ?? 0.0;
    final totalPaidVal = (json['total_paid'] as num?)?.toDouble() ?? 0.0;
    final rawDueVal = (json['total_due'] as num?)?.toDouble() ?? 0.0;
    final computedDue = totalPaidVal >= totalFeeVal ? 0.0 : rawDueVal;
    final rawStatus = json['status']?.toString() ?? 'Pending';
    final computedStatus = totalPaidVal > totalFeeVal
        ? 'Over Paid'
        : (totalPaidVal == totalFeeVal && totalFeeVal > 0
            ? 'Paid'
            : (rawStatus.toLowerCase() == 'overpaid' || rawStatus.toLowerCase() == 'over paid' ? 'Over Paid' : rawStatus));

    return HostelStudentFeeDetail360(
      studentId: json['student_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatarUrl: json['avatar_url'] as String?,
      className: json['class_name']?.toString() ?? '10 A',
      rollNumber: json['roll_number']?.toString() ?? '',
      hostelName: json['hostel_name']?.toString() ?? 'Boys Hostel A',
      roomNumber: json['room_number']?.toString() ?? 'A-101',
      bedNumber: json['bed_number']?.toString() ?? 'Bed 1',
      feePlan: json['fee_plan']?.toString() ?? 'Standard',
      totalFee: totalFeeVal,
      totalPaid: totalPaidVal,
      totalDue: computedDue,
      totalOverdue: (json['total_overdue'] as num?)?.toDouble() ?? 0.0,
      totalConcession: (json['total_concession'] as num?)?.toDouble() ?? 0.0,
      advanceCredit: (json['advance_credit'] as num?)?.toDouble() ?? (totalPaidVal > totalFeeVal ? totalPaidVal - totalFeeVal : 0.0),
      securityDepositExpected: (json['security_deposit_expected'] as num?)?.toDouble() ?? 0.0,
      securityDepositPaid: (json['security_deposit_paid'] as num?)?.toDouble() ?? 0.0,
      securityDepositRefunded: (json['security_deposit_refunded'] as num?)?.toDouble() ?? 0.0,
      status: computedStatus,
      nextDueDate: json['next_due_date']?.toString(),
      lastPaymentDate: json['last_payment_date']?.toString(),
      invoices: (json['invoices'] as List? ?? [])
          .map((i) => HostelInvoiceItemModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      payments: (json['payments'] as List? ?? [])
          .map((p) => HostelPaymentReceiptModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      ledger: (json['ledger'] as List? ?? [])
          .map((l) => HostelLedgerEntryModel.fromJson(l as Map<String, dynamic>))
          .toList(),
      concessions: (json['concessions'] as List? ?? [])
          .map((c) => HostelConcessionItemModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      penalties: (json['penalties'] as List? ?? [])
          .map((p) => HostelPenaltyItemModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      breakdown: (((json['breakdown'] ?? json['fee_breakdown']) as List?) ?? [])
          .map((b) => HostelFeeHeadBreakdownItem.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HostelInvoiceItemModel {
  final String id;
  final String invoiceNumber;
  final String billingPeriod;
  final String? invoiceDate;
  final String? dueDate;
  final double grossAmount;
  final double discountAmount;
  final double penaltyAmount;
  final double netAmount;
  final double paidAmount;
  final double balanceAmount;
  final String status;
  final String? studentName;
  final String? className;
  final String? roomNumber;
  final String? hostelName;

  HostelInvoiceItemModel({
    required this.id,
    required this.invoiceNumber,
    required this.billingPeriod,
    this.invoiceDate,
    this.dueDate,
    required this.grossAmount,
    this.discountAmount = 0.0,
    this.penaltyAmount = 0.0,
    required this.netAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.status,
    this.studentName,
    this.className,
    this.roomNumber,
    this.hostelName,
  });

  String get totalAmountFormatted => '₹ ${NumberFormat('#,##,###').format(netAmount.toInt())}';
  String get balanceAmountFormatted => '₹ ${NumberFormat('#,##,###').format(balanceAmount.toInt())}';
  String get dueDateFormatted => dueDate ?? 'Due in 15 days';

  factory HostelInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return HostelInvoiceItemModel(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      billingPeriod: json['billing_period']?.toString() ?? '',
      invoiceDate: json['invoice_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'GENERATED',
      studentName: json['student_name']?.toString(),
      className: json['class_name']?.toString(),
      roomNumber: json['room_number']?.toString(),
      hostelName: json['hostel_name']?.toString(),
    );
  }
}

class HostelPaymentReceiptModel {
  final String id;
  final String receiptNumber;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String? paymentDate;
  final String status;
  final String? notes;
  final String? studentName;
  final String? roomNumber;
  final String? hostelName;

  HostelPaymentReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    this.paymentDate,
    required this.status,
    this.notes,
    this.studentName,
    this.roomNumber,
    this.hostelName,
  });

  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(amount.toInt())}';
  String get paymentMode => paymentMethod;
  String get paymentDateFormatted => paymentDate ?? 'Today';

  factory HostelPaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return HostelPaymentReceiptModel(
      id: json['id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'CASH',
      transactionReference: json['transaction_reference']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      status: json['status']?.toString() ?? 'COMPLETED',
      notes: json['notes']?.toString(),
      studentName: json['student_name']?.toString(),
      roomNumber: json['room_number']?.toString(),
      hostelName: json['hostel_name']?.toString(),
    );
  }
}

class HostelLedgerEntryModel {
  final String id;
  final String entryType;
  final String? referenceNumber;
  final double debit;
  final double credit;
  final double balance;
  final String description;
  final String? transactionDate;

  HostelLedgerEntryModel({
    required this.id,
    required this.entryType,
    this.referenceNumber,
    this.debit = 0.0,
    this.credit = 0.0,
    this.balance = 0.0,
    required this.description,
    this.transactionDate,
  });

  String get dateFormatted => transactionDate ?? 'Today';
  String get runningBalanceFormatted => '₹ ${NumberFormat('#,##,###').format(balance.toInt())}';

  factory HostelLedgerEntryModel.fromJson(Map<String, dynamic> json) {
    return HostelLedgerEntryModel(
      id: json['id']?.toString() ?? '',
      entryType: json['entry_type']?.toString() ?? 'ENTRY',
      referenceNumber: json['reference_number']?.toString(),
      debit: (json['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      transactionDate: json['transaction_date']?.toString(),
    );
  }
}

class HostelConcessionItemModel {
  final String id;
  final String concessionType;
  final double concessionAmount;
  final String reason;
  final String status;
  final String? approvedByName;
  final String? appliedAt;

  HostelConcessionItemModel({
    required this.id,
    required this.concessionType,
    required this.concessionAmount,
    required this.reason,
    required this.status,
    this.approvedByName,
    this.appliedAt,
  });

  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(concessionAmount.toInt())}';

  factory HostelConcessionItemModel.fromJson(Map<String, dynamic> json) {
    return HostelConcessionItemModel(
      id: json['id']?.toString() ?? '',
      concessionType: json['concession_type']?.toString() ?? 'FIXED',
      concessionAmount: (json['concession_amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'APPROVED',
      approvedByName: json['approved_by_name']?.toString(),
      appliedAt: json['applied_at']?.toString(),
    );
  }
}

class HostelPenaltyItemModel {
  final String id;
  final String penaltyType;
  final String reason;
  final double amount;
  final String status;
  final String? addedByName;
  final String? createdAt;

  HostelPenaltyItemModel({
    required this.id,
    required this.penaltyType,
    required this.reason,
    required this.amount,
    required this.status,
    this.addedByName,
    this.createdAt,
  });

  String get amountFormatted => '₹ ${NumberFormat('#,##,###').format(amount.toInt())}';

  factory HostelPenaltyItemModel.fromJson(Map<String, dynamic> json) {
    return HostelPenaltyItemModel(
      id: json['id']?.toString() ?? '',
      penaltyType: json['charge_type']?.toString() ?? json['penalty_type']?.toString() ?? 'Penalty',
      reason: json['description']?.toString() ?? json['reason']?.toString() ?? 'Hostel fine',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'APPLIED',
      addedByName: json['added_by_name']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class HostelFeeHeadBreakdownItem {
  final String? id;
  final String headName;
  final String headCode;
  final double amount;
  final double discount;
  final double netAmount;
  final bool isMandatory;
  final bool isRefundable;
  final String chargeType;
  final String frequency;

  HostelFeeHeadBreakdownItem({
    this.id,
    required this.headName,
    required this.headCode,
    required this.amount,
    this.discount = 0.0,
    required this.netAmount,
    this.isMandatory = true,
    this.isRefundable = false,
    this.chargeType = 'FIXED',
    this.frequency = 'MONTHLY',
  });

  factory HostelFeeHeadBreakdownItem.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final disc = (json['discount'] as num?)?.toDouble() ?? 0.0;
    final net = (json['net_amount'] as num?)?.toDouble() ?? (amt - disc);
    return HostelFeeHeadBreakdownItem(
      id: json['id']?.toString(),
      headName: json['head_name']?.toString() ?? '',
      headCode: json['head_code']?.toString() ?? '',
      amount: amt,
      discount: disc,
      netAmount: net,
      isMandatory: json['is_mandatory'] != false,
      isRefundable: json['is_refundable'] == true,
      chargeType: json['charge_type']?.toString() ?? 'FIXED',
      frequency: json['frequency']?.toString() ?? 'MONTHLY',
    );
  }
}

class HostelFeePlanModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String? hostelName;
  final String roomType;
  final String roomCategory;
  final String billingCycle;
  final double totalAnnualAmount;
  final double totalCycleAmount;
  final String status;
  final List<HostelFeePlanHeadModel> heads;

  HostelFeePlanModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.hostelName,
    required this.roomType,
    required this.roomCategory,
    required this.billingCycle,
    required this.totalAnnualAmount,
    required this.totalCycleAmount,
    required this.status,
    this.heads = const [],
  });

  String get planName => name;
  String get formattedTotal => '₹ ${NumberFormat('#,##,###').format(totalAnnualAmount.toInt())}';

  factory HostelFeePlanModel.fromJson(Map<String, dynamic> json) {
    return HostelFeePlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      hostelName: json['hostel_name']?.toString(),
      roomType: json['room_type']?.toString() ?? 'Standard',
      roomCategory: json['room_category']?.toString() ?? 'Non-AC',
      billingCycle: json['billing_cycle']?.toString() ?? 'MONTHLY',
      totalAnnualAmount: (json['total_annual_amount'] as num?)?.toDouble() ?? 0.0,
      totalCycleAmount: (json['total_cycle_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'ACTIVE',
      heads: (json['heads'] as List? ?? [])
          .map((h) => HostelFeePlanHeadModel.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HostelFeePlanHeadModel {
  final String id;
  final String feeHeadCode;
  final String feeHeadName;
  final double amount;
  final String chargeType;
  final String frequency;
  final bool isRefundable;
  final bool isMandatory;
  final bool lateFeeApplicable;

  HostelFeePlanHeadModel({
    required this.id,
    required this.feeHeadCode,
    required this.feeHeadName,
    required this.amount,
    required this.chargeType,
    required this.frequency,
    this.isRefundable = false,
    this.isMandatory = true,
    this.lateFeeApplicable = true,
  });

  factory HostelFeePlanHeadModel.fromJson(Map<String, dynamic> json) {
    return HostelFeePlanHeadModel(
      id: json['id']?.toString() ?? '',
      feeHeadCode: json['fee_head_code']?.toString() ?? '',
      feeHeadName: json['fee_head_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      chargeType: json['charge_type']?.toString() ?? 'FIXED',
      frequency: json['frequency']?.toString() ?? 'MONTHLY',
      isRefundable: json['is_refundable'] == true,
      isMandatory: json['is_mandatory'] != false,
      lateFeeApplicable: json['late_fee_applicable'] != false,
    );
  }
}
