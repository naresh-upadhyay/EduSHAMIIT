import 'package:flutter/material.dart';

class DeviceManagementKpis {
  final int totalDevices;
  final int online;
  final int offline;
  final double onlinePercentage;
  final int deviceTypes;
  final String locationsSummary;
  final int buildingsCount;
  final int floorsCount;
  final int roomsCount;
  final int automationsActive;
  final int schedulesCount;
  final int alertsCount;

  const DeviceManagementKpis({
    this.totalDevices = 8742,
    this.online = 8342,
    this.offline = 400,
    this.onlinePercentage = 95.4,
    this.deviceTypes = 24,
    this.locationsSummary = '6 Buildings • 42 Floors',
    this.buildingsCount = 6,
    this.floorsCount = 42,
    this.roomsCount = 120,
    this.automationsActive = 128,
    this.schedulesCount = 276,
    this.alertsCount = 18,
  });

  factory DeviceManagementKpis.fromJson(Map<String, dynamic> json) {
    return DeviceManagementKpis(
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 8742,
      online: (json['online'] as num?)?.toInt() ?? 8342,
      offline: (json['offline'] as num?)?.toInt() ?? 400,
      onlinePercentage: (json['online_percentage'] as num?)?.toDouble() ?? 95.4,
      deviceTypes: (json['device_types'] as num?)?.toInt() ?? 24,
      locationsSummary: (json['locations_summary'] as String?) ?? '6 Buildings • 42 Floors',
      buildingsCount: (json['buildings_count'] as num?)?.toInt() ?? 6,
      floorsCount: (json['floors_count'] as num?)?.toInt() ?? 42,
      roomsCount: (json['rooms_count'] as num?)?.toInt() ?? 120,
      automationsActive: (json['automations_active'] as num?)?.toInt() ?? 128,
      schedulesCount: (json['schedules_count'] as num?)?.toInt() ?? 276,
      alertsCount: (json['alerts_count'] as num?)?.toInt() ?? 18,
    );
  }
}

class BuildingDeviceBreakdown {
  final String code;
  final String name;
  final int totalDevices;
  final int onlineDevices;
  final double onlinePct;

  const BuildingDeviceBreakdown({
    required this.code,
    required this.name,
    required this.totalDevices,
    required this.onlineDevices,
    required this.onlinePct,
  });

  factory BuildingDeviceBreakdown.fromJson(Map<String, dynamic> json) {
    return BuildingDeviceBreakdown(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 0,
      onlineDevices: (json['online_devices'] as num?)?.toInt() ?? 0,
      onlinePct: (json['online_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DeviceTypeBreakdown {
  final String type;
  final int count;
  final double percentage;
  final String colorHex;
  final String icon;

  const DeviceTypeBreakdown({
    required this.type,
    required this.count,
    required this.percentage,
    required this.colorHex,
    required this.icon,
  });

  factory DeviceTypeBreakdown.fromJson(Map<String, dynamic> json) {
    return DeviceTypeBreakdown(
      type: json['type'] ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color'] ?? '#2563EB',
      icon: json['icon'] ?? 'devices',
    );
  }
}

class EnergyDataPoint {
  final String time;
  final double loadKw;
  final double consumptionKwh;

  const EnergyDataPoint({
    required this.time,
    required this.loadKw,
    required this.consumptionKwh,
  });

  factory EnergyDataPoint.fromJson(Map<String, dynamic> json) {
    return EnergyDataPoint(
      time: json['time'] ?? '',
      loadKw: (json['load_kw'] as num?)?.toDouble() ?? 0.0,
      consumptionKwh: (json['consumption_kwh'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ActiveAutomationItem {
  final String id;
  final String name;
  final String description;
  final String triggerType;
  final bool isActive;
  final int executionCount;

  const ActiveAutomationItem({
    required this.id,
    required this.name,
    required this.description,
    required this.triggerType,
    required this.isActive,
    this.executionCount = 0,
  });

  factory ActiveAutomationItem.fromJson(Map<String, dynamic> json) {
    return ActiveAutomationItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      triggerType: json['trigger_type'] ?? '',
      isActive: json['is_active'] ?? true,
      executionCount: (json['execution_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceSceneStep {
  final int order;
  final String targetName;
  final String targetType;
  final String action;
  final String icon;
  final int delaySeconds;
  final Map<String, dynamic>? parameters;

  const DeviceSceneStep({
    required this.order,
    required this.targetName,
    this.targetType = 'device',
    required this.action,
    this.icon = 'lightbulb',
    this.delaySeconds = 0,
    this.parameters,
  });

  factory DeviceSceneStep.fromJson(Map<String, dynamic> json) {
    return DeviceSceneStep(
      order: (json['order'] as num?)?.toInt() ?? 1,
      targetName: json['target_name']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? 'device',
      action: json['action']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'lightbulb',
      delaySeconds: (json['delay_seconds'] as num?)?.toInt() ?? 0,
      parameters: json['parameters'] != null ? Map<String, dynamic>.from(json['parameters']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'target_name': targetName,
      'target_type': targetType,
      'action': action,
      'icon': icon,
      'delay_seconds': delaySeconds,
      if (parameters != null) 'parameters': parameters,
    };
  }
}

class DeviceSceneItem {
  final String id;
  final String sceneCode;
  final String name;
  final String code;
  final String category;
  final String sceneType; // scene, preset
  final String targetType;
  final String targetName;
  final int targetCount;
  final String locationScope;
  final List<String> tags;
  final String description;
  final String icon;
  final String colorHex;
  String get color => colorHex;
  final bool isPreset;
  final bool isActive;
  final String status; // active, disabled
  final String createdByName;
  final int executionCount;
  final int usedInAutomationsCount;
  final int usedInSchedulesCount;
  final bool isPopular;
  final String? thumbnailUrl;
  final List<DeviceSceneStep> steps;
  final String? lastAppliedAt;
  final String? createdAt;
  final String? updatedAt;

  const DeviceSceneItem({
    required this.id,
    required this.name,
    this.code = '',
    this.sceneCode = 'SCN-001',
    this.category = 'academic',
    this.sceneType = 'scene',
    this.targetType = 'devices',
    this.targetName = '8 devices',
    this.targetCount = 8,
    this.locationScope = 'Classroom / Academic Block',
    this.tags = const ['Scene', 'Academic'],
    this.description = '',
    this.icon = 'wb_sunny_rounded',
    String? color,
    String? colorHex,
    this.isPreset = false,
    this.isActive = true,
    this.status = 'active',
    this.createdByName = 'Admin',
    this.executionCount = 0,
    this.usedInAutomationsCount = 2,
    this.usedInSchedulesCount = 3,
    this.isPopular = false,
    this.thumbnailUrl,
    this.steps = const [],
    this.lastAppliedAt,
    this.createdAt,
    this.updatedAt,
  }) : colorHex = colorHex ?? color ?? '#2563EB';

  factory DeviceSceneItem.fromJson(Map<String, dynamic> json) {
    var rawSteps = json['steps'] as List? ?? [];
    var stepsList = rawSteps.map((e) {
      if (e is Map<String, dynamic>) {
        return DeviceSceneStep.fromJson(e);
      } else if (e is Map) {
        return DeviceSceneStep.fromJson(Map<String, dynamic>.from(e));
      }
      return DeviceSceneStep(order: 1, targetName: e.toString(), action: 'Execute');
    }).toList();

    var rawTags = json['tags'] as List? ?? ['Scene', 'Academic'];
    var tagsList = rawTags.map((e) => e.toString()).toList();
    final cHex = json['color']?.toString() ?? json['colorHex']?.toString() ?? '#2563EB';

    return DeviceSceneItem(
      id: json['id']?.toString() ?? '',
      sceneCode: json['scene_code']?.toString() ?? 'SCN-001',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? 'academic',
      sceneType: json['scene_type']?.toString() ?? (json['is_preset'] == true ? 'preset' : 'scene'),
      targetType: json['target_type']?.toString() ?? 'devices',
      targetName: json['target_name']?.toString() ?? '8 devices',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 8,
      locationScope: json['location_scope']?.toString() ?? 'Classroom / Academic Block',
      tags: tagsList,
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'wb_sunny_rounded',
      colorHex: cHex,
      isPreset: json['is_preset'] == true || json['scene_type'] == 'preset',
      isActive: json['is_active'] != false && json['status'] != 'disabled',
      status: json['status']?.toString() ?? 'active',
      createdByName: json['created_by_name']?.toString() ?? 'Admin',
      executionCount: (json['execution_count'] as num?)?.toInt() ?? 0,
      usedInAutomationsCount: (json['used_in_automations_count'] as num?)?.toInt() ?? 2,
      usedInSchedulesCount: (json['used_in_schedules_count'] as num?)?.toInt() ?? 3,
      isPopular: json['is_popular'] == true,
      thumbnailUrl: json['thumbnail_url']?.toString(),
      steps: stepsList,
      lastAppliedAt: json['last_applied_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  DeviceSceneItem copyWith({
    String? id,
    String? sceneCode,
    String? name,
    String? code,
    String? category,
    String? sceneType,
    String? targetType,
    String? targetName,
    int? targetCount,
    String? locationScope,
    List<String>? tags,
    String? description,
    String? icon,
    String? color,
    String? colorHex,
    bool? isPreset,
    bool? isActive,
    String? status,
    String? createdByName,
    int? executionCount,
    int? usedInAutomationsCount,
    int? usedInSchedulesCount,
    bool? isPopular,
    String? thumbnailUrl,
    List<DeviceSceneStep>? steps,
    String? lastAppliedAt,
    String? createdAt,
    String? updatedAt,
  }) {
    return DeviceSceneItem(
      id: id ?? this.id,
      sceneCode: sceneCode ?? this.sceneCode,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      sceneType: sceneType ?? this.sceneType,
      targetType: targetType ?? this.targetType,
      targetName: targetName ?? this.targetName,
      targetCount: targetCount ?? this.targetCount,
      locationScope: locationScope ?? this.locationScope,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? color ?? this.colorHex,
      isPreset: isPreset ?? this.isPreset,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      createdByName: createdByName ?? this.createdByName,
      executionCount: executionCount ?? this.executionCount,
      usedInAutomationsCount: usedInAutomationsCount ?? this.usedInAutomationsCount,
      usedInSchedulesCount: usedInSchedulesCount ?? this.usedInSchedulesCount,
      isPopular: isPopular ?? this.isPopular,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      steps: steps ?? this.steps,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DeviceAlertItem {
  final String id;
  final String title;
  final String description;
  final String severity; // critical, warning, info
  final bool isResolved;
  final String? createdAt;

  const DeviceAlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    this.isResolved = false,
    this.createdAt,
  });

  factory DeviceAlertItem.fromJson(Map<String, dynamic> json) {
    return DeviceAlertItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'warning',
      isResolved: json['is_resolved'] ?? false,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class DeviceItemModel {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String typeName;
  final String typeCode;
  final String typeIcon;
  final String? buildingCode;
  final String? floorCode;
  final String? roomNumber;
  final String locationDisplay;
  final bool isOnline;
  final bool powerState;
  final Map<String, dynamic> currentState;
  final String operationalStatus;
  final String? ipAddress;
  final String? macAddress;
  final double ratedPowerWatts;
  final String? notes;

  const DeviceItemModel({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.typeName,
    required this.typeCode,
    required this.typeIcon,
    this.buildingCode,
    this.floorCode,
    this.roomNumber,
    required this.locationDisplay,
    required this.isOnline,
    required this.powerState,
    required this.currentState,
    this.operationalStatus = 'operational',
    this.ipAddress,
    this.macAddress,
    this.ratedPowerWatts = 0.0,
    this.notes,
  });

  factory DeviceItemModel.fromJson(Map<String, dynamic> json) {
    return DeviceItemModel(
      id: json['id'] ?? '',
      deviceName: json['device_name'] ?? '',
      deviceCode: json['device_code'] ?? '',
      typeName: json['type_name'] ?? 'Device',
      typeCode: json['type_code'] ?? 'device',
      typeIcon: json['type_icon'] ?? 'devices',
      buildingCode: json['building_code'],
      floorCode: json['floor_code'],
      roomNumber: json['room_number'],
      locationDisplay: json['location_display'] ?? '',
      isOnline: json['is_online'] ?? true,
      powerState: json['power_state'] ?? true,
      currentState: json['current_state'] is Map
          ? Map<String, dynamic>.from(json['current_state'] as Map)
          : {},
      operationalStatus: json['operational_status'] ?? 'operational',
      ipAddress: json['ip_address'],
      macAddress: json['mac_address'],
      ratedPowerWatts: (json['rated_power_watts'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }

  DeviceItemModel copyWith({
    String? deviceName,
    String? deviceCode,
    String? typeName,
    String? typeCode,
    String? typeIcon,
    String? buildingCode,
    String? floorCode,
    String? roomNumber,
    String? locationDisplay,
    bool? isOnline,
    bool? powerState,
    Map<String, dynamic>? currentState,
    String? operationalStatus,
    String? ipAddress,
    String? macAddress,
    double? ratedPowerWatts,
    String? notes,
  }) {
    return DeviceItemModel(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      deviceCode: deviceCode ?? this.deviceCode,
      typeName: typeName ?? this.typeName,
      typeCode: typeCode ?? this.typeCode,
      typeIcon: typeIcon ?? this.typeIcon,
      buildingCode: buildingCode ?? this.buildingCode,
      floorCode: floorCode ?? this.floorCode,
      roomNumber: roomNumber ?? this.roomNumber,
      locationDisplay: locationDisplay ?? this.locationDisplay,
      isOnline: isOnline ?? this.isOnline,
      powerState: powerState ?? this.powerState,
      currentState: currentState ?? this.currentState,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      ratedPowerWatts: ratedPowerWatts ?? this.ratedPowerWatts,
      notes: notes ?? this.notes,
    );
  }
}

class LocationTreeNode {
  final String id;
  final String code;
  final String name;
  final int deviceCount;
  final List<LocationTreeNode> children;
  final bool isExpanded;

  const LocationTreeNode({
    required this.id,
    required this.code,
    required this.name,
    required this.deviceCount,
    this.children = const [],
    this.isExpanded = false,
  });

  factory LocationTreeNode.fromJson(Map<String, dynamic> json) {
    List<LocationTreeNode> childList = [];
    if (json['buildings'] is List) {
      childList = (json['buildings'] as List)
          .map((b) => LocationTreeNode.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList();
    } else if (json['floors'] is List) {
      childList = (json['floors'] as List)
          .map((f) => LocationTreeNode.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList();
    } else if (json['rooms'] is List) {
      childList = (json['rooms'] as List)
          .map((r) => LocationTreeNode(
                id: r['id'] ?? '',
                code: r['room_number'] ?? '',
                name: 'Room ${r['room_number']} - ${r['name'] ?? ''}',
                deviceCount: (r['device_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }

    return LocationTreeNode(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      deviceCount: (json['device_count'] as num?)?.toInt() ??
          (json['total_devices'] as num?)?.toInt() ??
          0,
      children: childList,
      isExpanded: childList.isNotEmpty,
    );
  }
}


/// Device Types & Profiles KPI Summary
class DeviceTypesProfilesKpis {
  final int totalDeviceTypes;
  final int activeProfiles;
  final int defaultProfiles;
  final int customProfiles;
  final int mappedDevices;
  final double complianceRate;

  const DeviceTypesProfilesKpis({
    this.totalDeviceTypes = 24,
    this.activeProfiles = 76,
    this.defaultProfiles = 24,
    this.customProfiles = 52,
    this.mappedDevices = 8742,
    this.complianceRate = 95.4,
  });

  factory DeviceTypesProfilesKpis.fromJson(Map<String, dynamic> json) {
    return DeviceTypesProfilesKpis(
      totalDeviceTypes: (json['total_device_types'] as num?)?.toInt() ?? 24,
      activeProfiles: (json['active_profiles'] as num?)?.toInt() ?? 76,
      defaultProfiles: (json['default_profiles'] as num?)?.toInt() ?? 24,
      customProfiles: (json['custom_profiles'] as num?)?.toInt() ?? 52,
      mappedDevices: (json['mapped_devices'] as num?)?.toInt() ?? 8742,
      complianceRate: (json['compliance_rate'] as num?)?.toDouble() ?? 95.4,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_device_types': totalDeviceTypes,
    'active_profiles': activeProfiles,
    'default_profiles': defaultProfiles,
    'custom_profiles': customProfiles,
    'mapped_devices': mappedDevices,
    'compliance_rate': complianceRate,
  };
}

/// Control Profile item belonging to a device type
class DeviceProfileItem {
  final String id;
  final String deviceTypeId;
  final String? deviceTypeName;
  final String? deviceTypeCode;
  final String? deviceTypeIcon;
  final String? deviceTypeColor;
  final String? categoryName;
  final String name;
  final String code;
  final String profileType; // 'default' or 'custom'
  final String? manufacturer;
  final String? model;
  final String description;
  final String version;
  final String status; // 'active', 'inactive', 'archived'
  final bool isDefault;
  final int usageCount;
  final Map<String, dynamic> capabilitiesOverride;
  final Map<String, dynamic> defaultSettings;
  final Map<String, dynamic> protocolConfig;
  final Map<String, dynamic> safetyLimits;
  final String? createdAt;
  final String? updatedAt;

  const DeviceProfileItem({
    required this.id,
    required this.deviceTypeId,
    this.deviceTypeName,
    this.deviceTypeCode,
    this.deviceTypeIcon,
    this.deviceTypeColor,
    this.categoryName,
    required this.name,
    required this.code,
    this.profileType = 'custom',
    this.manufacturer,
    this.model,
    this.description = '',
    this.version = '1.0.0',
    this.status = 'active',
    this.isDefault = false,
    this.usageCount = 0,
    this.capabilitiesOverride = const {},
    this.defaultSettings = const {},
    this.protocolConfig = const {},
    this.safetyLimits = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceProfileItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parseMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      return {};
    }

    return DeviceProfileItem(
      id: json['id']?.toString() ?? '',
      deviceTypeId: json['device_type_id']?.toString() ?? '',
      deviceTypeName: json['device_type_name']?.toString(),
      deviceTypeCode: json['device_type_code']?.toString(),
      deviceTypeIcon: json['device_type_icon']?.toString(),
      deviceTypeColor: json['device_type_color']?.toString(),
      categoryName: json['category_name']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      profileType: json['profile_type']?.toString() ?? 'custom',
      manufacturer: json['manufacturer']?.toString(),
      model: json['model']?.toString(),
      description: json['description']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0.0',
      status: json['status']?.toString() ?? 'active',
      isDefault: json['is_default'] == true,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      capabilitiesOverride: parseMap(json['capabilities_override']),
      defaultSettings: parseMap(json['default_settings']),
      protocolConfig: parseMap(json['protocol_config']),
      safetyLimits: parseMap(json['safety_limits']),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_type_id': deviceTypeId,
    'name': name,
    'code': code,
    'profile_type': profileType,
    'manufacturer': manufacturer,
    'model': model,
    'description': description,
    'version': version,
    'status': status,
    'is_default': isDefault,
    'usage_count': usageCount,
    'capabilities_override': capabilitiesOverride,
    'default_settings': defaultSettings,
    'protocol_config': protocolConfig,
    'safety_limits': safetyLimits,
  };
}

/// Device Type Detail Item
class DeviceTypeDetailItem {
  final String id;
  final String name;
  final String code;
  final String? categoryId;
  final String categoryName;
  final String categoryCode;
  final String categoryColor;
  final String systemCategory;
  final String description;
  final String icon;
  final String color;
  final String protocol;
  final List<String> supportedProtocols;
  final String? manufacturer;
  final List<String> supportedModels;
  final List<String> tags;
  final String? docUrl;
  final List<String> defaultCapabilities;
  final int mappedDevicesCount;
  final int profilesCount;
  final bool isActive;
  final String status;
  final String? updatedAt;
  final List<DeviceProfileItem> profiles;

  const DeviceTypeDetailItem({
    required this.id,
    required this.name,
    required this.code,
    this.categoryId,
    this.categoryName = 'General',
    this.categoryCode = 'general',
    this.categoryColor = '#2563EB',
    this.systemCategory = 'General',
    this.description = '',
    this.icon = 'devices',
    this.color = '#2563EB',
    this.protocol = 'MQTT',
    this.supportedProtocols = const ['MQTT'],
    this.manufacturer,
    this.supportedModels = const [],
    this.tags = const [],
    this.docUrl,
    this.defaultCapabilities = const [],
    this.mappedDevicesCount = 0,
    this.profilesCount = 1,
    this.isActive = true,
    this.status = 'Active',
    this.updatedAt,
    this.profiles = const [],
  });

  factory DeviceTypeDetailItem.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<DeviceProfileItem> parseProfiles(dynamic val) {
      if (val is List) {
        return val.map((e) => DeviceProfileItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      return [];
    }

    return DeviceTypeDetailItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name']?.toString() ?? json['system_category']?.toString() ?? 'General',
      categoryCode: json['category_code']?.toString() ?? 'general',
      categoryColor: json['category_color']?.toString() ?? json['color']?.toString() ?? '#2563EB',
      systemCategory: json['system_category']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'devices',
      color: json['color']?.toString() ?? '#2563EB',
      protocol: json['protocol']?.toString() ?? 'MQTT',
      supportedProtocols: parseStringList(json['supported_protocols']),
      manufacturer: json['manufacturer']?.toString(),
      supportedModels: parseStringList(json['supported_models']),
      tags: parseStringList(json['tags']),
      docUrl: json['doc_url']?.toString(),
      defaultCapabilities: parseStringList(json['default_capabilities']),
      mappedDevicesCount: (json['mapped_devices_count'] as num?)?.toInt() ?? 0,
      profilesCount: (json['profiles_count'] as num?)?.toInt() ?? 1,
      isActive: json['is_active'] != false,
      status: json['status']?.toString() ?? ((json['is_active'] != false) ? 'Active' : 'Inactive'),
      updatedAt: json['updated_at']?.toString(),
      profiles: parseProfiles(json['profiles']),
    );
  }

  DeviceTypeDetailItem copyWith({
    String? id,
    String? name,
    String? code,
    String? categoryId,
    String? categoryName,
    String? categoryCode,
    String? categoryColor,
    String? systemCategory,
    String? description,
    String? icon,
    String? color,
    String? protocol,
    List<String>? supportedProtocols,
    String? manufacturer,
    List<String>? supportedModels,
    List<String>? tags,
    String? docUrl,
    List<String>? defaultCapabilities,
    int? mappedDevicesCount,
    int? profilesCount,
    bool? isActive,
    String? status,
    String? updatedAt,
    List<DeviceProfileItem>? profiles,
  }) {
    return DeviceTypeDetailItem(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryCode: categoryCode ?? this.categoryCode,
      categoryColor: categoryColor ?? this.categoryColor,
      systemCategory: systemCategory ?? this.systemCategory,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      protocol: protocol ?? this.protocol,
      supportedProtocols: supportedProtocols ?? this.supportedProtocols,
      manufacturer: manufacturer ?? this.manufacturer,
      supportedModels: supportedModels ?? this.supportedModels,
      tags: tags ?? this.tags,
      docUrl: docUrl ?? this.docUrl,
      defaultCapabilities: defaultCapabilities ?? this.defaultCapabilities,
      mappedDevicesCount: mappedDevicesCount ?? this.mappedDevicesCount,
      profilesCount: profilesCount ?? this.profilesCount,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      profiles: profiles ?? this.profiles,
    );
  }
}

/// Standard Capability Catalog Item
class CapabilityTemplateItem {
  final String id;
  final String name;
  final String code;
  final String type; // switch, slider, stepper, dropdown, segmented, ptz, action_buttons, telemetry
  final String dataType; // boolean, number, string, object
  final String category;
  final String icon;
  final String description;
  final String? unit;
  final dynamic defaultValue;
  final List<String> options;
  final double? min;
  final double? max;
  final double? step;

  const CapabilityTemplateItem({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.dataType,
    required this.category,
    required this.icon,
    this.description = '',
    this.unit,
    this.defaultValue,
    this.options = const [],
    this.min,
    this.max,
    this.step,
  });

  factory CapabilityTemplateItem.fromJson(Map<String, dynamic> json) {
    List<String> parseOpts(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return CapabilityTemplateItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'switch',
      dataType: json['data_type']?.toString() ?? 'boolean',
      category: json['category']?.toString() ?? 'General',
      icon: json['icon']?.toString() ?? 'settings',
      description: json['description']?.toString() ?? '',
      unit: json['unit']?.toString(),
      defaultValue: json['default_value'],
      options: parseOpts(json['options']),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      step: (json['step'] as num?)?.toDouble(),
    );
  }
}

/// Device Groups KPI Summary
class DeviceGroupsKpis {
  final int totalGroups;
  final int activeGroups;
  final double activePercentage;
  final int inactiveGroups;
  final int totalDevices;
  final int groupedDevices;
  final double groupedPercentage;
  final int ungroupedDevices;
  final double ungroupedPercentage;

  double get activeGroupsPct => activePercentage;
  double get groupedDevicesPct => groupedPercentage;
  double get ungroupedDevicesPct => ungroupedPercentage;

  const DeviceGroupsKpis({
    this.totalGroups = 128,
    this.activeGroups = 118,
    this.activePercentage = 92.2,
    this.inactiveGroups = 10,
    this.totalDevices = 8742,
    this.groupedDevices = 8296,
    this.groupedPercentage = 95.0,
    this.ungroupedDevices = 446,
    this.ungroupedPercentage = 5.0,
  });

  factory DeviceGroupsKpis.fromJson(Map<String, dynamic> json) {
    return DeviceGroupsKpis(
      totalGroups: (json['total_groups'] as num?)?.toInt() ?? 128,
      activeGroups: (json['active_groups'] as num?)?.toInt() ?? 118,
      activePercentage: (json['active_percentage'] as num?)?.toDouble() ?? 92.2,
      inactiveGroups: (json['inactive_groups'] as num?)?.toInt() ?? 10,
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 8742,
      groupedDevices: (json['grouped_devices'] as num?)?.toInt() ?? 8296,
      groupedPercentage: (json['grouped_percentage'] as num?)?.toDouble() ?? 95.0,
      ungroupedDevices: (json['ungrouped_devices'] as num?)?.toInt() ?? 446,
      ungroupedPercentage: (json['ungrouped_percentage'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

/// Device Group Item Model
class DeviceGroupItem {
  final String id;
  final String name;
  final String code;
  final String description;
  final String groupType;
  final String icon;
  final String color;
  final String status;
  final String locationScope;
  final String profileName;
  final int deviceCount;
  final int onlineCount;
  final int offlineCount;
  final int schedulesCount;
  final int automationsCount;
  final int scenesCount;
  final String createdAtFormatted;
  final String updatedAtFormatted;
  final Map<String, dynamic> resolvedCapabilities;
  final List<Map<String, dynamic>> advancedControls;
  final List<String> deviceIds;

  int get memberCount => deviceCount;
  String get createdOn => createdAtFormatted;
  String get lastUpdated => updatedAtFormatted;

  const DeviceGroupItem({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.groupType = 'Composite',
    this.icon = 'grid_view',
    this.color = '#2563EB',
    this.status = 'active',
    this.locationScope = 'Entire Campus',
    this.profileName = 'Default Profile',
    this.deviceCount = 0,
    this.onlineCount = 0,
    this.offlineCount = 0,
    this.schedulesCount = 0,
    this.automationsCount = 0,
    this.scenesCount = 0,
    this.createdAtFormatted = '',
    this.updatedAtFormatted = '',
    this.resolvedCapabilities = const {},
    this.advancedControls = const [],
    this.deviceIds = const [],
  });

  factory DeviceGroupItem.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseListMap(dynamic val) {
      if (val is List) {
        return val.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }

    List<String> parseStrings(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, dynamic> parseMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      return {};
    }

    return DeviceGroupItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      groupType: json['group_type']?.toString() ?? 'Composite',
      icon: json['icon']?.toString() ?? 'grid_view',
      color: json['color']?.toString() ?? '#2563EB',
      status: json['status']?.toString() ?? 'active',
      locationScope: json['location_scope']?.toString() ?? 'Entire Campus',
      profileName: json['profile_name']?.toString() ?? 'Default Profile',
      deviceCount: (json['device_count'] as num?)?.toInt() ??
          (json['devices'] as num?)?.toInt() ??
          (json['member_count'] as num?)?.toInt() ??
          0,
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      offlineCount: (json['offline_count'] as num?)?.toInt() ?? 0,
      schedulesCount: (json['schedules_count'] as num?)?.toInt() ?? 0,
      automationsCount: (json['automations_count'] as num?)?.toInt() ?? 0,
      scenesCount: (json['scenes_count'] as num?)?.toInt() ?? 0,
      createdAtFormatted: json['created_on']?.toString() ??
          json['created_at_formatted']?.toString() ??
          json['created_at']?.toString() ??
          '',
      updatedAtFormatted: json['last_updated']?.toString() ??
          json['updated_at_formatted']?.toString() ??
          json['updated_at']?.toString() ??
          '',
      resolvedCapabilities: parseMap(json['resolved_capabilities']),
      advancedControls: parseListMap(json['advanced_controls']),
      deviceIds: parseStrings(json['device_ids']),
    );
  }
}


// ============================================================================
// LOCATIONS & SPATIAL MAPPING MODELS
// ============================================================================

class LocationsMappingKpis {
  final int buildings;
  final int floors;
  final int rooms;
  final int totalDevices;
  final int mappedDevices;
  final double mappedPct;
  final int unmappedDevices;
  final double unmappedPct;
  final int locationsWithDevices;
  final double coveragePct;

  const LocationsMappingKpis({
    this.buildings = 0,
    this.floors = 0,
    this.rooms = 0,
    this.totalDevices = 0,
    this.mappedDevices = 0,
    this.mappedPct = 0.0,
    this.unmappedDevices = 0,
    this.unmappedPct = 0.0,
    this.locationsWithDevices = 0,
    this.coveragePct = 0.0,
  });

  factory LocationsMappingKpis.fromJson(Map<String, dynamic> json) {
    return LocationsMappingKpis(
      buildings: (json['buildings'] as num?)?.toInt() ?? 0,
      floors: (json['floors'] as num?)?.toInt() ?? 0,
      rooms: (json['rooms'] as num?)?.toInt() ?? 0,
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 0,
      mappedDevices: (json['mapped_devices'] as num?)?.toInt() ?? 0,
      mappedPct: (json['mapped_pct'] as num?)?.toDouble() ?? 0.0,
      unmappedDevices: (json['unmapped_devices'] as num?)?.toInt() ?? 0,
      unmappedPct: (json['unmapped_pct'] as num?)?.toDouble() ?? 0.0,
      locationsWithDevices: (json['locations_with_devices'] as num?)?.toInt() ?? 0,
      coveragePct: (json['coverage_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'buildings': buildings,
    'floors': floors,
    'rooms': rooms,
    'total_devices': totalDevices,
    'mapped_devices': mappedDevices,
    'mapped_pct': mappedPct,
    'unmapped_devices': unmappedDevices,
    'unmapped_pct': unmappedPct,
    'locations_with_devices': locationsWithDevices,
    'coverage_pct': coveragePct,
  };
}

class LocationHierarchyNode {
  final String id;
  final String name;
  final String code;
  final String type; // campus, building, floor, room
  final String? buildingId;
  final int deviceCount;
  final int roomCount;
  final int level;
  final List<LocationHierarchyNode> children;

  const LocationHierarchyNode({
    required this.id,
    required this.name,
    this.code = '',
    this.type = 'floor',
    this.buildingId,
    this.deviceCount = 0,
    this.roomCount = 0,
    this.level = 0,
    this.children = const [],
  });

  factory LocationHierarchyNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List? ?? [];
    return LocationHierarchyNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'floor',
      buildingId: json['building_id']?.toString(),
      deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
      roomCount: (json['room_count'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      children: rawChildren
          .whereType<Map<String, dynamic>>()
          .map((c) => LocationHierarchyNode.fromJson(c))
          .toList(),
    );
  }
}

class LocationDetailsModel {
  final String id;
  final String title;
  final String? buildingId;
  final String buildingName;
  final String locationType;
  final String parentLocation;
  final int floorNo;
  final String status;
  final int totalRooms;
  final int mappedDevices;
  final int unmappedDevices;
  final int groupsAssigned;
  final int profilesInUse;
  final double coveragePct;
  final String imageUrl;
  final List<LocationRoomItem> rooms;
  final List<LocationAssignedGroupItem> assignedGroups;
  final int automationsCount;
  final int scenesCount;

  const LocationDetailsModel({
    required this.id,
    this.title = '',
    this.buildingId,
    this.buildingName = '',
    this.locationType = 'Floor',
    this.parentLocation = '',
    this.floorNo = 1,
    this.status = 'Active',
    this.totalRooms = 0,
    this.mappedDevices = 0,
    this.unmappedDevices = 0,
    this.groupsAssigned = 0,
    this.profilesInUse = 0,
    this.coveragePct = 0.0,
    this.imageUrl = 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=600&q=80',
    this.rooms = const [],
    this.assignedGroups = const [],
    this.automationsCount = 0,
    this.scenesCount = 0,
  });

  factory LocationDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List? ?? [];
    final rawGroups = json['assigned_groups'] as List? ?? [];
    return LocationDetailsModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      buildingId: json['building_id']?.toString(),
      buildingName: json['building_name']?.toString() ?? '',
      locationType: json['location_type']?.toString() ?? 'Floor',
      parentLocation: json['parent_location']?.toString() ?? '',
      floorNo: (json['floor_no'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'Active',
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      mappedDevices: (json['mapped_devices'] as num?)?.toInt() ?? 0,
      unmappedDevices: (json['unmapped_devices'] as num?)?.toInt() ?? 0,
      groupsAssigned: (json['groups_assigned'] as num?)?.toInt() ?? 0,
      profilesInUse: (json['profiles_in_use'] as num?)?.toInt() ?? 0,
      coveragePct: (json['coverage_pct'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url']?.toString() ??
          'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=600&q=80',
      rooms: rawRooms
          .whereType<Map<String, dynamic>>()
          .map((r) => LocationRoomItem.fromJson(r))
          .toList(),
      assignedGroups: rawGroups
          .whereType<Map<String, dynamic>>()
          .map((g) => LocationAssignedGroupItem.fromJson(g))
          .toList(),
      automationsCount: (json['automations_count'] as num?)?.toInt() ?? 0,
      scenesCount: (json['scenes_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LocationRoomItem {
  final String id;
  final String roomNumber;
  final String name;
  final String roomType;
  final int capacity;
  final String status;

  const LocationRoomItem({
    required this.id,
    required this.roomNumber,
    required this.name,
    this.roomType = 'Classroom',
    this.capacity = 40,
    this.status = 'Available',
  });

  factory LocationRoomItem.fromJson(Map<String, dynamic> json) {
    return LocationRoomItem(
      id: json['id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? 'Classroom',
      capacity: (json['capacity'] as num?)?.toInt() ?? 40,
      status: json['status']?.toString() ?? 'Available',
    );
  }
}

class LocationAssignedGroupItem {
  final String id;
  final String name;
  final String code;
  final String type;
  final int deviceCount;

  const LocationAssignedGroupItem({
    required this.id,
    required this.name,
    required this.code,
    this.type = 'Lighting',
    this.deviceCount = 0,
  });

  factory LocationAssignedGroupItem.fromJson(Map<String, dynamic> json) {
    return LocationAssignedGroupItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Lighting',
      deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceLocationMappingItem {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String deviceType;
  final String deviceTypeCode;
  final String? roomId;
  final String roomSpace;
  final String locationPath;
  final String mappingStatus;
  final bool isOnline;
  final bool powerState;

  const DeviceLocationMappingItem({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.deviceType,
    this.deviceTypeCode = 'general',
    this.roomId,
    this.roomSpace = 'A1-101 (Classroom)',
    this.locationPath = 'Academic Block (A) > 1F',
    this.mappingStatus = 'Mapped',
    this.isOnline = true,
    this.powerState = true,
  });

  factory DeviceLocationMappingItem.fromJson(Map<String, dynamic> json) {
    return DeviceLocationMappingItem(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? 'Device',
      deviceTypeCode: json['device_type_code']?.toString() ?? 'general',
      roomId: json['room_id']?.toString(),
      roomSpace: json['room_space']?.toString() ?? 'Unassigned',
      locationPath: json['location_path']?.toString() ?? 'Academic Block (A) > 1F',
      mappingStatus: json['mapping_status']?.toString() ?? 'Mapped',
      isOnline: json['is_online'] == true,
      powerState: json['power_state'] == true,
    );
  }
}

class FloorPlanAssetModel {
  final String id;
  final String floorId;
  final String? buildingId;
  final String buildingName;
  final String floorName;
  final int floorNumber;
  final String title;
  final String version;
  final double dimensionsWidth;
  final double dimensionsHeight;
  final double scalePixelsPerMeter;
  final List<FloorPlanRoomLayout> roomsLayout;
  final List<FloorPlanAvailableFloor> availableFloors;

  const FloorPlanAssetModel({
    required this.id,
    this.floorId = '8770a0e6-8aa9-4e65-9a85-539eabd5f9a6',
    this.buildingId,
    this.buildingName = 'Academic Block',
    this.floorName = 'First Floor',
    this.floorNumber = 1,
    this.title = 'Academic Block – First Floor Architectural Plan',
    this.version = 'v1.0',
    this.dimensionsWidth = 1200.0,
    this.dimensionsHeight = 750.0,
    this.scalePixelsPerMeter = 25.0,
    this.roomsLayout = const [],
    this.availableFloors = const [],
  });

  factory FloorPlanAssetModel.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms_layout'] as List? ?? [];
    final rawFloors = json['available_floors'] as List? ?? [];
    return FloorPlanAssetModel(
      id: json['id']?.toString() ?? '',
      floorId: json['floor_id']?.toString() ?? '8770a0e6-8aa9-4e65-9a85-539eabd5f9a6',
      buildingId: json['building_id']?.toString(),
      buildingName: json['building_name']?.toString() ?? 'Academic Block',
      floorName: json['floor_name']?.toString() ?? 'First Floor',
      floorNumber: (json['floor_number'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Academic Block – First Floor Architectural Plan',
      version: json['version']?.toString() ?? 'v1.0',
      dimensionsWidth: (json['dimensions_width'] as num?)?.toDouble() ?? 1200.0,
      dimensionsHeight: (json['dimensions_height'] as num?)?.toDouble() ?? 750.0,
      scalePixelsPerMeter: (json['scale_pixels_per_meter'] as num?)?.toDouble() ?? 25.0,
      roomsLayout: rawRooms
          .whereType<Map<String, dynamic>>()
          .map((r) => FloorPlanRoomLayout.fromJson(r))
          .toList(),
      availableFloors: rawFloors
          .whereType<Map<String, dynamic>>()
          .map((f) => FloorPlanAvailableFloor.fromJson(f))
          .toList(),
    );
  }
}

class FloorPlanAvailableFloor {
  final String id;
  final String name;
  final int floorLevel;
  final bool isCurrent;

  const FloorPlanAvailableFloor({
    required this.id,
    required this.name,
    this.floorLevel = 0,
    this.isCurrent = false,
  });

  factory FloorPlanAvailableFloor.fromJson(Map<String, dynamic> json) {
    return FloorPlanAvailableFloor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Floor',
      floorLevel: (json['floor_level'] as num?)?.toInt() ?? 0,
      isCurrent: json['is_current'] == true,
    );
  }
}

class FloorPlanRoomLayout {
  final String roomId;
  final String code;
  final String name;
  final String roomType;
  final double x;
  final double y;
  final double w;
  final double h;

  const FloorPlanRoomLayout({
    required this.roomId,
    required this.code,
    required this.name,
    this.roomType = 'Classroom',
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory FloorPlanRoomLayout.fromJson(Map<String, dynamic> json) {
    return FloorPlanRoomLayout(
      roomId: json['room_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? 'Classroom',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 0.2,
      h: (json['h'] as num?)?.toDouble() ?? 0.2,
    );
  }
}

class FloorPlanMarkerModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final String deviceCode;
  final String markerLabel;
  final String deviceType;
  final String deviceTypeCode;
  final double posX;
  final double posY;
  final double rotation;
  final bool isOnline;
  final bool powerState;
  final bool isMapped;
  final String? roomId;
  final String? roomNumber;
  final String? roomName;
  final Map<String, dynamic> currentState;

  const FloorPlanMarkerModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.deviceCode,
    required this.markerLabel,
    required this.deviceType,
    this.deviceTypeCode = 'general',
    required this.posX,
    required this.posY,
    this.rotation = 0.0,
    this.isOnline = true,
    this.powerState = true,
    this.isMapped = true,
    this.roomId,
    this.roomNumber,
    this.roomName,
    this.currentState = const {},
  });

  factory FloorPlanMarkerModel.fromJson(Map<String, dynamic> json) {
    return FloorPlanMarkerModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      markerLabel: json['marker_label']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? 'Device',
      deviceTypeCode: json['device_type_code']?.toString() ?? 'general',
      posX: (json['pos_x'] as num?)?.toDouble() ?? 0.0,
      posY: (json['pos_y'] as num?)?.toDouble() ?? 0.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      isOnline: json['is_online'] == true,
      powerState: json['power_state'] == true,
      isMapped: json['is_mapped'] == true,
      roomId: json['room_id']?.toString(),
      roomNumber: json['room_number']?.toString(),
      roomName: json['room_name']?.toString(),
      currentState: json['current_state'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['current_state'] as Map)
          : {},
    );
  }
}

class FloorPlanLegendModel {
  final int cctv;
  final int lighting;
  final int hvac;
  final int projector;
  final int accessPoint;
  final int audio;
  final int fan;
  final int total;

  const FloorPlanLegendModel({
    this.cctv = 0,
    this.lighting = 0,
    this.hvac = 0,
    this.projector = 0,
    this.accessPoint = 0,
    this.audio = 0,
    this.fan = 0,
    this.total = 0,
  });

  factory FloorPlanLegendModel.fromJson(Map<String, dynamic> json) {
    return FloorPlanLegendModel(
      cctv: (json['cctv'] as num?)?.toInt() ?? 0,
      lighting: (json['lighting'] as num?)?.toInt() ?? 0,
      hvac: (json['hvac'] as num?)?.toInt() ?? 0,
      projector: (json['projector'] as num?)?.toInt() ?? 0,
      accessPoint: (json['access_point'] as num?)?.toInt() ?? 0,
      audio: (json['audio'] as num?)?.toInt() ?? 0,
      fan: (json['fan'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ---------------------------------------------------------------------------
/// LIVE CONTROL MODELS (Campus Management -> Live Control)
/// ---------------------------------------------------------------------------

class LiveControlKpis {
  final int onlineDevices;
  final double onlinePercentage;
  final int offlineDevices;
  final double offlinePercentage;
  final int controllableNow;
  final int activeGroups;
  final int runningAutomations;
  final int activeSchedules;

  const LiveControlKpis({
    this.onlineDevices = 0,
    this.onlinePercentage = 0.0,
    this.offlineDevices = 0,
    this.offlinePercentage = 0.0,
    this.controllableNow = 0,
    this.activeGroups = 0,
    this.runningAutomations = 0,
    this.activeSchedules = 0,
  });

  factory LiveControlKpis.fromJson(Map<String, dynamic> json) {
    return LiveControlKpis(
      onlineDevices: (json['online_devices'] as num?)?.toInt() ?? 0,
      onlinePercentage: (json['online_percentage'] as num?)?.toDouble() ?? 0.0,
      offlineDevices: (json['offline_devices'] as num?)?.toInt() ?? 0,
      offlinePercentage: (json['offline_percentage'] as num?)?.toDouble() ?? 0.0,
      controllableNow: (json['controllable_now'] as num?)?.toInt() ?? 0,
      activeGroups: (json['active_groups'] as num?)?.toInt() ?? 0,
      runningAutomations: (json['running_automations'] as num?)?.toInt() ?? 0,
      activeSchedules: (json['active_schedules'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'online_devices': onlineDevices,
    'online_percentage': onlinePercentage,
    'offline_devices': offlineDevices,
    'offline_percentage': offlinePercentage,
    'controllable_now': controllableNow,
    'active_groups': activeGroups,
    'running_automations': runningAutomations,
    'active_schedules': activeSchedules,
  };
}

class LiveControlDeviceItem {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String ipAddress;
  final String macAddress;
  final String mqttTopic;
  final bool isOnline;
  final bool powerState;
  final Map<String, dynamic> currentState;
  final String operationalStatus;
  final double ratedPowerWatts;
  final String? buildingId;
  final String buildingName;
  final String? floorId;
  final String floorName;
  final String? roomId;
  final String roomName;
  final String roomNumber;
  final String? deviceTypeId;
  final String deviceTypeName;
  final String deviceTypeCode;
  final String icon;
  final String color;
  final String systemCategory;
  final String profileName;

  const LiveControlDeviceItem({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    this.ipAddress = '192.168.1.100',
    this.macAddress = '00:1A:2B:3C:4D:5E',
    this.mqttTopic = '',
    this.isOnline = true,
    this.powerState = true,
    this.currentState = const {},
    this.operationalStatus = 'operational',
    this.ratedPowerWatts = 0.0,
    this.buildingId,
    this.buildingName = 'Academic Block (A)',
    this.floorId,
    this.floorName = 'First Floor',
    this.roomId,
    this.roomName = 'Classroom',
    this.roomNumber = 'A1-103',
    this.deviceTypeId,
    this.deviceTypeName = 'Device',
    this.deviceTypeCode = 'generic',
    this.icon = 'devices',
    this.color = '#2563EB',
    this.systemCategory = 'General',
    this.profileName = 'Standard Profile',
  });

  // State helpers - Robustly typed to safely handle bool, num, or string values
  int get brightness {
    final v = currentState['brightness'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 80;
    if (v is bool) return v ? 100 : 0;
    return 80;
  }

  int get temperature {
    final v = currentState['temperature'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 24;
    return 24;
  }

  String get mode => currentState['mode']?.toString() ?? 'Cool';
  String get fanSpeed => currentState['fan_speed']?.toString() ?? 'Medium';
  bool get swing => currentState['swing'] != false;
  String get quickPreset => currentState['quick_preset']?.toString() ?? 'Classroom';

  List<int> get channels {
    final raw = currentState['channels'];
    if (raw is List) {
      final result = <int>[];
      for (int i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is bool) {
          if (item) result.add(i + 1);
        } else if (item is num) {
          result.add(item.toInt());
        } else if (item != null) {
          final parsed = int.tryParse(item.toString());
          if (parsed != null) result.add(parsed);
        }
      }
      return result.isNotEmpty ? result : [1, 2, 4];
    }
    return [1, 2, 4];
  }

  String get input => currentState['input']?.toString() ?? 'HDMI 1';

  int get volume {
    final v = currentState['volume'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 65;
    return 65;
  }

  bool get isLocked => currentState['status'] == 'locked' || currentState['lock_state'] == true;

  factory LiveControlDeviceItem.fromJson(Map<String, dynamic> json) {
    num? parseNum(dynamic val) {
      if (val is num) return val;
      if (val is String) return num.tryParse(val);
      return null;
    }

    return LiveControlDeviceItem(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? 'Unnamed Device',
      deviceCode: json['device_code']?.toString() ?? 'DEV-001',
      ipAddress: json['ip_address']?.toString() ?? '192.168.1.100',
      macAddress: json['mac_address']?.toString() ?? '00:1A:2B:3C:4D:5E',
      mqttTopic: json['mqtt_topic']?.toString() ?? '',
      isOnline: json['is_online'] == true,
      powerState: json['power_state'] == true,
      currentState: json['current_state'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['current_state'])
          : {},
      operationalStatus: json['operational_status']?.toString() ?? 'operational',
      ratedPowerWatts: parseNum(json['rated_power_watts'])?.toDouble() ?? 0.0,
      buildingId: json['building_id']?.toString(),
      buildingName: json['building_name']?.toString() ?? 'Academic Block (A)',
      floorId: json['floor_id']?.toString(),
      floorName: json['floor_name']?.toString() ?? 'First Floor',
      roomId: json['room_id']?.toString(),
      roomName: json['room_name']?.toString() ?? 'Classroom',
      roomNumber: json['room_number']?.toString() ?? 'A1-103',
      deviceTypeId: json['device_type_id']?.toString(),
      deviceTypeName: json['device_type_name']?.toString() ?? 'Device',
      deviceTypeCode: json['device_type_code']?.toString() ?? 'generic',
      icon: json['icon']?.toString() ?? 'devices',
      color: json['color']?.toString() ?? '#2563EB',
      systemCategory: json['system_category']?.toString() ?? 'General',
      profileName: json['profile_name']?.toString() ?? 'Standard Profile',
    );
  }

  LiveControlDeviceItem copyWith({
    String? id,
    String? deviceName,
    String? deviceCode,
    String? ipAddress,
    String? macAddress,
    String? mqttTopic,
    bool? isOnline,
    bool? powerState,
    Map<String, dynamic>? currentState,
    String? operationalStatus,
    double? ratedPowerWatts,
    String? buildingId,
    String? buildingName,
    String? floorId,
    String? floorName,
    String? roomId,
    String? roomName,
    String? roomNumber,
    String? deviceTypeId,
    String? deviceTypeName,
    String? deviceTypeCode,
    String? icon,
    String? color,
    String? systemCategory,
    String? profileName,
  }) {
    return LiveControlDeviceItem(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      deviceCode: deviceCode ?? this.deviceCode,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      isOnline: isOnline ?? this.isOnline,
      powerState: powerState ?? this.powerState,
      currentState: currentState ?? this.currentState,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      ratedPowerWatts: ratedPowerWatts ?? this.ratedPowerWatts,
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      floorId: floorId ?? this.floorId,
      floorName: floorName ?? this.floorName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      roomNumber: roomNumber ?? this.roomNumber,
      deviceTypeId: deviceTypeId ?? this.deviceTypeId,
      deviceTypeName: deviceTypeName ?? this.deviceTypeName,
      deviceTypeCode: deviceTypeCode ?? this.deviceTypeCode,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      systemCategory: systemCategory ?? this.systemCategory,
      profileName: profileName ?? this.profileName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_name': deviceName,
    'device_code': deviceCode,
    'ip_address': ipAddress,
    'mac_address': macAddress,
    'mqtt_topic': mqttTopic,
    'is_online': isOnline,
    'power_state': powerState,
    'current_state': currentState,
    'operational_status': operationalStatus,
    'rated_power_watts': ratedPowerWatts,
    'building_id': buildingId,
    'building_name': buildingName,
    'floor_id': floorId,
    'floor_name': floorName,
    'room_id': roomId,
    'room_name': roomName,
    'room_number': roomNumber,
    'device_type_id': deviceTypeId,
    'device_type_name': deviceTypeName,
    'device_type_code': deviceTypeCode,
    'icon': icon,
    'color': color,
    'system_category': systemCategory,
    'profile_name': profileName,
  };
}

class LiveControlDeviceDetails {
  final LiveControlDeviceItem device;
  final List<LiveDeviceCommandLog> recentLogs;

  const LiveControlDeviceDetails({
    required this.device,
    this.recentLogs = const [],
  });

  factory LiveControlDeviceDetails.fromJson(Map<String, dynamic> json) {
    return LiveControlDeviceDetails(
      device: LiveControlDeviceItem.fromJson(json['device'] as Map<String, dynamic>? ?? {}),
      recentLogs: (json['recent_logs'] as List<dynamic>?)
              ?.map((e) => LiveDeviceCommandLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class LiveDeviceCommandLog {
  final String id;
  final String commandType;
  final Map<String, dynamic> payload;
  final String status;
  final String? createdAt;

  const LiveDeviceCommandLog({
    required this.id,
    required this.commandType,
    this.payload = const {},
    this.status = 'acknowledged',
    this.createdAt,
  });

  factory LiveDeviceCommandLog.fromJson(Map<String, dynamic> json) {
    return LiveDeviceCommandLog(
      id: json['id']?.toString() ?? '',
      commandType: json['command_type']?.toString() ?? 'command',
      payload: json['payload'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['payload']) : {},
      status: json['status']?.toString() ?? 'acknowledged',
      createdAt: json['created_at']?.toString(),
    );
  }
}

// ====================================================================
// BULK OPERATIONS MODELS (Migration 492)
// ====================================================================

class BulkOperationOverview {
  final int totalDevices;
  final int onlineDevices;
  final double onlinePercentage;
  final int offlineDevices;
  final double offlinePercentage;
  final int selectedDevices;
  final int selectedGroups;
  final int selectedLocations;
  final int affectedDevices;
  final int operationsRunning;
  final int operationsCompletedToday;
  final int failedCommands;

  const BulkOperationOverview({
    this.totalDevices = 8742,
    this.onlineDevices = 8342,
    this.onlinePercentage = 95.4,
    this.offlineDevices = 400,
    this.offlinePercentage = 4.6,
    this.selectedDevices = 0,
    this.selectedGroups = 0,
    this.selectedLocations = 0,
    this.affectedDevices = 0,
    this.operationsRunning = 1,
    this.operationsCompletedToday = 3,
    this.failedCommands = 0,
  });

  factory BulkOperationOverview.fromJson(Map<String, dynamic> json) {
    return BulkOperationOverview(
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 8742,
      onlineDevices: (json['online_devices'] as num?)?.toInt() ?? 8342,
      onlinePercentage: (json['online_percentage'] as num?)?.toDouble() ?? 95.4,
      offlineDevices: (json['offline_devices'] as num?)?.toInt() ?? 400,
      offlinePercentage: (json['offline_percentage'] as num?)?.toDouble() ?? 4.6,
      selectedDevices: (json['selected_devices'] as num?)?.toInt() ?? 0,
      selectedGroups: (json['selected_groups'] as num?)?.toInt() ?? 0,
      selectedLocations: (json['selected_locations'] as num?)?.toInt() ?? 0,
      affectedDevices: (json['affected_devices'] as num?)?.toInt() ?? 0,
      operationsRunning: (json['operations_running'] as num?)?.toInt() ?? 1,
      operationsCompletedToday: (json['operations_completed_today'] as num?)?.toInt() ?? 3,
      failedCommands: (json['failed_commands'] as num?)?.toInt() ?? 0,
    );
  }
}

class BulkRecentOperationItem {
  final String id;
  final String operationCode;
  final String name;
  final String operationType;
  final String targetScope;
  final String status;
  final String initiatedBy;
  final String result;
  final int totalDevices;
  final int successfulDevices;
  final String? createdAt;

  const BulkRecentOperationItem({
    required this.id,
    required this.operationCode,
    required this.name,
    required this.operationType,
    required this.targetScope,
    required this.status,
    required this.initiatedBy,
    required this.result,
    required this.totalDevices,
    required this.successfulDevices,
    this.createdAt,
  });

  factory BulkRecentOperationItem.fromJson(Map<String, dynamic> json) {
    return BulkRecentOperationItem(
      id: json['id']?.toString() ?? '',
      operationCode: json['operation_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      operationType: json['operation_type']?.toString() ?? 'control',
      targetScope: json['target_scope']?.toString() ?? 'Devices',
      status: json['status']?.toString() ?? 'Success',
      initiatedBy: json['initiated_by']?.toString() ?? 'Admin',
      result: json['result']?.toString() ?? 'Completed',
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 0,
      successfulDevices: (json['successful_devices'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class BulkOperationTemplateItem {
  final String id;
  final String templateName;
  final String? description;
  final String operationType;
  final String targetType;
  final Map<String, dynamic> targetRules;
  final Map<String, dynamic> actionConfiguration;
  final String icon;
  final String color;

  const BulkOperationTemplateItem({
    required this.id,
    required this.templateName,
    this.description,
    required this.operationType,
    required this.targetType,
    this.targetRules = const {},
    this.actionConfiguration = const {},
    this.icon = 'tune',
    this.color = '#2563EB',
  });

  factory BulkOperationTemplateItem.fromJson(Map<String, dynamic> json) {
    return BulkOperationTemplateItem(
      id: json['id']?.toString() ?? '',
      templateName: json['template_name']?.toString() ?? '',
      description: json['description']?.toString(),
      operationType: json['operation_type']?.toString() ?? 'control',
      targetType: json['target_type']?.toString() ?? 'devices',
      targetRules: json['target_rules'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['target_rules']) : {},
      actionConfiguration: json['action_configuration'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['action_configuration']) : {},
      icon: json['icon']?.toString() ?? 'tune',
      color: json['color']?.toString() ?? '#2563EB',
    );
  }
}

class BulkTargetDeviceItem {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String typeName;
  final String typeCode;
  final String location;
  final bool isOnline;
  final bool powerState;

  const BulkTargetDeviceItem({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.typeName,
    required this.typeCode,
    required this.location,
    required this.isOnline,
    required this.powerState,
  });

  factory BulkTargetDeviceItem.fromJson(Map<String, dynamic> json) {
    return BulkTargetDeviceItem(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      typeName: json['type_name']?.toString() ?? 'Device',
      typeCode: json['type_code']?.toString() ?? 'device',
      location: json['location']?.toString() ?? 'Academic Block (A) > Room',
      isOnline: json['is_online'] == true,
      powerState: json['power_state'] == true,
    );
  }
}

// ============================================================================
// DEVICE SCHEDULES MODELS (ENTERPRISE SCHEDULES SYSTEM)
// ============================================================================

class DeviceSchedulesKpis {
  final int totalSchedules;
  final int activeSchedules;
  final double activePercentage;
  final int pausedSchedules;
  final double pausedPercentage;
  final int upcoming24h;
  final int executedToday;
  final int failedSkipped;
  final int completedCount;

  const DeviceSchedulesKpis({
    this.totalSchedules = 276,
    this.activeSchedules = 192,
    this.activePercentage = 69.6,
    this.pausedSchedules = 8,
    this.pausedPercentage = 2.9,
    this.upcoming24h = 34,
    this.executedToday = 428,
    this.failedSkipped = 6,
    this.completedCount = 2318,
  });

  factory DeviceSchedulesKpis.fromJson(Map<String, dynamic> json) {
    return DeviceSchedulesKpis(
      totalSchedules: (json['total_schedules'] as num?)?.toInt() ?? 276,
      activeSchedules: (json['active_schedules'] as num?)?.toInt() ?? 192,
      activePercentage: (json['active_percentage'] as num?)?.toDouble() ?? 69.6,
      pausedSchedules: (json['paused_schedules'] as num?)?.toInt() ?? 8,
      pausedPercentage: (json['paused_percentage'] as num?)?.toDouble() ?? 2.9,
      upcoming24h: (json['upcoming_24h'] as num?)?.toInt() ?? 34,
      executedToday: (json['executed_today'] as num?)?.toInt() ?? 428,
      failedSkipped: (json['failed_skipped'] as num?)?.toInt() ?? 6,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 2318,
    );
  }
}

class DeviceScheduleItem {
  final String id;
  final String scheduleCode;
  final String name;
  final String description;
  final String targetType; // group, location, device, multiple
  final String targetName;
  final int targetCount;
  final List<String> targetIds;
  final String operationType; // turn_on_off, set_value, turn_on, turn_off, brightness, set_speed, lock, play_audio, apply_scene
  final String operationValue;
  final String recurrenceType; // daily, weekdays, weekends, custom, once
  final String recurrenceLabel;
  final String timeWindowLabel;
  final String validityLabel;
  final String? startTime;
  final String? endTime;
  final List<int> daysOfWeek;
  final String nextRunAt;
  final String lastRunAt;
  final String lastStatus;
  final String status; // active, paused, completed
  final bool isActive;
  final String createdByName;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic> actionPayload;

  const DeviceScheduleItem({
    required this.id,
    this.scheduleCode = 'SCH-001',
    required this.name,
    this.description = '',
    this.targetType = 'group',
    this.targetName = '',
    this.targetCount = 1,
    this.targetIds = const [],
    this.operationType = 'turn_on_off',
    this.operationValue = 'ON/OFF',
    this.recurrenceType = 'daily',
    this.recurrenceLabel = 'Daily (Every day)',
    this.timeWindowLabel = '07:00 AM - 06:00 PM',
    this.validityLabel = '01 Jan 2025 - No End Date',
    this.startTime,
    this.endTime,
    this.daysOfWeek = const [1, 2, 3, 4, 5],
    this.nextRunAt = 'Tomorrow, 07:00 AM',
    this.lastRunAt = 'Today, 06:00 PM',
    this.lastStatus = 'success',
    this.status = 'active',
    this.isActive = true,
    this.createdByName = 'Admin',
    this.createdAt = '',
    this.updatedAt = '',
    this.actionPayload = const {},
  });

  factory DeviceScheduleItem.fromJson(Map<String, dynamic> json) {
    final targets = <String>[];
    if (json['target_ids'] is List) {
      for (final t in json['target_ids'] as List) {
        targets.add(t.toString());
      }
    }
    final days = <int>[];
    if (json['days_of_week'] is List) {
      for (final d in json['days_of_week'] as List) {
        if (d is num) days.add(d.toInt());
      }
    }

    return DeviceScheduleItem(
      id: json['id']?.toString() ?? '',
      scheduleCode: json['schedule_code']?.toString() ?? 'SCH-001',
      name: json['name']?.toString() ?? 'Schedule',
      description: json['description']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? 'group',
      targetName: json['target_name']?.toString() ?? '',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      targetIds: targets,
      operationType: json['operation_type']?.toString() ?? 'turn_on_off',
      operationValue: json['operation_value']?.toString() ?? 'ON/OFF',
      recurrenceType: json['recurrence_type']?.toString() ?? 'daily',
      recurrenceLabel: json['recurrence_label']?.toString() ?? 'Daily (Every day)',
      timeWindowLabel: json['time_window_label']?.toString() ?? '07:00 AM - 06:00 PM',
      validityLabel: json['validity_label']?.toString() ?? '01 Jan 2025 - No End Date',
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      daysOfWeek: days.isNotEmpty ? days : const [1, 2, 3, 4, 5],
      nextRunAt: json['next_run_at'] != null ? json['next_run_at'].toString() : 'Tomorrow, 07:00 AM',
      lastRunAt: json['last_run_at'] != null ? json['last_run_at'].toString() : 'Today, 06:00 PM',
      lastStatus: json['last_status']?.toString() ?? 'success',
      status: json['status']?.toString() ?? (json['is_active'] == false ? 'paused' : 'active'),
      isActive: json['is_active'] != false && json['status'] != 'paused',
      createdByName: json['created_by_name']?.toString() ?? 'Admin',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      actionPayload: json['action_payload'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['action_payload']) : const {},
    );
  }

  DeviceScheduleItem copyWith({
    String? id,
    String? scheduleCode,
    String? name,
    String? description,
    String? targetType,
    String? targetName,
    int? targetCount,
    List<String>? targetIds,
    String? operationType,
    String? operationValue,
    String? recurrenceType,
    String? recurrenceLabel,
    String? timeWindowLabel,
    String? validityLabel,
    String? startTime,
    String? endTime,
    List<int>? daysOfWeek,
    String? nextRunAt,
    String? lastRunAt,
    String? lastStatus,
    String? status,
    bool? isActive,
    String? createdByName,
    String? createdAt,
    String? updatedAt,
    Map<String, dynamic>? actionPayload,
  }) {
    return DeviceScheduleItem(
      id: id ?? this.id,
      scheduleCode: scheduleCode ?? this.scheduleCode,
      name: name ?? this.name,
      description: description ?? this.description,
      targetType: targetType ?? this.targetType,
      targetName: targetName ?? this.targetName,
      targetCount: targetCount ?? this.targetCount,
      targetIds: targetIds ?? this.targetIds,
      operationType: operationType ?? this.operationType,
      operationValue: operationValue ?? this.operationValue,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceLabel: recurrenceLabel ?? this.recurrenceLabel,
      timeWindowLabel: timeWindowLabel ?? this.timeWindowLabel,
      validityLabel: validityLabel ?? this.validityLabel,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastStatus: lastStatus ?? this.lastStatus,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actionPayload: actionPayload ?? this.actionPayload,
    );
  }
}

class DeviceScheduleTimelineEvent {
  final String id;
  final String scheduleId;
  final String eventTitle;
  final String actionType;
  final String scheduledTimeLabel;
  final String targetSummary;
  final String status;

  const DeviceScheduleTimelineEvent({
    required this.id,
    required this.scheduleId,
    required this.eventTitle,
    required this.actionType,
    required this.scheduledTimeLabel,
    this.targetSummary = '',
    this.status = 'upcoming',
  });

  factory DeviceScheduleTimelineEvent.fromJson(Map<String, dynamic> json) {
    return DeviceScheduleTimelineEvent(
      id: json['id']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString() ?? '',
      eventTitle: json['event_title']?.toString() ?? 'Scheduled Event',
      actionType: json['action_type']?.toString() ?? 'turn_on',
      scheduledTimeLabel: json['scheduled_time_label']?.toString() ?? (json['scheduled_time']?.toString() ?? 'Tomorrow, 07:00 AM'),
      targetSummary: json['target_summary']?.toString() ?? '',
      status: json['status']?.toString() ?? 'upcoming',
    );
  }
}

class DeviceScheduleExecutionLog {
  final String id;
  final String scheduleId;
  final String executionCode;
  final String triggerTimeLabel;
  final String actionExecuted;
  final String status;
  final int affectedDevicesCount;
  final int successCount;
  final int failedCount;
  final Map<String, dynamic> logDetails;

  const DeviceScheduleExecutionLog({
    required this.id,
    required this.scheduleId,
    required this.executionCode,
    required this.triggerTimeLabel,
    required this.actionExecuted,
    this.status = 'success',
    this.affectedDevicesCount = 1,
    this.successCount = 1,
    this.failedCount = 0,
    this.logDetails = const {},
  });

  factory DeviceScheduleExecutionLog.fromJson(Map<String, dynamic> json) {
    return DeviceScheduleExecutionLog(
      id: json['id']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString() ?? '',
      executionCode: json['execution_code']?.toString() ?? '',
      triggerTimeLabel: json['trigger_time_label']?.toString() ?? (json['trigger_time']?.toString() ?? 'Today'),
      actionExecuted: json['action_executed']?.toString() ?? 'Executed',
      status: json['status']?.toString() ?? 'success',
      affectedDevicesCount: (json['affected_devices_count'] as num?)?.toInt() ?? 1,
      successCount: (json['success_count'] as num?)?.toInt() ?? 1,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      logDetails: json['log_details'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['log_details']) : const {},
    );
  }
}

// ============================================================================
// SCENES & PRESETS ENTERPRISE MODELS
// ============================================================================

class DeviceScenesPresetsKpis {
  final int totalScenes;
  final int activeScenes;
  final double activePercentage;
  final int disabledScenes;
  final double disabledPercentage;
  final int totalPresets;
  final int usedInAutomations;
  final int usedInSchedules;
  final List<ScenePopularItem> popularScenes;
  final SceneUsageStats usageStats;

  const DeviceScenesPresetsKpis({
    this.totalScenes = 42,
    this.activeScenes = 36,
    this.activePercentage = 85.7,
    this.disabledScenes = 6,
    this.disabledPercentage = 14.3,
    this.totalPresets = 118,
    this.usedInAutomations = 24,
    this.usedInSchedules = 37,
    this.popularScenes = const [],
    this.usageStats = const SceneUsageStats(),
  });

  factory DeviceScenesPresetsKpis.fromJson(Map<String, dynamic> json) {
    var rawPopular = json['popular_scenes'] as List? ?? [];
    var popular = rawPopular.map((e) => ScenePopularItem.fromJson(Map<String, dynamic>.from(e))).toList();
    var usage = json['usage_stats'] is Map<String, dynamic>
        ? SceneUsageStats.fromJson(Map<String, dynamic>.from(json['usage_stats']))
        : const SceneUsageStats();

    return DeviceScenesPresetsKpis(
      totalScenes: (json['total_scenes'] as num?)?.toInt() ?? 42,
      activeScenes: (json['active_scenes'] as num?)?.toInt() ?? 36,
      activePercentage: (json['active_percentage'] as num?)?.toDouble() ?? 85.7,
      disabledScenes: (json['disabled_scenes'] as num?)?.toInt() ?? 6,
      disabledPercentage: (json['disabled_percentage'] as num?)?.toDouble() ?? 14.3,
      totalPresets: (json['total_presets'] as num?)?.toInt() ?? 118,
      usedInAutomations: (json['used_in_automations'] as num?)?.toInt() ?? 24,
      usedInSchedules: (json['used_in_schedules'] as num?)?.toInt() ?? 37,
      popularScenes: popular,
      usageStats: usage,
    );
  }
}

class ScenePopularItem {
  final String id;
  final String sceneCode;
  final String name;
  final String targetName;
  final int targetCount;
  final String icon;
  final String color;

  const ScenePopularItem({
    required this.id,
    required this.sceneCode,
    required this.name,
    this.targetName = '8 devices',
    this.targetCount = 8,
    this.icon = 'wb_sunny_rounded',
    this.color = '#F59E0B',
  });

  factory ScenePopularItem.fromJson(Map<String, dynamic> json) {
    return ScenePopularItem(
      id: json['id']?.toString() ?? '',
      sceneCode: json['scene_code']?.toString() ?? 'SCN-001',
      name: json['name']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '8 devices',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 8,
      icon: json['icon']?.toString() ?? 'wb_sunny_rounded',
      color: json['color']?.toString() ?? '#F59E0B',
    );
  }
}

class SceneUsageStats {
  final int totalExecutions30d;
  final List<SceneUsageBreakdown> breakdown;

  const SceneUsageStats({
    this.totalExecutions30d = 428,
    this.breakdown = const [
      SceneUsageBreakdown(name: 'Class Start', count: 128, percentage: 29.9, color: '#10B981'),
      SceneUsageBreakdown(name: 'Class End', count: 96, percentage: 22.4, color: '#3B82F6'),
      SceneUsageBreakdown(name: 'Presentation', count: 72, percentage: 16.8, color: '#8B5CF6'),
      SceneUsageBreakdown(name: 'Others (6)', count: 132, percentage: 30.9, color: '#F59E0B'),
    ],
  });

  factory SceneUsageStats.fromJson(Map<String, dynamic> json) {
    var rawList = json['breakdown'] as List? ?? [];
    var list = rawList.map((e) => SceneUsageBreakdown.fromJson(Map<String, dynamic>.from(e))).toList();
    return SceneUsageStats(
      totalExecutions30d: (json['total_executions_30d'] as num?)?.toInt() ?? 428,
      breakdown: list.isNotEmpty ? list : const [
        SceneUsageBreakdown(name: 'Class Start', count: 128, percentage: 29.9, color: '#10B981'),
        SceneUsageBreakdown(name: 'Class End', count: 96, percentage: 22.4, color: '#3B82F6'),
        SceneUsageBreakdown(name: 'Presentation', count: 72, percentage: 16.8, color: '#8B5CF6'),
        SceneUsageBreakdown(name: 'Others (6)', count: 132, percentage: 30.9, color: '#F59E0B'),
      ],
    );
  }
}

class SceneUsageBreakdown {
  final String name;
  final int count;
  final double percentage;
  final String color;

  const SceneUsageBreakdown({
    required this.name,
    required this.count,
    required this.percentage,
    required this.color,
  });

  factory SceneUsageBreakdown.fromJson(Map<String, dynamic> json) {
    return SceneUsageBreakdown(
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      color: json['color']?.toString() ?? '#2563EB',
    );
  }
}

class DeviceSceneExecutionRecord {
  final String id;
  final String executionCode;
  final String executedAt;
  final String executedByName;
  final String status;
  final int durationMs;
  final int affectedDevicesCount;
  final int successCount;
  final int failedCount;
  final String? sceneName;
  final String? sceneCode;
  final Map<String, dynamic> logDetails;

  const DeviceSceneExecutionRecord({
    required this.id,
    required this.executionCode,
    this.executedAt = 'Just now',
    this.executedByName = 'Admin',
    this.status = 'success',
    this.durationMs = 420,
    this.affectedDevicesCount = 8,
    this.successCount = 8,
    this.failedCount = 0,
    this.sceneName,
    this.sceneCode,
    this.logDetails = const {},
  });

  factory DeviceSceneExecutionRecord.fromJson(Map<String, dynamic> json) {
    return DeviceSceneExecutionRecord(
      id: json['id']?.toString() ?? '',
      executionCode: json['execution_code']?.toString() ?? '',
      executedAt: json['executed_at']?.toString() ?? 'Just now',
      executedByName: json['executed_by_name']?.toString() ?? 'Admin',
      status: json['status']?.toString() ?? 'success',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 420,
      affectedDevicesCount: (json['affected_devices_count'] as num?)?.toInt() ?? 8,
      successCount: (json['success_count'] as num?)?.toInt() ?? 8,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      sceneName: json['scene_name']?.toString(),
      sceneCode: json['scene_code']?.toString(),
      logDetails: json['log_details'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['log_details']) : const {},
    );
  }
}

// ============================================================================
// Energy & Usage Enterprise Models
// ============================================================================

class DeviceEnergyUsageKpis {
  final double totalEnergyTodayKwh;
  final double totalEnergyTodayTrend;
  final double totalCostTodayInr;
  final double totalCostTodayTrend;
  final double monthlyEnergyKwh;
  final double monthlyEnergyTrend;
  final double monthlyCostInr;
  final double monthlyCostTrend;
  final double co2EmissionMonthlyTonnes;
  final double co2EmissionTrend;
  final int activeDevicesCount;
  final int totalDevicesCount;
  final double uptimePct;

  const DeviceEnergyUsageKpis({
    this.totalEnergyTodayKwh = 482.7,
    this.totalEnergyTodayTrend = -12.4,
    this.totalCostTodayInr = 5795.0,
    this.totalCostTodayTrend = -12.4,
    this.monthlyEnergyKwh = 14860.0,
    this.monthlyEnergyTrend = -8.9,
    this.monthlyCostInr = 178320.0,
    this.monthlyCostTrend = -8.9,
    this.co2EmissionMonthlyTonnes = 11.2,
    this.co2EmissionTrend = -8.9,
    this.activeDevicesCount = 132,
    this.totalDevicesCount = 136,
    this.uptimePct = 97.1,
  });

  factory DeviceEnergyUsageKpis.fromJson(Map<String, dynamic> json) {
    return DeviceEnergyUsageKpis(
      totalEnergyTodayKwh: (json['total_energy_today_kwh'] as num?)?.toDouble() ?? 482.7,
      totalEnergyTodayTrend: (json['total_energy_today_trend'] as num?)?.toDouble() ?? -12.4,
      totalCostTodayInr: (json['total_cost_today_inr'] as num?)?.toDouble() ?? 5795.0,
      totalCostTodayTrend: (json['total_cost_today_trend'] as num?)?.toDouble() ?? -12.4,
      monthlyEnergyKwh: (json['monthly_energy_kwh'] as num?)?.toDouble() ?? 14860.0,
      monthlyEnergyTrend: (json['monthly_energy_trend'] as num?)?.toDouble() ?? -8.9,
      monthlyCostInr: (json['monthly_cost_inr'] as num?)?.toDouble() ?? 178320.0,
      monthlyCostTrend: (json['monthly_cost_trend'] as num?)?.toDouble() ?? -8.9,
      co2EmissionMonthlyTonnes: (json['co2_emission_monthly_tonnes'] as num?)?.toDouble() ?? 11.2,
      co2EmissionTrend: (json['co2_emission_trend'] as num?)?.toDouble() ?? -8.9,
      activeDevicesCount: (json['active_devices_count'] as num?)?.toInt() ?? 132,
      totalDevicesCount: (json['total_devices_count'] as num?)?.toInt() ?? 136,
      uptimePct: (json['uptime_pct'] as num?)?.toDouble() ?? 97.1,
    );
  }
}

class EnergyTrendPoint {
  final String date;
  final String label;
  final double dailyKwh;
  final double movingAvgKwh;
  final double costInr;
  final double co2Kg;

  const EnergyTrendPoint({
    required this.date,
    required this.label,
    required this.dailyKwh,
    required this.movingAvgKwh,
    this.costInr = 0.0,
    this.co2Kg = 0.0,
  });

  factory EnergyTrendPoint.fromJson(Map<String, dynamic> json) {
    return EnergyTrendPoint(
      date: json['date']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      dailyKwh: (json['daily_kwh'] as num?)?.toDouble() ?? 0.0,
      movingAvgKwh: (json['moving_avg_kwh'] as num?)?.toDouble() ?? 0.0,
      costInr: (json['cost_inr'] as num?)?.toDouble() ?? 0.0,
      co2Kg: (json['co2_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EnergyDeviceTypeSlice {
  final String name;
  final double kwh;
  final double percentage;
  final String colorHex;
  final int count;

  const EnergyDeviceTypeSlice({
    required this.name,
    required this.kwh,
    required this.percentage,
    required this.colorHex,
    this.count = 0,
  });

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF2563EB);
  }

  factory EnergyDeviceTypeSlice.fromJson(Map<String, dynamic> json) {
    return EnergyDeviceTypeSlice(
      name: json['name']?.toString() ?? '',
      kwh: (json['kwh'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color']?.toString() ?? '#2563EB',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class EnergyLocationSlice {
  final String name;
  final double kwh;
  final double percentage;
  final int deviceCount;

  const EnergyLocationSlice({
    required this.name,
    required this.kwh,
    required this.percentage,
    this.deviceCount = 0,
  });

  factory EnergyLocationSlice.fromJson(Map<String, dynamic> json) {
    return EnergyLocationSlice(
      name: json['name']?.toString() ?? '',
      kwh: (json['kwh'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceUptimeBreakdown {
  final double uptimePct;
  final int activeCount;
  final double activePct;
  final int idleCount;
  final double idlePct;
  final int offlineCount;
  final double offlinePct;
  final int totalDevices;

  const DeviceUptimeBreakdown({
    this.uptimePct = 97.1,
    this.activeCount = 132,
    this.activePct = 97.1,
    this.idleCount = 2,
    this.idlePct = 1.5,
    this.offlineCount = 2,
    this.offlinePct = 1.5,
    this.totalDevices = 136,
  });

  factory DeviceUptimeBreakdown.fromJson(Map<String, dynamic> json) {
    return DeviceUptimeBreakdown(
      uptimePct: (json['uptime_pct'] as num?)?.toDouble() ?? 97.1,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 132,
      activePct: (json['active_pct'] as num?)?.toDouble() ?? 97.1,
      idleCount: (json['idle_count'] as num?)?.toInt() ?? 2,
      idlePct: (json['idle_pct'] as num?)?.toDouble() ?? 1.5,
      offlineCount: (json['offline_count'] as num?)?.toInt() ?? 2,
      offlinePct: (json['offline_pct'] as num?)?.toDouble() ?? 1.5,
      totalDevices: (json['total_devices'] as num?)?.toInt() ?? 136,
    );
  }
}

class EnergyInsightItem {
  final String id;
  final String type; // 'positive', 'warning', 'recommendation'
  final String icon;
  final String title;
  final String text;

  const EnergyInsightItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.title,
    required this.text,
  });

  factory EnergyInsightItem.fromJson(Map<String, dynamic> json) {
    return EnergyInsightItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'positive',
      icon: json['icon']?.toString() ?? 'electric_bolt_rounded',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
    );
  }
}

class EnergyGoalsPolicy {
  final double monthlyTargetKwh;
  final double monthlyActualKwh;
  final double monthlyKwhPct;
  final double costTargetInr;
  final double costActualInr;
  final double costPct;
  final double emissionTargetTonnes;
  final double emissionActualTonnes;
  final double emissionPct;

  const EnergyGoalsPolicy({
    this.monthlyTargetKwh = 16000.0,
    this.monthlyActualKwh = 14860.0,
    this.monthlyKwhPct = 92.9,
    this.costTargetInr = 190000.0,
    this.costActualInr = 178320.0,
    this.costPct = 93.8,
    this.emissionTargetTonnes = 12.5,
    this.emissionActualTonnes = 11.2,
    this.emissionPct = 89.6,
  });

  factory EnergyGoalsPolicy.fromJson(Map<String, dynamic> json) {
    return EnergyGoalsPolicy(
      monthlyTargetKwh: (json['monthly_target_kwh'] as num?)?.toDouble() ?? 16000.0,
      monthlyActualKwh: (json['monthly_actual_kwh'] as num?)?.toDouble() ?? 14860.0,
      monthlyKwhPct: (json['monthly_kwh_pct'] as num?)?.toDouble() ?? 92.9,
      costTargetInr: (json['cost_target_inr'] as num?)?.toDouble() ?? 190000.0,
      costActualInr: (json['cost_actual_inr'] as num?)?.toDouble() ?? 178320.0,
      costPct: (json['cost_pct'] as num?)?.toDouble() ?? 93.8,
      emissionTargetTonnes: (json['emission_target_tonnes'] as num?)?.toDouble() ?? 12.5,
      emissionActualTonnes: (json['emission_actual_tonnes'] as num?)?.toDouble() ?? 11.2,
      emissionPct: (json['emission_pct'] as num?)?.toDouble() ?? 89.6,
    );
  }
}

class DeviceDetailedEnergyMetric {
  final String id;
  final String? deviceId;
  final String deviceName;
  final String deviceCode;
  final String deviceType;
  final String buildingName;
  final String roomName;
  final String locationPath;
  final String groupName;
  final String metricDate;
  final double energyKwh;
  final double usageHours;
  final double avgPowerWatts;
  final double costInr;
  final double co2Kg;
  final double trendPct;
  final String status;

  const DeviceDetailedEnergyMetric({
    required this.id,
    this.deviceId,
    required this.deviceName,
    required this.deviceCode,
    required this.deviceType,
    required this.buildingName,
    required this.roomName,
    required this.locationPath,
    required this.groupName,
    required this.metricDate,
    required this.energyKwh,
    required this.usageHours,
    required this.avgPowerWatts,
    required this.costInr,
    required this.co2Kg,
    required this.trendPct,
    this.status = 'active',
  });

  factory DeviceDetailedEnergyMetric.fromJson(Map<String, dynamic> json) {
    return DeviceDetailedEnergyMetric(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString(),
      deviceName: json['device_name']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
      locationPath: json['location_path']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? 'General',
      metricDate: json['metric_date']?.toString() ?? '',
      energyKwh: (json['energy_kwh'] as num?)?.toDouble() ?? 0.0,
      usageHours: (json['usage_hours'] as num?)?.toDouble() ?? 0.0,
      avgPowerWatts: (json['avg_power_watts'] as num?)?.toDouble() ?? 0.0,
      costInr: (json['cost_inr'] as num?)?.toDouble() ?? 0.0,
      co2Kg: (json['co2_kg'] as num?)?.toDouble() ?? 0.0,
      trendPct: (json['trend_pct'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'active',
    );
  }
}

// ----------------------------------------------------------------------------
// Location Energy Breakdown
// ----------------------------------------------------------------------------
class LocationEnergyBreakdown {
  final String buildingName;
  final double totalKwh;
  final double totalCostInr;
  final int deviceCount;
  final double areaSqM;
  final double energyIntensityKwhPerSqm;
  final double sharePercentage;
  final double trendPct;
  final int floorsCount;
  final int roomsCount;

  const LocationEnergyBreakdown({
    required this.buildingName,
    required this.totalKwh,
    required this.totalCostInr,
    required this.deviceCount,
    required this.areaSqM,
    required this.energyIntensityKwhPerSqm,
    required this.sharePercentage,
    required this.trendPct,
    required this.floorsCount,
    required this.roomsCount,
  });

  factory LocationEnergyBreakdown.fromJson(Map<String, dynamic> json) {
    return LocationEnergyBreakdown(
      buildingName: json['building_name']?.toString() ?? 'Building',
      totalKwh: (json['total_kwh'] as num?)?.toDouble() ?? 0.0,
      totalCostInr: (json['total_cost_inr'] as num?)?.toDouble() ?? 0.0,
      deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
      areaSqM: (json['area_sq_m'] as num?)?.toDouble() ?? 1000.0,
      energyIntensityKwhPerSqm: (json['energy_intensity_kwh_per_sqm'] as num?)?.toDouble() ?? 0.0,
      sharePercentage: (json['share_percentage'] as num?)?.toDouble() ?? 0.0,
      trendPct: (json['trend_pct'] as num?)?.toDouble() ?? 0.0,
      floorsCount: (json['floors_count'] as num?)?.toInt() ?? 2,
      roomsCount: (json['rooms_count'] as num?)?.toInt() ?? 8,
    );
  }
}

// ----------------------------------------------------------------------------
// Device Type Energy Breakdown
// ----------------------------------------------------------------------------
class DeviceTypeEnergyBreakdown {
  final String deviceType;
  final double totalKwh;
  final double sharePercentage;
  final int registeredDevices;
  final int monitoredDevices;
  final double totalOperatingHours;
  final double avgKwhPerDevice;
  final double costInr;
  final double co2Kg;
  final String efficiencyRating;

  const DeviceTypeEnergyBreakdown({
    required this.deviceType,
    required this.totalKwh,
    required this.sharePercentage,
    required this.registeredDevices,
    required this.monitoredDevices,
    required this.totalOperatingHours,
    required this.avgKwhPerDevice,
    required this.costInr,
    required this.co2Kg,
    required this.efficiencyRating,
  });

  factory DeviceTypeEnergyBreakdown.fromJson(Map<String, dynamic> json) {
    return DeviceTypeEnergyBreakdown(
      deviceType: json['device_type']?.toString() ?? 'Equipment',
      totalKwh: (json['total_kwh'] as num?)?.toDouble() ?? 0.0,
      sharePercentage: (json['share_percentage'] as num?)?.toDouble() ?? 0.0,
      registeredDevices: (json['registered_devices'] as num?)?.toInt() ?? 0,
      monitoredDevices: (json['monitored_devices'] as num?)?.toInt() ?? 0,
      totalOperatingHours: (json['total_operating_hours'] as num?)?.toDouble() ?? 0.0,
      avgKwhPerDevice: (json['avg_kwh_per_device'] as num?)?.toDouble() ?? 0.0,
      costInr: (json['cost_inr'] as num?)?.toDouble() ?? 0.0,
      co2Kg: (json['co2_kg'] as num?)?.toDouble() ?? 0.0,
      efficiencyRating: json['efficiency_rating']?.toString() ?? 'B',
    );
  }
}

// ----------------------------------------------------------------------------
// Electricity Tariff Item
// ----------------------------------------------------------------------------
class ElectricityTariffItem {
  final String id;
  final String providerName;
  final String tariffName;
  final String tariffType;
  final double ratePerKwhStandard;
  final double ratePerKwhPeak;
  final double ratePerKwhOffPeak;
  final String peakHoursStart;
  final String peakHoursEnd;
  final double fixedChargeMonthly;
  final double demandChargePerKw;
  final double taxPct;
  final bool isActive;

  const ElectricityTariffItem({
    required this.id,
    required this.providerName,
    required this.tariffName,
    required this.tariffType,
    required this.ratePerKwhStandard,
    required this.ratePerKwhPeak,
    required this.ratePerKwhOffPeak,
    required this.peakHoursStart,
    required this.peakHoursEnd,
    required this.fixedChargeMonthly,
    required this.demandChargePerKw,
    required this.taxPct,
    required this.isActive,
  });

  factory ElectricityTariffItem.fromJson(Map<String, dynamic> json) {
    return ElectricityTariffItem(
      id: json['id']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      tariffName: json['tariff_name']?.toString() ?? '',
      tariffType: json['tariff_type']?.toString() ?? 'time_of_use',
      ratePerKwhStandard: (json['rate_per_kwh_standard'] as num?)?.toDouble() ?? 12.0,
      ratePerKwhPeak: (json['rate_per_kwh_peak'] as num?)?.toDouble() ?? 15.5,
      ratePerKwhOffPeak: (json['rate_per_kwh_off_peak'] as num?)?.toDouble() ?? 8.5,
      peakHoursStart: json['peak_hours_start']?.toString() ?? '18:00',
      peakHoursEnd: json['peak_hours_end']?.toString() ?? '22:00',
      fixedChargeMonthly: (json['fixed_charge_monthly'] as num?)?.toDouble() ?? 5000.0,
      demandChargePerKw: (json['demand_charge_per_kw'] as num?)?.toDouble() ?? 350.0,
      taxPct: (json['tax_pct'] as num?)?.toDouble() ?? 18.0,
      isActive: json['is_active'] == true,
    );
  }
}

// ----------------------------------------------------------------------------
// Utility Bill Item
// ----------------------------------------------------------------------------
class UtilityBillItem {
  final String id;
  final String providerName;
  final String billNumber;
  final String billingPeriodStart;
  final String billingPeriodEnd;
  final double unitsConsumedKwh;
  final double amountInr;
  final double taxInr;
  final double fixedChargesInr;
  final double calculatedMeterKwh;
  final double variancePct;
  final String dueDate;
  final String status;
  final String? notes;

  const UtilityBillItem({
    required this.id,
    required this.providerName,
    required this.billNumber,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.unitsConsumedKwh,
    required this.amountInr,
    required this.taxInr,
    required this.fixedChargesInr,
    required this.calculatedMeterKwh,
    required this.variancePct,
    required this.dueDate,
    required this.status,
    this.notes,
  });

  factory UtilityBillItem.fromJson(Map<String, dynamic> json) {
    return UtilityBillItem(
      id: json['id']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      billNumber: json['bill_number']?.toString() ?? '',
      billingPeriodStart: json['billing_period_start']?.toString() ?? '',
      billingPeriodEnd: json['billing_period_end']?.toString() ?? '',
      unitsConsumedKwh: (json['units_consumed_kwh'] as num?)?.toDouble() ?? 0.0,
      amountInr: (json['amount_inr'] as num?)?.toDouble() ?? 0.0,
      taxInr: (json['tax_inr'] as num?)?.toDouble() ?? 0.0,
      fixedChargesInr: (json['fixed_charges_inr'] as num?)?.toDouble() ?? 0.0,
      calculatedMeterKwh: (json['calculated_meter_kwh'] as num?)?.toDouble() ?? 0.0,
      variancePct: (json['variance_pct'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'paid',
      notes: json['notes']?.toString(),
    );
  }
}

// ----------------------------------------------------------------------------
// Smart Energy Meter
// ----------------------------------------------------------------------------
class SmartEnergyMeter {
  final String id;
  final String meterName;
  final String meterCode;
  final String meterType;
  final String protocol;
  final String? mqttTopic;
  final String? ipAddress;
  final String buildingName;
  final String? floorName;
  final String? roomName;
  final String locationPath;
  final double voltage;
  final double currentAmps;
  final double activePowerWatts;
  final double powerFactor;
  final double frequencyHz;
  final double totalImportKwh;
  final String status;

  const SmartEnergyMeter({
    required this.id,
    required this.meterName,
    required this.meterCode,
    required this.meterType,
    required this.protocol,
    this.mqttTopic,
    this.ipAddress,
    required this.buildingName,
    this.floorName,
    this.roomName,
    required this.locationPath,
    required this.voltage,
    required this.currentAmps,
    required this.activePowerWatts,
    required this.powerFactor,
    required this.frequencyHz,
    required this.totalImportKwh,
    required this.status,
  });

  factory SmartEnergyMeter.fromJson(Map<String, dynamic> json) {
    return SmartEnergyMeter(
      id: json['id']?.toString() ?? '',
      meterName: json['meter_name']?.toString() ?? '',
      meterCode: json['meter_code']?.toString() ?? '',
      meterType: json['meter_type']?.toString() ?? 'smart_meter',
      protocol: json['protocol']?.toString() ?? 'mqtt',
      mqttTopic: json['mqtt_topic']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      buildingName: json['building_name']?.toString() ?? '',
      floorName: json['floor_name']?.toString(),
      roomName: json['room_name']?.toString(),
      locationPath: json['location_path']?.toString() ?? '',
      voltage: (json['voltage'] as num?)?.toDouble() ?? 230.0,
      currentAmps: (json['current_amps'] as num?)?.toDouble() ?? 0.0,
      activePowerWatts: (json['active_power_watts'] as num?)?.toDouble() ?? 0.0,
      powerFactor: (json['power_factor'] as num?)?.toDouble() ?? 0.95,
      frequencyHz: (json['frequency_hz'] as num?)?.toDouble() ?? 50.0,
      totalImportKwh: (json['total_import_kwh'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'online',
    );
  }
}

// ----------------------------------------------------------------------------
// Energy Report Item
// ----------------------------------------------------------------------------
class EnergyReportItem {
  final String id;
  final String reportTitle;
  final String templateType;
  final String scopeType;
  final String scopeId;
  final String dateFrom;
  final String dateTo;
  final String fileFormat;
  final int fileSizeKb;
  final String generatedBy;
  final String status;
  final String createdAt;

  const EnergyReportItem({
    required this.id,
    required this.reportTitle,
    required this.templateType,
    required this.scopeType,
    required this.scopeId,
    required this.dateFrom,
    required this.dateTo,
    required this.fileFormat,
    required this.fileSizeKb,
    required this.generatedBy,
    required this.status,
    required this.createdAt,
  });

  factory EnergyReportItem.fromJson(Map<String, dynamic> json) {
    return EnergyReportItem(
      id: json['id']?.toString() ?? '',
      reportTitle: json['report_title']?.toString() ?? '',
      templateType: json['template_type']?.toString() ?? '',
      scopeType: json['scope_type']?.toString() ?? 'campus',
      scopeId: json['scope_id']?.toString() ?? 'All',
      dateFrom: json['date_from']?.toString() ?? '',
      dateTo: json['date_to']?.toString() ?? '',
      fileFormat: json['file_format']?.toString() ?? 'pdf',
      fileSizeKb: (json['file_size_kb'] as num?)?.toInt() ?? 350,
      generatedBy: json['generated_by']?.toString() ?? 'Admin',
      status: json['status']?.toString() ?? 'completed',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}









// ============================================================================
// DEVICE HEALTH & DIAGNOSTICS ENTERPRISE MODELS
// ============================================================================

class DeviceHealthKpis {
  final int totalDevices;
  final int healthyCount;
  final double healthyPct;
  final int warningCount;
  final double warningPct;
  final int criticalCount;
  final double criticalPct;
  final int offlineCount;
  final double offlinePct;
  final double avgUptimePct;

  const DeviceHealthKpis({
    this.totalDevices = 136,
    this.healthyCount = 122,
    this.healthyPct = 89.7,
    this.warningCount = 8,
    this.warningPct = 5.9,
    this.criticalCount = 4,
    this.criticalPct = 2.9,
    this.offlineCount = 2,
    this.offlinePct = 1.5,
    this.avgUptimePct = 98.6,
  });

  factory DeviceHealthKpis.fromJson(Map<String, dynamic> json) {
    final tot = (json['total_devices'] as num?)?.toInt() ?? 136;
    final h = (json['healthy_count'] as num?)?.toInt() ?? 122;
    final w = (json['warning_count'] as num?)?.toInt() ?? 8;
    final c = (json['critical_count'] as num?)?.toInt() ?? 4;
    final off = (json['offline_count'] as num?)?.toInt() ?? 2;
    return DeviceHealthKpis(
      totalDevices: tot,
      healthyCount: h,
      healthyPct: (json['healthy_pct'] as num?)?.toDouble() ?? (tot > 0 ? (h / tot * 100) : 89.7),
      warningCount: w,
      warningPct: (json['warning_pct'] as num?)?.toDouble() ?? (tot > 0 ? (w / tot * 100) : 5.9),
      criticalCount: c,
      criticalPct: (json['critical_pct'] as num?)?.toDouble() ?? (tot > 0 ? (c / tot * 100) : 2.9),
      offlineCount: off,
      offlinePct: (json['offline_pct'] as num?)?.toDouble() ?? (tot > 0 ? (off / tot * 100) : 1.5),
      avgUptimePct: (json['avg_uptime_pct'] as num?)?.toDouble() ?? 98.6,
    );
  }
}

class HealthTrendPoint {
  final String date;
  final int healthy;
  final int warnings;
  final int criticalOffline;
  final int total;
  final double uptimePct;

  const HealthTrendPoint({
    required this.date,
    required this.healthy,
    required this.warnings,
    required this.criticalOffline,
    this.total = 136,
    this.uptimePct = 98.6,
  });

  factory HealthTrendPoint.fromJson(Map<String, dynamic> json) {
    return HealthTrendPoint(
      date: json['date']?.toString() ?? '',
      healthy: (json['healthy'] as num?)?.toInt() ?? 122,
      warnings: (json['warnings'] as num?)?.toInt() ?? 8,
      criticalOffline: (json['critical_offline'] as num?)?.toInt() ?? 6,
      total: (json['total'] as num?)?.toInt() ?? 136,
      uptimePct: (json['uptime_pct'] as num?)?.toDouble() ?? 98.6,
    );
  }
}

class HealthKeyAlert {
  final String title;
  final int count;
  final String severity;

  const HealthKeyAlert({
    required this.title,
    required this.count,
    required this.severity,
  });

  factory HealthKeyAlert.fromJson(Map<String, dynamic> json) {
    return HealthKeyAlert(
      title: json['title']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      severity: json['severity']?.toString() ?? 'warning',
    );
  }
}

class HealthDeviceTypeSlice {
  final String type;
  final int healthy;
  final int total;
  final double pct;
  final Color color;

  const HealthDeviceTypeSlice({
    required this.type,
    required this.healthy,
    required this.total,
    required this.pct,
    required this.color,
  });

  factory HealthDeviceTypeSlice.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return const Color(0xFF1677F2);
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      return const Color(0xFF1677F2);
    }

    return HealthDeviceTypeSlice(
      type: json['type']?.toString() ?? '',
      healthy: (json['healthy'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      pct: (json['pct'] as num?)?.toDouble() ?? 0.0,
      color: parseColor(json['color']?.toString()),
    );
  }
}

class HealthSystemStatus {
  final String mqttBroker;
  final String gateways;
  final String commandService;
  final String diagnosticsWorker;
  final String databaseTelemetry;
  final String lastDataReceived;

  const HealthSystemStatus({
    this.mqttBroker = 'Connected (QoS 1)',
    this.gateways = '5 Online / 5 Total',
    this.commandService = 'Healthy',
    this.diagnosticsWorker = 'Running',
    this.databaseTelemetry = 'Healthy',
    this.lastDataReceived = '10 Jan 2025, 02:18 PM',
  });

  factory HealthSystemStatus.fromJson(Map<String, dynamic> json) {
    return HealthSystemStatus(
      mqttBroker: json['mqtt_broker']?.toString() ?? 'Connected (QoS 1)',
      gateways: json['gateways']?.toString() ?? '5 Online / 5 Total',
      commandService: json['command_service']?.toString() ?? 'Healthy',
      diagnosticsWorker: json['diagnostics_worker']?.toString() ?? 'Running',
      databaseTelemetry: json['database_telemetry']?.toString() ?? 'Healthy',
      lastDataReceived: json['last_data_received']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }
}

class DeviceHealthItem {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String deviceType;
  final String locationPath;
  final String healthStatus;
  final String uptime;
  final double uptimePct;
  final String lastSeen;
  final String issuesAlerts;
  final int responseLatencyMs;
  final String firmwareVersion;
  final bool hasFirmwareUpdate;
  final String latestFirmwareVersion;
  final String gatewayName;
  final bool isOnline;

  const DeviceHealthItem({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.deviceType,
    required this.locationPath,
    required this.healthStatus,
    required this.uptime,
    required this.uptimePct,
    required this.lastSeen,
    required this.issuesAlerts,
    this.responseLatencyMs = 45,
    this.firmwareVersion = 'v2.4.1',
    this.hasFirmwareUpdate = false,
    this.latestFirmwareVersion = 'v2.4.1',
    this.gatewayName = 'Main Campus Gateway',
    this.isOnline = true,
  });

  factory DeviceHealthItem.fromJson(Map<String, dynamic> json) {
    return DeviceHealthItem(
      id: json['id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      deviceCode: json['device_code']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? 'Others',
      locationPath: json['location_path']?.toString() ?? '',
      healthStatus: json['health_status']?.toString() ?? 'healthy',
      uptime: json['uptime']?.toString() ?? '99.5%',
      uptimePct: (json['uptime_pct'] as num?)?.toDouble() ?? 99.5,
      lastSeen: json['last_seen']?.toString() ?? '10 Jan 2025, 02:17 PM',
      issuesAlerts: json['issues_alerts']?.toString() ?? '-',
      responseLatencyMs: (json['response_latency_ms'] as num?)?.toInt() ?? 45,
      firmwareVersion: json['firmware_version']?.toString() ?? 'v2.4.1',
      hasFirmwareUpdate: json['has_firmware_update'] == true,
      latestFirmwareVersion: json['latest_firmware_version']?.toString() ?? 'v2.4.1',
      gatewayName: json['gateway_name']?.toString() ?? 'Main Campus Gateway',
      isOnline: json['is_online'] != false,
    );
  }

  DeviceHealthItem copyWith({
    String? healthStatus,
    String? issuesAlerts,
    String? firmwareVersion,
    bool? hasFirmwareUpdate,
    bool? isOnline,
  }) {
    return DeviceHealthItem(
      id: id,
      deviceName: deviceName,
      deviceCode: deviceCode,
      deviceType: deviceType,
      locationPath: locationPath,
      healthStatus: healthStatus ?? this.healthStatus,
      uptime: uptime,
      uptimePct: uptimePct,
      lastSeen: lastSeen,
      issuesAlerts: issuesAlerts ?? this.issuesAlerts,
      responseLatencyMs: responseLatencyMs,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hasFirmwareUpdate: hasFirmwareUpdate ?? this.hasFirmwareUpdate,
      latestFirmwareVersion: latestFirmwareVersion,
      gatewayName: gatewayName,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class DeviceDiagnosticResultItem {
  final String testCode;
  final String testName;
  final String testCategory;
  final String status;
  final String actualValue;
  final String expectedValue;
  final String unit;
  final int durationMs;
  final String recommendedAction;

  const DeviceDiagnosticResultItem({
    required this.testCode,
    required this.testName,
    required this.testCategory,
    required this.status,
    required this.actualValue,
    required this.expectedValue,
    required this.unit,
    required this.durationMs,
    required this.recommendedAction,
  });

  factory DeviceDiagnosticResultItem.fromJson(Map<String, dynamic> json) {
    return DeviceDiagnosticResultItem(
      testCode: json['test_code']?.toString() ?? '',
      testName: json['test_name']?.toString() ?? '',
      testCategory: json['test_category']?.toString() ?? 'general',
      status: json['status']?.toString() ?? 'passed',
      actualValue: json['actual_value']?.toString() ?? '',
      expectedValue: json['expected_value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      recommendedAction: json['recommended_action']?.toString() ?? 'None required',
    );
  }
}

class CampusIotGatewayItem {
  final String id;
  final String gatewayCode;
  final String gatewayName;
  final String gatewayType;
  final String ipAddress;
  final String protocol;
  final String locationPath;
  final String status;
  final bool isOnline;
  final int connectedDevices;
  final double cpuUsagePct;
  final double memoryUsagePct;
  final double temperatureCelsius;
  final double uptimeHours;
  final String firmwareVersion;

  const CampusIotGatewayItem({
    required this.id,
    required this.gatewayCode,
    required this.gatewayName,
    required this.gatewayType,
    required this.ipAddress,
    required this.protocol,
    required this.locationPath,
    required this.status,
    required this.isOnline,
    required this.connectedDevices,
    required this.cpuUsagePct,
    required this.memoryUsagePct,
    required this.temperatureCelsius,
    required this.uptimeHours,
    required this.firmwareVersion,
  });

  factory CampusIotGatewayItem.fromJson(Map<String, dynamic> json) {
    return CampusIotGatewayItem(
      id: json['id']?.toString() ?? '',
      gatewayCode: json['gateway_code']?.toString() ?? '',
      gatewayName: json['gateway_name']?.toString() ?? '',
      gatewayType: json['gateway_type']?.toString() ?? 'mqtt',
      ipAddress: json['ip_address']?.toString() ?? '192.168.1.10',
      protocol: json['protocol']?.toString() ?? 'mqtt',
      locationPath: json['location_path']?.toString() ?? '',
      status: json['status']?.toString() ?? 'online',
      isOnline: json['is_online'] != false,
      connectedDevices: (json['connected_devices'] as num?)?.toInt() ?? 0,
      cpuUsagePct: (json['cpu_usage_pct'] as num?)?.toDouble() ?? 20.0,
      memoryUsagePct: (json['memory_usage_pct'] as num?)?.toDouble() ?? 40.0,
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble() ?? 38.0,
      uptimeHours: (json['uptime_hours'] as num?)?.toDouble() ?? 720.0,
      firmwareVersion: json['firmware_version']?.toString() ?? 'v3.2.0',
    );
  }
}

class DeviceHealthRuleItem {
  final String id;
  final String ruleName;
  final String ruleCode;
  final String scopeType;
  final String scopeName;
  final String metricName;
  final String operator;
  final double thresholdValue;
  final int durationSeconds;
  final String severity;
  final bool isActive;

  const DeviceHealthRuleItem({
    required this.id,
    required this.ruleName,
    required this.ruleCode,
    required this.scopeType,
    required this.scopeName,
    required this.metricName,
    required this.operator,
    required this.thresholdValue,
    required this.durationSeconds,
    required this.severity,
    required this.isActive,
  });

  factory DeviceHealthRuleItem.fromJson(Map<String, dynamic> json) {
    return DeviceHealthRuleItem(
      id: json['id']?.toString() ?? '',
      ruleName: json['rule_name']?.toString() ?? '',
      ruleCode: json['rule_code']?.toString() ?? '',
      scopeType: json['scope_type']?.toString() ?? 'global',
      scopeName: json['scope_name']?.toString() ?? 'Campus Wide',
      metricName: json['metric_name']?.toString() ?? '',
      operator: json['operator']?.toString() ?? '>',
      thresholdValue: (json['threshold_value'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 60,
      severity: json['severity']?.toString() ?? 'warning',
      isActive: json['is_active'] != false,
    );
  }
}


// ============================================================================
// ENTERPRISE IOT INTEGRATIONS & GATEWAYS MODELS
// ============================================================================

class IntegrationGatewayKpis {
  final int totalGateways;
  final int onlineGateways;
  final double onlineGatewaysPct;
  final int offlineGateways;
  final double offlineGatewaysPct;
  final int activeIntegrations;
  final int totalIntegrations;
  final double activeIntegrationsPct;
  final String dataThroughput;
  final int mqttConnections;
  final String integrationHealth;
  final int activeProtocols;

  IntegrationGatewayKpis({
    this.totalGateways = 8,
    this.onlineGateways = 7,
    this.onlineGatewaysPct = 87.5,
    this.offlineGateways = 1,
    this.offlineGatewaysPct = 12.5,
    this.activeIntegrations = 6,
    this.totalIntegrations = 6,
    this.activeIntegrationsPct = 100.0,
    this.dataThroughput = '12.8 MB/min',
    this.mqttConnections = 136,
    this.integrationHealth = 'Healthy',
    this.activeProtocols = 6,
  });

  factory IntegrationGatewayKpis.fromJson(Map<String, dynamic> json) {
    return IntegrationGatewayKpis(
      totalGateways: (json['total_gateways'] as num?)?.toInt() ?? 8,
      onlineGateways: (json['online_gateways'] as num?)?.toInt() ?? 7,
      onlineGatewaysPct: (json['online_gateways_pct'] as num?)?.toDouble() ?? 87.5,
      offlineGateways: (json['offline_gateways'] as num?)?.toInt() ?? 1,
      offlineGatewaysPct: (json['offline_gateways_pct'] as num?)?.toDouble() ?? 12.5,
      activeIntegrations: (json['active_integrations'] as num?)?.toInt() ?? 6,
      totalIntegrations: (json['total_integrations'] as num?)?.toInt() ?? 6,
      activeIntegrationsPct: (json['active_integrations_pct'] as num?)?.toDouble() ?? 100.0,
      dataThroughput: json['data_throughput']?.toString() ?? '12.8 MB/min',
      mqttConnections: (json['mqtt_connections'] as num?)?.toInt() ?? 136,
      integrationHealth: json['integration_health']?.toString() ?? 'Healthy',
      activeProtocols: (json['active_protocols'] as num?)?.toInt() ?? 6,
    );
  }
}

class IotProtocolItem {
  final String id;
  final String name;
  final String code;
  final String status;
  final bool isConnected;
  final int count;
  final String label;
  final String displayText;

  IotProtocolItem({
    required this.id,
    required this.name,
    required this.code,
    this.status = 'Active',
    this.isConnected = true,
    this.count = 0,
    this.label = 'devices',
    this.displayText = '',
  });

  factory IotProtocolItem.fromJson(Map<String, dynamic> json) {
    return IotProtocolItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      isConnected: json['is_connected'] != false,
      count: (json['count'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? 'devices',
      displayText: json['display_text']?.toString() ?? '${json['count'] ?? 0} ${json['label'] ?? "devices"}',
    );
  }
}

class IntegrationHealthServiceItem {
  final String name;
  final String status;
  final bool isOperational;

  IntegrationHealthServiceItem({
    required this.name,
    this.status = 'Operational',
    this.isOperational = true,
  });

  factory IntegrationHealthServiceItem.fromJson(Map<String, dynamic> json) {
    return IntegrationHealthServiceItem(
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Operational',
      isOperational: json['is_operational'] != false,
    );
  }
}

class CampusGatewayItem {
  final String id;
  final String gatewayCode;
  final String gatewayName;
  final String gatewayType;
  final String ipAddress;
  final String macAddress;
  final String protocols;
  final String locationPath;
  final String status;
  final bool isOnline;
  final int connectedDevicesCount;
  final String uptimeDisplay;
  final String firmwareVersion;
  final String? firmwareUpdateAvailable;
  final double dataThroughputMbMin;
  final String lastHeartbeat;

  CampusGatewayItem({
    required this.id,
    required this.gatewayCode,
    required this.gatewayName,
    this.gatewayType = 'edge_router',
    this.ipAddress = '192.168.10.21',
    this.macAddress = '00:1A:2B:3C:4D:5E',
    this.protocols = 'MQTT, Modbus (TCP)',
    this.locationPath = 'Main Block',
    this.status = 'online',
    this.isOnline = true,
    this.connectedDevicesCount = 28,
    this.uptimeDisplay = '15 days, 08:36:21 (99.6%)',
    this.firmwareVersion = 'v2.3.1',
    this.firmwareUpdateAvailable = 'v2.4.0',
    this.dataThroughputMbMin = 2.8,
    this.lastHeartbeat = '10 Jan 2025, 02:18 PM',
  });

  factory CampusGatewayItem.fromJson(Map<String, dynamic> json) {
    return CampusGatewayItem(
      id: json['id']?.toString() ?? '',
      gatewayCode: json['gateway_code']?.toString() ?? 'GW-0001',
      gatewayName: json['gateway_name']?.toString() ?? '',
      gatewayType: json['gateway_type']?.toString() ?? 'edge_router',
      ipAddress: json['ip_address']?.toString() ?? '192.168.10.21',
      macAddress: json['mac_address']?.toString() ?? '00:1A:2B:3C:4D:5E',
      protocols: json['protocols']?.toString() ?? 'MQTT, Modbus',
      locationPath: json['location_path']?.toString() ?? 'Main Block',
      status: json['status']?.toString() ?? 'online',
      isOnline: json['is_online'] != false,
      connectedDevicesCount: (json['connected_devices_count'] as num?)?.toInt() ?? 0,
      uptimeDisplay: json['uptime_display']?.toString() ?? '15 days, 08:36:21 (99.6%)',
      firmwareVersion: json['firmware_version']?.toString() ?? 'v2.3.1',
      firmwareUpdateAvailable: json['firmware_update_available']?.toString(),
      dataThroughputMbMin: (json['data_throughput_mb_min'] as num?)?.toDouble() ?? 1.6,
      lastHeartbeat: json['last_heartbeat']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }

  CampusGatewayItem copyWith({
    String? status,
    bool? isOnline,
    String? firmwareVersion,
    String? firmwareUpdateAvailable,
  }) {
    return CampusGatewayItem(
      id: id,
      gatewayCode: gatewayCode,
      gatewayName: gatewayName,
      gatewayType: gatewayType,
      ipAddress: ipAddress,
      macAddress: macAddress,
      protocols: protocols,
      locationPath: locationPath,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      connectedDevicesCount: connectedDevicesCount,
      uptimeDisplay: uptimeDisplay,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      firmwareUpdateAvailable: firmwareUpdateAvailable,
      dataThroughputMbMin: dataThroughputMbMin,
      lastHeartbeat: lastHeartbeat,
    );
  }
}

class ThirdPartyIntegrationItem {
  final String id;
  final String name;
  final String type;
  final String category;
  final String provider;
  final String protocol;
  final String connectionMode;
  final int connectedDevicesCount;
  final String status;
  final bool isActive;
  final String lastSync;

  ThirdPartyIntegrationItem({
    required this.id,
    required this.name,
    required this.type,
    this.category = 'custom',
    this.provider = 'Standard',
    required this.protocol,
    this.connectionMode = 'Direct',
    this.connectedDevicesCount = 0,
    this.status = 'active',
    this.isActive = true,
    this.lastSync = '10 Jan 2025, 02:10 PM',
  });

  factory ThirdPartyIntegrationItem.fromJson(Map<String, dynamic> json) {
    return ThirdPartyIntegrationItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Facility Integration',
      category: json['category']?.toString() ?? 'custom',
      provider: json['provider']?.toString() ?? 'Standard',
      protocol: json['protocol']?.toString() ?? 'MQTT',
      connectionMode: json['connection_mode']?.toString() ?? 'Direct',
      connectedDevicesCount: (json['connected_devices_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
      isActive: json['is_active'] != false,
      lastSync: json['last_sync']?.toString() ?? '10 Jan 2025, 02:10 PM',
    );
  }
}

class DiscoveredDeviceItem {
  final String id;
  final String deviceIdentifier;
  final String deviceName;
  final String deviceType;
  final String protocol;
  final String manufacturer;
  final String model;
  final String macAddress;
  final String ipAddress;
  final int signalStrengthDbm;
  final String locationSuggestion;
  final String status;
  final String gatewayName;

  DiscoveredDeviceItem({
    required this.id,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.deviceType,
    required this.protocol,
    this.manufacturer = 'Generic',
    this.model = 'Model-X',
    this.macAddress = '00:11:22:33:44:55',
    this.ipAddress = '192.168.10.199',
    this.signalStrengthDbm = -60,
    this.locationSuggestion = 'Main Block',
    this.status = 'newly_discovered',
    this.gatewayName = 'GW-A01 (Main Block)',
  });

  factory DiscoveredDeviceItem.fromJson(Map<String, dynamic> json) {
    return DiscoveredDeviceItem(
      id: json['id']?.toString() ?? '',
      deviceIdentifier: json['device_identifier']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      deviceType: json['device_type']?.toString() ?? 'Sensor',
      protocol: json['protocol']?.toString() ?? 'Zigbee',
      manufacturer: json['manufacturer']?.toString() ?? 'Generic',
      model: json['model']?.toString() ?? '',
      macAddress: json['mac_address']?.toString() ?? '00:11:22:33:44:55',
      ipAddress: json['ip_address']?.toString() ?? '192.168.10.199',
      signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt() ?? -60,
      locationSuggestion: json['location_suggestion']?.toString() ?? 'Main Block',
      status: json['status']?.toString() ?? 'newly_discovered',
      gatewayName: json['gateway_name']?.toString() ?? 'GW-A01 (Main Block)',
    );
  }
}

class IotWebhookItem {
  final String id;
  final String name;
  final String direction;
  final String endpointUrl;
  final List<String> eventTypes;
  final String status;
  final int retryCount;
  final String lastDelivery;
  final int lastStatusCode;

  IotWebhookItem({
    required this.id,
    required this.name,
    this.direction = 'outgoing',
    required this.endpointUrl,
    this.eventTypes = const [],
    this.status = 'active',
    this.retryCount = 3,
    this.lastDelivery = '10 Jan 2025, 02:15 PM',
    this.lastStatusCode = 200,
  });

  factory IotWebhookItem.fromJson(Map<String, dynamic> json) {
    List<String> events = [];
    if (json['event_types'] is List) {
      events = (json['event_types'] as List).map((e) => e.toString()).toList();
    }
    return IotWebhookItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'outgoing',
      endpointUrl: json['endpoint_url']?.toString() ?? '',
      eventTypes: events,
      status: json['status']?.toString() ?? 'active',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 3,
      lastDelivery: json['last_delivery_at']?.toString() ?? '10 Jan 2025, 02:15 PM',
      lastStatusCode: (json['last_status_code'] as num?)?.toInt() ?? 200,
    );
  }
}

class IotCertificateItem {
  final String id;
  final String name;
  final String certType;
  final String subject;
  final String issuer;
  final String status;
  final String thumbprint;

  IotCertificateItem({
    required this.id,
    required this.name,
    this.certType = 'client',
    this.subject = '',
    this.issuer = '',
    this.status = 'active',
    this.thumbprint = '',
  });

  factory IotCertificateItem.fromJson(Map<String, dynamic> json) {
    return IotCertificateItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      certType: json['cert_type']?.toString() ?? 'client',
      subject: json['subject']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      thumbprint: json['thumbprint']?.toString() ?? '',
    );
  }
}

class IotLogItem {
  final String id;
  final String source;
  final String severity;
  final String protocol;
  final String event;
  final String message;
  final String correlationId;
  final String timestamp;

  IotLogItem({
    required this.id,
    required this.source,
    this.severity = 'info',
    this.protocol = 'MQTT',
    required this.event,
    required this.message,
    this.correlationId = 'CORR-001',
    this.timestamp = '10 Jan 2025, 02:18 PM',
  });

  factory IotLogItem.fromJson(Map<String, dynamic> json) {
    return IotLogItem(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Gateway',
      severity: json['severity']?.toString() ?? 'info',
      protocol: json['protocol']?.toString() ?? 'MQTT',
      event: json['event']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      correlationId: json['correlation_id']?.toString() ?? 'CORR-001',
      timestamp: json['timestamp']?.toString() ?? json['created_at']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }
}


// ============================================================================
// ACCESS & PERMISSIONS ENTERPRISE DATA MODELS
// ============================================================================

class AccessPermissionsKpis {
  final int totalUsers;
  final int totalRoles;
  final int permissionPolicies;
  final int userGroups;
  final int pendingRequests;
  final String accessHealth;

  AccessPermissionsKpis({
    this.totalUsers = 238,
    this.totalRoles = 12,
    this.permissionPolicies = 6,
    this.userGroups = 18,
    this.pendingRequests = 4,
    this.accessHealth = 'Compliant',
  });

  factory AccessPermissionsKpis.fromJson(Map<String, dynamic> json) {
    return AccessPermissionsKpis(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 238,
      totalRoles: (json['total_roles'] as num?)?.toInt() ?? 12,
      permissionPolicies: (json['permission_policies'] as num?)?.toInt() ?? 6,
      userGroups: (json['user_groups'] as num?)?.toInt() ?? 18,
      pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 4,
      accessHealth: json['access_health']?.toString() ?? 'Compliant',
    );
  }
}

class RoleDistributionItem {
  final String name;
  final int count;
  final double percentage;
  final String colorHex;

  RoleDistributionItem({
    required this.name,
    required this.count,
    required this.percentage,
    required this.colorHex,
  });

  factory RoleDistributionItem.fromJson(Map<String, dynamic> json) {
    return RoleDistributionItem(
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color']?.toString() ?? json['color_hex']?.toString() ?? '#1677F2',
    );
  }
}

class PermissionCoverageItem {
  final String domain;
  final int percentage;

  PermissionCoverageItem({
    required this.domain,
    required this.percentage,
  });

  factory PermissionCoverageItem.fromJson(Map<String, dynamic> json) {
    return PermissionCoverageItem(
      domain: json['domain']?.toString() ?? '',
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
    );
  }
}

class EnterpriseRoleItem {
  final String id;
  final String roleName;
  final String roleCode;
  final String description;
  final int usersCount;
  final String keyPermissions;
  final String status;
  final bool isSystem;
  final String roleCategory;
  final String colorHex;
  final String iconName;
  final int priority;
  final String locationScope;
  final String deviceTypesScope;
  final String timePolicy;
  final String accessChannel;

  EnterpriseRoleItem({
    required this.id,
    required this.roleName,
    required this.roleCode,
    this.description = '',
    this.usersCount = 0,
    this.keyPermissions = '',
    this.status = 'Active',
    this.isSystem = false,
    this.roleCategory = 'Operational',
    this.colorHex = '#1677F2',
    this.iconName = 'admin_panel_settings',
    this.priority = 10,
    this.locationScope = 'Assigned Locations',
    this.deviceTypesScope = 'All (within assigned locations)',
    this.timePolicy = 'Allowed (24 x 7)',
    this.accessChannel = 'Web & Mobile',
  });

  EnterpriseRoleItem copyWith({
    String? roleName,
    String? description,
    int? usersCount,
    String? keyPermissions,
    String? status,
    String? locationScope,
    String? deviceTypesScope,
    String? timePolicy,
    String? accessChannel,
  }) {
    return EnterpriseRoleItem(
      id: id,
      roleName: roleName ?? this.roleName,
      roleCode: roleCode,
      description: description ?? this.description,
      usersCount: usersCount ?? this.usersCount,
      keyPermissions: keyPermissions ?? this.keyPermissions,
      status: status ?? this.status,
      isSystem: isSystem,
      roleCategory: roleCategory,
      colorHex: colorHex,
      iconName: iconName,
      priority: priority,
      locationScope: locationScope ?? this.locationScope,
      deviceTypesScope: deviceTypesScope ?? this.deviceTypesScope,
      timePolicy: timePolicy ?? this.timePolicy,
      accessChannel: accessChannel ?? this.accessChannel,
    );
  }

  factory EnterpriseRoleItem.fromJson(Map<String, dynamic> json) {
    return EnterpriseRoleItem(
      id: json['id']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      roleCode: json['role_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      usersCount: (json['users_count'] as num?)?.toInt() ?? 0,
      keyPermissions: json['key_permissions']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      isSystem: json['is_system'] == true,
      roleCategory: json['role_category']?.toString() ?? 'Operational',
      colorHex: json['color_hex']?.toString() ?? '#1677F2',
      iconName: json['icon_name']?.toString() ?? 'admin_panel_settings',
      priority: (json['priority'] as num?)?.toInt() ?? 10,
      locationScope: json['location_scope']?.toString() ?? 'Assigned Locations',
      deviceTypesScope: json['device_types_scope']?.toString() ?? 'All',
      timePolicy: json['time_policy']?.toString() ?? 'Allowed (24 x 7)',
      accessChannel: json['access_channel']?.toString() ?? 'Web & Mobile',
    );
  }
}

class EnterpriseUserAccessItem {
  final String id;
  final String userName;
  final String email;
  final String roleName;
  final String groupName;
  final String locationScope;
  final String status;
  final String lastLogin;

  EnterpriseUserAccessItem({
    required this.id,
    required this.userName,
    this.email = '',
    required this.roleName,
    this.groupName = 'General',
    this.locationScope = 'All Locations',
    this.status = 'Active',
    this.lastLogin = '10 Jan 2025, 02:18 PM',
  });

  EnterpriseUserAccessItem copyWith({
    String? roleName,
    String? groupName,
    String? locationScope,
    String? status,
  }) {
    return EnterpriseUserAccessItem(
      id: id,
      userName: userName,
      email: email,
      roleName: roleName ?? this.roleName,
      groupName: groupName ?? this.groupName,
      locationScope: locationScope ?? this.locationScope,
      status: status ?? this.status,
      lastLogin: lastLogin,
    );
  }

  factory EnterpriseUserAccessItem.fromJson(Map<String, dynamic> json) {
    return EnterpriseUserAccessItem(
      id: json['id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? 'General',
      locationScope: json['location_scope']?.toString() ?? 'All Locations',
      status: json['status']?.toString() ?? 'Active',
      lastLogin: json['last_login']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }
}

class EnterpriseUserGroupItem {
  final String id;
  final String groupName;
  final String groupCode;
  final String description;
  final int memberCount;
  final String status;

  EnterpriseUserGroupItem({
    required this.id,
    required this.groupName,
    required this.groupCode,
    this.description = '',
    this.memberCount = 0,
    this.status = 'Active',
  });

  factory EnterpriseUserGroupItem.fromJson(Map<String, dynamic> json) {
    return EnterpriseUserGroupItem(
      id: json['id']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      groupCode: json['group_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class PermissionMatrixRowItem {
  final String id;
  final String roleId;
  final String roleName;
  final String resource;
  bool canView;
  bool canCreate;
  bool canEdit;
  bool canDelete;
  bool canExecute;
  bool canControl;
  bool canApprove;
  bool canExport;

  PermissionMatrixRowItem({
    required this.id,
    required this.roleId,
    required this.roleName,
    required this.resource,
    this.canView = true,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canExecute = false,
    this.canControl = false,
    this.canApprove = false,
    this.canExport = false,
  });

  factory PermissionMatrixRowItem.fromJson(Map<String, dynamic> json) {
    return PermissionMatrixRowItem(
      id: json['id']?.toString() ?? '',
      roleId: json['role_id']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      resource: json['resource']?.toString() ?? '',
      canView: json['can_view'] == true,
      canCreate: json['can_create'] == true,
      canEdit: json['can_edit'] == true,
      canDelete: json['can_delete'] == true,
      canExecute: json['can_execute'] == true,
      canControl: json['can_control'] == true,
      canApprove: json['can_approve'] == true,
      canExport: json['can_export'] == true,
    );
  }
}

class AccessPolicyItem {
  final String id;
  final String policyName;
  final String policyCode;
  final String description;
  final String category;
  final String targetScope;
  final int priority;
  final bool isActive;
  final bool approvalRequired;

  AccessPolicyItem({
    required this.id,
    required this.policyName,
    required this.policyCode,
    this.description = '',
    required this.category,
    this.targetScope = 'All',
    this.priority = 10,
    this.isActive = true,
    this.approvalRequired = false,
  });

  factory AccessPolicyItem.fromJson(Map<String, dynamic> json) {
    return AccessPolicyItem(
      id: json['id']?.toString() ?? '',
      policyName: json['policy_name']?.toString() ?? '',
      policyCode: json['policy_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      targetScope: json['target_scope']?.toString() ?? 'All',
      priority: (json['priority'] as num?)?.toInt() ?? 10,
      isActive: json['is_active'] != false,
      approvalRequired: json['approval_required'] == true,
    );
  }
}

class AccessDelegationItem {
  final String id;
  final String delegateeName;
  final String delegateeEmail;
  final String delegatorName;
  final String assignedRole;
  final String locationScope;
  final String reason;
  final String startTime;
  final String endTime;
  final String status;

  AccessDelegationItem({
    required this.id,
    required this.delegateeName,
    this.delegateeEmail = '',
    required this.delegatorName,
    required this.assignedRole,
    required this.locationScope,
    required this.reason,
    required this.startTime,
    required this.endTime,
    this.status = 'Active',
  });

  factory AccessDelegationItem.fromJson(Map<String, dynamic> json) {
    return AccessDelegationItem(
      id: json['id']?.toString() ?? '',
      delegateeName: json['delegatee_name']?.toString() ?? '',
      delegateeEmail: json['delegatee_email']?.toString() ?? '',
      delegatorName: json['delegator_name']?.toString() ?? '',
      assignedRole: json['assigned_role']?.toString() ?? '',
      locationScope: json['location_scope']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
    );
  }
}

class AccessRequestItem {
  final String id;
  final String requestCode;
  final String requesterName;
  final String requesterEmail;
  final String requestedRole;
  final String requestedScope;
  final String duration;
  final String justification;
  final String priority;
  final String status;
  final String approverName;
  final String createdAt;

  AccessRequestItem({
    required this.id,
    required this.requestCode,
    required this.requesterName,
    this.requesterEmail = '',
    required this.requestedRole,
    required this.requestedScope,
    required this.duration,
    required this.justification,
    this.priority = 'Medium',
    this.status = 'Pending',
    this.approverName = '',
    this.createdAt = '10 Jan 2025, 02:18 PM',
  });

  factory AccessRequestItem.fromJson(Map<String, dynamic> json) {
    return AccessRequestItem(
      id: json['id']?.toString() ?? '',
      requestCode: json['request_code']?.toString() ?? '',
      requesterName: json['requester_name']?.toString() ?? '',
      requesterEmail: json['requester_email']?.toString() ?? '',
      requestedRole: json['requested_role']?.toString() ?? '',
      requestedScope: json['requested_scope']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '3 Days',
      justification: json['justification']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'Medium',
      status: json['status']?.toString() ?? 'Pending',
      approverName: json['approver_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }
}

class SecurityAuditLogItem {
  final String id;
  final String actorName;
  final String roleName;
  final String action;
  final String resource;
  final String target;
  final String status;
  final String ipAddress;
  final String correlationId;
  final String timestamp;

  SecurityAuditLogItem({
    required this.id,
    required this.actorName,
    required this.roleName,
    required this.action,
    required this.resource,
    required this.target,
    this.status = 'Success',
    this.ipAddress = '192.168.1.100',
    this.correlationId = 'CORR-SEC-001',
    this.timestamp = '10 Jan 2025, 02:18 PM',
  });

  factory SecurityAuditLogItem.fromJson(Map<String, dynamic> json) {
    return SecurityAuditLogItem(
      id: json['id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      resource: json['resource']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Success',
      ipAddress: json['ip_address']?.toString() ?? '192.168.1.100',
      correlationId: json['correlation_id']?.toString() ?? 'CORR-SEC-001',
      timestamp: json['timestamp']?.toString() ?? '10 Jan 2025, 02:18 PM',
    );
  }
}
