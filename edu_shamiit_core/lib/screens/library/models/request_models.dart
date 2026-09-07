import 'package:flutter/material.dart';

/// Individual Library Request Item for List and Table Views
class LibraryRequestItem {
  final String id;
  final String requestNumber;
  final String title;
  final String? author;
  final String? isbn;
  final String? publisher;
  final String? edition;
  final String language;
  final String requestType; // Book, E-Book, Digital Resource, etc.
  final String categoryCode;
  final String preferredFormat;
  final int quantity;
  final String priority; // Low, Medium, High, Urgent
  final String status; // NEW, ACTIVE, IN_PROGRESS, RESOLVED, COMPLETED, REJECTED, CANCELED
  final String availabilityStatus; // AVAILABLE, NOT_AVAILABLE, LICENSE_REQUIRED, etc.
  final String approvalStatus;
  
  // Requester details
  final String? requesterId;
  final String requesterName;
  final String requesterRole;
  final String requesterClass;
  final String? requesterAvatar;
  final String? memberCode;
  
  // Assigned staff
  final String? assignedToId;
  final String? assignedToName;
  final String? assignedToAvatar;
  
  // Dates
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? requiredBy;
  final DateTime? processedAt;
  
  // Reasons & details
  final String? reason;
  final String? description;
  final String? rejectionReason;
  final String? cancellationReason;
  final bool clarificationRequested;
  final String? clarificationMessage;
  final String? clarificationResponse;
  
  // Linked catalog book
  final String? bookId;
  final String? bookCoverUrl;
  final int? availableCopies;
  final int? totalCopies;
  final String? shelfLocation;
  final String? rackLocation;

  LibraryRequestItem({
    required this.id,
    required this.requestNumber,
    required this.title,
    this.author,
    this.isbn,
    this.publisher,
    this.edition,
    this.language = 'English',
    this.requestType = 'Book',
    this.categoryCode = 'BOOK',
    this.preferredFormat = 'Physical',
    this.quantity = 1,
    this.priority = 'Medium',
    this.status = 'NEW',
    this.availabilityStatus = 'AVAILABLE',
    this.approvalStatus = 'NOT_REQUIRED',
    this.requesterId,
    required this.requesterName,
    this.requesterRole = 'student',
    this.requesterClass = 'N/A',
    this.requesterAvatar,
    this.memberCode,
    this.assignedToId,
    this.assignedToName,
    this.assignedToAvatar,
    required this.createdAt,
    required this.updatedAt,
    this.requiredBy,
    this.processedAt,
    this.reason,
    this.description,
    this.rejectionReason,
    this.cancellationReason,
    this.clarificationRequested = false,
    this.clarificationMessage,
    this.clarificationResponse,
    this.bookId,
    this.bookCoverUrl,
    this.availableCopies,
    this.totalCopies,
    this.shelfLocation,
    this.rackLocation,
  });

  factory LibraryRequestItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    String reqNum = json['formatted_request_number']?.toString() ??
        json['request_number']?.toString() ??
        'REQ-${(json['id']?.toString() ?? '').substring(0, (json['id']?.toString().length ?? 0) >= 6 ? 6 : 0)}';

    return LibraryRequestItem(
      id: json['id']?.toString() ?? '',
      requestNumber: reqNum,
      title: json['title']?.toString() ?? 'Untitled Request',
      author: json['author']?.toString(),
      isbn: json['isbn']?.toString(),
      publisher: json['publisher']?.toString(),
      edition: json['edition']?.toString(),
      language: json['language']?.toString() ?? 'English',
      requestType: json['request_type']?.toString() ?? 'Book',
      categoryCode: json['category_code']?.toString() ?? 'BOOK',
      preferredFormat: json['preferred_format']?.toString() ?? 'Physical',
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      priority: json['priority']?.toString() ?? 'Medium',
      status: (json['status']?.toString() ?? 'NEW').toUpperCase(),
      availabilityStatus: json['availability_status']?.toString() ?? 'AVAILABLE',
      approvalStatus: json['approval_status']?.toString() ?? 'NOT_REQUIRED',
      requesterId: json['requester_id']?.toString() ?? json['requester_user_id']?.toString() ?? json['student_id']?.toString(),
      requesterName: json['requester_name']?.toString() ?? 'Library Member',
      requesterRole: json['requester_role']?.toString() ?? 'student',
      requesterClass: json['requester_class']?.toString() ?? 'N/A',
      requesterAvatar: json['requester_avatar']?.toString(),
      memberCode: json['member_code']?.toString(),
      assignedToId: json['assigned_to']?.toString(),
      assignedToName: json['assigned_to_name']?.toString(),
      assignedToAvatar: json['assigned_to_avatar']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      requiredBy: parseNullableDate(json['required_by'] ?? json['requested_due_date']),
      processedAt: parseNullableDate(json['processed_at']),
      reason: json['reason']?.toString(),
      description: json['description']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      clarificationRequested: json['clarification_requested'] == true,
      clarificationMessage: json['clarification_message']?.toString(),
      clarificationResponse: json['clarification_response']?.toString(),
      bookId: json['book_id']?.toString(),
      bookCoverUrl: json['book_cover_url']?.toString() ?? json['cover_url']?.toString(),
      availableCopies: int.tryParse(json['available_copies']?.toString() ?? ''),
      totalCopies: int.tryParse(json['total_copies']?.toString() ?? ''),
      shelfLocation: json['shelf_location']?.toString(),
      rackLocation: json['rack_location']?.toString() ?? json['rack_number']?.toString(),
    );
  }
}

/// Real-time Aggregated KPI Metrics & Side Panel Analytics
class RequestKpisModel {
  final int totalRequests;
  final int newRequests;
  final int inProgress;
  final int resolved;
  final int rejected;
  final int canceled;
  final List<RequestTypeCount> typeCounts;
  final List<StatusDistributionItem> statusDistribution;
  final List<RecentRequestItem> recentRequests;

  RequestKpisModel({
    this.totalRequests = 0,
    this.newRequests = 0,
    this.inProgress = 0,
    this.resolved = 0,
    this.rejected = 0,
    this.canceled = 0,
    this.typeCounts = const [],
    this.statusDistribution = const [],
    this.recentRequests = const [],
  });

  int get cancelled => canceled;


  factory RequestKpisModel.fromJson(Map<String, dynamic> json) {
    var rawTypes = json['type_counts'] as List? ?? [];
    var typesList = rawTypes.map((e) => RequestTypeCount.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    var rawStatus = json['status_distribution'] as List? ?? [];
    var statusList = rawStatus.map((e) => StatusDistributionItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    var rawRecent = json['recent_requests'] as List? ?? [];
    var recentList = rawRecent.map((e) => RecentRequestItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return RequestKpisModel(
      totalRequests: int.tryParse(json['total_requests']?.toString() ?? '0') ?? 0,
      newRequests: int.tryParse(json['new_requests']?.toString() ?? '0') ?? 0,
      inProgress: int.tryParse(json['in_progress']?.toString() ?? '0') ?? 0,
      resolved: int.tryParse(json['resolved']?.toString() ?? '0') ?? 0,
      rejected: int.tryParse(json['rejected']?.toString() ?? '0') ?? 0,
      canceled: int.tryParse(json['canceled']?.toString() ?? '0') ?? 0,
      typeCounts: typesList,
      statusDistribution: statusList,
      recentRequests: recentList,
    );
  }
}

class RequestTypeCount {
  final String type;
  final int count;

  const RequestTypeCount({required this.type, required this.count});

  factory RequestTypeCount.fromJson(Map<String, dynamic> json) {
    return RequestTypeCount(
      type: json['type']?.toString() ?? 'Other',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class StatusDistributionItem {
  final String status;
  final int count;
  final double percentage;

  const StatusDistributionItem({required this.status, required this.count, required this.percentage});


  factory StatusDistributionItem.fromJson(Map<String, dynamic> json) {
    return StatusDistributionItem(
      status: json['status']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Color getColor() {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'completed':
        return const Color(0xFF10B981);
      case 'in progress':
      case 'in_progress':
      case 'active':
        return const Color(0xFF3B82F6);
      case 'new':
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF8B5CF6);
    }
  }
}

class RecentRequestItem {
  final String id;
  final String requestNumber;
  final String title;
  final String? author;
  final String requestType;
  final String requesterName;
  final String status;
  final String priority;
  final DateTime createdAt;

  RecentRequestItem({
    required this.id,
    required this.requestNumber,
    required this.title,
    this.author,
    required this.requestType,
    required this.requesterName,
    required this.status,
    required this.priority,
    required this.createdAt,
  });

  factory RecentRequestItem.fromJson(Map<String, dynamic> json) {
    return RecentRequestItem(
      id: json['id']?.toString() ?? '',
      requestNumber: json['request_number']?.toString() ?? 'REQ-000',
      title: json['title']?.toString() ?? 'Book Request',
      author: json['author']?.toString(),
      requestType: json['request_type']?.toString() ?? 'Book',
      requesterName: json['requester_name']?.toString() ?? 'Member',
      status: (json['status']?.toString() ?? 'NEW').toUpperCase(),
      priority: json['priority']?.toString() ?? 'Medium',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Request Detail with Audit Timeline, Comments, and Attachments
class RequestDetailModel {
  final LibraryRequestItem request;
  final List<RequestTimelineEvent> timeline;
  final List<RequestComment> comments;
  final List<RequestAttachment> attachments;
  final List<String> availableActions;

  RequestDetailModel({
    required this.request,
    required this.timeline,
    required this.comments,
    required this.attachments,
    required this.availableActions,
  });

  factory RequestDetailModel.fromJson(Map<String, dynamic> json) {
    final reqMap = json['request'] is Map ? Map<String, dynamic>.from(json['request'] as Map) : json;
    final item = LibraryRequestItem.fromJson(reqMap);

    var rawTimeline = json['timeline'] as List? ?? [];
    var timelineList = rawTimeline.map((e) => RequestTimelineEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    var rawComments = json['comments'] as List? ?? [];
    var commentsList = rawComments.map((e) => RequestComment.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    var rawAttach = json['attachments'] as List? ?? [];
    var attachList = rawAttach.map((e) => RequestAttachment.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    var rawActions = json['available_actions'] as List? ?? [];
    var actionsList = rawActions.map((e) => e.toString()).toList();

    return RequestDetailModel(
      request: item,
      timeline: timelineList,
      comments: commentsList,
      attachments: attachList,
      availableActions: actionsList,
    );
  }
}

class RequestTimelineEvent {
  final String id;
  final String? fromStatus;
  final String toStatus;
  final String action;
  final String? comment;
  final String changedByName;
  final String? changedByRole;
  final DateTime createdAt;

  RequestTimelineEvent({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    required this.action,
    this.comment,
    required this.changedByName,
    this.changedByRole,
    required this.createdAt,
  });

  factory RequestTimelineEvent.fromJson(Map<String, dynamic> json) {
    return RequestTimelineEvent(
      id: json['id']?.toString() ?? '',
      fromStatus: json['from_status']?.toString(),
      toStatus: (json['to_status']?.toString() ?? '').toUpperCase(),
      action: json['action']?.toString() ?? 'STATUS_CHANGE',
      comment: json['comment']?.toString() ?? json['reason']?.toString(),
      changedByName: json['changed_by_name']?.toString() ?? 'System',
      changedByRole: json['changed_by_role']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class RequestComment {
  final String id;
  final String authorName;
  final String? authorRole;
  final String? authorAvatar;
  final String comment;
  final bool isInternal;
  final DateTime createdAt;

  RequestComment({
    required this.id,
    required this.authorName,
    this.authorRole,
    this.authorAvatar,
    required this.comment,
    this.isInternal = false,
    required this.createdAt,
  });

  factory RequestComment.fromJson(Map<String, dynamic> json) {
    return RequestComment(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Staff',
      authorRole: json['author_role']?.toString(),
      authorAvatar: json['author_avatar']?.toString(),
      comment: json['comment']?.toString() ?? '',
      isInternal: json['is_internal'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class RequestAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final int fileSize;
  final String uploadedByName;
  final DateTime createdAt;

  RequestAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.fileSize = 0,
    required this.uploadedByName,
    required this.createdAt,
  });

  factory RequestAttachment.fromJson(Map<String, dynamic> json) {
    return RequestAttachment(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? 'attachment',
      fileUrl: json['file_url']?.toString() ?? '',
      mimeType: json['mime_type']?.toString(),
      fileSize: int.tryParse(json['file_size']?.toString() ?? '0') ?? 0,
      uploadedByName: json['uploaded_by_name']?.toString() ?? 'User',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class RequestFilterOptionsModel {
  final List<String> categories;
  final List<String> requestTypes;
  final List<String> statuses;
  final List<String> priorities;
  final List<String> formats;
  final List<String> roles;
  final List<Map<String, dynamic>> librarians;

  RequestFilterOptionsModel({
    this.categories = const ['Book', 'E-Book', 'Digital Resource', 'Audiobook', 'Journal / Magazine', 'Other'],
    this.requestTypes = const ['Book', 'E-Book', 'Digital Resource', 'Audiobook', 'Journal / Magazine', 'Other'],
    this.statuses = const ['All', 'New', 'Active', 'In Progress', 'Resolved', 'Completed', 'Rejected', 'Cancelled'],
    this.priorities = const ['All', 'Low', 'Medium', 'High', 'Urgent'],
    this.formats = const ['Physical', 'PDF', 'E-Book (Kindle)', 'Audio', 'Web Access', 'Hard Copy'],
    this.roles = const ['All', 'Student', 'Teacher', 'Staff', 'Parent'],
    this.librarians = const [],
  });

  factory RequestFilterOptionsModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStrList(dynamic val, List<String> fallback) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return fallback;
    }

    var rawLib = json['librarians'] as List? ?? [];
    var libList = rawLib.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return RequestFilterOptionsModel(
      categories: parseStrList(json['categories'], ['Book', 'E-Book', 'Digital Resource', 'Audiobook', 'Journal / Magazine', 'Other']),
      requestTypes: parseStrList(json['request_types'], ['Book', 'E-Book', 'Digital Resource', 'Audiobook', 'Journal / Magazine', 'Other']),
      statuses: parseStrList(json['statuses'], ['All', 'New', 'Active', 'In Progress', 'Resolved', 'Completed', 'Rejected', 'Cancelled']),
      priorities: parseStrList(json['priorities'], ['All', 'Low', 'Medium', 'High', 'Urgent']),
      formats: parseStrList(json['formats'], ['Physical', 'PDF', 'E-Book (Kindle)', 'Audio', 'Web Access', 'Hard Copy']),
      roles: parseStrList(json['roles'], ['All', 'Student', 'Teacher', 'Staff', 'Parent']),
      librarians: libList,
    );
  }
}
