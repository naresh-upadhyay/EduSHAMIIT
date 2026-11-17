import '../../../services/api_service.dart';
import '../models/student_fee_models.dart';
import '../models/staff_salary_models.dart';

class PaymentManagementApiService {
  static final PaymentManagementApiService instance = PaymentManagementApiService._internal();
  PaymentManagementApiService._internal();

  final ApiService _api = ApiService();

  // =========================================================================
  // METADATA & LOOKUPS API
  // =========================================================================

  Future<Map<String, dynamic>> getStudentFeeMetadata() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/metadata',
        useCache: false,
      );
      if (res['success'] == true) {
        return {
          'classes': (res['classes'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'academic_years': (res['academic_years'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'fee_types': (res['fee_types'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'payment_modes': (res['payment_modes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        };
      }
    } catch (_) {}
    return {
      'classes': ['All Classes', 'Class 9', 'Class 10', 'Class 11', 'Class 12'],
      'academic_years': ['2026 - 2027', '2025 - 2026', '2024 - 2025'],
      'fee_types': ['Tuition Fee', 'Lab Fee', 'Library Fee', 'Exam Fee', 'Transport Fee'],
      'payment_modes': ['UPI', 'Net Banking', 'Cash Counter', 'Cheque/DD', 'POS Debit/Credit Card'],
    };
  }

  Future<Map<String, dynamic>> getStaffSalaryMetadata() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/metadata',
        useCache: false,
      );
      if (res['success'] == true) {
        return {
          'departments': (res['departments'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'roles': (res['roles'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'available_months': (res['available_months'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'payment_modes': (res['payment_modes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        };
      }
    } catch (_) {}
    return {
      'departments': ['Academic & Teaching', 'Administration', 'Finance & Accounts', 'Hostel Staff', 'IT & Support'],
      'roles': ['teacher', 'admin', 'accountant', 'hostel_warden', 'driver'],
      'available_months': ['2026-12', '2026-11', '2026-10', '2026-09', '2026-08'],
      'payment_modes': ['Direct Bank Transfer (NEFT/RTGS)', 'Company Cheque', 'Cash Disbursal', 'UPI Payment'],
    };
  }

  // =========================================================================
  // STUDENT FEES API
  // =========================================================================

  Future<StudentFeeKPIs> getStudentFeeSummary(String academicYear) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/summary',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true && res['kpis'] != null) {
        return StudentFeeKPIs.fromJson(Map<String, dynamic>.from(res['kpis']));
      }
    } catch (_) {}
    return StudentFeeKPIs();
  }

  Future<Map<String, dynamic>> getStudentFeeRoster({
    String academicYear = '2026 - 2027',
    String search = '',
    String? className,
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'search': search,
        'page': page,
        'page_size': pageSize,
      };
      if (className != null && className != 'All Classes' && className != 'All') {
        query['class_name'] = className;
      }
      if (status != null && status != 'All Status' && status != 'All Fees' && status != 'All') {
        query['status'] = status;
      }

      final res = await _api.get(
        '/v1/payment-management/student-fees/students',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['students'] is List) {
        final items = (res['students'] as List)
            .map((e) => StudentFeeRosterItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'students': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'students': <StudentFeeRosterItem>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>?> getStudentFeeDetail(String studentId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/students/$studentId',
        useCache: false,
      );
      if (res['success'] == true && res['detail'] != null) {
        return Map<String, dynamic>.from(res['detail']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> generateStudentInvoice(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/invoices',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> bulkGenerateStudentInvoices(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/invoices/bulk',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> collectStudentPayment(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/payments',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyStudentConcession(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/concessions',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStudentConcession(String concessionId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/concessions/$concessionId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addStudentPenalty(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/penalties',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStudentPenalty(String penaltyId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/penalties/$penaltyId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStudentInvoice(String invoiceId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/invoices/$invoiceId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<StudentFeeStructureItem>> getStudentFeeStructures() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/fee-structures',
        useCache: false,
      );
      if (res['success'] == true && res['structures'] is List) {
        return (res['structures'] as List)
            .map((e) => StudentFeeStructureItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> createStudentFeeStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/fee-structures',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStudentFeeStructure(String id) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/fee-structures/$id',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStudentFeeStructure(String id, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/student-fees/fee-structures/$id',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> voidStudentInvoice(String invoiceId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/invoices/$invoiceId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStudentInvoiceStatus(String invoiceId, String status, {String? remarks}) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/invoices/$invoiceId/status',
        {'status': status, 'remarks': remarks},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> voidStudentPayment(String paymentId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/payments/$paymentId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStudentPaymentStatus(String paymentId, String status, {String? remarks}) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/student-fees/payments/$paymentId/status',
        {'status': status, if (remarks != null && remarks.isNotEmpty) 'remarks': remarks},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getStudentFeeHistory(String studentId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/students/$studentId/history',
        useCache: false,
      );
      if (res['success'] == true && res['history'] is List) {
        return List<Map<String, dynamic>>.from(res['history']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> getAllStudentInvoices({
    String search = '',
    String? status,
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final query = <String, dynamic>{
        'search': search,
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status != 'All Status' && status != 'All') {
        query['status'] = status;
      }
      final res = await _api.get(
        '/v1/payment-management/student-fees/invoices-list',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['invoices'] is List) {
        final items = (res['invoices'] as List)
            .map((e) => StudentFeeInvoiceItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'invoices': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'invoices': <StudentFeeInvoiceItem>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> getAllStudentPayments({
    String search = '',
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/payments-list',
        query: {'search': search, 'page': page, 'page_size': pageSize},
        useCache: false,
      );
      if (res['success'] == true && res['payments'] is List) {
        final items = (res['payments'] as List)
            .map((e) => StudentFeePaymentItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'payments': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'payments': <StudentFeePaymentItem>[], 'pagination': {}};
  }

  Future<bool> executeStudentFeeBulkAction(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/bulk-actions',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // STAFF SALARY API
  // =========================================================================

  Future<StaffSalaryKPIs> getStaffSalarySummary(String monthStr) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/summary',
        query: {'month_str': monthStr},
        useCache: false,
      );
      if (res['success'] == true && res['kpis'] != null) {
        return StaffSalaryKPIs.fromJson(Map<String, dynamic>.from(res['kpis']));
      }
    } catch (_) {}
    return StaffSalaryKPIs();
  }

  Future<Map<String, dynamic>> getStaffSalaryRoster({
    String monthStr = '2026-10',
    String search = '',
    String? department,
    String? role,
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'month_str': monthStr,
        'search': search,
        'page': page,
        'page_size': pageSize,
      };
      if (department != null && department != 'All Departments' && department != 'All') {
        query['department'] = department;
      }
      if (role != null && role != 'All Roles' && role != 'All') {
        query['role'] = role;
      }
      if (status != null && status != 'All Status' && status != 'All Staff' && status != 'All') {
        query['status'] = status;
      }

      final res = await _api.get(
        '/v1/payment-management/staff-salary/staff',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['staff'] is List) {
        final items = (res['staff'] as List)
            .map((e) => StaffSalaryRosterItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'staff': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'staff': <StaffSalaryRosterItem>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>?> getStaffSalaryDetail(String staffId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/staff/$staffId',
        useCache: false,
      );
      if (res['success'] == true && res['detail'] != null) {
        return Map<String, dynamic>.from(res['detail']);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> processStaffPayout(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/payouts',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> bulkProcessStaffPayroll(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/payouts/bulk',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStaffSalaryStructure(String staffId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/staff-salary/structures/$staffId',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<StaffSalaryStructureItem>> getStaffSalaryStructures() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/structures',
        useCache: false,
      );
      if (res['success'] == true && res['structures'] is List) {
        return (res['structures'] as List)
            .map((e) => StaffSalaryStructureItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> getStaffPayslips({
    String? monthStr,
    String search = '',
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'search': search,
      };
      if (monthStr != null && monthStr.isNotEmpty) {
        query['month_str'] = monthStr;
      }
      final res = await _api.get(
        '/v1/payment-management/staff-salary/payslips',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['payslips'] is List) {
        final items = (res['payslips'] as List)
            .map((e) => StaffPayslipItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'payslips': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'payslips': <StaffPayslipItem>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> getStaffSalaryAdvances({
    String search = '',
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/advances',
        query: {'search': search, 'page': page, 'page_size': pageSize},
        useCache: false,
      );
      if (res['success'] == true && res['advances'] is List) {
        final items = (res['advances'] as List)
            .map((e) => StaffSalaryAdvanceItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'advances': items,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (_) {}
    return {'advances': <StaffSalaryAdvanceItem>[], 'pagination': {}};
  }

  Future<bool> requestStaffSalaryAdvance(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/advances',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStaffAdvanceStatus(String advanceId, String status, {String? remarks}) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/advances/$advanceId/status',
        {'status': status, 'remarks': remarks},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStaffSalaryAdvance(String advanceId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/staff-salary/advances/$advanceId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStaffPayoutStatus(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/payouts/status',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteStaffPayout(String payoutId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/staff-salary/payouts/$payoutId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> executeStaffSalaryBulkAction(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/bulk-actions',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // DYNAMIC UNIQUE-PAISE UPI ORCHESTRATION & BRIDGE APIs
  // =========================================================================

  Future<Map<String, dynamic>?> createPaymentIntent({
    required String studentId,
    String? invoiceId,
    required double amount,
    String paymentMethod = 'UPI',
    String? notes,
  }) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/payment-intents',
        {
          'student_id': studentId,
          if (invoiceId != null && invoiceId.isNotEmpty) 'invoice_id': invoiceId,
          'amount': amount,
          'payment_method': paymentMethod,
          'notes': notes,
        },
      );
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getPaymentIntentStatus(String intentId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/payment-intents/$intentId/status',
        useCache: false,
      );
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> submitIntentUtr(String intentId, String utr) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/payment-intents/$intentId/submit-utr',
        {'utr_number': utr},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> simulateBridgePayment(String intentId, {String? utr}) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/simulate-bridge-payment',
        {'intent_id': intentId, if (utr != null) 'utr': utr},
      );
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // SYSTEM CONFIGURATION -> PAYMENT CONFIGURATION CENTRE APIs
  // =========================================================================

  Future<Map<String, dynamic>?> getInstitutionPaymentConfiguration() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/config',
        useCache: false,
      );
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updatePaymentGeneralSettings(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/general',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateQrBehaviourSettings(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/qr-behaviour',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createUpiAccount(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/upi-accounts',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setDefaultUpiAccount(String accountId) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/upi-accounts/$accountId/set-default',
        {},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivateUpiAccount(String accountId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/config/upi-accounts/$accountId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createBankAccount(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/bank-accounts',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setDefaultBankAccount(String accountId) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/bank-accounts/$accountId/set-default',
        {},
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deactivateBankAccount(String accountId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/config/bank-accounts/$accountId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> testBridgeConnection() async {
    try {
      final res = await _api.post(
        '/v1/payment-management/config/bridge/test-connection',
        {},
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'connected': false, 'message': 'Network error reaching payment bridge: $e'};
    }
  }
}
