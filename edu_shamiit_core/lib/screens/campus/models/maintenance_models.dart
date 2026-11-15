import 'package:flutter/material.dart';

class MaintenanceKpis {
  final int totalRequests;
  final double totalChangePct;
  final int resolved;
  final double resolvedPct;
  final int inProgress;
  final double inProgressPct;
  final int overdue;
  final double overduePct;
  final int scheduled;
  final double avgResolutionDays;
  final double resolutionChangePct;
  final int myRequests;
  final int assignedToMe;
  final int highPriority;
  final int preventiveCount;
  final int plansCount;

  const MaintenanceKpis({
    this.totalRequests = 312,
    this.totalChangePct = 14.0,
    this.resolved = 254,
    this.resolvedPct = 81.4,
    this.inProgress = 34,
    this.inProgressPct = 10.9,
    this.overdue = 12,
    this.overduePct = 3.8,
    this.scheduled = 28,
    this.avgResolutionDays = 1.8,
    this.resolutionChangePct = -22.0,
    this.myRequests = 18,
    this.assignedToMe = 7,
    this.highPriority = 24,
    this.preventiveCount = 14,
    this.plansCount = 8,
  });

  factory MaintenanceKpis.fromJson(Map<String, dynamic> json) {
    return MaintenanceKpis(
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 312,
      totalChangePct: (json['total_change_pct'] as num?)?.toDouble() ?? 14.0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 254,
      resolvedPct: (json['resolved_pct'] as num?)?.toDouble() ?? 81.4,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 34,
      inProgressPct: (json['in_progress_pct'] as num?)?.toDouble() ?? 10.9,
      overdue: (json['overdue'] as num?)?.toInt() ?? 12,
      overduePct: (json['overdue_pct'] as num?)?.toDouble() ?? 3.8,
      scheduled: (json['scheduled'] as num?)?.toInt() ?? 28,
      avgResolutionDays: (json['avg_resolution_days'] as num?)?.toDouble() ?? 1.8,
      resolutionChangePct: (json['resolution_change_pct'] as num?)?.toDouble() ?? -22.0,
      myRequests: (json['my_requests'] as num?)?.toInt() ?? 18,
      assignedToMe: (json['assigned_to_me'] as num?)?.toInt() ?? 7,
      highPriority: (json['high_priority'] as num?)?.toInt() ?? 24,
      preventiveCount: (json['preventive_count'] as num?)?.toInt() ?? 14,
      plansCount: (json['plans_count'] as num?)?.toInt() ?? 8,
    );
  }
}

class MaintenanceRequestItem {
  final String id;
  final String requestCode;
  final String title;
  final String description;
  final String requestType;
  final String priority;
  final String status;
  final String locationDisplay;
  final String? specificLocation;
  final String? buildingId;
  final String? roomId;
  final String? equipmentId;
  final String reportedByName;
  final String reportedByRole;
  final DateTime reportedAt;
  final DateTime? preferredDate;
  final String? preferredTime;
  final DateTime? dueDate;
  final bool isOverdue;
  final String? assignedToName;
  final String? assignedToUserId;
  final String? assignedVendorName;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final double estimatedCost;
  final double actualCost;
  final bool isPreventive;
  final List<dynamic> attachments;

  const MaintenanceRequestItem({
    required this.id,
    required this.requestCode,
    required this.title,
    this.description = '',
    required this.requestType,
    required this.priority,
    required this.status,
    required this.locationDisplay,
    this.specificLocation,
    this.buildingId,
    this.roomId,
    this.equipmentId,
    required this.reportedByName,
    this.reportedByRole = 'Student',
    required this.reportedAt,
    this.preferredDate,
    this.preferredTime,
    this.dueDate,
    this.isOverdue = false,
    this.assignedToName,
    this.assignedToUserId,
    this.assignedVendorName,
    this.scheduledAt,
    this.startedAt,
    this.resolvedAt,
    this.resolutionNotes,
    this.estimatedCost = 0.0,
    this.actualCost = 0.0,
    this.isPreventive = false,
    this.attachments = const [],
  });

  factory MaintenanceRequestItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceRequestItem(
      id: json['id']?.toString() ?? '',
      requestCode: json['request_code'] ?? 'MT-0000',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      requestType: json['request_type'] ?? 'HVAC',
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Pending',
      locationDisplay: json['location_display'] ?? '',
      specificLocation: json['specific_location'],
      buildingId: json['building_id']?.toString(),
      roomId: json['room_id']?.toString(),
      equipmentId: json['equipment_id']?.toString(),
      reportedByName: json['reported_by_name'] ?? 'Admin',
      reportedByRole: json['reported_by_role'] ?? 'Student',
      reportedAt: DateTime.tryParse(json['reported_at']?.toString() ?? '') ?? DateTime.now(),
      preferredDate: json['preferred_date'] != null ? DateTime.tryParse(json['preferred_date'].toString()) : null,
      preferredTime: json['preferred_time'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      isOverdue: json['is_overdue'] == true,
      assignedToName: json['assigned_to_name'],
      assignedToUserId: json['assigned_to_user_id']?.toString(),
      assignedVendorName: json['assigned_vendor_name'],
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'].toString()) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      resolutionNotes: json['resolution_notes'],
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? 0.0,
      isPreventive: json['is_preventive'] == true,
      attachments: json['attachments'] is List ? json['attachments'] : const [],
    );
  }
}

class MaintenanceListResponse {
  final int totalCount;
  final List<MaintenanceRequestItem> records;
  final int page;
  final int pageSize;
  final int totalPages;

  const MaintenanceListResponse({
    this.totalCount = 0,
    this.records = const [],
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
  });

  factory MaintenanceListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['records'] as List? ?? [];
    return MaintenanceListResponse(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      records: rawList.map((x) => MaintenanceRequestItem.fromJson(x as Map<String, dynamic>)).toList(),
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 10,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

class MaintenanceTrendsItem {
  final String month;
  final int requests;
  final int resolved;

  const MaintenanceTrendsItem({
    required this.month,
    required this.requests,
    required this.resolved,
  });

  factory MaintenanceTrendsItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceTrendsItem(
      month: json['month'] ?? '',
      requests: (json['requests'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
    );
  }
}

class MaintenanceCategoryShare {
  final String type;
  final int count;
  final double pct;
  final Color color;

  const MaintenanceCategoryShare({
    required this.type,
    required this.count,
    required this.pct,
    required this.color,
  });

  factory MaintenanceCategoryShare.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF0284C7);
    final hex = json['color']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length == 7) {
      final intVal = int.tryParse('FF${hex.substring(1)}', radix: 16);
      if (intVal != null) parsedColor = Color(intVal);
    }
    return MaintenanceCategoryShare(
      type: json['type'] ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      pct: (json['pct'] as num?)?.toDouble() ?? 0.0,
      color: parsedColor,
    );
  }
}

class MaintenanceSlaStats {
  final double resolutionWithinSlaPct;
  final double avgResolutionDays;
  final double overdueRatePct;
  final double firstResponseHours;

  const MaintenanceSlaStats({
    this.resolutionWithinSlaPct = 81.4,
    this.avgResolutionDays = 1.8,
    this.overdueRatePct = 3.8,
    this.firstResponseHours = 4.2,
  });

  factory MaintenanceSlaStats.fromJson(Map<String, dynamic> json) {
    return MaintenanceSlaStats(
      resolutionWithinSlaPct: (json['resolution_within_sla_pct'] as num?)?.toDouble() ?? 81.4,
      avgResolutionDays: (json['avg_resolution_days'] as num?)?.toDouble() ?? 1.8,
      overdueRatePct: (json['overdue_rate_pct'] as num?)?.toDouble() ?? 3.8,
      firstResponseHours: (json['first_response_hours'] as num?)?.toDouble() ?? 4.2,
    );
  }
}

class MaintenanceAnalyticsData {
  final List<MaintenanceTrendsItem> trends;
  final List<MaintenanceCategoryShare> categories;
  final MaintenanceSlaStats sla;
  final int totalRequests;

  const MaintenanceAnalyticsData({
    this.trends = const [],
    this.categories = const [],
    this.sla = const MaintenanceSlaStats(),
    this.totalRequests = 312,
  });

  factory MaintenanceAnalyticsData.fromJson(Map<String, dynamic> json) {
    final rawTrends = json['trends'] as List? ?? [];
    final rawCategories = json['categories'] as List? ?? [];
    return MaintenanceAnalyticsData(
      trends: rawTrends.map((x) => MaintenanceTrendsItem.fromJson(x as Map<String, dynamic>)).toList(),
      categories: rawCategories.map((x) => MaintenanceCategoryShare.fromJson(x as Map<String, dynamic>)).toList(),
      sla: json['sla'] != null ? MaintenanceSlaStats.fromJson(json['sla'] as Map<String, dynamic>) : const MaintenanceSlaStats(),
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 312,
    );
  }
}

class MaintenancePlanItem {
  final String id;
  final String planCode;
  final String title;
  final String category;
  final String frequency;
  final String assignedTeam;
  final String? assignedTechnicianName;
  final double estimatedDurationHours;
  final double estimatedCost;
  final bool isActive;
  final DateTime nextDueDate;

  const MaintenancePlanItem({
    required this.id,
    required this.planCode,
    required this.title,
    required this.category,
    required this.frequency,
    this.assignedTeam = 'Maintenance Team',
    this.assignedTechnicianName,
    this.estimatedDurationHours = 2.0,
    this.estimatedCost = 0.0,
    this.isActive = true,
    required this.nextDueDate,
  });

  factory MaintenancePlanItem.fromJson(Map<String, dynamic> json) {
    return MaintenancePlanItem(
      id: json['id']?.toString() ?? '',
      planCode: json['plan_code'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? 'HVAC',
      frequency: json['frequency'] ?? 'Monthly',
      assignedTeam: json['assigned_team'] ?? 'Maintenance Team',
      assignedTechnicianName: json['assigned_technician_name'],
      estimatedDurationHours: (json['estimated_duration_hours'] as num?)?.toDouble() ?? 2.0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] != false,
      nextDueDate: DateTime.tryParse(json['next_due_date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class MaintenanceVendorItem {
  final String id;
  final String vendorName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String serviceCategory;
  final String contractType;
  final double slaResponseHours;
  final double slaResolutionHours;
  final bool isActive;

  const MaintenanceVendorItem({
    required this.id,
    required this.vendorName,
    this.contactPerson,
    this.phone,
    this.email,
    required this.serviceCategory,
    this.contractType = 'AMC',
    this.slaResponseHours = 4.0,
    this.slaResolutionHours = 24.0,
    this.isActive = true,
  });

  factory MaintenanceVendorItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceVendorItem(
      id: json['id']?.toString() ?? '',
      vendorName: json['vendor_name'] ?? '',
      contactPerson: json['contact_person'],
      phone: json['phone'],
      email: json['email'],
      serviceCategory: json['service_category'] ?? 'General',
      contractType: json['contract_type'] ?? 'AMC',
      slaResponseHours: (json['sla_response_hours'] as num?)?.toDouble() ?? 4.0,
      slaResolutionHours: (json['sla_resolution_hours'] as num?)?.toDouble() ?? 24.0,
      isActive: json['is_active'] != false,
    );
  }
}
