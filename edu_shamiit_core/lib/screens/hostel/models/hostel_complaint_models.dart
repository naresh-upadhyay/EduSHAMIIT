import 'package:intl/intl.dart';

/// Top 6 KPI summary metrics for Hostel Complaints tab matching screenshot
class ComplaintKpiData {
  final int totalComplaints;
  final String totalTrend;
  final String totalSubtitle;
  final int resolved;
  final String resolutionRate;
  final int pending;
  final String pendingPercentage;
  final int overdue;
  final String overduePercentage;
  final int highPriority;
  final String highPrioritySubtitle;
  final int maintenanceRelated;
  final String maintenancePercentage;
  final double avgResolutionHours;

  const ComplaintKpiData({
    this.totalComplaints = 36,
    this.totalTrend = '↑ 12%',
    this.totalSubtitle = 'This Month',
    this.resolved = 24,
    this.resolutionRate = '67% resolution rate',
    this.pending = 8,
    this.pendingPercentage = '22% of total',
    this.overdue = 4,
    this.overduePercentage = '11% of total',
    this.highPriority = 6,
    this.highPrioritySubtitle = 'Requires urgent attention',
    this.maintenanceRelated = 14,
    this.maintenancePercentage = '39% of total',
    this.avgResolutionHours = 18.5,
  });

  factory ComplaintKpiData.fromJson(Map<String, dynamic> json) {
    final total = (json['total_complaints'] as num?)?.toInt() ?? 0;
    final res = (json['resolved'] as num?)?.toInt() ?? 0;
    final pend = (json['pending'] as num?)?.toInt() ?? 0;
    final over = (json['overdue'] as num?)?.toInt() ?? 0;
    final high = (json['high_priority'] as num?)?.toInt() ?? 0;
    final maint = (json['maintenance_related'] as num?)?.toInt() ?? 0;
    final resRate = total > 0 ? '${((res / total) * 100).toStringAsFixed(0)}% resolution rate' : '0% resolution rate';
    final pendPct = total > 0 ? '${((pend / total) * 100).toStringAsFixed(0)}% of total' : '0% of total';
    final overPct = total > 0 ? '${((over / total) * 100).toStringAsFixed(0)}% of total' : '0% of total';
    final maintPct = total > 0 ? '${((maint / total) * 100).toStringAsFixed(0)}% of total' : '0% of total';

    return ComplaintKpiData(
      totalComplaints: total,
      totalTrend: json['total_trend'] as String? ?? '0%',
      totalSubtitle: json['total_subtitle'] as String? ?? 'This Month',
      resolved: res,
      resolutionRate: json['resolution_rate'] as String? ?? resRate,
      pending: pend,
      pendingPercentage: json['pending_percentage'] as String? ?? pendPct,
      overdue: over,
      overduePercentage: json['overdue_percentage'] as String? ?? overPct,
      highPriority: high,
      highPrioritySubtitle: json['high_priority_subtitle'] as String? ?? (high > 0 ? 'Requires urgent attention' : 'No urgent issues'),
      maintenanceRelated: maint,
      maintenancePercentage: json['maintenance_percentage'] as String? ?? maintPct,
      avgResolutionHours: (json['avg_resolution_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Represents a single Complaint item in the enterprise data table
class HostelComplaintItem {
  final String id;
  final String complaintNumber;
  final int displayIndex;
  final String title;
  final String description;
  final String category;
  final String? subcategory;
  final String priority; // LOW, MEDIUM, HIGH, URGENT, CRITICAL
  final String status; // NEW, ACTIVE, IN_PROGRESS, ON_HOLD, RESOLVED, COMPLETED, REJECTED, CANCELED
  final String? reportedByUserId;
  final String reportedByName;
  final String? reportedByClass;
  final String? reportedByRole;
  final String? reportedByPhone;
  final String? reportedByEmail;
  final String? reportedByAvatar;
  final String? hostelId;
  final String hostelName;
  final String? buildingName;
  final String? floorName;
  final String? roomId;
  final String? roomNumber;
  final String? bedCode;
  final String? facilityType;
  final String? equipmentId;
  final String? equipmentName;
  final String? locationText;
  final String? primaryAssigneeUserId;
  final String? primaryAssigneeName;
  final String? primaryAssigneeRole;
  final String source;
  final DateTime? responseDueAt;
  final DateTime? resolutionDueAt;
  final DateTime? resolvedAt;
  final DateTime? completedAt;
  final String? resolutionSummary;
  final String? resolutionType;
  final String? rejectionReason;
  final String? cancellationReason;
  final String slaStatus;
  final String slaDisplay;
  final String? thumbnailUrl;
  final List<dynamic> attachments;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String raisedOnFormatted;

  const HostelComplaintItem({
    required this.id,
    required this.complaintNumber,
    this.displayIndex = 1,
    required this.title,
    required this.description,
    required this.category,
    this.subcategory,
    this.priority = 'MEDIUM',
    this.status = 'NEW',
    this.reportedByUserId,
    required this.reportedByName,
    this.reportedByClass,
    this.reportedByRole,
    this.reportedByPhone,
    this.reportedByEmail,
    this.reportedByAvatar,
    this.hostelId,
    required this.hostelName,
    this.buildingName,
    this.floorName,
    this.roomId,
    this.roomNumber,
    this.bedCode,
    this.facilityType,
    this.equipmentId,
    this.equipmentName,
    this.locationText,
    this.primaryAssigneeUserId,
    this.primaryAssigneeName,
    this.primaryAssigneeRole,
    this.source = 'STUDENT_PORTAL',
    this.responseDueAt,
    this.resolutionDueAt,
    this.resolvedAt,
    this.completedAt,
    this.resolutionSummary,
    this.resolutionType,
    this.rejectionReason,
    this.cancellationReason,
    this.slaStatus = 'ON_TRACK',
    this.slaDisplay = 'On Track',
    this.thumbnailUrl,
    this.attachments = const [],
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    required this.raisedOnFormatted,
  });

  factory HostelComplaintItem.fromJson(Map<String, dynamic> json, {int index = 1}) {
    DateTime created = DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    DateTime updated = DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? created;
    DateTime? resDue = json['resolution_due_at'] != null ? DateTime.tryParse(json['resolution_due_at'].toString()) : null;
    DateTime? respDue = json['response_due_at'] != null ? DateTime.tryParse(json['response_due_at'].toString()) : null;
    DateTime? resolved = json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null;
    DateTime? completed = json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null;

    String raisedOn = DateFormat('dd MMM yyyy\nhh:mm a').format(created);

    return HostelComplaintItem(
      id: json['id']?.toString() ?? '',
      complaintNumber: json['complaint_number']?.toString() ?? 'HC-2024-001',
      displayIndex: index,
      title: json['title']?.toString() ?? 'Hostel Grievance',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      subcategory: json['subcategory']?.toString(),
      priority: (json['priority']?.toString() ?? 'MEDIUM').toUpperCase(),
      status: (json['status']?.toString() ?? 'NEW').toUpperCase(),
      reportedByUserId: json['reported_by_user_id']?.toString(),
      reportedByName: json['reported_by_name']?.toString() ?? 'Student',
      reportedByClass: json['reported_by_class']?.toString() ?? 'Class 10 A',
      reportedByRole: json['reported_by_role']?.toString() ?? 'Student',
      reportedByPhone: json['reported_by_phone']?.toString(),
      reportedByEmail: json['reported_by_email']?.toString(),
      reportedByAvatar: json['reported_by_avatar']?.toString(),
      hostelId: json['hostel_id']?.toString(),
      hostelName: json['hostel_name']?.toString() ?? 'Boys Hostel A',
      buildingName: json['building_name']?.toString(),
      floorName: json['floor_name']?.toString(),
      roomId: json['room_id']?.toString(),
      roomNumber: json['room_number']?.toString(),
      bedCode: json['bed_code']?.toString(),
      facilityType: json['facility_type']?.toString() ?? 'Room',
      equipmentId: json['equipment_id']?.toString(),
      equipmentName: json['equipment_name']?.toString(),
      locationText: json['location_text']?.toString(),
      primaryAssigneeUserId: json['primary_assignee_user_id']?.toString(),
      primaryAssigneeName: json['primary_assignee_name']?.toString(),
      primaryAssigneeRole: json['primary_assignee_role']?.toString() ?? 'Maintenance Staff',
      source: json['source']?.toString() ?? 'STUDENT_PORTAL',
      responseDueAt: respDue,
      resolutionDueAt: resDue,
      resolvedAt: resolved,
      completedAt: completed,
      resolutionSummary: json['resolution_summary']?.toString(),
      resolutionType: json['resolution_type']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      slaStatus: json['sla_status']?.toString() ?? 'ON_TRACK',
      slaDisplay: json['sla_display']?.toString() ?? 'On Track',
      thumbnailUrl: json['thumbnail_url']?.toString(),
      attachments: json['attachments'] is List ? (json['attachments'] as List) : const [],
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: created,
      updatedAt: updated,
      raisedOnFormatted: raisedOn,
    );
  }
}

/// 360-degree full detail of a complaint
class HostelComplaintDetail360 {
  final HostelComplaintItem complaint;
  final List<ComplaintCommentItem> comments;
  final List<ComplaintAssignmentItem> assignments;
  final List<ComplaintHistoryItem> history;
  final ComplaintFeedbackItem? feedback;
  final Map<String, dynamic>? relatedAsset;

  const HostelComplaintDetail360({
    required this.complaint,
    this.comments = const [],
    this.assignments = const [],
    this.history = const [],
    this.feedback,
    this.relatedAsset,
  });

  factory HostelComplaintDetail360.fromJson(Map<String, dynamic> json) {
    final complaintData = json['complaint'] is Map<String, dynamic>
        ? json['complaint'] as Map<String, dynamic>
        : json;
    
    final commentsList = (json['comments'] as List<dynamic>?)
            ?.map((e) => ComplaintCommentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final assignmentsList = (json['assignments'] as List<dynamic>?)
            ?.map((e) => ComplaintAssignmentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final historyList = (json['history'] as List<dynamic>?)
            ?.map((e) => ComplaintHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final feedbackData = json['feedback'] is Map<String, dynamic>
        ? ComplaintFeedbackItem.fromJson(json['feedback'] as Map<String, dynamic>)
        : null;

    final assetData = json['related_asset'] is Map<String, dynamic>
        ? json['related_asset'] as Map<String, dynamic>
        : null;

    return HostelComplaintDetail360(
      complaint: HostelComplaintItem.fromJson(complaintData),
      comments: commentsList,
      assignments: assignmentsList,
      history: historyList,
      feedback: feedbackData,
      relatedAsset: assetData,
    );
  }
}

/// A discussion update or internal staff note
class ComplaintCommentItem {
  final String id;
  final String? authorUserId;
  final String authorName;
  final String? authorRole;
  final String? authorAvatar;
  final String commentType; // 'PUBLIC_UPDATE' or 'INTERNAL_NOTE'
  final String message;
  final List<dynamic> attachments;
  final DateTime createdAt;
  final String timeFormatted;

  const ComplaintCommentItem({
    required this.id,
    this.authorUserId,
    required this.authorName,
    this.authorRole,
    this.authorAvatar,
    this.commentType = 'PUBLIC_UPDATE',
    required this.message,
    this.attachments = const [],
    required this.createdAt,
    required this.timeFormatted,
  });

  factory ComplaintCommentItem.fromJson(Map<String, dynamic> json) {
    DateTime dt = DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    return ComplaintCommentItem(
      id: json['id']?.toString() ?? '',
      authorUserId: json['author_user_id']?.toString(),
      authorName: json['author_name']?.toString() ?? 'Staff Member',
      authorRole: json['author_role']?.toString() ?? 'Staff',
      authorAvatar: json['author_avatar']?.toString(),
      commentType: json['comment_type']?.toString() ?? 'PUBLIC_UPDATE',
      message: json['message']?.toString() ?? '',
      attachments: json['attachments'] is List ? json['attachments'] as List : const [],
      createdAt: dt,
      timeFormatted: DateFormat('dd MMM yyyy, hh:mm a').format(dt),
    );
  }
}

/// An assignment history record
class ComplaintAssignmentItem {
  final String id;
  final String assignedUserId;
  final String assignedUserName;
  final String? assignedUserRole;
  final String assignmentType;
  final String? assignedByName;
  final DateTime assignedAt;
  final String? notes;
  final String status;

  const ComplaintAssignmentItem({
    required this.id,
    required this.assignedUserId,
    required this.assignedUserName,
    this.assignedUserRole,
    this.assignmentType = 'PRIMARY',
    this.assignedByName,
    required this.assignedAt,
    this.notes,
    this.status = 'ACTIVE',
  });

  factory ComplaintAssignmentItem.fromJson(Map<String, dynamic> json) {
    return ComplaintAssignmentItem(
      id: json['id']?.toString() ?? '',
      assignedUserId: json['assigned_user_id']?.toString() ?? '',
      assignedUserName: json['assigned_user_name']?.toString() ?? 'Staff',
      assignedUserRole: json['assigned_user_role']?.toString(),
      assignmentType: json['assignment_type']?.toString() ?? 'PRIMARY',
      assignedByName: json['assigned_by_name']?.toString(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

/// An immutable timeline audit event
class ComplaintHistoryItem {
  final String id;
  final String actorName;
  final String? actorRole;
  final String? fromStatus;
  final String? toStatus;
  final String eventTitle;
  final String? actionNote;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String timeFormatted;

  const ComplaintHistoryItem({
    required this.id,
    required this.actorName,
    this.actorRole,
    this.fromStatus,
    this.toStatus,
    required this.eventTitle,
    this.actionNote,
    this.metadata,
    required this.createdAt,
    required this.timeFormatted,
  });

  factory ComplaintHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime dt = DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    return ComplaintHistoryItem(
      id: json['id']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'System',
      actorRole: json['actor_role']?.toString(),
      fromStatus: json['from_status']?.toString(),
      toStatus: json['to_status']?.toString(),
      eventTitle: json['event_title']?.toString() ?? 'Status Updated',
      actionNote: json['action_note']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null,
      createdAt: dt,
      timeFormatted: DateFormat('dd MMM yyyy, hh:mm a').format(dt),
    );
  }
}

/// Resident feedback after resolution
class ComplaintFeedbackItem {
  final String? id;
  final String? submittedByName;
  final int rating;
  final double? explicitAverageRating;
  final int? resolutionQuality;
  final int? responseTimeRating;
  final int? staffBehaviorRating;
  final String? comment;
  final bool isSatisfied;
  final DateTime? createdAt;

  const ComplaintFeedbackItem({
    this.id,
    this.submittedByName,
    this.rating = 5,
    this.explicitAverageRating,
    this.resolutionQuality,
    this.responseTimeRating,
    this.staffBehaviorRating,
    this.comment,
    this.isSatisfied = true,
    this.createdAt,
  });

  double get averageRating {
    if (explicitAverageRating != null) return explicitAverageRating!;
    final aspects = [
      resolutionQuality,
      responseTimeRating,
      staffBehaviorRating,
    ].whereType<int>().toList();
    if (aspects.isNotEmpty) {
      final sum = aspects.fold<int>(0, (a, b) => a + b);
      return double.parse((sum / aspects.length).toStringAsFixed(1));
    }
    return rating.toDouble();
  }

  String get ratingLabel {
    final avg = averageRating;
    if (avg >= 4.5) return 'Excellent';
    if (avg >= 3.5) return 'Very Good';
    if (avg >= 2.5) return 'Good';
    if (avg >= 1.5) return 'Fair';
    return 'Poor';
  }

  factory ComplaintFeedbackItem.fromJson(Map<String, dynamic> json) {
    return ComplaintFeedbackItem(
      id: json['id']?.toString(),
      submittedByName: json['submitted_by_name']?.toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      explicitAverageRating: (json['average_rating'] as num?)?.toDouble(),
      resolutionQuality: (json['resolution_quality'] as num?)?.toInt(),
      responseTimeRating: (json['response_time_rating'] as num?)?.toInt(),
      staffBehaviorRating: (json['staff_behavior_rating'] as num?)?.toInt(),
      comment: json['comment']?.toString(),
      isSatisfied: json['is_satisfied'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

/// Server-side pagination metadata
class ComplaintPagination {
  final int totalRecords;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  const ComplaintPagination({
    this.totalRecords = 0,
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
    this.hasNext = false,
    this.hasPrev = false,
  });

  factory ComplaintPagination.fromJson(Map<String, dynamic> json) {
    return ComplaintPagination(
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 10,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }
}
