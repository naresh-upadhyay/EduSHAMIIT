import 'package:flutter/foundation.dart';
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
        useCache: true,
      );
      if (res['success'] == true) {
        return {
          'classes': (res['classes'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'academic_years': (res['academic_years'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'fee_types': (res['fee_types'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'payment_modes': (res['payment_modes'] as List?)?.map((e) => e.toString()).toList() ?? [],
          'classes_with_sections': (res['classes_with_sections'] is List)
              ? (res['classes_with_sections'] as List).cast<dynamic>()
              : <dynamic>[],
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
        useCache: true,
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

  Future<StudentFeeKPIs> getStudentFeeSummary(String academicYear, {String? className}) async {
    try {
      final query = <String, dynamic>{'academic_year': academicYear};
      if (className != null && className != 'All Classes' && className.isNotEmpty) {
        query['class_name'] = className;
      }
      final res = await _api.get(
        '/v1/payment-management/student-fees/summary',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['kpis'] != null) {
        return StudentFeeKPIs.fromJson(Map<String, dynamic>.from(res['kpis']));
      }
    } catch (e) {
      // ignore or log
    }
    return StudentFeeKPIs();
  }

  Future<Map<String, dynamic>> getStudentFeeRoster({
    String academicYear = '2026 - 2027',
    String search = '',
    String? className,
    String? status,
    String? sortBy,
    String? sortOrder,
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
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
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
        final pagination = res['pagination'] is Map
            ? Map<String, dynamic>.from(res['pagination'] as Map)
            : <String, dynamic>{
                'total_items': res['total_items'] ?? items.length,
                'total_pages': res['total_pages'] ?? 1,
                'page': res['page'] ?? page,
                'page_size': res['page_size'] ?? pageSize,
              };
        return {
          'students': items,
          'pagination': pagination,
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

  Future<Map<String, dynamic>> refundStudentFee(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/refunds',
        payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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

  Future<List<StudentFeeStructureItem>> getStudentFeeStructures({
    String? classGrade,
    String? sectionName,
    String? frequencyType,
    String? search,
  }) async {
    final result = await getStudentFeeStructuresWithSummary(
      classGrade: classGrade,
      sectionName: sectionName,
      frequencyType: frequencyType,
      search: search,
    );
    return result['structures'] as List<StudentFeeStructureItem>? ?? [];
  }

  Future<Map<String, dynamic>> getStudentFeeStructuresWithSummary({
    String? classGrade,
    String? sectionName,
    String? frequencyType,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (classGrade != null && classGrade.isNotEmpty && classGrade != 'All Classes') queryParams['class_grade'] = classGrade;
      if (sectionName != null && sectionName.isNotEmpty && sectionName != 'All Sections') queryParams['section_name'] = sectionName;
      if (frequencyType != null && frequencyType.isNotEmpty && frequencyType != 'All Frequencies') queryParams['frequency_type'] = frequencyType;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final queryStr = queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : '';
      final res = await _api.get(
        '/v1/payment-management/student-fees/fee-structures$queryStr',
        useCache: false,
      );
      if (res['success'] == true && res['structures'] is List) {
        final list = (res['structures'] as List)
            .map((e) => StudentFeeStructureItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final summary = res['summary'] is Map
            ? FeeStructureCohortSummary.fromJson(Map<String, dynamic>.from(res['summary'] as Map))
            : FeeStructureCohortSummary();
        return {
          'structures': list,
          'summary': summary,
        };
      }
    } catch (_) {}
    return {
      'structures': <StudentFeeStructureItem>[],
      'summary': FeeStructureCohortSummary(),
    };
  }

  Future<bool> cloneStudentFeeStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/fee-structures/clone',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStudentApplicableFeeStructure(String studentId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/students/$studentId/applicable-fee-structure',
        useCache: false,
      );
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res as Map);
      }
    } catch (_) {}
    return null;
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

  Future<Map<String, dynamic>> settleInvoiceFromAdvance(String invoiceId) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/invoices/$invoiceId/settle-from-advance',
        {},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> settleStudentInvoicesFromAdvance(String studentId) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/students/$studentId/settle-advance',
        {},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
    String? sortBy,
    String? sortOrder,
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
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
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
        final pagination = res['pagination'] is Map
            ? Map<String, dynamic>.from(res['pagination'] as Map)
            : <String, dynamic>{
                'total_items': res['total_items'] ?? items.length,
                'total_pages': res['total_pages'] ?? 1,
                'page': res['page'] ?? page,
                'page_size': res['page_size'] ?? pageSize,
              };
        return {
          'staff': items,
          'pagination': pagination,
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

  Future<List<Map<String, dynamic>>> searchAllStaffForPayroll({
    String search = '',
    String monthStr = '2026-10',
  }) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/search-all',
        query: {
          'search': search,
          'month_str': monthStr,
        },
        useCache: false,
      );
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('[PaymentManagementApi] searchAllStaffForPayroll error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUnconfiguredStaffForSalary({String search = ''}) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/staff-salary/unconfigured-staff',
        query: {'search': search},
        useCache: false,
      );
      if (res['success'] == true && res['staff'] is List) {
        return (res['staff'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[PaymentManagementApi] getUnconfiguredStaffForSalary error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> triggerAutoPayrollRun({
    required String monthStr,
    String paymentMode = 'Direct Bank Transfer (NEFT/RTGS)',
    bool sendEmail = true,
  }) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/auto-payroll-run',
        {
          'month_str': monthStr,
          'payment_mode': paymentMode,
          'send_email_notifications': sendEmail,
        },
      );
      return res;
    } catch (e) {
      debugPrint('[PaymentManagementApi] triggerAutoPayrollRun error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> processStaffPayout(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/payouts',
        payload,
      );
      if (res['success'] == true) {
        return {
          'success': true,
          'message': res['message'] ?? 'Salary payout processed successfully',
          'payout': res,
        };
      }
      return {
        'success': false,
        'message': res['detail'] ?? res['message'] ?? 'Failed to process salary payout',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
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

  Future<Map<String, dynamic>> getSalaryStructuresCatalog({
    String? department,
    String search = '',
    String sortBy = 'name',
    String sortOrder = 'ASC',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'search': search,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (department != null && department.isNotEmpty && department != 'All Departments') {
        query['department'] = department;
      }
      final res = await _api.get(
        '/v1/payment-management/staff-salary/structures',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['structures'] is List) {
        final items = (res['structures'] as List)
            .map((e) => StaffSalaryStructureItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'structures': items,
          'total_items': (res['total_items'] as num?)?.toInt() ?? items.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'page': (res['page'] as num?)?.toInt() ?? page,
          'page_size': (res['page_size'] as num?)?.toInt() ?? pageSize,
        };
      }
    } catch (_) {}
    return {
      'structures': <StaffSalaryStructureItem>[],
      'total_items': 0,
      'total_pages': 1,
      'page': page,
      'page_size': pageSize,
    };
  }

  Future<bool> createSalaryStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/structures',
        payload,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getStaffPayslips({
    String? monthStr,
    String? department,
    String search = '',
    String sortBy = 'payslip_number',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'search': search,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (monthStr != null && monthStr.isNotEmpty) {
        query['month_str'] = monthStr;
      }
      if (department != null && department.isNotEmpty && department != 'All Departments') {
        query['department'] = department;
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
          'total_items': (res['total_items'] as num?)?.toInt() ?? items.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'page': (res['page'] as num?)?.toInt() ?? page,
          'page_size': (res['page_size'] as num?)?.toInt() ?? pageSize,
        };
      }
    } catch (_) {}
    return {
      'payslips': <StaffPayslipItem>[],
      'total_items': 0,
      'total_pages': 1,
      'page': page,
      'page_size': pageSize,
    };
  }

  Future<Map<String, dynamic>> getStaffSalaryAdvances({
    String? status,
    String search = '',
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'search': search,
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (status != null && status.isNotEmpty && status != 'All Status') {
        query['status'] = status;
      }
      final res = await _api.get(
        '/v1/payment-management/staff-salary/advances',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['advances'] is List) {
        final items = (res['advances'] as List)
            .map((e) => StaffSalaryAdvanceItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'advances': items,
          'total_items': (res['total_items'] as num?)?.toInt() ?? items.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'page': (res['page'] as num?)?.toInt() ?? page,
          'page_size': (res['page_size'] as num?)?.toInt() ?? pageSize,
        };
      }
    } catch (_) {}
    return {
      'advances': <StaffSalaryAdvanceItem>[],
      'total_items': 0,
      'total_pages': 1,
      'page': page,
      'page_size': pageSize,
    };
  }

  Future<bool> settleStaffSalaryAdvance(
    String advanceId, {
    required double settlementAmount,
    String paymentMode = 'Cash',
    String remarks = 'Early loan clearance',
  }) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/staff-salary/advances/$advanceId/settle',
        {
          'settlement_amount': settlementAmount,
          'payment_mode': paymentMode,
          'remarks': remarks,
        },
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
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

  Future<bool> updateUpiAccount(String accountId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/config/upi-accounts/$accountId',
        payload,
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

  Future<bool> updateBankAccount(String accountId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/config/bank-accounts/$accountId',
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

  Future<Map<String, dynamic>> testDeviceActive(String deviceId) async {
    try {
      final res = await _api.get(
        '/v1/payment-management/config/devices/${Uri.encodeComponent(deviceId)}/test-active',
        useCache: false,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {
        'success': false,
        'is_active': false,
        'status': 'NETWORK_ERROR',
        'message': 'Failed to query device active status: $e',
      };
    }
  }

  // ============================================================================
  // FEE INVOICE AUTOMATION RULES & ADVANCED BULK GENERATION
  // ============================================================================

  Future<List<Map<String, dynamic>>> getFeeScheduleRules() async {
    try {
      final res = await _api.get(
        '/v1/payment-management/student-fees/schedules',
        useCache: false,
      );
      if (res['success'] == true && res['rules'] is List) {
        return List<Map<String, dynamic>>.from(res['rules']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createFeeScheduleRule(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/schedules',
        payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': 'Failed to create schedule rule: $e'};
    }
  }

  Future<Map<String, dynamic>> updateFeeScheduleRule(String ruleId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put(
        '/v1/payment-management/student-fees/schedules/$ruleId',
        payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': 'Failed to update schedule rule: $e'};
    }
  }

  Future<Map<String, dynamic>> toggleFeeScheduleRule(String ruleId) async {
    try {
      final res = await _api.patch(
        '/v1/payment-management/student-fees/schedules/$ruleId/toggle',
        {},
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': 'Failed to toggle rule: $e'};
    }
  }

  Future<bool> deleteFeeScheduleRule(String ruleId) async {
    try {
      final res = await _api.delete(
        '/v1/payment-management/student-fees/schedules/$ruleId',
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> runFeeScheduleRuleNow(String ruleId) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/schedules/$ruleId/run',
        {},
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': 'Failed to trigger rule: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getFeeScheduleRuns({String? ruleId, int limit = 50}) async {
    try {
      String path = '/v1/payment-management/student-fees/schedules/runs?limit=$limit';
      if (ruleId != null && ruleId.isNotEmpty) {
        path += '&rule_id=$ruleId';
      }
      final res = await _api.get(path, useCache: false);
      if (res['success'] == true && res['runs'] is List) {
        return List<Map<String, dynamic>>.from(res['runs']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getTargetStudentsPreview({
    String targetType = 'CLASS',
    String targetClass = 'All Classes',
    String? targetSection,
    double? amount,
  }) async {
    try {
      var path = '/v1/payment-management/student-fees/target-students-preview?target_type=${Uri.encodeComponent(targetType)}&target_class=${Uri.encodeComponent(targetClass)}';
      if (targetSection != null && targetSection.isNotEmpty && targetSection != 'All Sections') {
        path += '&target_section=${Uri.encodeComponent(targetSection)}';
      }
      if (amount != null && amount > 0) {
        path += '&amount=$amount';
      }
      final res = await _api.get(path, useCache: false);
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'count': 0, 'students': []};
    }
  }

  Future<Map<String, dynamic>> enhancedBulkGenerateInvoices(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post(
        '/v1/payment-management/student-fees/invoices/bulk-generate',
        payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {'success': false, 'message': 'Failed to bulk generate: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> getCohortMatchingFeeStructures({
    required String classGrade,
    required String sectionName,
    String academicYear = '2026 - 2027',
  }) async {
    try {
      final encClass = Uri.encodeComponent(classGrade);
      final encSec = Uri.encodeComponent(sectionName);
      final encYear = Uri.encodeComponent(academicYear);
      final res = await _api.get(
        '/v1/payment-management/student-fees/fee-structures/cohort-matching?class_grade=$encClass&section_name=$encSec&academic_year=$encYear',
        useCache: false,
      );
      if (res['success'] == true && res['fee_structures'] != null) {
        final list = res['fee_structures'] as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
