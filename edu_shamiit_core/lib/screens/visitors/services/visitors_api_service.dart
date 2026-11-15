import 'dart:convert';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/visitor_models.dart';

class VisitorsApiService {
  final ApiService _api = ApiService();

  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
  }) async {
    final query = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    if (dateRangeLabel != null && dateRangeLabel.isNotEmpty) query['date_range_label'] = dateRangeLabel;
    if (location != null && location.isNotEmpty && location != 'All' && location != 'All Locations') {
      query['location'] = location;
    }
    if (category != null && category.isNotEmpty && category != 'All' && category != 'All Visitor Types') {
      query['category'] = category;
    }
    try {
      final res = await _api.get('/visitors/kpis', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return VisitorKPIs.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const VisitorKPIs();
  }

  Future<Map<String, dynamic>> getVisits({
    String search = '',
    String location = 'All Locations',
    String category = 'All Visitor Types',
    String status = 'All Status',
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'location': location,
      'category': category,
      'status': status,
      'page': page,
      'page_size': pageSize,
      if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
      if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
    };
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    try {
      final res = await _api.get('/visitors/visits', query: query, useCache: false);
      if (res['success'] == true) {
        final records = (res['data'] as List? ?? [])
            .map((item) => VisitorItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = VisitorPagination.fromJson(res['pagination'] as Map<String, dynamic>? ?? {});
        return {'records': records, 'pagination': pagination};
      }
    } catch (_) {}
    return {'records': <VisitorItem>[], 'pagination': const VisitorPagination()};
  }

  Future<VisitorDetail360?> getVisitDetails(String visitId) async {
    try {
      final res = await _api.get('/visitors/visits/$visitId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return VisitorDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> registerVisitor(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/register', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateVisit(String visitId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put('/visitors/visits/$visitId', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkInVisit(String visitId, {String entryLocation = 'Main Gate', String? remarks}) async {
    try {
      final res = await _api.post('/visitors/visits/$visitId/check-in', {
        'entry_location': entryLocation,
        'remarks': remarks,
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkOutVisit(String visitId, {String exitLocation = 'Main Gate', String? remarks}) async {
    try {
      final res = await _api.post('/visitors/visits/$visitId/check-out', {
        'exit_location': exitLocation,
        'remarks': remarks,
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> bulkCheckOutVisits(List<String> visitIds, {String exitLocation = 'Main Gate', String? remarks}) async {
    try {
      final res = await _api.post('/visitors/visits/bulk-check-out', {
        'visit_ids': visitIds,
        'exit_location': exitLocation,
        'remarks': remarks ?? 'Bulk check-out',
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> extendVisit(String visitId, {int extensionMinutes = 60, String? reason}) async {
    try {
      final res = await _api.post('/visitors/visits/$visitId/extend', {
        'extension_minutes': extensionMinutes,
        'reason': reason ?? 'Visit extended by host',
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelVisit(String visitId, {String? reason}) async {
    try {
      final res = await _api.post('/visitors/visits/$visitId/cancel', {
        'reason': reason ?? 'Cancelled by administration',
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAppointments({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'status': status,
      if (location != null && location.isNotEmpty) 'location': location,
      if (category != null && category.isNotEmpty) 'category': category,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      'page': page,
      'page_size': pageSize,
      if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
      if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
    };
    try {
      final res = await _api.get('/visitors/appointments', query: query, useCache: false);
      if (res['success'] == true) {
        final records = (res['data'] as List? ?? [])
            .map((item) => ScheduledAppointmentItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = VisitorPagination.fromJson(res['pagination'] as Map<String, dynamic>? ?? {});
        return {'records': records, 'pagination': pagination};
      }
    } catch (_) {}
    return {'records': <ScheduledAppointmentItem>[], 'pagination': const VisitorPagination()};
  }

  Future<Map<String, dynamic>> scheduleAppointment(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/appointments', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> approveAppointment(String appointmentId, {String? reason}) async {
    try {
      final res = await _api.post('/visitors/appointments/$appointmentId/approve', {'reason': reason});
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectAppointment(String appointmentId, {String? reason}) async {
    try {
      final res = await _api.post('/visitors/appointments/$appointmentId/reject', {'reason': reason});
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getRestrictions({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? reason,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'status': status,
      if (location != null && location.isNotEmpty) 'location': location,
      if (category != null && category.isNotEmpty) 'category': category,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      'page': page,
      'page_size': pageSize,
      if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
      if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
    };
    try {
      final res = await _api.get('/visitors/restrictions', query: query, useCache: false);
      if (res['success'] == true) {
        final records = (res['data'] as List? ?? [])
            .map((item) => BlacklistedVisitorItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = VisitorPagination.fromJson(res['pagination'] as Map<String, dynamic>? ?? {});
        return {'records': records, 'pagination': pagination};
      }
    } catch (_) {}
    return {'records': <BlacklistedVisitorItem>[], 'pagination': const VisitorPagination()};
  }

  Future<Map<String, dynamic>> createRestriction(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/restrictions', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo}) async {
    final query = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    try {
      final res = await _api.get('/visitors/appointments/kpis', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return ScheduledKPIs.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const ScheduledKPIs();
  }

  Future<AppointmentDetail360?> getAppointmentDetails(String appointmentId) async {
    try {
      final res = await _api.get('/visitors/appointments/$appointmentId/details', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AppointmentDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> rescheduleAppointment(String appointmentId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/appointments/$appointmentId/reschedule', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelAppointment(String appointmentId, {String? reason}) async {
    try {
      final res = await _api.post('/visitors/appointments/$appointmentId/cancel', {'reason': reason});
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo}) async {
    final query = <String, dynamic>{
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    };
    try {
      final res = await _api.get('/visitors/restrictions/kpis', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return BlacklistKPIs.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const BlacklistKPIs();
  }

  Future<RestrictionDetail360?> getRestrictionDetails(String restrictionId) async {
    try {
      final res = await _api.get('/visitors/restrictions/$restrictionId/details', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return RestrictionDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> updateRestriction(String restrictionId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.patch('/visitors/restrictions/$restrictionId', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkRestrictionEligibility({String? visitorId, String? phone, String location = 'Main Gate'}) async {
    try {
      final res = await _api.post('/visitors/restrictions/check-eligibility', {
        'visitor_id': visitorId,
        'phone': phone,
        'location': location,
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> liftRestriction(String restrictionId, {required String reason}) async {
    try {
      final res = await _api.post('/visitors/restrictions/$restrictionId/lift', {'reason': reason});
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unblockVisitor(String visitorId, {String? reason, String? liftedByName}) async {
    try {
      final res = await _api.post('/visitors/$visitorId/unblock', {
        'reason': reason ?? 'Administrative review completed; access restored',
        'lifted_by_name': liftedByName ?? 'Director / Principal',
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<VisitorAnalyticsData> getAnalytics() async {
    try {
      final res = await _api.get('/visitors/analytics', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return VisitorAnalyticsData.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const VisitorAnalyticsData();
  }

  Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final res = await _api.get('/visitors/locations', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> searchExisting(String query) async {
    try {
      final res = await _api.get('/visitors/search-existing', query: {'query': query}, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<int>> exportVisitsCSV() async {
    try {
      final csvString = await _api.getString('/visitors/reports/export');
      return utf8.encode(csvString);
    } catch (_) {
      return <int>[];
    }
  }

  Future<String> exportVisitsCSVText({
    String? search,
    String? location,
    String? category,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (location != null && location != 'All' && location != 'All Locations') queryParams['location'] = location;
      if (category != null && category != 'All' && category != 'All Visitor Types') queryParams['category'] = category;
      if (status != null && status != 'All' && status != 'All Status') queryParams['status'] = status;
      if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      return await _api.getString('/visitors/reports/export$queryString');
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> getProfiles({
    String search = '',
    String visitorType = 'All',
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'visitor_type': visitorType,
      'page': page,
      'page_size': pageSize,
    };
    try {
      final res = await _api.get('/visitors/profiles', query: query, useCache: false);
      if (res['success'] == true) {
        final records = (res['data'] as List? ?? [])
            .map((item) => VisitorProfileItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = VisitorPagination.fromJson(res['pagination'] as Map<String, dynamic>? ?? {});
        return {'records': records, 'pagination': pagination};
      }
    } catch (_) {}
    return {'records': <VisitorProfileItem>[], 'pagination': const VisitorPagination()};
  }

  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/profiles', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> generateBatchGatePasses(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/visitors/gate-passes/generate-batch', payload);
      if (res['success'] == true && res['data'] is List) {
        final passes = (res['data'] as List)
            .map((e) => GeneratedGatePassItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'passes': passes, 'message': res['message']};
      }
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString(), 'passes': <GeneratedGatePassItem>[]};
    }
  }

  Future<GatePassScanResult> scanGatePassImage(String base64Image) async {
    try {
      final res = await _api.post('/visitors/gate-passes/scan-image', {
        'image_base64': base64Image,
      });
      return GatePassScanResult.fromJson(res);
    } catch (e) {
      return GatePassScanResult(
        success: false,
        isValid: false,
        message: 'Failed to scan image: $e',
      );
    }
  }

  Future<GatePassScanResult> verifyGatePass(String tokenOrPassNumber) async {
    try {
      final res = await _api.post('/visitors/gate-passes/verify', {
        'token_or_ref': tokenOrPassNumber,
      });
      return GatePassScanResult.fromJson(res);
    } catch (e) {
      return GatePassScanResult(
        success: false,
        isValid: false,
        message: 'Failed to verify pass: $e',
      );
    }
  }

  Future<Map<String, dynamic>> executeScanAction(
    String passNumber, {
    required String action,
    String location = 'Main Gate',
    String? remarks,
  }) async {
    try {
      final res = await _api.post('/visitors/gate-passes/$passNumber/scan-action', {
        'action': action,
        'location': location,
        'remarks': remarks,
      });
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadDocument({
    String? visitorId,
    String? appointmentId,
    String? restrictionId,
    String? visitId,
    required String documentName,
    required String documentType,
    required String fileUrl,
    int? fileSizeBytes,
    String? verificationStatus,
  }) async {
    try {
      final payload = {
        if (visitorId != null && visitorId.isNotEmpty) 'visitor_id': visitorId,
        if (appointmentId != null && appointmentId.isNotEmpty) 'appointment_id': appointmentId,
        if (restrictionId != null && restrictionId.isNotEmpty) 'restriction_id': restrictionId,
        if (visitId != null && visitId.isNotEmpty) 'visit_id': visitId,
        'document_name': documentName,
        'document_type': documentType,
        'file_url': fileUrl,
        'file_size_bytes': fileSizeBytes ?? 0,
        'verification_status': verificationStatus ?? 'VERIFIED',
      };
      final res = await _api.post('/visitors/documents', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteDocument(String documentId) async {
    try {
      final res = await _api.delete('/visitors/documents/$documentId');
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<Map<String, dynamic>> checkInAppointment(
    String appointmentId, {
    String entryLocation = 'Main Gate',
    String? remarks,
  }) async {
    try {
      final payload = {
        'entry_location': entryLocation,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      };
      final res = await _api.post('/visitors/appointments/$appointmentId/check-in', payload);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  Future<List<HostSearchResultItem>> searchHosts(String query) async {
    try {
      final res = await _api.get('/visitors/hosts/search', query: {'query': query}, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((j) => HostSearchResultItem.fromJson(j))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<InstantRestrictionResult> checkInstantRestriction({String? phone, String? idNumber}) async {
    try {
      final params = <String, dynamic>{};
      if (phone != null && phone.isNotEmpty) params['phone'] = phone;
      if (idNumber != null && idNumber.isNotEmpty) params['id_number'] = idNumber;
      final res = await _api.get('/visitors/restrictions/check-instant', query: params, useCache: false);
      return InstantRestrictionResult.fromJson(res);
    } catch (e) {
      return const InstantRestrictionResult(isRestricted: false);
    }
  }

  Future<Map<String, dynamic>> getExecutiveSummaryReport({String? dateFrom, String? dateTo}) async {
    try {
      final params = <String, dynamic>{};
      if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
      if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
      final res = await _api.get('/visitors/reports/executive-summary', query: params, useCache: false);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }
}


