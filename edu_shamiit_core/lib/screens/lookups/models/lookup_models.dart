// ============================================================================
// Lookup Models for EduSHAMIIT ERP
// ============================================================================

class LookupUsageModel {
  final int totalRecords;
  final int modulesCount;
  final String modulesSummary;
  final List<Map<String, dynamic>> breakdown;

  const LookupUsageModel({
    this.totalRecords = 0,
    this.modulesCount = 0,
    this.modulesSummary = '0 Modules',
    this.breakdown = const [],
  });

  factory LookupUsageModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LookupUsageModel();
    return LookupUsageModel(
      totalRecords: json['total_records'] is int ? json['total_records'] : int.tryParse('${json['total_records']}') ?? 0,
      modulesCount: json['modules_count'] is int ? json['modules_count'] : int.tryParse('${json['modules_count']}') ?? 0,
      modulesSummary: json['modules_summary']?.toString() ?? '0 Modules',
      breakdown: (json['breakdown'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
    );
  }
}

class LookupStatsModel {
  final int totalValues;
  final int activeValues;
  final int inactiveValues;
  final String usedInModule;
  final int modulesCount;
  final int totalRecords;
  final String keyType;

  const LookupStatsModel({
    this.totalValues = 0,
    this.activeValues = 0,
    this.inactiveValues = 0,
    this.usedInModule = '0 Modules',
    this.modulesCount = 0,
    this.totalRecords = 0,
    this.keyType = 'CUSTOM',
  });

  factory LookupStatsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LookupStatsModel();
    return LookupStatsModel(
      totalValues: json['total_values'] is int ? json['total_values'] : int.tryParse('${json['total_values']}') ?? 0,
      activeValues: json['active_values'] is int ? json['active_values'] : int.tryParse('${json['active_values']}') ?? 0,
      inactiveValues: json['inactive_values'] is int ? json['inactive_values'] : int.tryParse('${json['inactive_values']}') ?? 0,
      usedInModule: json['used_in_module']?.toString() ?? '0 Modules',
      modulesCount: json['modules_count'] is int ? json['modules_count'] : int.tryParse('${json['modules_count']}') ?? 0,
      totalRecords: json['total_records'] is int ? json['total_records'] : int.tryParse('${json['total_records']}') ?? 0,
      keyType: json['key_type']?.toString() ?? 'CUSTOM',
    );
  }
}

class LookupKeyModel {
  final String id;
  final String schoolId;
  final String keyName;
  final String keyCode;
  final String description;
  final String keyType; // 'SYSTEM', 'CUSTOM'
  final String icon;
  final String status; // 'ACTIVE', 'INACTIVE'
  final int version;
  final String createdBy;
  final String creatorName;
  final bool isOwner;
  final int totalValuesCount;
  final int activeValuesCount;
  final int inactiveValuesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final LookupUsageModel usage;

  const LookupKeyModel({
    required this.id,
    required this.schoolId,
    required this.keyName,
    required this.keyCode,
    this.description = '',
    this.keyType = 'CUSTOM',
    this.icon = 'folder_outlined',
    this.status = 'ACTIVE',
    this.version = 1,
    this.createdBy = '',
    this.creatorName = 'System',
    this.isOwner = false,
    this.totalValuesCount = 0,
    this.activeValuesCount = 0,
    this.inactiveValuesCount = 0,
    this.createdAt,
    this.updatedAt,
    this.usage = const LookupUsageModel(),
  });

  bool get isSystem => keyType.toUpperCase() == 'SYSTEM';
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory LookupKeyModel.fromJson(Map<String, dynamic> json) {
    return LookupKeyModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      keyName: json['key_name']?.toString() ?? '',
      keyCode: json['key_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      keyType: json['key_type']?.toString() ?? 'CUSTOM',
      icon: json['icon']?.toString() ?? 'folder_outlined',
      status: json['status']?.toString() ?? 'ACTIVE',
      version: json['version'] is int ? json['version'] : int.tryParse('${json['version']}') ?? 1,
      createdBy: json['created_by']?.toString() ?? '',
      creatorName: json['creator_name']?.toString() ?? 'System',
      isOwner: json['is_owner'] == true,
      totalValuesCount: json['total_values_count'] is int ? json['total_values_count'] : int.tryParse('${json['total_values_count']}') ?? 0,
      activeValuesCount: json['active_values_count'] is int ? json['active_values_count'] : int.tryParse('${json['active_values_count']}') ?? 0,
      inactiveValuesCount: json['inactive_values_count'] is int ? json['inactive_values_count'] : int.tryParse('${json['inactive_values_count']}') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      usage: LookupUsageModel.fromJson(json['usage'] as Map<String, dynamic>?),
    );
  }
}

class LookupValueModel {
  final String id;
  final String lookupKeyId;
  final String valueName;
  final String valueCode;
  final String description;
  final String status; // 'ACTIVE', 'INACTIVE'
  final int sortOrder;
  final String createdBy;
  final String creatorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final LookupUsageModel usage;

  const LookupValueModel({
    required this.id,
    required this.lookupKeyId,
    required this.valueName,
    required this.valueCode,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
    this.createdBy = '',
    this.creatorName = 'System',
    this.createdAt,
    this.updatedAt,
    this.usage = const LookupUsageModel(),
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory LookupValueModel.fromJson(Map<String, dynamic> json) {
    return LookupValueModel(
      id: json['id']?.toString() ?? '',
      lookupKeyId: json['lookup_key_id']?.toString() ?? '',
      valueName: json['value_name']?.toString() ?? '',
      valueCode: json['value_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: json['sort_order'] is int ? json['sort_order'] : int.tryParse('${json['sort_order']}') ?? 0,
      createdBy: json['created_by']?.toString() ?? '',
      creatorName: json['creator_name']?.toString() ?? 'System',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      usage: LookupUsageModel.fromJson(json['usage'] as Map<String, dynamic>?),
    );
  }
}

class LookupAuditModel {
  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String userId;
  final String userName;
  final Map<String, dynamic> details;
  final Map<String, dynamic>? beforeState;
  final Map<String, dynamic>? afterState;
  final DateTime? createdAt;

  const LookupAuditModel({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.userName,
    this.details = const {},
    this.beforeState,
    this.afterState,
    this.createdAt,
  });

  factory LookupAuditModel.fromJson(Map<String, dynamic> json) {
    return LookupAuditModel(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'System User',
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {},
      beforeState: json['before_state'] is Map ? Map<String, dynamic>.from(json['before_state']) : null,
      afterState: json['after_state'] is Map ? Map<String, dynamic>.from(json['after_state']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
