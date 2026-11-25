import 'package:flutter/foundation.dart';
import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/campus_models.dart';

class CampusApiService {
  static final CampusApiService instance = CampusApiService._internal();
  CampusApiService._internal();

  final ApiService _api = ApiService();

  // 1. Dashboard KPIs
  Future<CampusKpis> getKpis({String? campusId}) async {
    try {
      final query = <String, dynamic>{};
      if (campusId != null && campusId.isNotEmpty) {
        query['campus_id'] = campusId;
      }
      final res = await _api.get('/v1/campus/kpis', query: query, useCache: false);
      return CampusKpis.fromJson(res);
    } catch (_) {}
    return const CampusKpis();
  }

  // 2. Metadata Lookups
  Future<Map<String, dynamic>> getLookups() async {
    try {
      final res = await _api.get('/v1/campus/lookups', useCache: false);
      return res;
    } catch (_) {}
    return {};
  }

  // 3. Buildings Listing
  Future<Map<String, dynamic>> getBuildings({
    int page = 1,
    int pageSize = 10,
    String? search,
    String? buildingType,
    String? status,
    String? campusId,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (buildingType != null && buildingType.isNotEmpty && buildingType != 'All') {
        query['building_type'] = buildingType;
      }
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status;
      if (campusId != null && campusId.isNotEmpty) query['campus_id'] = campusId;

      final res = await _api.get('/v1/campus/buildings', query: query, useCache: false);
      if (res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => BuildingModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'total_count': res['total_count'] ?? list.length,
          'page': res['page'] ?? page,
          'page_size': res['page_size'] ?? pageSize,
          'data': list,
        };
      }
    } catch (_) {}
    return {'total_count': 0, 'page': page, 'page_size': pageSize, 'data': <BuildingModel>[]};
  }

  // 4. Building Details with Floors breakdown
  Future<Map<String, dynamic>?> getBuildingDetails(String buildingId) async {
    try {
      final res = await _api.get('/v1/campus/buildings/$buildingId', useCache: false);
      if (res['success'] == true) {
        return res;
      }
    } catch (_) {}
    return null;
  }

  // 5. Create or Update Building
  Future<Map<String, dynamic>> saveBuilding(Map<String, dynamic> payload, {String? buildingId}) async {
    try {
      if (buildingId != null && buildingId.isNotEmpty) {
        return await _api.put('/v1/campus/buildings/$buildingId', payload);
      } else {
        return await _api.post('/v1/campus/buildings', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBuildingPhoto(String buildingId, String imageUrl) async {
    try {
      return await _api.patch('/v1/campus/buildings/$buildingId/photo', {'image_url': imageUrl});
    } catch (_) {
      try {
        return await _api.put('/v1/campus/buildings/$buildingId', {'image_url': imageUrl});
      } catch (e) {
        return {'success': false, 'message': e.toString()};
      }
    }
  }

  // 6. Delete or Archive Building
  Future<Map<String, dynamic>> deleteBuilding(String buildingId) async {
    try {
      return await _api.delete('/v1/campus/buildings/$buildingId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> archiveBuilding(String buildingId) async {
    try {
      return await _api.post('/v1/campus/buildings/$buildingId/archive', {});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 7. Floors
  Future<List<BuildingFloorModel>> getFloors(
    String buildingId, {
    int page = 1,
    int pageSize = 50,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;

      final res = await _api.get('/v1/campus/buildings/$buildingId/floors', query: query, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .map((e) => BuildingFloorModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return <BuildingFloorModel>[];
  }

  Future<Map<String, dynamic>> saveFloor(String buildingId, Map<String, dynamic> payload, {String? floorId}) async {
    try {
      if (floorId != null && floorId.isNotEmpty) {
        return await _api.put('/v1/campus/floors/$floorId', payload);
      } else {
        return await _api.post('/v1/campus/buildings/$buildingId/floors', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteFloor(String floorId) async {
    try {
      return await _api.delete('/v1/campus/floors/$floorId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 8. Rooms
  Future<Map<String, dynamic>> getRooms({
    int page = 1,
    int pageSize = 10,
    String? search,
    String? buildingId,
    String? floorId,
    String? roomType,
    String? operationalStatus,
    String? assignmentStatus,
    int? minCapacity,
    int? maxCapacity,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (buildingId != null && buildingId.isNotEmpty) query['building_id'] = buildingId;
      if (floorId != null && floorId.isNotEmpty) query['floor_id'] = floorId;
      if (roomType != null && roomType.isNotEmpty && roomType != 'All') query['room_type'] = roomType;
      if (operationalStatus != null && operationalStatus.isNotEmpty && operationalStatus != 'All') {
        query['operational_status'] = operationalStatus;
      }
      if (assignmentStatus != null && assignmentStatus.isNotEmpty && assignmentStatus != 'All') {
        query['assignment_status'] = assignmentStatus;
      }
      if (minCapacity != null) query['min_capacity'] = minCapacity;
      if (maxCapacity != null) query['max_capacity'] = maxCapacity;
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;

      final res = await _api.get('/v1/campus/rooms', query: query, useCache: false);
      if (res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => RoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'total_count': res['total_count'] ?? list.length,
          'page': res['page'] ?? page,
          'page_size': res['page_size'] ?? pageSize,
          'data': list,
        };
      }
    } catch (_) {}
    return {'total_count': 0, 'page': page, 'page_size': pageSize, 'data': <RoomModel>[]};
  }

  Future<Map<String, dynamic>?> getRoomDetails(String roomId) async {
    try {
      final res = await _api.get('/v1/campus/rooms/$roomId', useCache: false);
      if (res['success'] == true) {
        return res;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> saveRoom(Map<String, dynamic> payload, {String? roomId}) async {
    try {
      if (roomId != null && roomId.isNotEmpty) {
        return await _api.put('/v1/campus/rooms/$roomId', payload);
      } else {
        return await _api.post('/v1/campus/rooms', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteRoom(String roomId) async {
    try {
      return await _api.delete('/v1/campus/rooms/$roomId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 9. Bulk Operations
  Future<Map<String, dynamic>> bulkCreateRooms(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/campus/rooms/bulk-create', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> bulkImportRooms(List<Map<String, dynamic>> rows) async {
    try {
      return await _api.post('/v1/campus/rooms/bulk-import', {'rows': rows});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 10. Room Equipment
  Future<List<RoomEquipmentModel>> getRoomEquipment(String roomId) async {
    try {
      final res = await _api.get('/v1/campus/rooms/$roomId/equipment', useCache: false);
      final list = (res['items'] ?? res['data']) as List?;
      if (list != null) {
        return list.map((e) => RoomEquipmentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    return <RoomEquipmentModel>[];
  }

  Future<Map<String, dynamic>> saveEquipment(String roomId, Map<String, dynamic> payload, {String? equipmentId}) async {
    try {
      if (equipmentId != null && equipmentId.isNotEmpty) {
        return await _api.put('/v1/campus/rooms/$roomId/equipment/$equipmentId', payload);
      } else {
        return await _api.post('/v1/campus/rooms/$roomId/equipment', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteEquipment(String roomId, String equipmentId) async {
    try {
      return await _api.delete('/v1/campus/rooms/$roomId/equipment/$equipmentId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 11. Room Allocations
  Future<Map<String, dynamic>> allocateRoom(String roomId, Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/campus/rooms/$roomId/assignments', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 12. Export
  void exportData(String exportType, {String? buildingId}) {
    String url = '/v1/campus/export?export_type=$exportType';
    if (buildingId != null && buildingId.isNotEmpty) {
      url += '&building_id=$buildingId';
    }
    getDownloadHelper().downloadFile(
      '${AppConfig.apiBaseUrl}$url',
      'campus_${exportType}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  // 13. Image & Document File Upload
  Future<String?> uploadImage(Uint8List bytes, String filename) async {
    try {
      final res = await _api.multipartPostBytes(
        '/v1/campus/upload-image',
        bytes,
        filename,
        'file',
      );
      if (res['success'] == true) {
        return (res['data']?['url'] ?? res['data']?['file_url'])?.toString();
      }
    } catch (e) {
      debugPrint('Error in uploadImage: $e');
    }
    return null;
  }

  Future<String?> uploadDocument(Uint8List bytes, String filename) async {
    return uploadImage(bytes, filename);
  }

  // 14. Building Documents CRUD
  Future<List<BuildingDocumentModel>> getBuildingDocuments(
    String buildingId, {
    int page = 1,
    int pageSize = 50,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;

      final res = await _api.get('/v1/campus/buildings/$buildingId/documents', query: query, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .map((e) => BuildingDocumentModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> saveBuildingDocument(
    String buildingId,
    Map<String, dynamic> payload, {
    String? docId,
  }) async {
    try {
      if (docId != null && docId.isNotEmpty) {
        return await _api.put('/v1/campus/buildings/$buildingId/documents/$docId', payload);
      } else {
        return await _api.post('/v1/campus/buildings/$buildingId/documents', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteBuildingDocument(String buildingId, String docId) async {
    try {
      return await _api.delete('/v1/campus/buildings/$buildingId/documents/$docId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 15. Building Occupancy CRUD (Space Booking Driven)
  Future<Map<String, dynamic>> getBuildingOccupancy(
    String buildingId, {
    String? targetDate,
    int page = 1,
    int pageSize = 200,
    String? sortBy,
    String? sortOrder,
    String? search,
    String? statusFilter,
    String? floorId,
    String? roomType,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (targetDate != null && targetDate.isNotEmpty) query['target_date'] = targetDate;
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'ALL') {
        query['status_filter'] = statusFilter;
      }
      if (floorId != null && floorId.isNotEmpty && floorId != 'all') {
        query['floor_id'] = floorId;
      }
      if (roomType != null && roomType.isNotEmpty && roomType != 'all') {
        query['room_type'] = roomType;
      }

      final res = await _api.get('/v1/campus/buildings/$buildingId/occupancy', query: query, useCache: false);
      final list = (res['data'] as List?)
              ?.map((e) => BuildingOccupancyModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <BuildingOccupancyModel>[];
      final metrics = (res['metrics'] as Map<String, dynamic>?) ?? {};
      return {
        'metrics': metrics,
        'target_date': res['target_date'],
        'is_today': res['is_today'] ?? true,
        'total_count': res['total_count'] ?? list.length,
        'data': list,
      };
    } catch (_) {}
    return {
      'metrics': <String, dynamic>{},
      'target_date': targetDate,
      'is_today': true,
      'total_count': 0,
      'data': <BuildingOccupancyModel>[],
    };
  }

  /// Assign Academic Class & Section to Room via Space Booking
  Future<Map<String, dynamic>> assignClassSectionToRoom(
    String buildingId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _api.post('/v1/campus/buildings/$buildingId/assign-section', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Load Academic Entities (Classes, Sections, Subjects) for quick space assignment
  Future<Map<String, dynamic>> getAcademicEntitiesForAllocation() async {
    try {
      return await _api.get('/v1/campus/academic-entities-for-allocation', useCache: true);
    } catch (e) {
      return {'success': false, 'classes': [], 'subjects': []};
    }
  }

  Future<Map<String, dynamic>> saveBuildingOccupancy(
    String buildingId,
    Map<String, dynamic> payload, {
    String? assignmentId,
  }) async {
    try {
      if (assignmentId != null && assignmentId.isNotEmpty) {
        return await _api.put('/v1/campus/buildings/$buildingId/occupancy/$assignmentId', payload);
      } else {
        return await _api.post('/v1/campus/buildings/$buildingId/occupancy', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteBuildingOccupancy(String buildingId, String assignmentId) async {
    try {
      return await _api.delete('/v1/campus/buildings/$buildingId/occupancy/$assignmentId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // 16. Building Maintenance CRUD
  Future<List<BuildingMaintenanceModel>> getBuildingMaintenance(
    String buildingId, {
    int page = 1,
    int pageSize = 50,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'page_size': pageSize};
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder;

      final res = await _api.get('/v1/campus/buildings/$buildingId/maintenance', query: query, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .map((e) => BuildingMaintenanceModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> saveBuildingMaintenance(
    String buildingId,
    Map<String, dynamic> payload, {
    String? requestId,
  }) async {
    try {
      if (requestId != null && requestId.isNotEmpty) {
        return await _api.put('/v1/campus/buildings/$buildingId/maintenance/$requestId', payload);
      } else {
        return await _api.post('/v1/campus/buildings/$buildingId/maintenance', payload);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteBuildingMaintenance(String buildingId, String requestId) async {
    try {
      return await _api.delete('/v1/campus/buildings/$buildingId/maintenance/$requestId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // Facilities API
  // ==========================================
  Future<Map<String, dynamic>> getFacilities({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? category,
    String? status,
    String? buildingId,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (category != null && category.isNotEmpty && category != 'All Categories') query['category'] = category;
      if (status != null && status.isNotEmpty && status != 'All Statuses') query['status'] = status;
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') query['building_id'] = buildingId;

      final res = await _api.get('/v1/campus/facilities', query: query, useCache: false);
      if (res['data'] is List) {
        return {
          'data': List<Map<String, dynamic>>.from(res['data'] as List),
          'total_count': res['total_count'] ?? 0,
          'page': res['page'] ?? page,
          'page_size': res['page_size'] ?? pageSize,
          'total_pages': res['total_pages'] ?? 1,
        };
      }
    } catch (_) {}
    return {'data': <Map<String, dynamic>>[], 'total_count': 0, 'page': page, 'page_size': pageSize, 'total_pages': 1};
  }

  Future<Map<String, dynamic>> saveFacility(Map<String, dynamic> payload, {String? facilityId}) async {
    try {
      final body = Map<String, dynamic>.from(payload);
      if (facilityId != null && facilityId.isNotEmpty) {
        body['id'] = facilityId;
      }
      return await _api.post('/v1/campus/facilities', body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteFacility(String facilityId) async {
    try {
      return await _api.delete('/v1/campus/facilities/$facilityId');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // Utilities & Services API
  // ==========================================
  Future<Map<String, dynamic>> getUtilitiesKpis() async {
    try {
      final res = await _api.get('/v1/campus/utilities/kpis', useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> getUtilityReadings({
    String? utilityType,
    String? search,
    String sortBy = 'recorded_at',
    String sortOrder = 'desc',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (utilityType != null && utilityType.isNotEmpty && utilityType != 'All') {
        query['utility_type'] = utilityType;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      final res = await _api.get('/v1/campus/utilities/readings', query: query, useCache: false);
      if (res['data'] is List) {
        return {
          'data': List<Map<String, dynamic>>.from(res['data'] as List),
          'total_count': res['total_count'] ?? 0,
          'page': res['page'] ?? page,
          'page_size': res['page_size'] ?? pageSize,
          'total_pages': res['total_pages'] ?? 1,
        };
      }
    } catch (_) {}
    return {'data': <Map<String, dynamic>>[], 'total_count': 0, 'page': page, 'page_size': pageSize, 'total_pages': 1};
  }

  Future<Map<String, dynamic>> logUtilityReading(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/campus/utilities/readings', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUtilityAnomalies({String? readingId}) async {
    try {
      final query = <String, dynamic>{};
      if (readingId != null && readingId.isNotEmpty) {
        query['reading_id'] = readingId;
      }
      return await _api.get('/v1/campus/utilities/anomalies', query: query, useCache: false);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // Reports API
  // ==========================================
  void exportCampusReport({
    required int reportType,
    String? buildingId,
    String? timeRange,
  }) {
    final query = <String, String>{
      'report_type': reportType.toString(),
    };
    if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
      query['building_id'] = buildingId;
    }
    if (timeRange != null && timeRange.isNotEmpty) {
      query['time_range'] = timeRange;
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/campus/reports/export').replace(queryParameters: query);
    getDownloadHelper().downloadFile(uri.toString(), 'campus_report_${DateTime.now().millisecondsSinceEpoch}.csv');
  }
}
