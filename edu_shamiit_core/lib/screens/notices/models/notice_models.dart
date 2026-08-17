import 'package:flutter/material.dart';

// ============================================================================
// Notice Model
// ============================================================================

class NoticeModel {
  final String id;
  final String? schoolId;
  final String title;
  final String content;
  final String category;
  final String priority; // 'low', 'normal', 'high', 'urgent'
  final String status; // 'draft', 'pending_approval', 'scheduled', 'published', 'expired', 'archived', 'rejected'
  final String? authorId;
  final String? authorName;
  final String? authorRole;
  final String targetScope; // 'entire_institute', 'roles', 'classes', 'departments', 'custom'
  final List<String> targetRoles;
  final List<String> targetClasses;
  final List<String> targetDepartments;
  final List<String> targetUserIds;
  final String timezone;
  final DateTime? publishedAt;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final bool requiresAcknowledgement;
  final DateTime? acknowledgementDeadline;
  final List<String> notificationChannels;
  final List<NoticeAttachmentModel> attachments;
  final List<NoticeLinkModel> links;
  final String approvalStatus; // 'approved', 'pending', 'rejected', 'changes_requested'
  final String? rejectionReason;
  final bool isPinned;
  final bool isUrgent;
  final int viewCount;
  final int ackCount;
  final int recipientCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Personalized recipient state
  final bool userIsRead;
  final DateTime? userReadAt;
  final bool userIsAcknowledged;
  final DateTime? userAcknowledgedAt;
  final String userAckStatus; // 'pending', 'acknowledged', 'declined'

  NoticeModel({
    required this.id,
    this.schoolId,
    required this.title,
    required this.content,
    this.category = 'General',
    this.priority = 'normal',
    this.status = 'published',
    this.authorId,
    this.authorName,
    this.authorRole,
    this.targetScope = 'entire_institute',
    this.targetRoles = const [],
    this.targetClasses = const [],
    this.targetDepartments = const [],
    this.targetUserIds = const [],
    this.timezone = 'Asia/Kolkata',
    this.publishedAt,
    this.scheduledAt,
    this.expiresAt,
    this.requiresAcknowledgement = false,
    this.acknowledgementDeadline,
    this.notificationChannels = const ['in_app'],
    this.attachments = const [],
    this.links = const [],
    this.approvalStatus = 'approved',
    this.rejectionReason,
    this.isPinned = false,
    this.isUrgent = false,
    this.viewCount = 0,
    this.ackCount = 0,
    this.recipientCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.userIsRead = false,
    this.userReadAt,
    this.userIsAcknowledged = false,
    this.userAcknowledgedAt,
    this.userAckStatus = 'pending',
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    List<NoticeAttachmentModel> parseAttachments(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => NoticeAttachmentModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    }

    List<NoticeLinkModel> parseLinks(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => NoticeLinkModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
      return [];
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return NoticeModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Notice',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      priority: (json['priority'] ?? 'normal').toString().toLowerCase(),
      status: (json['status'] ?? 'published').toString().toLowerCase(),
      authorId: json['author_id']?.toString(),
      authorName: json['author_name']?.toString(),
      authorRole: json['author_role']?.toString(),
      targetScope: json['target_scope']?.toString() ?? 'entire_institute',
      targetRoles: parseStringList(json['target_roles']),
      targetClasses: parseStringList(json['target_classes']),
      targetDepartments: parseStringList(json['target_departments']),
      targetUserIds: parseStringList(json['target_user_ids']),
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
      publishedAt: parseDate(json['published_at']),
      scheduledAt: parseDate(json['scheduled_at']),
      expiresAt: parseDate(json['expires_at']),
      requiresAcknowledgement: json['requires_acknowledgement'] == true,
      acknowledgementDeadline: parseDate(json['acknowledgement_deadline']),
      notificationChannels: parseStringList(json['notification_channels']),
      attachments: parseAttachments(json['attachments']),
      links: parseLinks(json['links']),
      approvalStatus: (json['approval_status'] ?? 'approved').toString().toLowerCase(),
      rejectionReason: json['rejection_reason']?.toString(),
      isPinned: json['is_pinned'] == true,
      isUrgent: json['is_urgent'] == true,
      viewCount: int.tryParse(json['view_count']?.toString() ?? '0') ?? 0,
      ackCount: int.tryParse(json['ack_count']?.toString() ?? '0') ?? 0,
      recipientCount: int.tryParse(json['recipient_count']?.toString() ?? '0') ?? 0,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
      userIsRead: json['user_is_read'] == true,
      userReadAt: parseDate(json['user_read_at']),
      userIsAcknowledged: json['user_is_acknowledged'] == true,
      userAcknowledgedAt: parseDate(json['user_acknowledged_at']),
      userAckStatus: json['user_ack_status']?.toString() ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'content': content,
      'category': category,
      'priority': priority,
      'status': status,
      'author_id': authorId,
      'author_name': authorName,
      'author_role': authorRole,
      'target_scope': targetScope,
      'target_roles': targetRoles,
      'target_classes': targetClasses,
      'target_departments': targetDepartments,
      'target_user_ids': targetUserIds,
      'timezone': timezone,
      'published_at': publishedAt?.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'requires_acknowledgement': requiresAcknowledgement,
      'acknowledgement_deadline': acknowledgementDeadline?.toIso8601String(),
      'notification_channels': notificationChannels,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'links': links.map((e) => e.toJson()).toList(),
      'approval_status': approvalStatus,
      'rejection_reason': rejectionReason,
      'is_pinned': isPinned,
      'is_urgent': isUrgent,
    };
  }

  double get ackPercentage {
    if (recipientCount <= 0) return 0.0;
    return (ackCount / recipientCount * 100).clamp(0.0, 100.0);
  }

  bool get isNewlyPublished {
    if (publishedAt == null) return false;
    return DateTime.now().difference(publishedAt!).inHours < 48;
  }
}

// ============================================================================
// Notice Attachment Model
// ============================================================================

class NoticeAttachmentModel {
  final String? id;
  final String name;
  final String url;
  final int? size;
  final String? type;

  NoticeAttachmentModel({
    this.id,
    required this.name,
    required this.url,
    this.size,
    this.type,
  });

  factory NoticeAttachmentModel.fromJson(Map<String, dynamic> json) {
    return NoticeAttachmentModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'File',
      url: json['url']?.toString() ?? '',
      size: int.tryParse(json['size']?.toString() ?? ''),
      type: json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'size': size,
      'type': type,
    };
  }

  String get formattedSize {
    if (size == null || size! <= 0) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// Notice Link Model
// ============================================================================

class NoticeLinkModel {
  final String title;
  final String url;
  final String type;

  NoticeLinkModel({
    required this.title,
    required this.url,
    this.type = 'external',
  });

  factory NoticeLinkModel.fromJson(Map<String, dynamic> json) {
    return NoticeLinkModel(
      title: json['title']?.toString() ?? 'Link',
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'external',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'type': type,
    };
  }
}

// ============================================================================
// Notice Recipient Model
// ============================================================================

class NoticeRecipientModel {
  final String id;
  final String userId;
  final String fullName;
  final String role;
  final String? className;
  final String? department;
  final String? avatarUrl;
  final String? phone;
  final String deliveryStatus;
  final bool isRead;
  final DateTime? readAt;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final String acknowledgementStatus;
  final String? declineReason;

  NoticeRecipientModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.role,
    this.className,
    this.department,
    this.avatarUrl,
    this.phone,
    this.deliveryStatus = 'sent',
    this.isRead = false,
    this.readAt,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.acknowledgementStatus = 'pending',
    this.declineReason,
  });

  factory NoticeRecipientModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString())?.toLocal();
    }

    return NoticeRecipientModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'User',
      role: json['role']?.toString() ?? 'student',
      className: json['class']?.toString(),
      department: json['department']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      phone: json['phone']?.toString(),
      deliveryStatus: json['delivery_status']?.toString() ?? 'sent',
      isRead: json['is_read'] == true,
      readAt: parseDate(json['read_at']),
      isAcknowledged: json['is_acknowledged'] == true,
      acknowledgedAt: parseDate(json['acknowledged_at']),
      acknowledgementStatus: json['acknowledgement_status']?.toString() ?? 'pending',
      declineReason: json['decline_reason']?.toString(),
    );
  }
}

// ============================================================================
// Notice Summary / Analytics Model
// ============================================================================

class NoticeSummaryModel {
  final int totalNotices;
  final int published;
  final int scheduled;
  final int drafts;
  final int expired;
  final int archived;
  final int pendingApproval;

  final int totalViews;
  final int viewed;
  final int notViewed;
  final int partiallyViewed;
  final double viewRatePct;

  final List<NoticeCategoryStatModel> categoryDistribution;

  const NoticeSummaryModel({
    this.totalNotices = 0,
    this.published = 0,
    this.scheduled = 0,
    this.drafts = 0,
    this.expired = 0,
    this.archived = 0,
    this.pendingApproval = 0,
    this.totalViews = 0,
    this.viewed = 0,
    this.notViewed = 0,
    this.partiallyViewed = 0,
    this.viewRatePct = 0.0,
    this.categoryDistribution = const [],
  });

  factory NoticeSummaryModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map ? json['stats'] : {};
    final eng = json['engagement'] is Map ? json['engagement'] : {};
    final catList = json['category_distribution'] is List ? json['category_distribution'] as List : [];

    return NoticeSummaryModel(
      totalNotices: int.tryParse(stats['total_notices']?.toString() ?? '0') ?? 0,
      published: int.tryParse(stats['published']?.toString() ?? '0') ?? 0,
      scheduled: int.tryParse(stats['scheduled']?.toString() ?? '0') ?? 0,
      drafts: int.tryParse(stats['drafts']?.toString() ?? '0') ?? 0,
      expired: int.tryParse(stats['expired']?.toString() ?? '0') ?? 0,
      archived: int.tryParse(stats['archived']?.toString() ?? '0') ?? 0,
      pendingApproval: int.tryParse(stats['pending_approval']?.toString() ?? '0') ?? 0,
      totalViews: int.tryParse(eng['total_views']?.toString() ?? '0') ?? 0,
      viewed: int.tryParse(eng['viewed']?.toString() ?? '0') ?? 0,
      notViewed: int.tryParse(eng['not_viewed']?.toString() ?? '0') ?? 0,
      partiallyViewed: int.tryParse(eng['partially_viewed']?.toString() ?? '0') ?? 0,
      viewRatePct: double.tryParse(eng['view_rate_pct']?.toString() ?? '0.0') ?? 0.0,
      categoryDistribution: catList.map((e) => NoticeCategoryStatModel.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class NoticeCategoryStatModel {
  final String category;
  final int count;
  final double percentage;

  NoticeCategoryStatModel({
    required this.category,
    required this.count,
    required this.percentage,
  });

  factory NoticeCategoryStatModel.fromJson(Map<String, dynamic> json) {
    return NoticeCategoryStatModel(
      category: json['category']?.toString() ?? 'General',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

// ============================================================================
// Notice Category Configuration Model
// ============================================================================

class NoticeCategoryModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String icon;
  final String color;
  final bool isActive;
  final int sortOrder;

  NoticeCategoryModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.icon = 'notifications',
    this.color = '#3B82F6',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory NoticeCategoryModel.fromJson(Map<String, dynamic> json) {
    return NoticeCategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString() ?? 'notifications',
      color: json['color']?.toString() ?? '#3B82F6',
      isActive: json['is_active'] != false,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
    );
  }

  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }
}

// ============================================================================
// Notice Audit Log Model
// ============================================================================

class NoticeAuditLogModel {
  final String id;
  final String? userName;
  final String? userRole;
  final String action;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  NoticeAuditLogModel({
    required this.id,
    this.userName,
    this.userRole,
    required this.action,
    this.details = const {},
    required this.createdAt,
  });

  factory NoticeAuditLogModel.fromJson(Map<String, dynamic> json) {
    return NoticeAuditLogModel(
      id: json['id']?.toString() ?? '',
      userName: json['user_name']?.toString(),
      userRole: json['user_role']?.toString(),
      action: json['action']?.toString() ?? '',
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}
