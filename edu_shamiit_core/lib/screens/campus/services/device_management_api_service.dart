import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/device_management_models.dart';

class DeviceManagementApiService {
  static final DeviceManagementApiService instance = DeviceManagementApiService._internal();
  DeviceManagementApiService._internal();

  final ApiService _api = ApiService();

  /// 1. Fetch Device Dashboard Overview
  Future<Map<String, dynamic>> getOverview() async {
    try {
      final res = await _api.get('/v1/devices/overview', useCache: false);
      return res;
    } catch (_) {}
    return {};
  }

  /// 1b. Fetch Device Registry Fleet KPIs
  Future<DeviceManagementKpis> getRegistryKpis({String? schoolId}) async {
    try {
      final query = <String, dynamic>{};
      if (schoolId != null) query['school_id'] = schoolId;
      final res = await _api.get('/v1/devices/registry/kpis', query: query, useCache: false);
      if (res.isNotEmpty) {
        return DeviceManagementKpis.fromJson(res);
      }
    } catch (_) {}
    return const DeviceManagementKpis();
  }

  /// 2. List Devices with Filtering, Sorting and Pagination
  Future<Map<String, dynamic>> listDevices({
    String? search,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? typeCode,
    String? status,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'All' && buildingId != 'Entire Campus') query['building_id'] = buildingId;
      if (floorId != null && floorId.isNotEmpty && floorId != 'All') query['floor_id'] = floorId;
      if (roomId != null && roomId.isNotEmpty && roomId != 'All') query['room_id'] = roomId;
      if (typeCode != null && typeCode.isNotEmpty && typeCode != 'All') query['type_code'] = typeCode;
      if (status != null && status.isNotEmpty && status != 'All') query['status'] = status.toLowerCase();
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;
      if (sortOrder != null && sortOrder.isNotEmpty) query['sort_order'] = sortOrder.toLowerCase();

      final res = await _api.get('/v1/devices', query: query, useCache: false);
      return res;
    } catch (_) {}
    return {'total': 0, 'page': page, 'page_size': pageSize, 'devices': []};
  }

  /// 3. Fetch Location Hierarchy Tree
  Future<LocationTreeNode?> getLocationTree() async {
    try {
      final res = await _api.get('/v1/devices/tree', useCache: false);
      return LocationTreeNode.fromJson(res);
    } catch (_) {}
    return null;
  }

  /// 4. Execute Device Command (e.g. power toggle, temperature, brightness, etc.)
  Future<Map<String, dynamic>> executeCommand(
    String deviceId,
    String commandType,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _api.post(
        '/v1/devices/$deviceId/command',
        {
          'command_type': commandType,
          'payload': payload,
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 5. Execute Bulk Device Commands
  Future<Map<String, dynamic>> executeBulkCommand(
    List<String> deviceIds,
    String commandType,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _api.post(
        '/v1/devices/bulk-command',
        {
          'device_ids': deviceIds,
          'command_type': commandType,
          'payload': payload,
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 6. Execute Scene Preset
  Future<Map<String, dynamic>> executeScene(String sceneId) async {
    try {
      final res = await _api.post('/v1/devices/scenes/$sceneId/execute', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 7. Register New Device
  Future<Map<String, dynamic>> createDevice(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/devices', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 8. Delete Device
  Future<Map<String, dynamic>> deleteDevice(String deviceId) async {
    try {
      final res = await _api.delete('/v1/devices/$deviceId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 8b. Bulk Delete Devices
  Future<Map<String, dynamic>> bulkDeleteDevices(List<String> deviceIds) async {
    try {
      final res = await _api.post('/v1/devices/bulk-delete', {'device_ids': deviceIds});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 9. Export Devices CSV
  Future<void> exportDevicesCsv() async {
    try {
      final url = '${AppConfig.apiBaseUrl}/api/v1/devices/export';
      getDownloadHelper().downloadFile(url, 'campus_devices_export.csv');
    } catch (_) {}
  }

  /// 10. Reboot Device Hardware via MQTT
  Future<Map<String, dynamic>> rebootDevice(String deviceId) async {
    try {
      final res = await _api.post('/v1/devices/reboot/$deviceId', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 11. Fetch Device Groups
  Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final res = await _api.get('/v1/devices/groups', useCache: false);
      return (res['groups'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// 12. Fetch Automation Rules
  Future<List<Map<String, dynamic>>> getAutomations() async {
    try {
      final res = await _api.get('/v1/devices/automations', useCache: false);
      return (res['automations'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// 13. Toggle Automation Rule Active Status
  Future<bool> toggleAutomation(String id) async {
    try {
      final res = await _api.patch('/v1/devices/automations/$id/toggle', {});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 14. Fetch Schedules
  Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final res = await _api.get('/v1/devices/schedules', useCache: false);
      return (res['schedules'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// 15. Toggle Schedule Active Status
  Future<bool> toggleSchedule(String id) async {
    try {
      final res = await _api.patch('/v1/devices/schedules/$id/toggle', {});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 16. Fetch Alerts
  Future<List<Map<String, dynamic>>> getAlerts() async {
    try {
      final res = await _api.get('/v1/devices/alerts', useCache: false);
      return (res['alerts'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// 17. Resolve Alert
  Future<bool> resolveAlert(String id) async {
    try {
      final res = await _api.patch('/v1/devices/alerts/$id/resolve', {});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 18. Fetch Audit Logs
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    try {
      final res = await _api.get('/v1/devices/audit-logs', useCache: false);
      return (res['audit_logs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return [];
  }

  /// 19. Create Custom Scene
  Future<Map<String, dynamic>> createScene(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/devices/scenes', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 20. Update Device Specifications
  Future<bool> updateDevice(String deviceId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/v1/devices/$deviceId', data);
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 21. Ping Device via MQTT
  Future<Map<String, dynamic>> pingDevice(String deviceId) async {
    try {
      final res = await _api.post('/v1/devices/ping/$deviceId', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 22. Create Device Group
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/devices/groups', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 23. Update Device Group
  Future<Map<String, dynamic>> updateGroup(String groupId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put('/v1/devices/groups/$groupId', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 24. Delete Device Group
  Future<bool> deleteGroup(String groupId) async {
    try {
      final res = await _api.delete('/v1/devices/groups/$groupId');
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 25. Execute Device Group Action
  Future<bool> executeGroupAction(String groupId, String action, [Map<String, dynamic>? params]) async {
    try {
      final res = await _api.post('/v1/devices/groups/$groupId/action', {
        'action': action,
        if (params != null) 'parameters': params,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 26. Create Automation Rule
  Future<Map<String, dynamic>> createAutomationRule(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/devices/automations', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 27. Update Automation Rule
  Future<Map<String, dynamic>> updateAutomationRule(String ruleId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.put('/v1/devices/automations/$ruleId', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 28. Delete Automation Rule
  Future<bool> deleteAutomationRule(String ruleId) async {
    try {
      final res = await _api.delete('/v1/devices/automations/$ruleId');
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 29. Duplicate Automation Rule
  Future<Map<String, dynamic>> duplicateAutomationRule(String ruleId) async {
    try {
      final res = await _api.post('/v1/devices/automations/$ruleId/duplicate', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 30. Test / Simulate Automation Rule
  Future<Map<String, dynamic>> testAutomationRule(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/v1/devices/automations/test', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 31. Run Automation Rules Cron Job Now
  Future<Map<String, dynamic>> runAutomationCron() async {
    try {
      final res = await _api.post('/v1/devices/automations/cron/run', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 32. Get Automation Rules Cron Status
  Future<Map<String, dynamic>> getAutomationCronStatus() async {
    try {
      final res = await _api.get('/v1/devices/automations/cron/status', useCache: false);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 32a. Get Automation Rules Dynamic KPIs
  Future<Map<String, dynamic>> getAutomationKpis() async {
    try {
      final res = await _api.get('/v1/devices/automations/kpis', useCache: false);
      if (res['success'] == true && res['kpis'] is Map) {
        return Map<String, dynamic>.from(res['kpis']);
      }
    } catch (_) {}
    return {};
  }

  /// 32b. Get Automation Cascading Options (Building -> Floor -> Room, Types, Groups, Devices, Scenes)
  Future<Map<String, dynamic>> getAutomationCascadingOptions({String? buildingId, String? floorId}) async {
    try {
      final qParams = <String, String>{};
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'All Buildings') {
        qParams['building_id'] = buildingId;
      }
      if (floorId != null && floorId.isNotEmpty && floorId != 'All Floors') {
        qParams['floor_id'] = floorId;
      }
      final uri = Uri(path: '/v1/devices/automations/cascading-options', queryParameters: qParams.isEmpty ? null : qParams);
      final res = await _api.get(uri.toString(), useCache: false);
      if (res['success'] == true && res['options'] is Map) {
        return Map<String, dynamic>.from(res['options']);
      }
    } catch (_) {}
    return {};
  }

  /// 32c. List Automation Rules with Database Pagination, Search & Sorting
  Future<Map<String, dynamic>> listAutomations({
    String? search,
    String? buildingId,
    String? deviceType,
    String? status,
    String? category,
    String sortBy = 'created_at',
    String sortDir = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final qParams = <String, String>{
        'sort_by': sortBy,
        'sort_dir': sortDir,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (search != null && search.trim().isNotEmpty) qParams['search'] = search.trim();
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'All Buildings') qParams['building_id'] = buildingId;
      if (deviceType != null && deviceType.isNotEmpty && deviceType != 'All Device Types') qParams['device_type'] = deviceType;
      if (status != null && status.isNotEmpty && status != 'All Status') qParams['status'] = status;
      if (category != null && category.isNotEmpty && category != 'All') qParams['category'] = category;

      final uri = Uri(path: '/v1/devices/automations', queryParameters: qParams);
      final res = await _api.get(uri.toString(), useCache: false);
      return res;
    } catch (e) {
      return {'success': false, 'automations': [], 'total': 0, 'error': e.toString()};
    }
  }

  /// 32d. Bulk Automation Action (enable, disable, delete, run)
  Future<bool> bulkAutomationAction(List<String> ruleIds, String action) async {
    try {
      final res = await _api.post('/v1/devices/automations/bulk', {
        'rule_ids': ruleIds,
        'action': action,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 32e. Execute Automation Rule on Live Devices
  Future<Map<String, dynamic>> executeAutomationRule(String ruleId) async {
    try {
      final res = await _api.post('/v1/devices/automations/$ruleId/execute', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // DEVICE TYPES & PROFILES API METHODS
  // ============================================================================

  /// 33. Fetch Device Types & Profiles KPIs
  Future<DeviceTypesProfilesKpis> getTypesProfilesKpis() async {
    try {
      final res = await _api.get('/v1/devices/types-and-profiles/kpis', useCache: false);
      if (res.isNotEmpty) {
        return DeviceTypesProfilesKpis.fromJson(res);
      }
    } catch (_) {}
    return const DeviceTypesProfilesKpis();
  }

  /// 34. List Device Types with Pagination and Filters
  Future<Map<String, dynamic>> getDeviceTypes({
    String? category,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (category != null && category.isNotEmpty && category != 'All' && category != 'All Categories') {
        query['category'] = category;
      }
      if (status != null && status.isNotEmpty && status != 'All' && status != 'All Status') {
        query['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }

      final res = await _api.get('/v1/devices/types', query: query, useCache: false);
      if (res.isNotEmpty) {
        final list = (res['types'] as List? ?? [])
            .map((e) => DeviceTypeDetailItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'types': list,
          'total': (res['total'] as num?)?.toInt() ?? list.length,
          'page': (res['page'] as num?)?.toInt() ?? page,
          'page_size': (res['page_size'] as num?)?.toInt() ?? pageSize,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
        };
      }
    } catch (_) {}
    return {'types': <DeviceTypeDetailItem>[], 'total': 0, 'page': page, 'page_size': pageSize, 'total_pages': 1};
  }

  /// 34b. Fetch Dynamic Device Categories
  Future<List<String>> getDeviceCategories() async {
    try {
      final res = await _api.get('/v1/devices/categories', useCache: false);
      if (res['categories'] is List) {
        final list = (res['categories'] as List).map((e) => e.toString()).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [
      'Security',
      'AV & Display',
      'Network',
      'Power & Energy',
      'Building Automation',
      'Environment',
      'Safety & Fire',
      'Access Control',
    ];
  }

  /// 34c. Bulk Delete Device Types
  Future<Map<String, dynamic>> bulkDeleteDeviceTypes(List<String> typeIds) async {
    try {
      final res = await _api.post('/v1/devices/types/bulk-delete', {'type_ids': typeIds});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 34d. Bulk Toggle Device Types Status
  Future<Map<String, dynamic>> bulkToggleDeviceTypesStatus(List<String> typeIds, bool isActive) async {
    try {
      final res = await _api.post('/v1/devices/types/bulk-status', {'type_ids': typeIds, 'is_active': isActive});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 35. Get Device Type Detail
  Future<DeviceTypeDetailItem?> getDeviceTypeDetail(String typeId) async {
    try {
      final res = await _api.get('/v1/devices/types/$typeId', useCache: false);
      if (res['type'] != null) {
        return DeviceTypeDetailItem.fromJson(Map<String, dynamic>.from(res['type'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// 36. Create Device Type
  Future<Map<String, dynamic>> createDeviceType(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/devices/types', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 37. Update Device Type
  Future<Map<String, dynamic>> updateDeviceType(String typeId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/v1/devices/types/$typeId', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 38. Delete Device Type
  Future<Map<String, dynamic>> deleteDeviceType(String typeId) async {
    try {
      final res = await _api.delete('/v1/devices/types/$typeId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 39. Duplicate Device Type
  Future<Map<String, dynamic>> duplicateDeviceType(String typeId) async {
    try {
      final res = await _api.post('/v1/devices/types/$typeId/duplicate', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 40. List Device Profiles
  Future<List<DeviceProfileItem>> getDeviceProfiles({
    String? deviceTypeId,
    String? profileType,
    String? status,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (deviceTypeId != null && deviceTypeId.isNotEmpty) query['device_type_id'] = deviceTypeId;
      if (profileType != null && profileType.isNotEmpty) query['profile_type'] = profileType;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

      final res = await _api.get('/v1/devices/profiles', query: query, useCache: false);
      if (res['profiles'] is List) {
        return (res['profiles'] as List)
            .map((e) => DeviceProfileItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 41. Create Device Profile
  Future<Map<String, dynamic>> createDeviceProfile(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/devices/profiles', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 42. Get Device Profile
  Future<DeviceProfileItem?> getDeviceProfile(String profileId) async {
    try {
      final res = await _api.get('/v1/devices/profiles/$profileId', useCache: false);
      if (res['profile'] != null) {
        return DeviceProfileItem.fromJson(Map<String, dynamic>.from(res['profile'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// 43. Update Device Profile
  Future<Map<String, dynamic>> updateDeviceProfile(String profileId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/v1/devices/profiles/$profileId', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 44. Delete Device Profile
  Future<Map<String, dynamic>> deleteDeviceProfile(String profileId) async {
    try {
      final res = await _api.delete('/v1/devices/profiles/$profileId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 45. Duplicate Device Profile
  Future<Map<String, dynamic>> duplicateDeviceProfile(String profileId) async {
    try {
      final res = await _api.post('/v1/devices/profiles/$profileId/duplicate', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 46. Deploy Device Profile to Devices
  Future<Map<String, dynamic>> deployDeviceProfile(String profileId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/devices/profiles/$profileId/deploy', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 47. Get Standard Capabilities Library
  Future<List<CapabilityTemplateItem>> getCapabilitiesLibrary() async {
    try {
      final res = await _api.get('/v1/devices/capabilities/library', useCache: false);
      if (res['capabilities'] is List) {
        return (res['capabilities'] as List)
            .map((e) => CapabilityTemplateItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 48. Create Custom Capability
  Future<Map<String, dynamic>> createCustomCapability(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/devices/capabilities', data);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 49. Get Protocol Mappings
  Future<List<Map<String, dynamic>>> getProtocolMappings() async {
    try {
      final res = await _api.get('/v1/devices/protocols/mappings', useCache: false);
      if (res['protocols'] is List) {
        return List<Map<String, dynamic>>.from(res['protocols'] as List);
      }
    } catch (_) {}
    return [];
  }

  /// 50. Get Device Groups KPIs
  Future<DeviceGroupsKpis> getDeviceGroupsKpis() async {
    try {
      final res = await _api.get('/v1/devices/groups/kpis', useCache: false);
      return DeviceGroupsKpis.fromJson(res);
    } catch (_) {}
    return const DeviceGroupsKpis();
  }

  /// 51. Get Device Groups List (with server pagination, database sorting & filtering)
  Future<Map<String, dynamic>> getDeviceGroups({
    String? status,
    String? location,
    String? groupType,
    String? profile,
    String? search,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (location != null && location.isNotEmpty) 'location': location,
        if (groupType != null && groupType.isNotEmpty) 'group_type': groupType,
        if (profile != null && profile.isNotEmpty) 'profile': profile,
        if (search != null && search.isNotEmpty) 'search': search,
        if (sortBy != null && sortBy.isNotEmpty) 'sort_by': sortBy,
        if (sortOrder != null && sortOrder.isNotEmpty) 'sort_order': sortOrder,
      };

      final queryString = query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final res = await _api.get('/v1/devices/groups?$queryString', useCache: false);

      List<DeviceGroupItem> groups = [];
      if (res['groups'] is List) {
        groups = (res['groups'] as List)
            .map((e) => DeviceGroupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      return {
        'groups': groups,
        'total': res['total'] ?? groups.length,
        'page': res['page'] ?? page,
        'page_size': res['page_size'] ?? pageSize,
        'total_pages': res['total_pages'] ?? 1,
      };
    } catch (_) {}
    return {'groups': <DeviceGroupItem>[], 'total': 0, 'page': 1, 'page_size': 10, 'total_pages': 1};
  }

  /// 51b. Get Device Group Filter Options (dynamic distinct locations, group types, profiles from DB)
  Future<Map<String, List<String>>> getDeviceGroupFilterOptions() async {
    try {
      final res = await _api.get('/v1/devices/groups/filter-options', useCache: false);
      List<String> toStrList(dynamic list) => (list as List? ?? []).map((e) => e.toString()).toList();
      return {
        'locations': toStrList(res['locations']),
        'group_types': toStrList(res['group_types']),
        'profiles': toStrList(res['profiles']),
      };
    } catch (_) {}
    return {'locations': [], 'group_types': [], 'profiles': []};
  }

  /// 51c. Bulk Delete Device Groups
  Future<bool> bulkDeleteDeviceGroups(List<String> groupIds) async {
    try {
      final res = await _api.post('/v1/devices/groups/bulk-delete', {'group_ids': groupIds});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 51d. Bulk Toggle Device Groups Status
  Future<bool> bulkToggleDeviceGroupsStatus(List<String> groupIds, String status) async {
    try {
      final res = await _api.post('/v1/devices/groups/bulk-status', {'group_ids': groupIds, 'status': status});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 52. Get Device Group Detail
  Future<DeviceGroupItem?> getDeviceGroupDetail(String groupId) async {
    try {
      final res = await _api.get('/v1/devices/groups/$groupId', useCache: false);
      if (res['group'] is Map) {
        return DeviceGroupItem.fromJson(Map<String, dynamic>.from(res['group'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// 53. Execute Capability-Aware Group Command
  Future<Map<String, dynamic>> executeGroupCommand(String groupId, String commandType, [Map<String, dynamic>? parameters]) async {
    try {
      final res = await _api.post('/v1/devices/groups/$groupId/commands', {
        'command_type': commandType,
        if (parameters != null) 'parameters': parameters,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 54. Duplicate Device Group
  Future<bool> duplicateDeviceGroup(String groupId) async {
    try {
      final res = await _api.post('/v1/devices/groups/$groupId/duplicate', {});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 55. Toggle Device Group Status
  Future<bool> toggleDeviceGroupStatus(String groupId, String status) async {
    try {
      final res = await _api.patch('/v1/devices/groups/$groupId/status?status=$status', {});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 56. Get Device Group Members
  Future<List<Map<String, dynamic>>> getDeviceGroupMembers(String groupId, {String? search}) async {
    try {
      final q = search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : '';
      final res = await _api.get('/v1/devices/groups/$groupId/members$q', useCache: false);
      if (res['members'] is List) {
        return List<Map<String, dynamic>>.from(res['members'] as List);
      }
    } catch (_) {}
    return [];
  }

  /// 57. Add Group Members
  Future<bool> addDeviceGroupMembers(String groupId, List<String> deviceIds) async {
    try {
      final res = await _api.post('/v1/devices/groups/$groupId/members', {'device_ids': deviceIds});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 58. Remove Group Member
  Future<bool> removeDeviceGroupMember(String groupId, String deviceId) async {
    try {
      final res = await _api.delete('/v1/devices/groups/$groupId/members/$deviceId');
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 59. Export Device Groups
  Future<List<Map<String, dynamic>>> exportDeviceGroups() async {
    try {
      final res = await _api.get('/v1/devices/groups/export', useCache: false);
      if (res['groups'] is List) {
        return List<Map<String, dynamic>>.from(res['groups'] as List);
      }
    } catch (_) {}
    return [];
  }

  /// 60. Import Device Groups
  Future<bool> importDeviceGroups(List<Map<String, dynamic>> groups) async {
    try {
      final res = await _api.post('/v1/devices/groups/import', {'groups': groups});
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  // ============================================================================
  // LOCATIONS & SPATIAL MAPPING SERVICES
  // ============================================================================

  /// 61. Fetch Locations & Mapping KPIs
  Future<LocationsMappingKpis> fetchLocationsMappingKpis() async {
    try {
      final res = await _api.get('/v1/devices/locations/kpis', useCache: false);
      if (res['data'] is Map) {
        return LocationsMappingKpis.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (_) {}
    return const LocationsMappingKpis();
  }

  /// 62. Fetch Campus Hierarchy Tree
  Future<LocationHierarchyNode?> fetchLocationsHierarchy() async {
    try {
      final res = await _api.get('/v1/devices/locations/hierarchy', useCache: false);
      if (res['tree'] is Map) {
        return LocationHierarchyNode.fromJson(Map<String, dynamic>.from(res['tree'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// 63. Fetch Location Specifications & Child Assets
  Future<LocationDetailsModel?> fetchLocationDetails({String? floorId, String? buildingId}) async {
    try {
      final query = <String>[];
      if (floorId != null) query.add('floor_id=$floorId');
      if (buildingId != null) query.add('building_id=$buildingId');
      final qs = query.isNotEmpty ? '?${query.join('&')}' : '';
      final res = await _api.get('/v1/devices/locations/details$qs', useCache: false);
      if (res['data'] is Map) {
        return LocationDetailsModel.fromJson(Map<String, dynamic>.from(res['data'] as Map));
      }
    } catch (_) {}
    return null;
  }

  /// 64. Fetch Location Mapped Devices (Table View)
  Future<Map<String, dynamic>> fetchLocationDevices({
    String? floorId,
    String? buildingId,
    String? roomId,
    String? deviceType,
    String? groupId,
    String? profileId,
    String? mappingStatus,
    String? search,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final query = <String>[
        'page=$page',
        'limit=$limit',
      ];
      if (floorId != null) query.add('floor_id=$floorId');
      if (buildingId != null) query.add('building_id=$buildingId');
      if (roomId != null) query.add('room_id=$roomId');
      if (deviceType != null && deviceType != 'All' && !deviceType.startsWith('All')) query.add('device_type=${Uri.encodeComponent(deviceType)}');
      if (groupId != null && groupId != 'All' && !groupId.startsWith('All')) query.add('group_id=${Uri.encodeComponent(groupId)}');
      if (profileId != null && profileId != 'All' && !profileId.startsWith('All')) query.add('profile_id=${Uri.encodeComponent(profileId)}');
      if (mappingStatus != null && mappingStatus != 'All' && !mappingStatus.startsWith('All')) query.add('mapping_status=${Uri.encodeComponent(mappingStatus)}');
      if (search != null && search.isNotEmpty) query.add('search=${Uri.encodeComponent(search)}');
      if (sortBy != null && sortBy.isNotEmpty) query.add('sort_by=${Uri.encodeComponent(sortBy)}');
      if (sortOrder != null && sortOrder.isNotEmpty) query.add('sort_order=${Uri.encodeComponent(sortOrder)}');

      final res = await _api.get('/v1/devices/locations/devices?${query.join('&')}', useCache: false);
      List<DeviceLocationMappingItem> items = [];
      final rawDevs = res['devices'] ?? (res['data'] is Map ? (res['data'] as Map)['devices'] : null);
      if (rawDevs is List) {
        items = rawDevs
            .map((e) => DeviceLocationMappingItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      final total = res['total'] ?? (res['data'] is Map ? (res['data'] as Map)['total'] : null) ?? items.length;
      return {
        'devices': items,
        'total': total,
        'page': res['page'] ?? page,
        'limit': res['limit'] ?? limit,
      };
    } catch (_) {}
    return {'devices': <DeviceLocationMappingItem>[], 'total': 0, 'page': page, 'limit': limit};
  }

  /// 65. Map Devices to Location
  Future<bool> mapDevicesToLocation({
    required List<String> deviceIds,
    required String buildingId,
    required String floorId,
    String? roomId,
    String mountType = 'Wall',
    double mountHeight = 2.4,
    String? assetTag,
    String? notes,
  }) async {
    try {
      final res = await _api.post('/v1/devices/locations/map', {
        'device_ids': deviceIds,
        'building_id': buildingId,
        'floor_id': floorId,
        if (roomId != null) 'room_id': roomId,
        'mount_type': mountType,
        'mount_height_meters': mountHeight,
        if (assetTag != null) 'asset_tag': assetTag,
        if (notes != null) 'notes': notes,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 66. Bulk Map Devices to Location
  Future<bool> bulkMapDevices({
    required List<String> deviceIds,
    required String buildingId,
    required String floorId,
    String? roomId,
    String mountType = 'Wall',
    double mountHeight = 2.4,
    String? assetTagPrefix,
    String? notes,
  }) async {
    try {
      final res = await _api.post('/v1/devices/locations/bulk-map', {
        'device_ids': deviceIds,
        'building_id': buildingId,
        'floor_id': floorId,
        if (roomId != null) 'room_id': roomId,
        'mount_type': mountType,
        'mount_height_meters': mountHeight,
        if (assetTagPrefix != null) 'asset_tag_prefix': assetTagPrefix,
        if (notes != null) 'notes': notes,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 67. Unmap Devices
  Future<bool> unmapDevicesFromLocation({
    required List<String> deviceIds,
    String? reason,
  }) async {
    try {
      final res = await _api.post('/v1/devices/locations/unmap', {
        'device_ids': deviceIds,
        if (reason != null) 'reason': reason,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 68. Move Device to Location
  Future<bool> moveDeviceLocation({
    required String deviceId,
    required String toBuildingId,
    required String toFloorId,
    String? toRoomId,
    String? reason,
  }) async {
    try {
      final res = await _api.post('/v1/devices/locations/move', {
        'device_id': deviceId,
        'to_building_id': toBuildingId,
        'to_floor_id': toFloorId,
        if (toRoomId != null) 'to_room_id': toRoomId,
        if (reason != null) 'reason': reason,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 69. Fetch Floor Plan Asset & Device Markers
  Future<Map<String, dynamic>> fetchFloorPlanAndMarkers(String floorId) async {
    try {
      final res = await _api.get('/v1/devices/locations/floor-plan/$floorId', useCache: false);
      FloorPlanAssetModel? plan;
      if (res['floor_plan'] is Map) {
        plan = FloorPlanAssetModel.fromJson(Map<String, dynamic>.from(res['floor_plan'] as Map));
      }
      List<FloorPlanMarkerModel> markers = [];
      if (res['markers'] is List) {
        markers = (res['markers'] as List)
            .map((e) => FloorPlanMarkerModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      FloorPlanLegendModel legend = const FloorPlanLegendModel();
      if (res['legend'] is Map) {
        legend = FloorPlanLegendModel.fromJson(Map<String, dynamic>.from(res['legend'] as Map));
      }
      return {
        'floor_plan': plan,
        'asset': plan,
        'markers': markers,
        'legend': legend,
      };
    } catch (_) {}
    return {
      'floor_plan': null,
      'asset': null,
      'markers': <FloorPlanMarkerModel>[],
      'legend': const FloorPlanLegendModel(),
    };
  }

  /// 70. Save or Reposition Floor Plan Marker
  Future<bool> saveFloorPlanMarker({
    required String floorId,
    required String deviceId,
    String? floorPlanId,
    String? roomId,
    required double posX,
    required double posY,
    double rotation = 0,
    String? label,
  }) async {
    try {
      final res = await _api.post('/v1/devices/locations/floor-plan/$floorId/markers', {
        if (floorPlanId != null) 'floor_plan_id': floorPlanId,
        'floor_id': floorId,
        'device_id': deviceId,
        if (roomId != null) 'room_id': roomId,
        'pos_x': posX,
        'pos_y': posY,
        'rotation_degrees': rotation,
        if (label != null) 'marker_label': label,
      });
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// 71. Delete Floor Plan Marker
  Future<bool> deleteFloorPlanMarker({
    required String floorId,
    required String markerId,
  }) async {
    try {
      final res = await _api.delete('/v1/devices/locations/floor-plan/$floorId/markers/$markerId');
      return res['success'] == true;
    } catch (_) {}
    return false;
  }

  /// -------------------------------------------------------------------------
  /// LIVE CONTROL SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 72. Fetch Live Control KPIs
  Future<LiveControlKpis> fetchLiveControlKpis({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/live-control/kpis$q');
      return LiveControlKpis.fromJson(res);
    } catch (_) {}
    return const LiveControlKpis();
  }

  /// 73. Fetch Live Control Devices (Paginated & Sorted)
  Future<Map<String, dynamic>> fetchLiveControlDevicesPaginated({
    String? schoolId,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? deviceTypeId,
    String? category,
    String? status,
    String? search,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? pageSize,
  }) async {
    try {
      final qParams = <String>[];
      if (schoolId != null) qParams.add('school_id=$schoolId');
      if (buildingId != null) qParams.add('building_id=$buildingId');
      if (floorId != null) qParams.add('floor_id=$floorId');
      if (roomId != null) qParams.add('room_id=$roomId');
      if (deviceTypeId != null) qParams.add('device_type_id=$deviceTypeId');
      if (category != null && category.isNotEmpty && category != 'All Device Types') {
        qParams.add('category=${Uri.encodeComponent(category)}');
      }
      if (status != null && status.isNotEmpty && status != 'All Status') {
        qParams.add('status=${Uri.encodeComponent(status.toLowerCase())}');
      }
      if (search != null && search.isNotEmpty) {
        qParams.add('search=${Uri.encodeComponent(search)}');
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        qParams.add('sort_by=${Uri.encodeComponent(sortBy)}');
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        qParams.add('sort_order=${Uri.encodeComponent(sortOrder)}');
      }
      if (page != null) qParams.add('page=$page');
      if (pageSize != null) qParams.add('page_size=$pageSize');

      final qs = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';
      final res = await _api.get('/v1/devices/live-control/devices$qs');
      List<LiveControlDeviceItem> devices = [];
      if (res['devices'] is List) {
        devices = (res['devices'] as List)
            .map((e) => LiveControlDeviceItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return {
        'devices': devices,
        'total': (res['total'] as num?)?.toInt() ?? devices.length,
        'page': (res['page'] as num?)?.toInt() ?? (page ?? 1),
        'page_size': (res['page_size'] as num?)?.toInt() ?? (pageSize ?? 10),
        'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
      };
    } catch (_) {}
    return {
      'devices': <LiveControlDeviceItem>[],
      'total': 0,
      'page': page ?? 1,
      'page_size': pageSize ?? 10,
      'total_pages': 1,
    };
  }

  /// 73. Fetch Live Control Devices (legacy helper)
  Future<List<LiveControlDeviceItem>> fetchLiveControlDevices({
    String? schoolId,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? deviceTypeId,
    String? category,
    String? status,
    String? search,
  }) async {
    final res = await fetchLiveControlDevicesPaginated(
      schoolId: schoolId,
      buildingId: buildingId,
      floorId: floorId,
      roomId: roomId,
      deviceTypeId: deviceTypeId,
      category: category,
      status: status,
      search: search,
      page: 1,
      pageSize: 50,
    );
    return res['devices'] as List<LiveControlDeviceItem>? ?? [];
  }

  /// 74. Execute Live Control Command
  Future<Map<String, dynamic>> executeLiveControlCommand({
    required String deviceId,
    required String commandType,
    required Map<String, dynamic> payload,
    String? schoolId,
  }) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.post('/v1/devices/live-control/execute-command$q', {
        'device_id': deviceId,
        'command_type': commandType,
        'payload': payload,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 74b. Bulk Execute Live Control Command
  Future<Map<String, dynamic>> bulkExecuteLiveControlCommand({
    required List<String> deviceIds,
    required String commandType,
    required Map<String, dynamic> payload,
    String? schoolId,
  }) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.post('/v1/devices/live-control/bulk-command$q', {
        'device_ids': deviceIds,
        'command_type': commandType,
        'payload': payload,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString(), 'count': 0};
    }
  }

  /// 75. Fetch Live Control Device Details
  Future<LiveControlDeviceDetails?> fetchLiveControlDeviceDetails(
    String deviceId, {
    String? schoolId,
  }) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/live-control/devices/$deviceId/details$q');
      return LiveControlDeviceDetails.fromJson(res);
    } catch (_) {}
    return null;
  }

  /// -------------------------------------------------------------------------
  /// BULK OPERATIONS SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 76. Fetch Bulk Operations Overview
  Future<Map<String, dynamic>> fetchBulkOperationsOverview({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/bulk-operations/overview$q');
    } catch (_) {}
    return {};
  }

  /// 76b. Fetch Cascading Locations (Strict hierarchical locations & lookups)
  Future<Map<String, dynamic>> fetchBulkCascadingLocations({
    String? schoolId,
    String? buildingId,
    String? floorId,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        if (buildingId != null && buildingId.isNotEmpty) 'building_id': buildingId,
        if (floorId != null && floorId.isNotEmpty) 'floor_id': floorId,
      };
      return await _api.get('/v1/devices/bulk-operations/cascading-locations', query: q);
    } catch (_) {}
    return {};
  }

  /// 77. Fetch Bulk Target Devices with Sorting & Server Pagination
  Future<Map<String, dynamic>> fetchBulkTargetDevices({
    String? schoolId,
    String? search,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? building,
    String? floor,
    String? room,
    String? deviceType,
    String? status,
    String? profile,
    String sortBy = 'device_name',
    String sortOrder = 'asc',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (buildingId != null && buildingId.isNotEmpty) 'building_id': buildingId,
        if (floorId != null && floorId.isNotEmpty) 'floor_id': floorId,
        if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
        if (building != null && building != 'All Buildings') 'building': building,
        if (floor != null && floor != 'All Floors') 'floor': floor,
        if (room != null && room != 'All Rooms') 'room': room,
        if (deviceType != null && deviceType != 'All Types') 'device_type': deviceType,
        if (status != null && status != 'All Status') 'status': status,
        if (profile != null && profile != 'All Profiles') 'profile': profile,
        'sort_by': sortBy,
        'sort_order': sortOrder,
        'page': page,
        'page_size': pageSize,
      };
      return await _api.get('/v1/devices/bulk-operations/targets', query: q);
    } catch (_) {}
    return {};
  }

  /// 78. Execute Bulk Operation
  Future<Map<String, dynamic>> executeBulkOperationAction(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/devices/bulk-operations/execute', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 78b. List Bulk Operations
  Future<Map<String, dynamic>> listBulkOperations({
    String? schoolId,
    int page = 1,
    int pageSize = 10,
    String? status,
    String? operationType,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'page': page,
        'page_size': pageSize,
        if (status != null && status.isNotEmpty) 'status': status,
        if (operationType != null && operationType.isNotEmpty) 'operation_type': operationType,
        if (search != null && search.isNotEmpty) 'search': search,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      return await _api.get('/v1/devices/bulk-operations', query: q);
    } catch (_) {}
    return {};
  }

  /// 78c. Get Bulk Operation Details
  Future<Map<String, dynamic>> getBulkOperationDetails(String operationId, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/bulk-operations/$operationId$q');
    } catch (_) {}
    return {};
  }

  /// 78d. Cancel Running Bulk Operation
  Future<Map<String, dynamic>> cancelBulkOperation(String operationId, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.post('/v1/devices/bulk-operations/$operationId/cancel$q', {});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 78e. Retry Failed Devices in Bulk Operation
  Future<Map<String, dynamic>> retryFailedBulkOperation(String operationId, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.post('/v1/devices/bulk-operations/$operationId/retry-failed$q', {});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 78f. List Bulk Templates
  Future<List<dynamic>> listBulkTemplates({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/bulk-operations/templates$q');
      if (res['templates'] is List) return res['templates'] as List<dynamic>;
      if (res['data'] is List) return res['data'] as List<dynamic>;
      if (res['items'] is List) return res['items'] as List<dynamic>;
    } catch (_) {}
    return [];
  }

  /// 78g. Create Bulk Template
  Future<Map<String, dynamic>> createBulkTemplate(Map<String, dynamic> payload, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.post('/v1/devices/bulk-operations/templates$q', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 78h. Delete Bulk Template
  Future<Map<String, dynamic>> deleteBulkTemplate(String templateId, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.delete('/v1/devices/bulk-operations/templates/$templateId$q');
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 78i. Execute Bulk Template
  Future<Map<String, dynamic>> executeBulkTemplate(String templateId, {String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.post('/v1/devices/bulk-operations/templates/$templateId/execute$q', {});
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// -------------------------------------------------------------------------
  /// ENERGY & USAGE SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 79. Fetch Energy Usage Overview
  Future<Map<String, dynamic>> fetchEnergyUsageOverview({String? schoolId, String period = '30d'}) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'period': period,
      };
      return await _api.get('/v1/devices/energy-usage/overview', query: q);
    } catch (_) {}
    return {};
  }

  /// 80. Fetch Energy Usage Devices
  Future<Map<String, dynamic>> fetchEnergyUsageDevices({
    String? schoolId,
    int limit = 10,
    int offset = 0,
    String? search,
    String? location,
    String? deviceType,
    String? group,
    String? usageLevel,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'limit': limit,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
        if (location != null && location != 'All Locations') 'location': location,
        if (deviceType != null && deviceType != 'All Device Types') 'device_type': deviceType,
        if (group != null && group != 'All Groups') 'group': group,
        if (usageLevel != null) 'usage_level': usageLevel,
      };
      return await _api.get('/v1/devices/energy-usage/devices', query: q);
    } catch (_) {}
    return {};
  }

  /// 81. Fetch Energy Locations Breakdown
  Future<List<dynamic>> fetchEnergyLocations({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/energy-usage/locations$q');
      return (res['locations'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 82. Fetch Energy Device Types Breakdown
  Future<List<dynamic>> fetchEnergyDeviceTypes({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/energy-usage/device-types$q');
      return (res['categories'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 83. Fetch Energy Cost Analysis
  Future<Map<String, dynamic>> fetchEnergyCostAnalysis({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/energy-usage/cost-analysis$q');
    } catch (_) {}
    return {};
  }

  /// 84. Fetch Energy Meters
  Future<List<dynamic>> fetchEnergyMeters({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/energy-usage/meters$q');
      return (res['meters'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 85. Fetch Energy Reports
  Future<List<dynamic>> fetchEnergyReports({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/energy-usage/reports$q');
      return (res['reports'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// -------------------------------------------------------------------------
  /// DEVICE HEALTH & DIAGNOSTICS SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 86. Fetch Health Dashboard
  Future<Map<String, dynamic>> fetchHealthDashboard({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/health-diagnostics/dashboard$q');
    } catch (_) {}
    return {};
  }

  /// 87. Fetch Health Devices
  Future<Map<String, dynamic>> fetchHealthDevices({
    String? schoolId,
    int page = 1,
    int pageSize = 50,
    String? search,
    String? status,
    String? type,
    String? location,
    String? group,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'All Health Status') 'status': status,
        if (type != null && type != 'All Device Types') 'type': type,
        if (location != null && location != 'All Locations') 'location': location,
        if (group != null && group != 'All Groups') 'group': group,
      };
      return await _api.get('/v1/devices/health-diagnostics/devices', query: q);
    } catch (_) {}
    return {};
  }

  /// 88. Fetch Health Gateways
  Future<List<dynamic>> fetchHealthGateways({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/health-diagnostics/gateways$q');
      return (res['gateways'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 89. Fetch Health Rules
  Future<List<dynamic>> fetchHealthRules({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/health-diagnostics/rules$q');
      return (res['rules'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 90. Run Device Diagnostics
  Future<Map<String, dynamic>> runDeviceDiagnostics(
    String deviceId, {
    String? schoolId,
    List<String>? tests,
  }) async {
    try {
      return await _api.post('/v1/devices/health-diagnostics/run-diagnostic', {
        'device_id': deviceId,
        if (schoolId != null) 'school_id': schoolId,
        if (tests != null) 'tests': tests,
      });
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 91. Reboot Device Health
  Future<Map<String, dynamic>> rebootDeviceHealth(String deviceId, {String? schoolId}) async {
    try {
      return await _api.post('/v1/devices/health-diagnostics/reboot', {
        'device_id': deviceId,
        if (schoolId != null) 'school_id': schoolId,
      });
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 92. Update Device Firmware Health
  Future<Map<String, dynamic>> updateDeviceFirmwareHealth(
    String deviceId, {
    String? schoolId,
    String? targetVersion,
  }) async {
    try {
      return await _api.post('/v1/devices/health-diagnostics/update-firmware', {
        'device_id': deviceId,
        if (schoolId != null) 'school_id': schoolId,
        if (targetVersion != null) 'target_version': targetVersion,
      });
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// -------------------------------------------------------------------------
  /// INTEGRATIONS & GATEWAYS SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 93. Fetch Integrations Dashboard
  Future<Map<String, dynamic>> fetchIntegrationsDashboard({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/integrations-gateways/dashboard$q');
    } catch (_) {}
    return {};
  }

  /// 94. Fetch Gateways List
  Future<List<dynamic>> fetchGatewaysList({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/integrations-gateways/gateways$q');
      return (res['gateways'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 95. Fetch Integrations List
  Future<List<dynamic>> fetchIntegrationsList({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/integrations-gateways/integrations$q');
      return (res['integrations'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 96. Restart Gateway
  Future<Map<String, dynamic>> restartGateway(String gatewayId, {String? schoolId}) async {
    try {
      return await _api.post('/v1/devices/integrations-gateways/gateways/$gatewayId/restart', {
        if (schoolId != null) 'school_id': schoolId,
      });
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// -------------------------------------------------------------------------
  /// ACCESS & PERMISSIONS SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 97. Fetch Access Permissions Dashboard
  Future<Map<String, dynamic>> fetchAccessPermissionsDashboard({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/access-permissions/dashboard$q');
    } catch (_) {}
    return {};
  }

  /// 98. Fetch Access Roles
  Future<List<dynamic>> fetchAccessRoles({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/access-permissions/roles$q');
      return (res['roles'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 99. Fetch Access Users (Joined with Profiles from Users Management)
  Future<Map<String, dynamic>> fetchAccessUsers({
    String? schoolId,
    int page = 1,
    int pageSize = 10,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'page': page,
        'page_size': pageSize,
        if (role != null && role != 'All Roles') 'role': role,
        if (status != null && status != 'All Status') 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      };
      return await _api.get('/v1/devices/access-permissions/users', query: q);
    } catch (_) {}
    return {};
  }

  /// 100. Assign User Access Role / Group
  Future<Map<String, dynamic>> assignUserAccess(String userId, Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/devices/access-permissions/users/$userId/assign', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// -------------------------------------------------------------------------
  /// AUDIT LOGS SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 101. Fetch Audit Logs Dashboard
  Future<Map<String, dynamic>> fetchAuditLogsDashboard({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/audit-logs/dashboard$q');
    } catch (_) {}
    return {};
  }

  /// 102. Fetch Audit Logs Entries
  Future<Map<String, dynamic>> fetchAuditLogsEntries({
    String? schoolId,
    int page = 1,
    int limit = 10,
    String? eventType,
    String? search,
    String? user,
    String? deviceType,
    String? location,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'page': page,
        'limit': limit,
        if (eventType != null && eventType != 'All Event Types') 'event_type': eventType,
        if (search != null && search.isNotEmpty) 'search': search,
        if (user != null && user != 'All Users') 'user': user,
        if (deviceType != null && deviceType != 'All Device Types') 'device_type': deviceType,
        if (location != null && location != 'All Locations') 'location': location,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };
      return await _api.get('/v1/devices/audit-logs', query: q);
    } catch (_) {}
    return {};
  }

  /// 103. Fetch Audit Retention Policies
  Future<List<dynamic>> fetchAuditRetentionPolicies({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/audit-logs/retention-policies$q');
      return (res['policies'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 104. Fetch Audit Reports
  Future<List<dynamic>> fetchAuditReports({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/audit-logs/reports$q');
      return (res['reports'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// -------------------------------------------------------------------------
  /// IMPORT / EXPORT SERVICE METHODS
  /// -------------------------------------------------------------------------

  /// 105. Fetch Import / Export Overview
  Future<Map<String, dynamic>> fetchImportExportOverview({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      return await _api.get('/v1/devices/import-export/overview$q');
    } catch (_) {}
    return {};
  }

  /// 106. Fetch Import / Export Operations
  Future<Map<String, dynamic>> fetchImportExportOperations({
    String? schoolId,
    int page = 1,
    int pageSize = 10,
    String? operationType,
    String? status,
    String? search,
  }) async {
    try {
      final q = <String, dynamic>{
        if (schoolId != null) 'school_id': schoolId,
        'page': page,
        'page_size': pageSize,
        if (operationType != null && operationType != 'All Operations') 'operation_type': operationType,
        if (status != null && status != 'All Status') 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      };
      return await _api.get('/v1/devices/import-export/operations', query: q);
    } catch (_) {}
    return {};
  }

  /// 107. Fetch Import / Export Schedules
  Future<List<dynamic>> fetchImportExportSchedules({String? schoolId}) async {
    try {
      final q = schoolId != null ? '?school_id=$schoolId' : '';
      final res = await _api.get('/v1/devices/import-export/schedules$q');
      return (res['schedules'] as List?) ?? [];
    } catch (_) {}
    return [];
  }

  /// 108. Execute Device Export
  Future<Map<String, dynamic>> executeDeviceExport(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/devices/import-export/execute-export', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 109. Execute Device Import
  Future<Map<String, dynamic>> executeDeviceImport(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/devices/import-export/execute-import', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 110. Create Import / Export Schedule
  Future<Map<String, dynamic>> createImportExportSchedule(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/v1/devices/import-export/schedules', payload);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final deviceManagementApiServiceProvider = Provider<DeviceManagementApiService>((ref) {
  return DeviceManagementApiService.instance;
});
