
import 'package:intl/intl.dart';

/// KPI summary metrics for Hostel Leave & Outing module
class LeaveOutingKpiData {
  final int totalRequests;
  final String totalTrend;
  final int approved;
  final String approvalRate;
  final int pending;
  final String pendingSubtitle;
  final int rejected;
  final String rejectedRate;
  final int currentlyOut;
  final String currentlyOutSubtitle;
  final int dueToday;
  final String dueTodaySubtitle;
  final int overdue;
  final int canceled;

  const LeaveOutingKpiData({
    this.totalRequests = 0,
    this.totalTrend = '↑ 12% This Month',
    this.approved = 0,
    this.approvalRate = '0% approval rate',
    this.pending = 0,
    this.pendingSubtitle = 'Waiting for approval',
    this.rejected = 0,
    this.rejectedRate = '0% of requests',
    this.currentlyOut = 0,
    this.currentlyOutSubtitle = 'Students away',
    this.dueToday = 0,
    this.dueTodaySubtitle = 'Students',
    this.overdue = 0,
    this.canceled = 0,
  });

  factory LeaveOutingKpiData.fromJson(Map<String, dynamic> json) {
    String formatApprovalRate(dynamic val) {
      if (val == null) return '0% approval rate';
      final str = val.toString().trim();
      if (str.isEmpty) return '0% approval rate';
      if (str.contains('approval rate') || str.contains('%')) return str;
      return '$str% approval rate';
    }

    String formatRejectedRate(dynamic val) {
      if (val == null) return '0% of requests';
      final str = val.toString().trim();
      if (str.isEmpty) return '0% of requests';
      if (str.contains('of requests') || str.contains('%')) return str;
      return '$str% of requests';
    }

    return LeaveOutingKpiData(
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? (json['total'] as num?)?.toInt() ?? 0,
      totalTrend: json['total_trend']?.toString() ?? json['total_growth_label']?.toString() ?? '↑ 12% This Month',
      approved: (json['approved'] as num?)?.toInt() ?? (json['approved_count'] as num?)?.toInt() ?? 0,
      approvalRate: formatApprovalRate(json['approval_rate'] ?? json['approval_rate_pct']),
      pending: (json['pending'] as num?)?.toInt() ?? (json['pending_count'] as num?)?.toInt() ?? 0,
      pendingSubtitle: json['pending_subtitle']?.toString() ?? json['pending_subtext']?.toString() ?? 'Waiting for approval',
      rejected: (json['rejected'] as num?)?.toInt() ?? (json['rejected_count'] as num?)?.toInt() ?? 0,
      rejectedRate: formatRejectedRate(json['rejected_rate'] ?? json['rejected_rate_pct']),
      currentlyOut: (json['currently_out'] as num?)?.toInt() ?? (json['currently_out_count'] as num?)?.toInt() ?? 0,
      currentlyOutSubtitle: json['currently_out_subtitle']?.toString() ?? json['currently_out_subtext']?.toString() ?? 'Students away',
      dueToday: (json['due_today'] as num?)?.toInt() ?? (json['due_today_count'] as num?)?.toInt() ?? 0,
      dueTodaySubtitle: json['due_today_subtitle']?.toString() ?? json['due_today_subtext']?.toString() ?? 'Students',
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      canceled: (json['canceled'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Attached supporting document for leave/outing request
class LeaveOutingDocumentItem {
  final String id;
  final String documentName;
  final String documentType;
  final String? fileUrl;
  final int fileSizeBytes;
  final String fileSizeFormatted;
  final String contentType;
  final DateTime? uploadedAt;
  final String? uploadedByName;
  final String? notes;

  const LeaveOutingDocumentItem({
    required this.id,
    required this.documentName,
    this.documentType = 'Parent Consent',
    this.fileUrl,
    this.fileSizeBytes = 0,
    this.fileSizeFormatted = '150 KB',
    this.contentType = 'application/pdf',
    this.uploadedAt,
    this.uploadedByName,
    this.notes,
  });

  factory LeaveOutingDocumentItem.fromJson(Map<String, dynamic> json) {
    return LeaveOutingDocumentItem(
      id: json['id']?.toString() ?? '',
      documentName: json['document_name']?.toString() ?? json['title']?.toString() ?? 'Document.pdf',
      documentType: json['document_type']?.toString() ?? 'Parent Consent',
      fileUrl: json['file_url'] as String?,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      fileSizeFormatted: json['file_size_formatted']?.toString() ?? '150 KB',
      contentType: json['content_type']?.toString() ??
          (json['document_name']?.toString().toLowerCase().endsWith('.png') == true
              ? 'image/png'
              : (json['document_name']?.toString().toLowerCase().endsWith('.jpg') == true ||
                      json['document_name']?.toString().toLowerCase().endsWith('.jpeg') == true
                  ? 'image/jpeg'
                  : (json['document_name']?.toString().toLowerCase().endsWith('.webp') == true
                      ? 'image/webp'
                      : 'application/pdf'))),
      uploadedAt: json['uploaded_at'] != null ? DateTime.tryParse(json['uploaded_at'].toString()) : null,
      uploadedByName: json['uploaded_by_name'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'document_name': documentName,
    'document_type': documentType,
    'file_url': fileUrl,
    'file_size_bytes': fileSizeBytes,
    'file_size_formatted': fileSizeFormatted,
    'content_type': contentType,
    'notes': notes,
  };
}

/// Internal note or audit record for leave/outing request
class LeaveOutingNoteItem {
  final String id;
  final String note;
  final String category;
  final DateTime? createdAt;
  final String? authorName;

  const LeaveOutingNoteItem({
    required this.id,
    required this.note,
    this.category = 'General',
    this.createdAt,
    this.authorName,
  });

  factory LeaveOutingNoteItem.fromJson(Map<String, dynamic> json) {
    return LeaveOutingNoteItem(
      id: json['id']?.toString() ?? '',
      note: json['note']?.toString() ?? json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      authorName: json['author_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note,
    'category': category,
  };
}

/// Represents a single Leave/Outing request displayed in the central data table
class LeaveOutingRequestItem {
  final String id;
  final String requestNumber;
  final int displayIndex;
  final String studentId;
  final String studentName;
  final String? studentAvatar;
  final String? admissionNumber;
  final String? rollNumber;
  final String? className;
  final String? sectionName;
  final String? hostelName;
  final String? roomNumber;
  final String? bedNumber;
  final String requestType; // 'LEAVE' or 'OUTING'
  final String? requestSubtype;
  final String reason;
  final String destination;
  final String? fromDateFormatted;
  final String? toDateFormatted;
  final DateTime? startAt;
  final DateTime? expectedReturnAt;
  final DateTime? actualExitAt;
  final DateTime? actualReturnAt;
  final String durationText;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'CANCELED', 'EXITED', 'RETURNED', 'OVERDUE'
  final bool isEmergency;
  final String? requestedOnFormatted;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? gatePassId;
  final String? passNumber;
  final String? guardianName;
  final String? guardianPhone;
  final String? guardianRelationship;
  final bool guardianConfirmed;
  final String? accompaniedBy;
  final String? transportMode;
  final String? vehicleNumber;
  final String? companionName;
  final String? companionPhone;
  final String? specialInstructions;
  final String? destinationAddress;
  final String? exitGate;
  final String? exitVerifiedByName;
  final String? exitRemarks;
  final String? returnGate;
  final String? returnVerifiedByName;
  final String? returnRemarks;
  final String? approvalRemarks;
  final String? rejectionReason;
  final List<LeaveOutingDocumentItem> documents;
  final List<LeaveOutingNoteItem> internalNotes;
  final GatePassData? gatePass;
  final String? qrBase64;
  final List<MovementLogItem> movementLogs;
  final List<Map<String, dynamic>> timeline;
  final int version;
  final DateTime? createdAt;

  const LeaveOutingRequestItem({
    required this.id,
    required this.requestNumber,
    this.displayIndex = 1,
    required this.studentId,
    required this.studentName,
    this.studentAvatar,
    this.admissionNumber,
    this.rollNumber,
    this.className,
    this.sectionName,
    this.hostelName,
    this.roomNumber,
    this.bedNumber,
    required this.requestType,
    this.requestSubtype,
    required this.reason,
    required this.destination,
    this.fromDateFormatted,
    this.toDateFormatted,
    this.startAt,
    this.expectedReturnAt,
    this.actualExitAt,
    this.actualReturnAt,
    required this.durationText,
    required this.status,
    this.isEmergency = false,
    this.requestedOnFormatted,
    this.approvedByName,
    this.approvedAt,
    this.gatePassId,
    this.passNumber,
    this.guardianName,
    this.guardianPhone,
    this.guardianRelationship,
    this.guardianConfirmed = false,
    this.accompaniedBy,
    this.transportMode = 'WALK',
    this.vehicleNumber,
    this.companionName,
    this.companionPhone,
    this.specialInstructions,
    this.destinationAddress,
    this.exitGate,
    this.exitVerifiedByName,
    this.exitRemarks,
    this.returnGate,
    this.returnVerifiedByName,
    this.returnRemarks,
    this.approvalRemarks,
    this.rejectionReason,
    this.documents = const [],
    this.internalNotes = const [],
    this.gatePass,
    this.qrBase64,
    this.movementLogs = const [],
    this.timeline = const [],
    this.version = 1,
    this.createdAt,
  });

  factory LeaveOutingRequestItem.fromJson(Map<String, dynamic> json) {
    List<LeaveOutingDocumentItem> parsedDocs = [];
    if (json['documents'] is List) {
      parsedDocs = (json['documents'] as List)
          .map((d) => LeaveOutingDocumentItem.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    List<LeaveOutingNoteItem> parsedNotes = [];
    if (json['internal_notes'] is List) {
      parsedNotes = (json['internal_notes'] as List)
          .map((n) => LeaveOutingNoteItem.fromJson(n as Map<String, dynamic>))
          .toList();
    }

    List<MovementLogItem> parsedMovement = [];
    if (json['movement_logs'] is List) {
      parsedMovement = (json['movement_logs'] as List)
          .map((m) => MovementLogItem.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    List<Map<String, dynamic>> parsedTimeline = [];
    if (json['timeline'] is List) {
      parsedTimeline = (json['timeline'] as List)
          .map((t) => t as Map<String, dynamic>)
          .toList();
    }

    GatePassData? pass;
    if (json['gate_pass'] is Map<String, dynamic>) {
      pass = GatePassData.fromJson(json['gate_pass'] as Map<String, dynamic>);
    }

    final studentObj = json['student'] as Map<String, dynamic>?;
    final rawName = json['student_name']?.toString() ?? studentObj?['full_name']?.toString();
    final studentName = (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : 'Unknown Student';

    return LeaveOutingRequestItem(
      id: json['id']?.toString() ?? '',
      requestNumber: json['request_number']?.toString() ?? '',
      displayIndex: (json['display_index'] as num?)?.toInt() ?? 1,
      studentId: json['student_id']?.toString() ?? studentObj?['id']?.toString() ?? '',
      studentName: studentName,
      studentAvatar: json['student_avatar']?.toString() ?? studentObj?['avatar_url']?.toString(),
      admissionNumber: json['admission_number']?.toString() ?? studentObj?['admission_number']?.toString(),
      rollNumber: json['roll_number']?.toString() ?? studentObj?['roll_number']?.toString(),
      className: json['class_name']?.toString() ?? studentObj?['class']?.toString(),
      sectionName: json['section_name']?.toString() ?? (studentObj?['class'] != null ? studentObj!['class'].toString().split(' ').last : null),
      hostelName: json['hostel_name']?.toString() ?? json['building_name']?.toString(),
      roomNumber: json['room_number']?.toString(),
      bedNumber: json['bed_number']?.toString() ?? json['bed_code']?.toString(),
      requestType: (json['request_type']?.toString())?.toUpperCase() ?? 'OUTING',
      requestSubtype: json['request_subtype']?.toString(),
      reason: json['reason']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      fromDateFormatted: json['from_date_formatted']?.toString(),
      toDateFormatted: json['to_date_formatted']?.toString(),
      startAt: json['start_at'] != null ? DateTime.tryParse(json['start_at'].toString()) : null,
      expectedReturnAt: json['expected_return_at'] != null ? DateTime.tryParse(json['expected_return_at'].toString()) : null,
      actualExitAt: json['actual_exit_at'] != null ? DateTime.tryParse(json['actual_exit_at'].toString()) : null,
      actualReturnAt: json['actual_return_at'] != null ? DateTime.tryParse(json['actual_return_at'].toString()) : null,
      durationText: json['duration_text']?.toString() ?? '1 day',
      status: (json['status']?.toString())?.toUpperCase() ?? 'PENDING',
      isEmergency: json['is_emergency'] as bool? ?? false,
      requestedOnFormatted: json['requested_on_formatted']?.toString(),
      approvedByName: json['approved_by_name']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      gatePassId: json['gate_pass_id']?.toString() ?? pass?.id,
      passNumber: json['pass_number']?.toString() ?? pass?.passNumber,
      guardianName: json['guardian_name']?.toString(),
      guardianPhone: json['guardian_phone']?.toString(),
      guardianRelationship: json['guardian_relationship']?.toString() ?? 'Father',
      guardianConfirmed: json['guardian_confirmed'] as bool? ?? false,
      accompaniedBy: json['accompanied_by']?.toString() ?? 'SELF',
      transportMode: json['transport_mode']?.toString() ?? 'WALK',
      vehicleNumber: json['vehicle_number']?.toString(),
      companionName: json['companion_name']?.toString(),
      companionPhone: json['companion_phone']?.toString(),
      specialInstructions: json['special_instructions']?.toString(),
      destinationAddress: json['destination_address']?.toString(),
      exitGate: json['exit_gate']?.toString(),
      exitVerifiedByName: json['exit_verified_by_name']?.toString(),
      exitRemarks: json['exit_remarks']?.toString(),
      returnGate: json['return_gate']?.toString(),
      returnVerifiedByName: json['return_verified_by_name']?.toString(),
      returnRemarks: json['return_remarks']?.toString(),
      approvalRemarks: json['approval_remarks']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      documents: parsedDocs,
      internalNotes: parsedNotes,
      gatePass: pass,
      qrBase64: json['qr_base64']?.toString() ??
          (pass?.qrBase64) ??
          (json['gate_pass'] is Map ? json['gate_pass']['qr_base64']?.toString() : null),
      movementLogs: parsedMovement,
      timeline: parsedTimeline,
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  LeaveOutingRequestItem copyWith({
    String? studentName,
    String? studentId,
    String? studentAvatar,
    String? admissionNumber,
    String? rollNumber,
    String? className,
    String? sectionName,
    String? hostelName,
    String? roomNumber,
    String? bedNumber,
    String? status,
    String? reason,
    String? destination,
    String? requestType,
    String? requestSubtype,
    DateTime? startAt,
    DateTime? expectedReturnAt,
    DateTime? actualExitAt,
    DateTime? actualReturnAt,
    String? fromDateFormatted,
    String? toDateFormatted,
    String? durationText,
    bool? isEmergency,
    String? approvedByName,
    DateTime? approvedAt,
    String? passNumber,
    String? guardianName,
    String? guardianPhone,
    String? guardianRelationship,
    bool? guardianConfirmed,
    String? accompaniedBy,
    String? transportMode,
    String? vehicleNumber,
    String? companionName,
    String? companionPhone,
    String? specialInstructions,
    String? destinationAddress,
    String? exitGate,
    String? exitRemarks,
    String? returnGate,
    String? returnRemarks,
    String? approvalRemarks,
    String? rejectionReason,
    List<LeaveOutingDocumentItem>? documents,
    List<LeaveOutingNoteItem>? internalNotes,
    GatePassData? gatePass,
    String? qrBase64,
    List<MovementLogItem>? movementLogs,
    List<Map<String, dynamic>>? timeline,
    int? version,
  }) {
    return LeaveOutingRequestItem(
      id: id,
      requestNumber: requestNumber,
      displayIndex: displayIndex,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentAvatar: studentAvatar ?? this.studentAvatar,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      hostelName: hostelName ?? this.hostelName,
      roomNumber: roomNumber ?? this.roomNumber,
      bedNumber: bedNumber ?? this.bedNumber,
      requestType: requestType ?? this.requestType,
      requestSubtype: requestSubtype ?? this.requestSubtype,
      reason: reason ?? this.reason,
      destination: destination ?? this.destination,
      fromDateFormatted: fromDateFormatted ?? this.fromDateFormatted,
      toDateFormatted: toDateFormatted ?? this.toDateFormatted,
      startAt: startAt ?? this.startAt,
      expectedReturnAt: expectedReturnAt ?? this.expectedReturnAt,
      actualExitAt: actualExitAt ?? this.actualExitAt,
      actualReturnAt: actualReturnAt ?? this.actualReturnAt,
      durationText: durationText ?? this.durationText,
      status: status ?? this.status,
      isEmergency: isEmergency ?? this.isEmergency,
      requestedOnFormatted: requestedOnFormatted,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      gatePassId: gatePassId,
      passNumber: passNumber ?? this.passNumber,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
      guardianConfirmed: guardianConfirmed ?? this.guardianConfirmed,
      accompaniedBy: accompaniedBy ?? this.accompaniedBy,
      transportMode: transportMode ?? this.transportMode,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      companionName: companionName ?? this.companionName,
      companionPhone: companionPhone ?? this.companionPhone,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      exitGate: exitGate ?? this.exitGate,
      exitVerifiedByName: exitVerifiedByName,
      exitRemarks: exitRemarks ?? this.exitRemarks,
      returnGate: returnGate ?? this.returnGate,
      returnVerifiedByName: returnVerifiedByName,
      returnRemarks: returnRemarks ?? this.returnRemarks,
      approvalRemarks: approvalRemarks ?? this.approvalRemarks,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      documents: documents ?? this.documents,
      internalNotes: internalNotes ?? this.internalNotes,
      gatePass: gatePass ?? this.gatePass,
      qrBase64: qrBase64 ?? this.qrBase64,
      movementLogs: movementLogs ?? this.movementLogs,
      timeline: timeline ?? this.timeline,
      version: version ?? this.version,
      createdAt: createdAt,
    );
  }

  String get displayFromDate {
    if (fromDateFormatted != null && fromDateFormatted!.trim().isNotEmpty) {
      return fromDateFormatted!;
    }
    if (startAt != null) {
      final ist = startAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy').format(ist);
    }
    return '—';
  }

  String get displayToDate {
    if (toDateFormatted != null && toDateFormatted!.trim().isNotEmpty) {
      return toDateFormatted!;
    }
    if (expectedReturnAt != null) {
      final ist = expectedReturnAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy').format(ist);
    }
    return '—';
  }

  String get displayRequestedOn {
    if (requestedOnFormatted != null && requestedOnFormatted!.trim().isNotEmpty) {
      return requestedOnFormatted!;
    }
    if (createdAt != null) {
      final ist = createdAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy').format(ist);
    }
    if (startAt != null) {
      final ist = startAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy').format(ist);
    }
    return '—';
  }

  String get displayDuration {
    if (durationText.isNotEmpty && durationText != '1 day') {
      return durationText;
    }
    if (startAt != null && expectedReturnAt != null) {
      final diff = expectedReturnAt!.difference(startAt!);
      if (diff.inDays >= 1) {
        final days = diff.inDays + (diff.inHours % 24 > 0 ? 1 : 0);
        return '$days ${days == 1 ? "day" : "days"}';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"}';
      }
    }
    return durationText.isNotEmpty ? durationText : '1 day';
  }

  String get classSectionDisplay {
    final c = className ?? '';
    final s = sectionName != null && sectionName!.isNotEmpty ? ' $sectionName' : '';
    final r = rollNumber != null && rollNumber!.isNotEmpty ? ' | $rollNumber' : '';
    return '$c$s$r'.trim();
  }
}

/// Item shown in the "Awaiting Approval" right sidebar card
class AwaitingApprovalItem {
  final String id;
  final String studentName;
  final String? studentAvatar;
  final String requestType; // 'LEAVE' or 'OUTING'
  final String durationSubtitle; // e.g. "Outing • 11 May 2024" or "Leave • 18 May 2024 - 22 May 2024"
  final String status;

  const AwaitingApprovalItem({
    required this.id,
    required this.studentName,
    this.studentAvatar,
    required this.requestType,
    required this.durationSubtitle,
    this.status = 'Pending',
  });

  factory AwaitingApprovalItem.fromJson(Map<String, dynamic> json) {
    return AwaitingApprovalItem(
      id: json['id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      studentAvatar: json['student_avatar'] as String?,
      requestType: (json['request_type'] as String?)?.toUpperCase() ?? 'OUTING',
      durationSubtitle: json['duration_subtitle'] as String? ?? 'Pending Request',
      status: json['status'] as String? ?? 'Pending',
    );
  }
}

/// Full Digital Gate Pass model with QR verification data
class GatePassData {
  final String id;
  final String passNumber;
  final String verificationToken;
  final String qrReference;
  final String? qrBase64;
  final String status; // 'ACTIVE', 'USED', 'EXPIRED', 'CANCELED'
  final String studentName;
  final String? studentPhoto;
  final String? admissionNumber;
  final String? rollNumber;
  final String? className;
  final String? hostelName;
  final String? roomNumber;
  final String requestType;
  final String destination;
  final String? validFromFormatted;
  final String? validUntilFormatted;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? emergencyContact;
  final String? specialInstructions;
  final DateTime? usedExitAt;
  final DateTime? usedReturnAt;

  const GatePassData({
    required this.id,
    required this.passNumber,
    required this.verificationToken,
    required this.qrReference,
    this.qrBase64,
    required this.status,
    required this.studentName,
    this.studentPhoto,
    this.admissionNumber,
    this.rollNumber,
    this.className,
    this.hostelName,
    this.roomNumber,
    required this.requestType,
    required this.destination,
    this.validFromFormatted,
    this.validUntilFormatted,
    this.validFrom,
    this.validUntil,
    this.approvedByName,
    this.approvedAt,
    this.emergencyContact,
    this.specialInstructions,
    this.usedExitAt,
    this.usedReturnAt,
  });

  factory GatePassData.fromJson(Map<String, dynamic> json) {
    return GatePassData(
      id: json['id']?.toString() ?? '',
      passNumber: json['pass_number']?.toString() ?? '',
      verificationToken: json['verification_token']?.toString() ?? '',
      qrReference: json['qr_reference']?.toString() ?? '',
      qrBase64: json['qr_base64']?.toString() ?? json['qr_code_base64']?.toString(),
      status: (json['status']?.toString())?.toUpperCase() ?? 'ACTIVE',
      studentName: json['student_name']?.toString() ?? 'Student',
      studentPhoto: json['student_photo']?.toString(),
      admissionNumber: json['admission_number']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      className: json['class_name']?.toString(),
      hostelName: json['hostel_name']?.toString(),
      roomNumber: json['room_number']?.toString(),
      requestType: (json['request_type']?.toString())?.toUpperCase() ?? 'OUTING',
      destination: json['destination']?.toString() ?? '',
      validFromFormatted: json['valid_from_formatted']?.toString(),
      validUntilFormatted: json['valid_until_formatted']?.toString(),
      validFrom: json['valid_from'] != null ? DateTime.tryParse(json['valid_from'].toString()) : null,
      validUntil: json['valid_until'] != null ? DateTime.tryParse(json['valid_until'].toString()) : null,
      approvedByName: json['approved_by_name']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      emergencyContact: json['emergency_contact']?.toString(),
      specialInstructions: json['special_instructions']?.toString(),
      usedExitAt: json['used_exit_at'] != null ? DateTime.tryParse(json['used_exit_at'].toString()) : null,
      usedReturnAt: json['used_return_at'] != null ? DateTime.tryParse(json['used_return_at'].toString()) : null,
    );
  }
}

/// Movement audit record (Exit or Return)
class MovementLogItem {
  final String id;
  final String movementType; // 'EXIT' or 'RETURN'
  final DateTime timestamp;
  final String gate;
  final String verifiedByName;
  final String? remarks;

  const MovementLogItem({
    required this.id,
    required this.movementType,
    required this.timestamp,
    required this.gate,
    required this.verifiedByName,
    this.remarks,
  });

  factory MovementLogItem.fromJson(Map<String, dynamic> json) {
    return MovementLogItem(
      id: json['id']?.toString() ?? '',
      movementType: (json['movement_type'] as String?)?.toUpperCase() ?? 'EXIT',
      timestamp: DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now(),
      gate: json['gate'] as String? ?? 'Main Gate',
      verifiedByName: json['verified_by_name'] as String? ?? 'Security Staff',
      remarks: json['remarks'] as String?,
    );
  }
}

/// Configurable rules and settings
class LeaveOutingSettingsData {
  final bool leaveAllowed;
  final bool outingAllowed;
  final String outingStartTime;
  final String lastAllowedReturnTime;
  final bool guardianConfirmationRequired;
  final bool wardenApprovalRequired;
  final bool directorApprovalRequired;
  final bool autoGatepassOnApproval;
  final int lateReturnGracePeriodMins;
  final int maxOutingsPerMonth;
  final int maxLeaveDays;

  const LeaveOutingSettingsData({
    this.leaveAllowed = true,
    this.outingAllowed = true,
    this.outingStartTime = '06:00',
    this.lastAllowedReturnTime = '20:00',
    this.guardianConfirmationRequired = true,
    this.wardenApprovalRequired = true,
    this.directorApprovalRequired = false,
    this.autoGatepassOnApproval = true,
    this.lateReturnGracePeriodMins = 30,
    this.maxOutingsPerMonth = 4,
    this.maxLeaveDays = 14,
  });

  factory LeaveOutingSettingsData.fromJson(Map<String, dynamic> json) {
    return LeaveOutingSettingsData(
      leaveAllowed: json['leave_allowed'] as bool? ?? true,
      outingAllowed: json['outing_allowed'] as bool? ?? true,
      outingStartTime: json['outing_start_time'] as String? ?? '06:00',
      lastAllowedReturnTime: json['last_allowed_return_time'] as String? ?? '20:00',
      guardianConfirmationRequired: json['guardian_confirmation_required'] as bool? ?? true,
      wardenApprovalRequired: json['warden_approval_required'] as bool? ?? true,
      directorApprovalRequired: json['director_approval_required'] as bool? ?? false,
      autoGatepassOnApproval: json['auto_gatepass_on_approval'] as bool? ?? true,
      lateReturnGracePeriodMins: (json['late_return_grace_period_mins'] as num?)?.toInt() ?? 30,
      maxOutingsPerMonth: (json['max_outings_per_month'] as num?)?.toInt() ?? 4,
      maxLeaveDays: (json['max_leave_days'] as num?)?.toInt() ?? 14,
    );
  }

  Map<String, dynamic> toJson() => {
    'leave_allowed': leaveAllowed,
    'outing_allowed': outingAllowed,
    'outing_start_time': outingStartTime,
    'last_allowed_return_time': lastAllowedReturnTime,
    'guardian_confirmation_required': guardianConfirmationRequired,
    'warden_approval_required': wardenApprovalRequired,
    'director_approval_required': directorApprovalRequired,
    'auto_gatepass_on_approval': autoGatepassOnApproval,
    'late_return_grace_period_mins': lateReturnGracePeriodMins,
    'max_outings_per_month': maxOutingsPerMonth,
    'max_leave_days': maxLeaveDays,
  };
}
