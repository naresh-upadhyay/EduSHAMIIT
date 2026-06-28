/// Document category enum matching backend category strings.
enum DocumentCategory {
  aiGenerated('ai_generated', '🤖 AI Generated', 'AI Generated'),
  myUploads('my_uploads', '📤 My Uploads', 'My Uploads'),
  teacherShared('teacher_shared', '👩‍🏫 Teacher Shared', 'Teacher Shared'),
  chatShared('chat_shared', '💬 Chat Shared', 'Chat Shared'),
  schoolNotice('school_notice', '🏫 School Notices', 'School Notices');

  final String value;
  final String label;
  final String shortLabel;

  const DocumentCategory(this.value, this.label, this.shortLabel);

  static DocumentCategory fromValue(String value) {
    return DocumentCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => DocumentCategory.myUploads,
    );
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
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final sharedBy = json['shared_by'] as Map<String, dynamic>?;
    final owner = json['owner'] as Map<String, dynamic>?;
    return DocumentModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      ownerName: owner?['full_name'] as String? ?? 'Unknown',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      category: DocumentCategory.fromValue(json['category'] as String? ?? 'my_uploads'),
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      content: json['content'] as String?,
      sourceChatSessionId: json['source_chat_session_id'] as String?,
      sharedById: json['shared_by_id'] as String?,
      sharedByName: sharedBy?['full_name'] as String?,
      sharedByRole: sharedBy?['role'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
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
    if (fileName == null) return 'TXT';
    final parts = fileName!.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }
}
