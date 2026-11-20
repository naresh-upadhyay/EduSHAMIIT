import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/maintenance_models.dart';

class MaintenanceApiService {
  static final MaintenanceApiService instance = MaintenanceApiService._internal();
  MaintenanceApiService._internal();

  final ApiService _api = ApiService();

  /// 1. Fetch Maintenance Dashboard KPIs
  Future<MaintenanceKpis> getKpis() async {
    try {
      final res = await _api.get('/v1/maintenance/kpis', useCache: false);
      if (res['data'] is Map) {
        return MaintenanceKpis.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      } else if (res.containsKey('total_requests')) {
        return MaintenanceKpis.fromJson(res);
      }
    } catch (_) {}
    return const MaintenanceKpis();
  }

  /// 2. Fetch Paged & Filtered Maintenance Requests
  Future<MaintenanceListResponse> getRequests({
    String view = 'all',
    String? buildingId,
    String? location,
    String? type,
    String? status,
    String? priority,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'view': view,
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
        query['building_id'] = buildingId;
      }
      if (location != null && location.isNotEmpty && location != 'All') {
        query['location'] = location;
      }
      if (type != null && type.isNotEmpty && type != 'All') {
        query['type'] = type;
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        query['status'] = status;
      }
      if (priority != null && priority.isNotEmpty && priority != 'All') {
        query['priority'] = priority;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (startDate != null) {
        query['start_date'] = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      }
      if (endDate != null) {
        query['end_date'] = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      }

      final res = await _api.get('/v1/maintenance/requests', query: query, useCache: false);
      return MaintenanceListResponse.fromJson(res);
    } catch (_) {}
    return const MaintenanceListResponse();
  }

  /// 3. Fetch Operational Analytics (Trends, Donut Breakdown, SLA)
  Future<MaintenanceAnalyticsData> getAnalytics() async {
    try {
      final res = await _api.get('/v1/maintenance/analytics', useCache: false);
      return MaintenanceAnalyticsData.fromJson(res);
    } catch (_) {}
    return const MaintenanceAnalyticsData();
  }

  /// 4. Create Maintenance Request
  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/maintenance/requests', payload);
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 5. Update Status
  Future<Map<String, dynamic>> updateStatus(String requestId, String newStatus, {String? remarks, String? resolutionNotes, double? actualCost}) async {
    try {
      final body = <String, dynamic>{
        'new_status': newStatus,
        if (remarks != null) 'remarks': remarks,
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
        if (actualCost != null) 'actual_cost': actualCost,
      };
      final res = await _api.post('/v1/maintenance/requests/$requestId/status', body);
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 6. Assign Technician or Vendor
  Future<Map<String, dynamic>> assignTechnician(String requestId, {
    required String assignedToName,
    String? assignedToUserId,
    String? vendorId,
    String? vendorName,
    DateTime? scheduledAt,
    String? instructions,
  }) async {
    try {
      final body = <String, dynamic>{
        'assigned_to_name': assignedToName,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (vendorId != null) 'vendor_id': vendorId,
        if (vendorName != null) 'vendor_name': vendorName,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        if (instructions != null) 'instructions': instructions,
      };
      final res = await _api.post('/v1/maintenance/requests/$requestId/assign', body);
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 7. Fetch Single Request Detail
  Future<MaintenanceRequestItem?> getRequestDetail(String requestId) async {
    try {
      final res = await _api.get('/v1/maintenance/requests/$requestId', useCache: false);
      return MaintenanceRequestItem.fromJson(res);
    } catch (_) {}
    return null;
  }

  /// 8. Fetch Preventive Plans
  Future<List<MaintenancePlanItem>> getPlans() async {
    try {
      final res = await _api.get('/v1/maintenance/plans', useCache: false);
      final raw = res['data'] is List ? res['data'] as List : (res['plans'] is List ? res['plans'] as List : []);
      return raw.map((e) => MaintenancePlanItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {}
    return [];
  }

  /// 9. Create Preventive Plan
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/maintenance/plans', payload);
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 10. Fetch Service Vendors & AMCs
  Future<List<MaintenanceVendorItem>> getVendors() async {
    try {
      final res = await _api.get('/v1/maintenance/vendors', useCache: false);
      final raw = res['data'] is List ? res['data'] as List : (res['vendors'] is List ? res['vendors'] as List : []);
      return raw.map((e) => MaintenanceVendorItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {}
    return [];
  }

  /// 11. Export CSV
  Future<void> exportCsv() async {
    final url = '${AppConfig.apiBaseUrl}/v1/maintenance/export';
    getDownloadHelper().downloadFile(url, 'campus_maintenance_requests.csv');
  }
}
