import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/hostel_fee_models.dart';

class HostelFeeService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> getFeeSummary({String academicYear = '2026 - 2027'}) async {
    try {
      final res = await _api.get(
        '/hostel/fees/summary',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final kpis = HostelFeeKPIs.fromJson(data['kpis'] as Map<String, dynamic>? ?? {});
        final feeSummary = HostelFeeSummaryDonut.fromJson(data['fee_summary'] as Map<String, dynamic>? ?? {});
        final upcoming = (data['upcoming_invoices'] as List? ?? [])
            .map((u) => HostelUpcomingInvoiceItem.fromJson(u as Map<String, dynamic>))
            .toList();
        final recent = (data['recent_payments'] as List? ?? [])
            .map((r) => HostelRecentPaymentItem.fromJson(r as Map<String, dynamic>))
            .toList();
        return {
          'kpis': kpis,
          'fee_summary': feeSummary,
          'upcoming_invoices': upcoming,
          'recent_payments': recent,
        };
      }
    } catch (e) {
      // Fallback
    }
    return {
      'kpis': HostelFeeKPIs(),
      'fee_summary': HostelFeeSummaryDonut(),
      'upcoming_invoices': <HostelUpcomingInvoiceItem>[],
      'recent_payments': <HostelRecentPaymentItem>[],
    };
  }

  Future<Map<String, dynamic>> getStudentFees({
    String academicYear = '2026 - 2027',
    String search = '',
    String? hostelId,
    String? className,
    String? status,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String sortOrder = 'ASC',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_order': sortOrder,
      };
      if (search.trim().isNotEmpty) query['search'] = search.trim();
      if (hostelId != null && hostelId.trim().isNotEmpty && hostelId != 'All Hostels') {
        query['hostel_id'] = hostelId.trim();
      }
      if (className != null && className.trim().isNotEmpty && className != 'All Classes') {
        query['class_name'] = className.trim();
      }
      if (status != null && status.trim().isNotEmpty && status != 'All Status') {
        query['status'] = status.trim();
      }
      if (sortBy != null && sortBy.trim().isNotEmpty) {
        query['sort_by'] = sortBy.trim();
      }

      final res = await _api.get(
        '/hostel/fees/students',
        query: query,
        useCache: false,
      );
      if (res['success'] == true) {
        final list = (res['data'] as List? ?? [])
            .map((s) => HostelStudentFeeItem.fromJson(s as Map<String, dynamic>))
            .toList();
        final pagination = HostelFeeRosterPagination.fromJson(res['pagination'] as Map<String, dynamic>? ?? {});
        return {
          'students': list,
          'pagination': pagination,
        };
      }
    } catch (e) {
      // Fallback
    }
    return {
      'students': <HostelStudentFeeItem>[],
      'pagination': HostelFeeRosterPagination(),
    };
  }

  Future<HostelStudentFeeDetail360?> getStudentFee360(String studentId) async {
    try {
      final res = await _api.get('/hostel/fees/students/$studentId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return HostelStudentFeeDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getStudentFeeHeads(String studentId) async {
    try {
      final res = await _api.get('/hostel/fees/students/$studentId/heads', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return List<Map<String, dynamic>>.from(res['data'] as List);
      }
    } catch (e) {
      // Return empty
    }
    return [];
  }

  Future<bool> addStudentFeeHead(String studentId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/hostel/fees/students/$studentId/heads', data);
      return res['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStudentFeeHead(String studentId, String headId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/hostel/fees/students/$studentId/heads/$headId', data);
      return res['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteStudentFeeHead(String studentId, String headId) async {
    try {
      final res = await _api.delete('/hostel/fees/students/$studentId/heads/$headId');
      return res['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<List<HostelLedgerEntryModel>> getStudentLedger(String studentId) async {
    try {
      final res = await _api.get('/hostel/fees/students/$studentId/ledger', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((l) => HostelLedgerEntryModel.fromJson(l as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<List<HostelFeePlanModel>> getFeeStructures({String academicYear = '2026 - 2027'}) async {
    final res = await getFeeStructuresPaged(academicYear: academicYear, pageSize: 100);
    return res['plans'] as List<HostelFeePlanModel>;
  }

  Future<Map<String, dynamic>> getFeeStructuresPaged({
    String academicYear = '2026 - 2027',
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String sortOrder = 'ASC',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_order': sortOrder,
      };
      if (sortBy != null && sortBy.trim().isNotEmpty) {
        query['sort_by'] = sortBy.trim();
      }
      final res = await _api.get(
        '/hostel/fees/structures',
        query: query,
        useCache: false,
      );
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((p) => HostelFeePlanModel.fromJson(p as Map<String, dynamic>))
            .toList();
        return {
          'plans': list,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (e) {
      // Fallback
    }
    return {'plans': <HostelFeePlanModel>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> createFeeStructure(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/structures', payload);
  }

  Future<Map<String, dynamic>> assignFeePlan(String studentId, String feePlanId, {String academicYear = '2026 - 2027'}) async {
    return await _api.post('/hostel/fees/assign', {
      'student_id': studentId,
      'fee_plan_id': feePlanId,
      'academic_year': academicYear,
    });
  }

  Future<Map<String, dynamic>> getInvoices({
    String? studentId,
    String? status,
    String academicYear = '2026 - 2027',
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String sortOrder = 'DESC',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_order': sortOrder,
      };
      if (studentId != null) query['student_id'] = studentId;
      if (status != null && status != 'ALL') query['status'] = status;
      if (sortBy != null && sortBy.trim().isNotEmpty) query['sort_by'] = sortBy.trim();

      final res = await _api.get('/hostel/fees/invoices', query: query, useCache: false);
      if (res['success'] == true) {
        final list = (res['data'] as List? ?? [])
            .map((i) => HostelInvoiceItemModel.fromJson(i as Map<String, dynamic>))
            .toList();
        return {
          'invoices': list,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (e) {
      // Fallback
    }
    return {'invoices': <HostelInvoiceItemModel>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> generateInvoice(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/invoices', payload);
  }

  Future<Map<String, dynamic>> generateBulkInvoices(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/invoices/bulk', payload);
  }

  Future<Map<String, dynamic>> cancelInvoice(String invoiceId, {String? reason}) async {
    return await _api.post('/hostel/fees/invoices/$invoiceId/cancel', {
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> getPayments({
    String? studentId,
    String? invoiceId,
    String? academicYear,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String sortOrder = 'DESC',
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort_order': sortOrder,
      };
      if (studentId != null) query['student_id'] = studentId;
      if (invoiceId != null) query['invoice_id'] = invoiceId;
      if (academicYear != null) query['academic_year'] = academicYear;
      if (sortBy != null && sortBy.trim().isNotEmpty) query['sort_by'] = sortBy.trim();

      final res = await _api.get('/hostel/fees/payments', query: query, useCache: false);
      if (res['success'] == true) {
        final list = (res['data'] as List? ?? [])
            .map((p) => HostelPaymentReceiptModel.fromJson(p as Map<String, dynamic>))
            .toList();
        return {
          'payments': list,
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (e) {
      // Fallback
    }
    return {'payments': <HostelPaymentReceiptModel>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> collectPayment(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/payments', payload);
  }

  Future<Map<String, dynamic>> reversePayment(String paymentId, String reason) async {
    return await _api.post('/hostel/fees/payments/$paymentId/reverse', {'reason': reason});
  }

  Future<Map<String, dynamic>> applyConcession(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/concessions', payload);
  }

  Future<Map<String, dynamic>> addPenalty(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/penalties', payload);
  }

  Future<List<Map<String, dynamic>>> getRefunds({String? studentId, String? status}) async {
    final res = await getRefundsPaged(studentId: studentId, status: status, pageSize: 100);
    return res['refunds'] as List<Map<String, dynamic>>;
  }

  Future<Map<String, dynamic>> getRefundsPaged({
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String sortOrder = 'DESC',
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort_order': sortOrder,
      };
      if (studentId != null) query['student_id'] = studentId;
      if (status != null && status != 'ALL') query['status'] = status;
      if (sortBy != null && sortBy.trim().isNotEmpty) query['sort_by'] = sortBy.trim();

      final res = await _api.get('/hostel/fees/refunds', query: query, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return {
          'refunds': (res['data'] as List).cast<Map<String, dynamic>>(),
          'pagination': res['pagination'] ?? {},
        };
      }
    } catch (e) {
      // Fallback
    }
    return {'refunds': <Map<String, dynamic>>[], 'pagination': {}};
  }

  Future<Map<String, dynamic>> requestRefund(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/refunds', payload);
  }

  Future<Map<String, dynamic>> approveRefund(String refundId, Map<String, dynamic> payload) async {
    return await _api.patch('/hostel/fees/refunds/$refundId/approve', payload);
  }

  Future<Map<String, dynamic>> getReport(String reportType, {String academicYear = '2026 - 2027'}) async {
    try {
      final res = await _api.get(
        '/hostel/fees/reports/$reportType',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true) {
        return res;
      }
    } catch (e) {
      // Fallback
    }
    return {'success': false, 'data': []};
  }

  Future<Map<String, dynamic>> sendReminders(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/fees/reminders', payload);
  }

  Future<List<int>?> exportFeesCsv({
    String? academicYear,
    String? hostelId,
    String? className,
    String? status,
    String? search,
    List<String>? studentIds,
    List<String>? accountIds,
  }) async {
    final queryParams = <String, String>{};
    if (academicYear != null && academicYear.isNotEmpty) queryParams['academic_year'] = academicYear;
    if (hostelId != null && hostelId.isNotEmpty && hostelId != 'All Hostels') queryParams['hostel_id'] = hostelId;
    if (className != null && className.isNotEmpty && className != 'All Classes') queryParams['class_name'] = className;
    if (status != null && status.isNotEmpty && status != 'All Status') queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (studentIds != null && studentIds.isNotEmpty) queryParams['student_ids'] = studentIds.join(',');
    if (accountIds != null && accountIds.isNotEmpty) queryParams['account_ids'] = accountIds.join(',');

    final uri = Uri(path: '/hostel/fees/export', queryParameters: queryParams.isEmpty ? null : queryParams);
    return await _api.getRawBytes(uri.toString());
  }
}
