import 'package:flutter/foundation.dart';

/// Financial Dashboard Overview Model
class FinanceOverviewData {
  final double totalRevenue;
  final double totalFeeDemand;
  final double totalCollected;
  final double totalOutstanding;
  final double overdueAmount;
  final double collectionRate;
  final int totalStudents;
  final int studentsWithDues;
  final double todayCollection;
  final double totalExpenses;
  final double payrollCost;
  final double netBalance;
  final double cashBankBalance;
  final List<FeeHeadCollectionData> feeHeadCollection;
  final List<DuesAgingData> duesAging;
  final List<CollectionTrendData> collectionTrend;

  FinanceOverviewData({
    required this.totalRevenue,
    required this.totalFeeDemand,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.overdueAmount,
    required this.collectionRate,
    required this.totalStudents,
    required this.studentsWithDues,
    required this.todayCollection,
    required this.totalExpenses,
    required this.payrollCost,
    required this.netBalance,
    required this.cashBankBalance,
    required this.feeHeadCollection,
    required this.duesAging,
    required this.collectionTrend,
  });

  factory FinanceOverviewData.fromJson(Map<String, dynamic> json) {
    return FinanceOverviewData(
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalFeeDemand: (json['total_fee_demand'] ?? 0).toDouble(),
      totalCollected: (json['total_collected'] ?? 0).toDouble(),
      totalOutstanding: (json['total_outstanding'] ?? 0).toDouble(),
      overdueAmount: (json['overdue_amount'] ?? 0).toDouble(),
      collectionRate: (json['collection_rate'] ?? 0).toDouble(),
      totalStudents: json['total_students'] ?? 0,
      studentsWithDues: json['students_with_dues'] ?? 0,
      todayCollection: (json['today_collection'] ?? 0).toDouble(),
      totalExpenses: (json['total_expenses'] ?? 0).toDouble(),
      payrollCost: (json['payroll_cost'] ?? 0).toDouble(),
      netBalance: (json['net_balance'] ?? 0).toDouble(),
      cashBankBalance: (json['cash_bank_balance'] ?? 0).toDouble(),
      feeHeadCollection: (json['fee_head_collection'] as List? ?? [])
          .map((e) => FeeHeadCollectionData.fromJson(e))
          .toList(),
      duesAging: (json['dues_aging'] as List? ?? [])
          .map((e) => DuesAgingData.fromJson(e))
          .toList(),
      collectionTrend: (json['collection_trend'] as List? ?? [])
          .map((e) => CollectionTrendData.fromJson(e))
          .toList(),
    );
  }
}

class FeeHeadCollectionData {
  final String feeHead;
  final double collected;
  final double pctCollected;
  final double outstanding;

  FeeHeadCollectionData({
    required this.feeHead,
    required this.collected,
    required this.pctCollected,
    required this.outstanding,
  });

  factory FeeHeadCollectionData.fromJson(Map<String, dynamic> json) {
    return FeeHeadCollectionData(
      feeHead: json['fee_head'] ?? '',
      collected: (json['collected'] ?? 0).toDouble(),
      pctCollected: (json['pct_collected'] ?? 0).toDouble(),
      outstanding: (json['outstanding'] ?? 0).toDouble(),
    );
  }
}

class DuesAgingData {
  final String bucket;
  final double amount;
  final int students;

  DuesAgingData({
    required this.bucket,
    required this.amount,
    required this.students,
  });

  factory DuesAgingData.fromJson(Map<String, dynamic> json) {
    return DuesAgingData(
      bucket: json['bucket'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      students: json['students'] ?? 0,
    );
  }
}

class CollectionTrendData {
  final String month;
  final double amount;

  CollectionTrendData({
    required this.month,
    required this.amount,
  });

  factory CollectionTrendData.fromJson(Map<String, dynamic> json) {
    return CollectionTrendData(
      month: json['month'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }
}

/// Fee Ledger Row Item Model
class FeeLedgerItem {
  final String id;
  final String invoiceNumber;
  final String studentId;
  final String studentName;
  final String admissionNo;
  final String rollNumber;
  final String classSection;
  final String feeHead;
  final String academicYear;
  final double amountDemand;
  final double amountConcession;
  final double amountPayable;
  final double amountPaid;
  final double amountBalance;
  final String dueDate;
  final String status;
  final String? createdAt;

  FeeLedgerItem({
    required this.id,
    required this.invoiceNumber,
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    required this.rollNumber,
    required this.classSection,
    required this.feeHead,
    required this.academicYear,
    required this.amountDemand,
    required this.amountConcession,
    required this.amountPayable,
    required this.amountPaid,
    required this.amountBalance,
    required this.dueDate,
    required this.status,
    this.createdAt,
  });

  factory FeeLedgerItem.fromJson(Map<String, dynamic> json) {
    return FeeLedgerItem(
      id: json['id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? 'Student',
      admissionNo: json['admission_no'] ?? 'N/A',
      rollNumber: json['roll_number'] ?? 'N/A',
      classSection: json['class_section'] ?? 'Class A',
      feeHead: json['fee_head'] ?? '',
      academicYear: json['academic_year'] ?? '2026-27',
      amountDemand: (json['amount_demand'] ?? 0).toDouble(),
      amountConcession: (json['amount_concession'] ?? 0).toDouble(),
      amountPayable: (json['amount_payable'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      amountBalance: (json['amount_balance'] ?? 0).toDouble(),
      dueDate: json['due_date'] ?? '',
      status: json['status'] ?? 'UNPAID',
      createdAt: json['created_at'],
    );
  }
}

/// Student Fee Profile Model
class StudentFeeAccountData {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> feeBreakdown;
  final List<Map<String, dynamic>> paymentHistory;

  StudentFeeAccountData({
    required this.profile,
    required this.summary,
    required this.feeBreakdown,
    required this.paymentHistory,
  });

  factory StudentFeeAccountData.fromJson(Map<String, dynamic> json) {
    return StudentFeeAccountData(
      profile: json['profile'] ?? {},
      summary: json['summary'] ?? {},
      feeBreakdown: (json['fee_breakdown'] as List? ?? []).cast<Map<String, dynamic>>(),
      paymentHistory: (json['payment_history'] as List? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}

/// Fee Structure Model
class FeeStructureModel {
  final String id;
  final String name;
  final String academicYear;
  final String className;
  final double totalAmount;
  final String status;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> installments;

  FeeStructureModel({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.className,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.installments,
  });

  factory FeeStructureModel.fromJson(Map<String, dynamic> json) {
    return FeeStructureModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      academicYear: json['academic_year'] ?? '',
      className: json['class_name'] ?? 'All Classes',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      items: (json['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      installments: (json['installments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

/// Chart of Accounts Model
class ChartOfAccount {
  final String id;
  final String accountCode;
  final String accountName;
  final String accountType; // ASSET, LIABILITY, EQUITY, INCOME, EXPENSE
  final bool isActive;

  ChartOfAccount({
    required this.id,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.isActive,
  });

  factory ChartOfAccount.fromJson(Map<String, dynamic> json) {
    return ChartOfAccount(
      id: json['id'] ?? '',
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name'] ?? '',
      accountType: json['account_type'] ?? 'ASSET',
      isActive: json['is_active'] ?? true,
    );
  }
}

/// Staff Payslip Model
class StaffPayslip {
  final String id;
  final String payslipNumber;
  final String staffName;
  final String staffRole;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double netPayable;
  final String paymentStatus;

  StaffPayslip({
    required this.id,
    required this.payslipNumber,
    required this.staffName,
    required this.staffRole,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.netPayable,
    required this.paymentStatus,
  });

  factory StaffPayslip.fromJson(Map<String, dynamic> json) {
    return StaffPayslip(
      id: json['id'] ?? '',
      payslipNumber: json['payslip_number'] ?? '',
      staffName: json['staff_name'] ?? 'Staff Member',
      staffRole: json['staff_role'] ?? 'Teacher',
      basicSalary: (json['basic_salary'] ?? 0).toDouble(),
      allowances: (json['allowances'] ?? 0).toDouble(),
      deductions: (json['deductions'] ?? 0).toDouble(),
      netPayable: (json['net_payable'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'PAID',
    );
  }
}

/// Expense Model
class ExpenseModel {
  final String id;
  final String expenseNumber;
  final String title;
  final double amount;
  final double totalAmount;
  final String expenseDate;
  final String paymentMode;
  final String status;

  ExpenseModel({
    required this.id,
    required this.expenseNumber,
    required this.title,
    required this.amount,
    required this.totalAmount,
    required this.expenseDate,
    required this.paymentMode,
    required this.status,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] ?? '',
      expenseNumber: json['expense_number'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      expenseDate: json['expense_date'] ?? '',
      paymentMode: json['payment_mode'] ?? 'CASH',
      status: json['status'] ?? 'APPROVED',
    );
  }
}

/// Bank Account Model
class BankAccountModel {
  final String id;
  final String accountName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;
  final double currentBalance;

  BankAccountModel({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    required this.currentBalance,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] ?? '',
      accountName: json['account_name'] ?? '',
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'] ?? '',
      accountType: json['account_type'] ?? 'CURRENT',
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
    );
  }
}

/// Vendor Model
class VendorModel {
  final String id;
  final String vendorName;
  final String category;
  final String contactPerson;
  final String phone;
  final double outstandingPayable;

  VendorModel({
    required this.id,
    required this.vendorName,
    required this.category,
    required this.contactPerson,
    required this.phone,
    required this.outstandingPayable,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: json['id'] ?? '',
      vendorName: json['vendor_name'] ?? '',
      category: json['category'] ?? 'Supplier',
      contactPerson: json['contact_person'] ?? '',
      phone: json['phone'] ?? '',
      outstandingPayable: (json['outstanding_payable'] ?? 0).toDouble(),
    );
  }
}
