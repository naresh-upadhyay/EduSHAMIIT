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
  Future<List<BuildingFloorModel>> getFloors(String buildingId, {int page = 1, int pageSize = 50}) async {
    try {
      final res = await _api.get('/v1/campus/buildings/$buildingId/floors', query: {
        'page': page,
        'page_size': pageSize,
      }, useCache: false);
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
}
