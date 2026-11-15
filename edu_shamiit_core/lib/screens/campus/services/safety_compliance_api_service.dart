import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/safety_compliance_models.dart';

class SafetyComplianceApiService {
  static final SafetyComplianceApiService instance = SafetyComplianceApiService._internal();
  SafetyComplianceApiService._internal();

  final ApiService _api = ApiService();

  /// 1. Fetch Safety Dashboard KPIs
  Future<SafetyComplianceKpis> getKpis() async {
    try {
      final res = await _api.get('/v1/safety-compliance/kpis', useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return SafetyComplianceKpis.fromJson(res['data']);
      } else if (res['data'] is Map) {
        return SafetyComplianceKpis.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (_) {}
    return const SafetyComplianceKpis();
  }

  /// 2. Fetch Paged Inspections
  Future<SafetyListResponse<SafetyInspectionItem>> getInspections({
    String? category,
    String? status,
    String? buildingId,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (category != null && category.isNotEmpty && category != 'All') query['category'] = category;
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') query['building_id'] = buildingId;
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

      final res = await _api.get('/v1/safety-compliance/inspections', query: query, useCache: false);
      final rawList = res['records'] as List? ?? [];
      final records = rawList.map((e) => SafetyInspectionItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return SafetyListResponse<SafetyInspectionItem>(
        totalCount: (res['total_count'] as num?)?.toInt() ?? records.length,
        records: records,
        page: page,
        pageSize: pageSize,
        totalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {}
    return const SafetyListResponse<SafetyInspectionItem>();
  }

  /// 3. Upsert Inspection
  Future<Map<String, dynamic>> saveInspection(Map<String, dynamic> payload, {String? inspectionId}) async {
    if (inspectionId != null && inspectionId.isNotEmpty) {
      return await _api.put('/v1/safety-compliance/inspections/$inspectionId', payload);
    } else {
      return await _api.post('/v1/safety-compliance/inspections', payload);
    }
  }

  /// 4. Delete Inspection
  Future<Map<String, dynamic>> deleteInspection(String inspectionId) async {
    return await _api.delete('/v1/safety-compliance/inspections/$inspectionId');
  }

  /// 5. Fetch Paged Incidents
  Future<SafetyListResponse<SafetyIncidentItem>> getIncidents({
    String? severity,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (severity != null && severity.isNotEmpty && severity != 'All') query['severity'] = severity;
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

      final res = await _api.get('/v1/safety-compliance/incidents', query: query, useCache: false);
      final rawList = res['records'] as List? ?? [];
      final records = rawList.map((e) => SafetyIncidentItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return SafetyListResponse<SafetyIncidentItem>(
        totalCount: (res['total_count'] as num?)?.toInt() ?? records.length,
        records: records,
        page: page,
        pageSize: pageSize,
        totalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {}
    return const SafetyListResponse<SafetyIncidentItem>();
  }

  /// 6. Upsert Incident
  Future<Map<String, dynamic>> saveIncident(Map<String, dynamic> payload, {String? incidentId}) async {
    if (incidentId != null && incidentId.isNotEmpty) {
      return await _api.put('/v1/safety-compliance/incidents/$incidentId', payload);
    } else {
      return await _api.post('/v1/safety-compliance/incidents', payload);
    }
  }

  /// 7. Delete Incident
  Future<Map<String, dynamic>> deleteIncident(String incidentId) async {
    return await _api.delete('/v1/safety-compliance/incidents/$incidentId');
  }

  /// 8. Fetch Paged Compliance Certificates
  Future<SafetyListResponse<ComplianceCertificateItem>> getCertificates({
    String? category,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (category != null && category.isNotEmpty && category != 'All') query['category'] = category;
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

      final res = await _api.get('/v1/safety-compliance/certificates', query: query, useCache: false);
      final rawList = res['records'] as List? ?? [];
      final records = rawList.map((e) => ComplianceCertificateItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return SafetyListResponse<ComplianceCertificateItem>(
        totalCount: (res['total_count'] as num?)?.toInt() ?? records.length,
        records: records,
        page: page,
        pageSize: pageSize,
        totalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {}
    return const SafetyListResponse<ComplianceCertificateItem>();
  }

  /// 9. Upsert Certificate
  Future<Map<String, dynamic>> saveCertificate(Map<String, dynamic> payload, {String? certificateId}) async {
    if (certificateId != null && certificateId.isNotEmpty) {
      return await _api.put('/v1/safety-compliance/certificates/$certificateId', payload);
    } else {
      return await _api.post('/v1/safety-compliance/certificates', payload);
    }
  }

  /// 10. Delete Certificate
  Future<Map<String, dynamic>> deleteCertificate(String certificateId) async {
    return await _api.delete('/v1/safety-compliance/certificates/$certificateId');
  }

  /// 11. Fetch Paged Safety Drills
  Future<SafetyListResponse<SafetyDrillItem>> getDrills({
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;

      final res = await _api.get('/v1/safety-compliance/drills', query: query, useCache: false);
      final rawList = res['records'] as List? ?? [];
      final records = rawList.map((e) => SafetyDrillItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      return SafetyListResponse<SafetyDrillItem>(
        totalCount: (res['total_count'] as num?)?.toInt() ?? records.length,
        records: records,
        page: page,
        pageSize: pageSize,
        totalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
      );
    } catch (_) {}
    return const SafetyListResponse<SafetyDrillItem>();
  }

  /// 12. Upsert Drill
  Future<Map<String, dynamic>> saveDrill(Map<String, dynamic> payload, {String? drillId}) async {
    if (drillId != null && drillId.isNotEmpty) {
      return await _api.put('/v1/safety-compliance/drills/$drillId', payload);
    } else {
      return await _api.post('/v1/safety-compliance/drills', payload);
    }
  }

  /// 13. Delete Drill
  Future<Map<String, dynamic>> deleteDrill(String drillId) async {
    return await _api.delete('/v1/safety-compliance/drills/$drillId');
  }

  /// 14. Export CSV
  Future<void> exportCsv(String type) async {
    final url = '${AppConfig.apiBaseUrl}/v1/safety-compliance/export?export_type=$type';
    getDownloadHelper().downloadFile(url, 'campus_safety_${type}_${DateTime.now().millisecondsSinceEpoch}.csv');
  }
}
