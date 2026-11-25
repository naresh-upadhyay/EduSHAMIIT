import 'package:flutter/material.dart';

/// Document category enum matching backend category strings and UI tags.
enum DocumentCategory {
  aiGenerated('ai_generated', '🤖 AI Generated', 'AI Generated'),
  myUploads('my_uploads', '📤 My Uploads', 'My Uploads'),
  teacherShared('teacher_shared', '👩‍🏫 Teacher Shared', 'Teacher Shared'),
  chatShared('chat_shared', '💬 Chat Shared', 'Chat Shared'),
  schoolNotice('school_notice', '🏫 School Notices', 'School Notices'),
  academic('academic', '📚 Academic', 'Academic'),
  finance('finance', '💰 Finance', 'Finance'),
  administrative('administrative', '🏢 Administrative', 'Administrative'),
  humanResources('human_resources', '👥 Human Resources', 'HR'),
  admissions('admissions', '🎓 Admissions', 'Admissions'),
  compliance('compliance', '⚖️ Compliance', 'Compliance'),
  templates('templates', '📑 Templates', 'Templates'),
  archive('archive', '🗄️ Archive', 'Archive');

  final String value;
  final String label;
  final String shortLabel;

  const DocumentCategory(this.value, this.label, this.shortLabel);

  static DocumentCategory fromValue(String value) {
    final lower = value.toLowerCase().trim();
    for (final c in DocumentCategory.values) {
      if (c.value.toLowerCase() == lower || c.name.toLowerCase() == lower) {
        return c;
      }
    }
    return DocumentCategory.myUploads;
  }
}

/// Model representing a document in the Documents Hub.
class DocumentModel {
  final String id;
  final String schoolId;
  final String ownerId;
  final String ownerName;
  final String title;
  final String? description;
  final DocumentCategory category;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? content; // For AI-generated text docs
  final String? sourceChatSessionId;
  final String? sharedById;
  final String? sharedByName;
  final String? sharedByRole;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? folderId;
  final String? folderName;
  final String _fileType;
  final String approvalStatus;
  final int versionNumber;
  final bool isStarred;
  final bool isDeleted;
  final bool allowDownload;
  final bool canShare;
  final bool canDelete;
  final String? ownerRole;
  final String? ownerAvatar;
  final String? storagePath;
  final String? department;
  final String? tags;
  final String? accessType;
  final bool isArchived;
  final DateTime? deletedAt;
  final DateTime? expiryDate;
  final int downloadCount;
  final int previewCount;
  final int versionsCount;
  final int sharesCount;
  final String currentUserPermission;

  const DocumentModel({
    required this.id,
    required this.schoolId,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    this.description,
    required this.category,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.content,
    this.sourceChatSessionId,
    this.sharedById,
    this.sharedByName,
    this.sharedByRole,
    required this.createdAt,
    this.updatedAt,
    this.folderId,
    this.folderName,
    String? fileType,
    this.approvalStatus = 'Approved',
    this.versionNumber = 1,
    this.isStarred = false,
    this.isDeleted = false,
    this.allowDownload = true,
    this.canShare = true,
    this.canDelete = true,
    this.ownerRole,
    this.ownerAvatar,
    this.storagePath,
    this.department,
    this.tags,
    this.accessType,
    this.isArchived = false,
    this.deletedAt,
    this.expiryDate,
    this.downloadCount = 0,
    this.previewCount = 0,
    this.versionsCount = 0,
    this.sharesCount = 0,
    this.currentUserPermission = 'Editor',
  }) : _fileType = fileType ?? '';

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final sharedBy = json['shared_by'] as Map<String, dynamic>?;
    final owner = json['owner'] as Map<String, dynamic>?;

    String? parsedFileType = json['file_type']?.toString();
    final fileName = json['file_name']?.toString();
    final mimeType = json['mime_type']?.toString();

    if (parsedFileType == null || parsedFileType.isEmpty) {
      if (fileName != null && fileName.contains('.')) {
        parsedFileType = fileName.split('.').last.toUpperCase();
      } else if (mimeType != null) {
        if (mimeType.contains('pdf')) {
          parsedFileType = 'PDF';
        } else if (mimeType.contains('word') || mimeType.contains('docx')) {
          parsedFileType = 'DOCX';
        } else if (mimeType.contains('sheet') || mimeType.contains('excel')) {
          parsedFileType = 'XLSX';
        } else if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
          parsedFileType = 'PPTX';
        } else if (mimeType.contains('image')) {
          parsedFileType = 'IMAGE';
        }
      }
    }

    String? parsedDepartment;
    if (json['department'] is List) {
      parsedDepartment = (json['department'] as List).map((e) => e.toString()).join(', ');
    } else if (json['department'] != null) {
      parsedDepartment = json['department'].toString();
    }

    String? parsedTags;
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).join(', ');
    } else if (json['tags'] != null) {
      parsedTags = json['tags'].toString();
    }

    String? parsedAccessType;
    if (json['access_type'] is List) {
      parsedAccessType = (json['access_type'] as List).map((e) => e.toString()).join(', ');
    } else if (json['access_type'] != null) {
      parsedAccessType = json['access_type'].toString();
    }

    return DocumentModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? owner?['full_name']?.toString() ?? 'Admin',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString(),
      category: DocumentCategory.fromValue(json['category']?.toString() ?? 'my_uploads'),
      fileUrl: json['file_url']?.toString(),
      fileName: fileName,
      fileSize: (json['file_size'] as num?)?.toInt(),
      mimeType: mimeType,
      content: json['content']?.toString(),
      sourceChatSessionId: json['source_chat_session_id']?.toString(),
      sharedById: json['shared_by_id']?.toString(),
      sharedByName: sharedBy?['full_name']?.toString(),
      sharedByRole: sharedBy?['role']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      folderId: json['folder_id']?.toString(),
      folderName: json['folder_name']?.toString(),
      fileType: parsedFileType,
      approvalStatus: json['approval_status']?.toString() ?? 'Approved',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      isStarred: json['is_starred'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      allowDownload: json['allow_download'] as bool? ?? true,
      canShare: json['can_share'] as bool? ?? true,
      canDelete: json['can_delete'] as bool? ?? true,
      ownerRole: json['owner_role']?.toString() ?? owner?['role']?.toString(),
      ownerAvatar: json['owner_avatar']?.toString(),
      storagePath: json['storage_path']?.toString(),
      department: parsedDepartment,
      tags: parsedTags,
      accessType: parsedAccessType,
      isArchived: json['is_archived'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'].toString()) : null,
      downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
      previewCount: (json['preview_count'] as num?)?.toInt() ?? 0,
      versionsCount: (json['versions_count'] as num?)?.toInt() ?? 0,
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      currentUserPermission: json['current_user_permission']?.toString() ?? 'Editor',
    );
  }

  /// String value of the category enum for serialization.
  String get categoryRaw => category.value;

  /// Explicit or derived file type string (e.g., 'PDF', 'DOCX', 'XLSX').
  String get fileType {
    if (_fileType.isNotEmpty) return _fileType;
    if (fileName != null && fileName!.contains('.')) {
      return fileName!.split('.').last.toUpperCase();
    }
    if (mimeType != null) {
      if (mimeType!.contains('pdf')) return 'PDF';
      if (mimeType!.contains('word') || mimeType!.contains('docx')) return 'DOCX';
      if (mimeType!.contains('sheet') || mimeType!.contains('excel')) return 'XLSX';
      if (mimeType!.contains('presentation') || mimeType!.contains('powerpoint')) return 'PPTX';
    }
    return 'FILE';
  }

  /// Whether this is a file-backed document (as opposed to text-only AI doc).
  bool get isFileBacked => fileUrl != null && fileUrl!.isNotEmpty;

  /// Whether this is an AI-generated text document.
  bool get isAiTextDoc => category == DocumentCategory.aiGenerated && !isFileBacked;

  /// Human-readable file size.
  String get fileSizeLabel {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// File extension from fileName.
  String get extension {
    if (fileName == null) return fileType;
    final parts = fileName!.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : fileType;
  }

  /// Color accent for file badges.
  Color get fileTypeBadgeColor {
    final t = fileType.toUpperCase();
    if (t.contains('PDF')) return const Color(0xFFEF4444);
    if (t.contains('DOC') || t.contains('WORD')) return const Color(0xFF2563EB);
    if (t.contains('XLS') || t.contains('SHEET') || t.contains('CSV')) return const Color(0xFF10B981);
    if (t.contains('PPT') || t.contains('PRESENTATION')) return const Color(0xFFF97316);
    if (t.contains('IMAGE') || t.contains('PNG') || t.contains('JPG') || t.contains('JPEG')) {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF64748B);
  }

  /// Material icon for file representation.
  IconData get fileTypeIcon {
    final t = fileType.toUpperCase();
    if (t.contains('PDF')) return Icons.picture_as_pdf_rounded;
    if (t.contains('DOC') || t.contains('WORD')) return Icons.description_rounded;
    if (t.contains('XLS') || t.contains('SHEET') || t.contains('CSV')) return Icons.table_chart_rounded;
    if (t.contains('PPT') || t.contains('PRESENTATION')) return Icons.slideshow_rounded;
    if (t.contains('IMAGE') || t.contains('PNG') || t.contains('JPG') || t.contains('JPEG')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  DocumentModel copyWith({
    String? id,
    String? schoolId,
    String? ownerId,
    String? ownerName,
    String? title,
    String? description,
    DocumentCategory? category,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? content,
    String? sourceChatSessionId,
    String? sharedById,
    String? sharedByName,
    String? sharedByRole,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    String? folderName,
    String? fileType,
    String? approvalStatus,
    int? versionNumber,
    bool? isStarred,
    bool? isDeleted,
    bool? allowDownload,
    bool? canShare,
    bool? canDelete,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      content: content ?? this.content,
      sourceChatSessionId: sourceChatSessionId ?? this.sourceChatSessionId,
      sharedById: sharedById ?? this.sharedById,
      sharedByName: sharedByName ?? this.sharedByName,
      sharedByRole: sharedByRole ?? this.sharedByRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      fileType: fileType ?? _fileType,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      versionNumber: versionNumber ?? this.versionNumber,
      isStarred: isStarred ?? this.isStarred,
      isDeleted: isDeleted ?? this.isDeleted,
      allowDownload: allowDownload ?? this.allowDownload,
      canShare: canShare ?? this.canShare,
      canDelete: canDelete ?? this.canDelete,
    );
  }
}

/// Model representing a folder in Document Management hierarchy.
class FolderModel {
  final String id;
  final String name;
  final String? category;
  final Color color;
  final String? icon;
  final int documentCount;
  final int totalTreeCount;
  final List<FolderModel> children;
  final String? parentId;

  const FolderModel({
    required this.id,
    required this.name,
    this.category,
    this.color = const Color(0xFF2563EB),
    this.icon,
    this.documentCount = 0,
    this.totalTreeCount = 0,
    this.children = const [],
    this.parentId,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF2563EB);
    final rawColor = json['color'];
    if (rawColor is Color) {
      parsedColor = rawColor;
    } else if (rawColor is int) {
      parsedColor = Color(rawColor);
    } else if (rawColor is String && rawColor.isNotEmpty) {
      final hex = rawColor.replaceAll('#', '');
      if (hex.length == 6) {
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        parsedColor = Color(int.parse(hex, radix: 16));
      }
    }

    final rawChildren = json['children'] as List<dynamic>? ?? [];
    final children = rawChildren
        .map((c) => FolderModel.fromJson(c as Map<String, dynamic>))
        .toList();

    final docCount = (json['document_count'] as num?)?.toInt() ?? 0;
    final treeCount = (json['total_tree_count'] as num?)?.toInt() ?? docCount;

    return FolderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Folder',
      category: json['category'] as String?,
      color: parsedColor,
      icon: json['icon'] as String?,
      documentCount: docCount,
      totalTreeCount: treeCount,
      children: children,
      parentId: json['parent_id'] as String?,
    );
  }

  IconData get iconData {
    switch (icon?.toLowerCase()) {
      case 'school':
      case 'school_rounded':
        return Icons.school_rounded;
      case 'description':
      case 'file':
        return Icons.description_rounded;
      case 'finance':
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'people':
      case 'group':
        return Icons.group_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      case 'folder':
      default:
        return Icons.folder_rounded;
    }
  }

  Color get colorValue => color;
}

/// Statistics / KPIs for the Document Hub.
class DocumentStatsModel {
  final int totalDocuments;
  final int sharedDocuments;
  final int storageUsedBytes;
  final String storageUsedLabel;
  final int storageQuotaBytes;
  final String storageQuotaLabel;
  final int storagePercentage;
  final int recentUploads;
  final int recentToday;
  final int pendingApprovals;
  final int expiringSoon;

  const DocumentStatsModel({
    this.totalDocuments = 0,
    this.sharedDocuments = 0,
    this.storageUsedBytes = 0,
    this.storageUsedLabel = '0 B',
    this.storageQuotaBytes = 0,
    this.storageQuotaLabel = '0 B',
    this.storagePercentage = 0,
    this.recentUploads = 0,
    this.recentToday = 0,
    this.pendingApprovals = 0,
    this.expiringSoon = 0,
  });

  factory DocumentStatsModel.fromJson(Map<String, dynamic> json) {
    return DocumentStatsModel(
      totalDocuments: (json['total_documents'] as num?)?.toInt() ?? 0,
      sharedDocuments: (json['shared_documents'] as num?)?.toInt() ?? 0,
      storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
      storageUsedLabel: json['storage_used_label'] as String? ?? '0 B',
      storageQuotaBytes: (json['storage_quota_bytes'] as num?)?.toInt() ?? 0,
      storageQuotaLabel: json['storage_quota_label'] as String? ?? '0 B',
      storagePercentage: (json['storage_percentage'] as num?)?.toInt() ?? 0,
      recentUploads: (json['recent_uploads'] as num?)?.toInt() ?? 0,
      recentToday: (json['recent_today'] as num?)?.toInt() ?? 0,
      pendingApprovals: (json['pending_approvals'] as num?)?.toInt() ?? 0,
      expiringSoon: (json['expiring_soon'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Version record for Document history.
class DocumentVersionModel {
  final String id;
  final String documentId;
  final int versionNumber;
  final String fileName;
  final int? fileSize;
  final String fileSizeLabel;
  final String uploaderName;
  final String? changeSummary;
  final DateTime createdAt;
  final String? fileUrl;

  const DocumentVersionModel({
    required this.id,
    this.documentId = '',
    required this.versionNumber,
    required this.fileName,
    this.fileSize,
    this.fileSizeLabel = '',
    required this.uploaderName,
    this.changeSummary,
    required this.createdAt,
    this.fileUrl,
  });

  factory DocumentVersionModel.fromJson(Map<String, dynamic> json) {
    final size = (json['file_size'] as num?)?.toInt();
    String sizeLabel = json['file_size_label'] as String? ?? '';
    if (sizeLabel.isEmpty && size != null) {
      if (size < 1024) {
        sizeLabel = '$size B';
      } else if (size < 1024 * 1024) {
        sizeLabel = '${(size / 1024).toStringAsFixed(1)} KB';
      } else {
        sizeLabel = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return DocumentVersionModel(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      fileName: json['file_name']?.toString() ?? '',
      fileSize: size,
      fileSizeLabel: sizeLabel,
      uploaderName: json['uploader_name']?.toString() ?? 'Admin',
      changeSummary: json['change_summary']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fileUrl: json['file_url']?.toString(),
    );
  }
}

/// Sharing record for a document.
class DocumentShareModel {
  final String id;
  final String documentId;
  final String shareType;
  final String? targetId;
  final String? targetName;
  final String permissionLevel;
  final bool allowDownload;
  final bool allowPrint;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final String? targetRole;
  final String? message;

  const DocumentShareModel({
    required this.id,
    this.documentId = '',
    required this.shareType,
    this.targetId,
    this.targetName,
    this.permissionLevel = 'Viewer',
    this.allowDownload = true,
    this.allowPrint = true,
    this.expiryDate,
    required this.createdAt,
    this.targetRole,
    this.message,
  });

  factory DocumentShareModel.fromJson(Map<String, dynamic> json) {
    return DocumentShareModel(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      shareType: json['share_type']?.toString() ?? 'User',
      targetId: json['target_id']?.toString(),
      targetName: json['target_name']?.toString(),
      permissionLevel: json['permission_level']?.toString() ?? 'Viewer',
      allowDownload: json['allow_download'] as bool? ?? true,
      allowPrint: json['allow_print'] as bool? ?? true,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      targetRole: json['target_role']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

/// Activity log item for document audit trail.
class DocumentActivityModel {
  final String id;
  final String documentId;
  final String activityType;
  final String actorName;
  final String description;
  final DateTime createdAt;

  const DocumentActivityModel({
    required this.id,
    this.documentId = '',
    this.activityType = '',
    this.actorName = '',
    this.description = '',
    required this.createdAt,
  });

  factory DocumentActivityModel.fromJson(Map<String, dynamic> json) {
    return DocumentActivityModel(
      id: json['id']?.toString() ?? '',
      documentId: json['document_id']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'System',
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Requisition / Request model for institutional documents.
class DocumentRequestModel {
  final String id;
  final String? requesterName;
  final String? requesterId;
  final String title;
  final String category;
  final String priority;
  final String status;
  final String? description;
  final String? responseNotes;
  final String? fulfilledDocumentId;
  final DateTime createdAt;

  const DocumentRequestModel({
    required this.id,
    this.requesterName,
    this.requesterId,
    required this.title,
    this.category = 'General',
    this.priority = 'Medium',
    this.status = 'Pending',
    this.description,
    this.responseNotes,
    this.fulfilledDocumentId,
    required this.createdAt,
  });

  factory DocumentRequestModel.fromJson(Map<String, dynamic> json) {
    return DocumentRequestModel(
      id: json['id']?.toString() ?? '',
      requesterName: json['requester_name']?.toString(),
      requesterId: json['requester_id']?.toString(),
      title: json['title']?.toString() ?? 'Untitled Request',
      category: json['category']?.toString() ?? 'General',
      priority: json['priority']?.toString() ?? 'Medium',
      status: json['status']?.toString() ?? 'Pending',
      description: json['description']?.toString(),
      responseNotes: json['response_notes']?.toString(),
      fulfilledDocumentId: json['fulfilled_document_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
