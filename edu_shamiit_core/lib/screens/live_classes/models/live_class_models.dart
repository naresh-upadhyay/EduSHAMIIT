library;

/// Models for Live Class Management Module (Join & Conduct, Recordings, Attendance)

class JoinConductDashboardData {
  final int liveNow;
  final int todaysClasses;
  final int totalParticipantsLive;
  final int recordingInProgress;
  final int avgClassDurationMin;
  final String classQuality;
  final String systemStatus;

  final ActiveLiveSession? activeSession;
  final List<LiveParticipant> participants;
  final List<UpcomingClass> upcomingClasses;
  final ClassEngagement engagement;

  JoinConductDashboardData({
    required this.liveNow,
    required this.todaysClasses,
    required this.totalParticipantsLive,
    required this.recordingInProgress,
    required this.avgClassDurationMin,
    required this.classQuality,
    required this.systemStatus,
    this.activeSession,
    this.participants = const [],
    this.upcomingClasses = const [],
    required this.engagement,
  });

  factory JoinConductDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final active = json['active_session'] as Map<String, dynamic>?;
    final parts = (json['participants'] as List?)
            ?.map((p) => LiveParticipant.fromJson(p))
            .toList() ??
        [];
    final upcoming = (json['upcoming_classes'] as List?)
            ?.map((u) => UpcomingClass.fromJson(u))
            .toList() ??
        [];
    final eng = json['engagement'] as Map<String, dynamic>? ?? {};

    return JoinConductDashboardData(
      liveNow: kpis['live_now'] ?? 0,
      todaysClasses: kpis['todays_classes'] ?? 0,
      totalParticipantsLive: kpis['total_participants_live'] ?? 0,
      recordingInProgress: kpis['recording_in_progress'] ?? 0,
      avgClassDurationMin: kpis['avg_class_duration_min'] ?? 45,
      classQuality: kpis['class_quality'] ?? 'Excellent (98%)',
      systemStatus: kpis['system_status'] ?? 'Online',
      activeSession: active != null ? ActiveLiveSession.fromJson(active) : null,
      participants: parts,
      upcomingClasses: upcoming,
      engagement: ClassEngagement.fromJson(eng),
    );
  }
}

class ActiveLiveSession {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String subjectIcon;
  final String className;
  final String sectionName;
  final String classSection;
  final String? teacherId;
  final String teacherName;
  final String teacherRole;
  final int durationMinutes;
  final String status;
  final bool isLive;
  final String recordingStatus;
  final bool recordingEnabled;
  final String roomCode;
  final String meetingLink;
  final int viewerCount;
  final int maxParticipants;
  final bool allowStudentMic;
  final bool allowStudentCam;
  final bool allowStudentShare;
  final bool allowChat;
  final bool allowReactions;
  final bool waitingRoomEnabled;
  final String dateStr;
  final String timeStr;
  final String recordingElapsedStr;

  ActiveLiveSession({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.subjectIcon,
    required this.className,
    required this.sectionName,
    required this.classSection,
    this.teacherId,
    required this.teacherName,
    required this.teacherRole,
    required this.durationMinutes,
    required this.status,
    required this.isLive,
    required this.recordingStatus,
    required this.recordingEnabled,
    required this.roomCode,
    required this.meetingLink,
    required this.viewerCount,
    required this.maxParticipants,
    this.allowStudentMic = true,
    this.allowStudentCam = true,
    this.allowStudentShare = false,
    this.allowChat = true,
    this.allowReactions = true,
    this.waitingRoomEnabled = false,
    required this.dateStr,
    required this.timeStr,
    required this.recordingElapsedStr,
  });

  ActiveLiveSession copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? subjectIcon,
    String? className,
    String? sectionName,
    String? classSection,
    String? teacherId,
    String? teacherName,
    String? teacherRole,
    int? durationMinutes,
    String? status,
    bool? isLive,
    String? recordingStatus,
    bool? recordingEnabled,
    String? roomCode,
    String? meetingLink,
    int? viewerCount,
    int? maxParticipants,
    bool? allowStudentMic,
    bool? allowStudentCam,
    bool? allowStudentShare,
    bool? allowChat,
    bool? allowReactions,
    bool? waitingRoomEnabled,
    String? dateStr,
    String? timeStr,
    String? recordingElapsedStr,
  }) {
    return ActiveLiveSession(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      subjectIcon: subjectIcon ?? this.subjectIcon,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      classSection: classSection ?? this.classSection,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherRole: teacherRole ?? this.teacherRole,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      isLive: isLive ?? this.isLive,
      recordingStatus: recordingStatus ?? this.recordingStatus,
      recordingEnabled: recordingEnabled ?? this.recordingEnabled,
      roomCode: roomCode ?? this.roomCode,
      meetingLink: meetingLink ?? this.meetingLink,
      viewerCount: viewerCount ?? this.viewerCount,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      allowStudentMic: allowStudentMic ?? this.allowStudentMic,
      allowStudentCam: allowStudentCam ?? this.allowStudentCam,
      allowStudentShare: allowStudentShare ?? this.allowStudentShare,
      allowChat: allowChat ?? this.allowChat,
      allowReactions: allowReactions ?? this.allowReactions,
      waitingRoomEnabled: waitingRoomEnabled ?? this.waitingRoomEnabled,
      dateStr: dateStr ?? this.dateStr,
      timeStr: timeStr ?? this.timeStr,
      recordingElapsedStr: recordingElapsedStr ?? this.recordingElapsedStr,
    );
  }

  factory ActiveLiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveLiveSession(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Organic Compounds – Introduction',
      description: json['description'] ?? '',
      subject: json['subject'] ?? 'Chemistry',
      subjectIcon: json['subject_icon'] ?? '🧪',
      className: json['class_name'] ?? 'Class 12',
      sectionName: json['section_name'] ?? 'A',
      classSection: json['class_section'] ?? 'Class 12 - A',
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'] ?? 'Aarav Sharma',
      teacherRole: json['teacher_role'] ?? 'teacher',
      durationMinutes: json['duration_minutes'] ?? 45,
      status: json['status'] ?? 'live',
      isLive: json['is_live'] ?? true,
      recordingStatus: json['recording_status'] ?? 'IDLE',
      recordingEnabled: json['recording_enabled'] ?? false,
      roomCode: json['room_code'] ?? '12A-CHEM',
      meetingLink: json['meeting_link'] ?? 'https://meet.edushamiit.com/c/12A-chem',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 1,
      allowStudentMic: json['allow_student_mic'] ?? true,
      allowStudentCam: json['allow_student_cam'] ?? true,
      allowStudentShare: json['allow_student_share'] ?? false,
      allowChat: json['allow_chat'] ?? true,
      allowReactions: json['allow_reactions'] ?? true,
      waitingRoomEnabled: json['waiting_room_enabled'] ?? false,
      dateStr: json['date_str'] ?? 'Tue, 21 Jan 2025',
      timeStr: json['time_str'] ?? '08:00 AM - 08:45 AM (45 min)',
      recordingElapsedStr: json['recording_elapsed_str'] ?? '00:18:24',
    );
  }

  factory ActiveLiveSession.fromMyClassItem(MyClassItem item, [MyClassDetails? details]) {
    final parts = item.classSection.split('-');
    final cls = parts.isNotEmpty ? parts[0].trim() : 'Class 12';
    final sec = parts.length > 1 ? parts[1].trim() : 'A';
    return ActiveLiveSession(
      id: item.id,
      title: item.topic.isNotEmpty ? item.topic : (details?.topic ?? 'Class Session'),
      description: item.description.isNotEmpty ? item.description : (details?.description ?? ''),
      subject: item.subjectName.isNotEmpty ? item.subjectName : (details?.subject ?? 'Chemistry'),
      subjectIcon: item.subjectIcon.isNotEmpty ? item.subjectIcon : (details?.subjectIcon ?? '🧪'),
      className: cls,
      sectionName: sec,
      classSection: item.classSection.isNotEmpty ? item.classSection : (details?.classSection ?? '$cls - $sec'),
      teacherId: item.teacherId,
      teacherName: item.teacherName.isNotEmpty ? item.teacherName : (details?.hostName ?? 'Teacher'),
      teacherRole: details?.hostRole ?? 'Teacher',
      durationMinutes: item.durationMinutes > 0 ? item.durationMinutes : 45,
      status: item.status.isNotEmpty ? item.status : 'live',
      isLive: true,
      recordingStatus: item.recordingStatus.isNotEmpty ? item.recordingStatus : 'RECORDING',
      recordingEnabled: item.recordingEnabled,
      roomCode: item.roomCode.isNotEmpty ? item.roomCode : (details?.meetingCode ?? '12A-CHEM'),
      meetingLink: item.meetingLink.isNotEmpty ? item.meetingLink : (details?.meetingLink ?? 'https://meet.edushamiit.com/c/12A-chem'),
      viewerCount: item.viewerCount > 0 ? item.viewerCount : (details?.viewerCount ?? 0),
      maxParticipants: item.maxParticipants > 0 ? item.maxParticipants : (details?.maxParticipants ?? 1),
      allowStudentMic: true,
      allowStudentCam: true,
      allowStudentShare: false,
      allowChat: true,
      allowReactions: true,
      waitingRoomEnabled: false,
      dateStr: item.scheduledDateStr.isNotEmpty ? item.scheduledDateStr : (details?.dateStr ?? 'Today'),
      timeStr: item.scheduledTimeStr.isNotEmpty ? item.scheduledTimeStr : (details?.timeStr ?? '08:00 AM - 08:45 AM (45 min)'),
      recordingElapsedStr: '00:00:00',
    );
  }
}

class LiveParticipant {
  final String id;
  final String userId;
  final String name;
  final String role;
  final String initials;
  final bool micMuted;
  final bool camOff;
  final bool isSpeaking;
  final String color;

  LiveParticipant({
    required this.id,
    this.userId = '',
    required this.name,
    required this.role,
    required this.initials,
    required this.micMuted,
    required this.camOff,
    required this.isSpeaking,
    required this.color,
  });

  LiveParticipant copyWith({
    String? id,
    String? userId,
    String? name,
    String? role,
    String? initials,
    bool? micMuted,
    bool? camOff,
    bool? isSpeaking,
    String? color,
  }) {
    return LiveParticipant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      initials: initials ?? this.initials,
      micMuted: micMuted ?? this.micMuted,
      camOff: camOff ?? this.camOff,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      color: color ?? this.color,
    );
  }

  factory LiveParticipant.fromJson(Map<String, dynamic> json) {
    return LiveParticipant(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'Student',
      initials: json['initials'] ?? (json['name'] != null && json['name'].isNotEmpty ? json['name'].substring(0, 1) : 'U'),
      micMuted: json['mic_muted'] ?? true,
      camOff: json['cam_off'] ?? false,
      isSpeaking: json['is_speaking'] ?? false,
      color: json['color'] ?? '#2563EB',
    );
  }
}

class UpcomingClass {
  final String id;
  final String className;
  final String subject;
  final String timeStr;
  final String badge;
  final String status;

  UpcomingClass({
    required this.id,
    required this.className,
    required this.subject,
    required this.timeStr,
    required this.badge,
    required this.status,
  });

  factory UpcomingClass.fromJson(Map<String, dynamic> json) {
    return UpcomingClass(
      id: json['id'] ?? '',
      className: json['class_name'] ?? '',
      subject: json['subject'] ?? '',
      timeStr: json['time_str'] ?? '',
      badge: json['badge'] ?? 'Scheduled',
      status: json['status'] ?? 'scheduled',
    );
  }
}

class ClassEngagement {
  final int overallPercentage;
  final int activeParticipantsPct;
  final int interactionPct;
  final int pollResponsePct;
  final int contentViewPct;

  ClassEngagement({
    required this.overallPercentage,
    required this.activeParticipantsPct,
    required this.interactionPct,
    required this.pollResponsePct,
    required this.contentViewPct,
  });

  factory ClassEngagement.fromJson(Map<String, dynamic> json) {
    return ClassEngagement(
      overallPercentage: json['overall_percentage'] ?? 92,
      activeParticipantsPct: json['active_participants_pct'] ?? 92,
      interactionPct: json['interaction_pct'] ?? 88,
      pollResponsePct: json['poll_response_pct'] ?? 95,
      contentViewPct: json['content_view_pct'] ?? 93,
    );
  }
}

// ============================================================================
// RECORDINGS TAB MODELS
// ============================================================================

class RecordingsDashboardData {
  final int totalRecordings;
  final int thisWeek;
  final String totalDurationDisplay;
  final double storageUsedGb;
  final double storageTotalTb;
  final int storageUsedPercentage;
  final int totalDownloads;
  final int avgViews;
  final int retentionRatePct;

  final StorageBreakdown storageBreakdown;
  final RecordingSettings settings;
  final List<AnalyticsDataPoint> analytics30Days;

  RecordingsDashboardData({
    required this.totalRecordings,
    required this.thisWeek,
    required this.totalDurationDisplay,
    required this.storageUsedGb,
    required this.storageTotalTb,
    required this.storageUsedPercentage,
    required this.totalDownloads,
    required this.avgViews,
    required this.retentionRatePct,
    required this.storageBreakdown,
    required this.settings,
    required this.analytics30Days,
  });

  factory RecordingsDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final sb = json['storage_breakdown'] as Map<String, dynamic>? ?? {};
    final sets = json['settings'] as Map<String, dynamic>? ?? {};
    final pts = (json['analytics_30_days'] as List?)
            ?.map((p) => AnalyticsDataPoint.fromJson(p))
            .toList() ??
        [];

    return RecordingsDashboardData(
      totalRecordings: (kpis['total_recordings'] as num?)?.toInt() ?? 0,
      thisWeek: (kpis['this_week'] as num?)?.toInt() ?? 0,
      totalDurationDisplay: kpis['total_duration_display'] ?? '0 min',
      storageUsedGb: (kpis['storage_used_gb'] as num?)?.toDouble() ?? 0.0,
      storageTotalTb: (kpis['storage_total_tb'] as num?)?.toDouble() ?? 1.0,
      storageUsedPercentage: (kpis['storage_used_percentage'] as num?)?.toInt() ?? 0,
      totalDownloads: (kpis['total_downloads'] as num?)?.toInt() ?? 0,
      avgViews: (kpis['avg_views'] as num?)?.toInt() ?? 0,
      retentionRatePct: (kpis['retention_rate_pct'] as num?)?.toInt() ?? 100,
      storageBreakdown: StorageBreakdown.fromJson(sb),
      settings: RecordingSettings.fromJson(sets),
      analytics30Days: pts,
    );
  }
}

class StorageBreakdown {
  final double recordingsGb;
  final double recordingsPct;
  final double classResourcesGb;
  final double classResourcesPct;
  final double othersGb;
  final double othersPct;
  final double freeSpaceGb;
  final double freeSpacePct;

  StorageBreakdown({
    required this.recordingsGb,
    required this.recordingsPct,
    required this.classResourcesGb,
    required this.classResourcesPct,
    required this.othersGb,
    required this.othersPct,
    required this.freeSpaceGb,
    required this.freeSpacePct,
  });

  factory StorageBreakdown.fromJson(Map<String, dynamic> json) {
    return StorageBreakdown(
      recordingsGb: (json['recordings_gb'] ?? 612.3).toDouble(),
      recordingsPct: (json['recordings_pct'] ?? 59.8).toDouble(),
      classResourcesGb: (json['class_resources_gb'] ?? 94.6).toDouble(),
      classResourcesPct: (json['class_resources_pct'] ?? 9.2).toDouble(),
      othersGb: (json['others_gb'] ?? 21.5).toDouble(),
      othersPct: (json['others_pct'] ?? 2.0).toDouble(),
      freeSpaceGb: (json['free_space_gb'] ?? 295.6).toDouble(),
      freeSpacePct: (json['free_space_pct'] ?? 29.0).toDouble(),
    );
  }
}

class RecordingSettings {
  final bool autoRecording;
  final bool cloudStorage;
  final int defaultRetentionDays;
  final String recordingQuality;
  final bool allowStudentDownload;

  RecordingSettings({
    required this.autoRecording,
    required this.cloudStorage,
    required this.defaultRetentionDays,
    required this.recordingQuality,
    required this.allowStudentDownload,
  });

  factory RecordingSettings.fromJson(Map<String, dynamic> json) {
    return RecordingSettings(
      autoRecording: json['auto_recording'] ?? true,
      cloudStorage: json['cloud_storage'] ?? true,
      defaultRetentionDays: json['default_retention_days'] ?? 180,
      recordingQuality: json['recording_quality'] ?? 'HD (720p)',
      allowStudentDownload: json['allow_student_download'] ?? true,
    );
  }
}

enum RuleLogicalOperator { and, or }

enum RuleField {
  meetingTitle,
  classSectionCombo,
  subject,
  teacherHost,
  sessionType,
  scheduledDay,
}

enum RuleConditionOperator {
  contains,
  doesNotContain,
  equals,
  doesNotEqual,
  startsWith,
  endsWith,
  matchesPattern,
}

class AutoRecordingQueryClause {
  String id;
  RuleLogicalOperator logicalOp;
  RuleField field;
  RuleConditionOperator operator;
  String value;

  AutoRecordingQueryClause({
    required this.id,
    this.logicalOp = RuleLogicalOperator.and,
    this.field = RuleField.meetingTitle,
    this.operator = RuleConditionOperator.contains,
    this.value = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'logical_op': logicalOp.name.toUpperCase(),
        'field': field.name,
        'operator': operator.name,
        'value': value,
      };

  factory AutoRecordingQueryClause.fromJson(Map<String, dynamic> json) => AutoRecordingQueryClause(
        id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        logicalOp: (json['logical_op'] == 'OR') ? RuleLogicalOperator.or : RuleLogicalOperator.and,
        field: RuleField.values.firstWhere((e) => e.name == json['field'], orElse: () => RuleField.meetingTitle),
        operator: RuleConditionOperator.values.firstWhere((e) => e.name == json['operator'], orElse: () => RuleConditionOperator.contains),
        value: json['value'] ?? '',
      );
}

class AutoRecordingRuleSet {
  final bool globalAutoRecordAll;
  final Set<String> enabledClassSectionIds;
  final List<AutoRecordingQueryClause> customQueryClauses;

  AutoRecordingRuleSet({
    this.globalAutoRecordAll = false,
    Set<String>? enabledClassSectionIds,
    List<AutoRecordingQueryClause>? customQueryClauses,
  })  : enabledClassSectionIds = enabledClassSectionIds ?? {'10-A', 'Class 10 - 10-A'},
        customQueryClauses = customQueryClauses ??
            [
              AutoRecordingQueryClause(
                id: 'clause_1',
                logicalOp: RuleLogicalOperator.and,
                field: RuleField.subject,
                operator: RuleConditionOperator.contains,
                value: 'Computer Science',
              ),
              AutoRecordingQueryClause(
                id: 'clause_2',
                logicalOp: RuleLogicalOperator.or,
                field: RuleField.meetingTitle,
                operator: RuleConditionOperator.contains,
                value: 'Exam',
              ),
            ];

  bool get hasActiveRules => globalAutoRecordAll || enabledClassSectionIds.isNotEmpty || customQueryClauses.any((c) => c.value.trim().isNotEmpty);

  AutoRecordingRuleSet copyWith({
    bool? globalAutoRecordAll,
    Set<String>? enabledClassSectionIds,
    List<AutoRecordingQueryClause>? customQueryClauses,
  }) {
    return AutoRecordingRuleSet(
      globalAutoRecordAll: globalAutoRecordAll ?? this.globalAutoRecordAll,
      enabledClassSectionIds: enabledClassSectionIds ?? this.enabledClassSectionIds,
      customQueryClauses: customQueryClauses ?? this.customQueryClauses,
    );
  }

  bool evaluatesToTrue({
    required String title,
    required String classSection,
    required String subject,
    required String teacherName,
    String? sessionType,
    String? dayOfWeek,
  }) {
    if (globalAutoRecordAll) return true;

    // Check assigned class/section toggles
    for (final id in enabledClassSectionIds) {
      if (classSection.trim().toLowerCase().contains(id.trim().toLowerCase()) ||
          id.trim().toLowerCase().contains(classSection.trim().toLowerCase())) {
        return true;
      }
    }

    // Evaluate SHAMIIT query builder clauses
    if (customQueryClauses.isEmpty) return false;

    bool currentResult = false;
    for (int i = 0; i < customQueryClauses.length; i++) {
      final clause = customQueryClauses[i];
      if (clause.value.trim().isEmpty) continue;
      final bool match = _evaluateClause(
        clause,
        title: title,
        classSection: classSection,
        subject: subject,
        teacherName: teacherName,
        sessionType: sessionType,
        dayOfWeek: dayOfWeek,
      );

      if (i == 0) {
        currentResult = match;
      } else {
        if (clause.logicalOp == RuleLogicalOperator.and) {
          currentResult = currentResult && match;
        } else {
          currentResult = currentResult || match;
        }
      }
    }
    return currentResult;
  }

  bool _evaluateClause(
    AutoRecordingQueryClause clause, {
    required String title,
    required String classSection,
    required String subject,
    required String teacherName,
    String? sessionType,
    String? dayOfWeek,
  }) {
    String actual = '';
    switch (clause.field) {
      case RuleField.meetingTitle:
        actual = title;
        break;
      case RuleField.classSectionCombo:
        actual = classSection;
        break;
      case RuleField.subject:
        actual = subject;
        break;
      case RuleField.teacherHost:
        actual = teacherName;
        break;
      case RuleField.sessionType:
        actual = sessionType ?? 'Regular';
        break;
      case RuleField.scheduledDay:
        actual = dayOfWeek ?? '';
        break;
    }

    final target = clause.value.trim().toLowerCase();
    final cur = actual.trim().toLowerCase();

    switch (clause.operator) {
      case RuleConditionOperator.contains:
        return cur.contains(target);
      case RuleConditionOperator.doesNotContain:
        return !cur.contains(target);
      case RuleConditionOperator.equals:
        return cur == target;
      case RuleConditionOperator.doesNotEqual:
        return cur != target;
      case RuleConditionOperator.startsWith:
        return cur.startsWith(target);
      case RuleConditionOperator.endsWith:
        return cur.endsWith(target);
      case RuleConditionOperator.matchesPattern:
        try {
          return RegExp(target).hasMatch(cur);
        } catch (_) {
          return false;
        }
    }
  }
}


class AnalyticsDataPoint {
  final String date;
  final int views;
  final int downloads;

  AnalyticsDataPoint({required this.date, required this.views, required this.downloads});

  factory AnalyticsDataPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsDataPoint(
      date: json['date'] ?? '',
      views: json['views'] ?? 0,
      downloads: json['downloads'] ?? 0,
    );
  }
}

class RecordingItem {
  final String id;
  final String liveClassId;
  final String title;
  final String? description;
  final String? recordingUrl;
  final String? classId;
  final String? sectionId;
  final String? subjectId;
  final String? teacherId;
  final String classSection;
  final String subjectName;
  final String teacherName;
  final String dateTimeStr;
  final String durationStr;
  final int durationSeconds;
  final int views;
  final int downloadsCount;
  final int fileSizeBytes;
  final int sharedCount;
  final String? mimeType;
  final String? storageKey;
  final String? uploadedBy;
  final String sizeStr;
  final String status;
  final String visibility;
  final String type;
  final List<String> tags;

  RecordingItem({
    required this.id,
    required this.liveClassId,
    required this.title,
    this.description,
    this.recordingUrl,
    this.classId,
    this.sectionId,
    this.subjectId,
    this.teacherId,
    required this.classSection,
    required this.subjectName,
    required this.teacherName,
    required this.dateTimeStr,
    required this.durationStr,
    required this.durationSeconds,
    required this.views,
    this.downloadsCount = 0,
    this.fileSizeBytes = 0,
    this.sharedCount = 0,
    this.mimeType,
    this.storageKey,
    this.uploadedBy,
    required this.sizeStr,
    required this.status,
    required this.visibility,
    this.type = 'Live Class',
    this.tags = const [],
  });

  RecordingItem copyWith({
    String? title,
    String? description,
    String? recordingUrl,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? classSection,
    String? subjectName,
    String? teacherName,
    int? durationSeconds,
    String? durationStr,
    int? views,
    int? downloadsCount,
    int? sharedCount,
    String? status,
    String? visibility,
    List<String>? tags,
  }) {
    return RecordingItem(
      id: id,
      liveClassId: liveClassId,
      title: title ?? this.title,
      description: description ?? this.description,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      classSection: classSection ?? this.classSection,
      subjectName: subjectName ?? this.subjectName,
      teacherName: teacherName ?? this.teacherName,
      dateTimeStr: dateTimeStr,
      durationStr: durationStr ?? this.durationStr,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      views: views ?? this.views,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      fileSizeBytes: fileSizeBytes,
      sharedCount: sharedCount ?? this.sharedCount,
      mimeType: mimeType,
      storageKey: storageKey,
      uploadedBy: uploadedBy,
      sizeStr: sizeStr,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      type: type,
      tags: tags ?? this.tags,
    );
  }

  factory RecordingItem.fromJson(Map<String, dynamic> json) {
    return RecordingItem(
      id: (json['id'] ?? '').toString(),
      liveClassId: (json['live_class_id'] ?? '').toString(),
      title: (json['title'] ?? 'Recorded Lecture').toString(),
      description: json['description']?.toString(),
      recordingUrl: json['recording_url']?.toString(),
      classId: json['class_id']?.toString(),
      sectionId: json['section_id']?.toString(),
      subjectId: json['subject_id']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      classSection: (json['class_section'] ?? 'Class').toString(),
      subjectName: (json['subject_name'] ?? 'General').toString(),
      teacherName: (json['teacher_name'] ?? 'Teacher').toString(),
      dateTimeStr: (json['date_time_str'] ?? '').toString(),
      durationStr: (json['duration_str'] ?? '1 min').toString(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      downloadsCount: (json['downloads_count'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['file_size'] as num?)?.toInt() ?? 0,
      sharedCount: (json['shared_count'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type']?.toString(),
      storageKey: json['storage_key']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      sizeStr: (json['size_str'] ?? '0 B').toString(),
      status: (json['status'] ?? 'Processed').toString(),
      visibility: (json['visibility'] ?? 'CLASS').toString(),
      type: (json['type'] ?? 'Live Class').toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

// ============================================================================
// ATTENDANCE TAB MODELS
// ============================================================================

class AttendanceDashboardData {
  final int totalSessions;
  final int attendanceMarked;
  final double attendanceMarkedPct;
  final int totalParticipants;
  final int presentCount;
  final double presentPct;
  final int absentCount;
  final double absentPct;
  final double avgAttendancePct;
  final double thisWeekPct;
  final String thisWeekChange;

  final AttendanceSessionDetails? sessionDetails;
  final LiveClassAttendanceSummary summary;
  final List<TrendPoint> trend;
  final AutoAttendanceRules autoRules;

  AttendanceDashboardData({
    required this.totalSessions,
    required this.attendanceMarked,
    required this.attendanceMarkedPct,
    required this.totalParticipants,
    required this.presentCount,
    required this.presentPct,
    required this.absentCount,
    required this.absentPct,
    required this.avgAttendancePct,
    required this.thisWeekPct,
    required this.thisWeekChange,
    this.sessionDetails,
    required this.summary,
    required this.trend,
    required this.autoRules,
  });

  factory AttendanceDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final sess = json['session_details'] as Map<String, dynamic>?;
    final sum = json['summary'] as Map<String, dynamic>? ?? {};
    final tr = (json['trend'] as List?)
            ?.map((t) => TrendPoint.fromJson(t))
            .toList() ??
        [];
    final rules = json['auto_rules'] as Map<String, dynamic>? ?? {};

    return AttendanceDashboardData(
      totalSessions: kpis['total_sessions'] ?? 248,
      attendanceMarked: kpis['attendance_marked'] ?? 236,
      attendanceMarkedPct: (kpis['attendance_marked_pct'] ?? 95.2).toDouble(),
      totalParticipants: kpis['total_participants'] ?? 9842,
      presentCount: kpis['present_count'] ?? 9121,
      presentPct: (kpis['present_pct'] ?? 92.7).toDouble(),
      absentCount: kpis['absent_count'] ?? 721,
      absentPct: (kpis['absent_pct'] ?? 7.3).toDouble(),
      avgAttendancePct: (kpis['avg_attendance_pct'] ?? 92.7).toDouble(),
      thisWeekPct: (kpis['this_week_pct'] ?? 92.9).toDouble(),
      thisWeekChange: kpis['this_week_change'] ?? '+1.4%',
      sessionDetails: sess != null ? AttendanceSessionDetails.fromJson(sess) : null,
      summary: LiveClassAttendanceSummary.fromJson(sum),
      trend: tr,
      autoRules: AutoAttendanceRules.fromJson(rules),
    );
  }
}

class AttendanceSessionDetails {
  final String id;
  final String title;
  final String subject;
  final String classSection;
  final String dateStr;
  final String timeStr;
  final String teacherName;
  final String statusBadge;
  final int totalStudents;
  final String attendanceStatus;

  AttendanceSessionDetails({
    required this.id,
    required this.title,
    required this.subject,
    required this.classSection,
    required this.dateStr,
    required this.timeStr,
    required this.teacherName,
    required this.statusBadge,
    required this.totalStudents,
    required this.attendanceStatus,
  });

  factory AttendanceSessionDetails.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionDetails(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Quadratic Equations',
      subject: json['subject'] ?? 'Mathematics',
      classSection: json['class_section'] ?? 'Class 10 - A',
      dateStr: json['date_str'] ?? 'Tue, 21 Jan 2025',
      timeStr: json['time_str'] ?? '08:00 AM - 08:45 AM (45 min)',
      teacherName: json['teacher_name'] ?? 'Instructor',
      statusBadge: json['status_badge'] ?? 'Live Class (Completed)',
      totalStudents: json['total_students'] ?? 42,
      attendanceStatus: json['attendance_status'] ?? 'Marked (92.7%)',
    );
  }
}

class JoinConductKPIs {
  final int liveNow;
  final int todaysClasses;
  final int totalParticipantsLive;
  final int recordingInProgress;
  final int avgClassDurationMin;
  final String classQuality;
  final String systemStatus;

  JoinConductKPIs({
    required this.liveNow,
    required this.todaysClasses,
    required this.totalParticipantsLive,
    required this.recordingInProgress,
    required this.avgClassDurationMin,
    required this.classQuality,
    required this.systemStatus,
  });

  factory JoinConductKPIs.fromJson(Map<String, dynamic> json) {
    return JoinConductKPIs(
      liveNow: json['live_now'] ?? 1,
      todaysClasses: json['todays_classes'] ?? 1,
      totalParticipantsLive: json['total_participants_live'] ?? 43,
      recordingInProgress: json['recording_in_progress'] ?? 1,
      avgClassDurationMin: json['avg_class_duration_min'] ?? 45,
      classQuality: json['class_quality'] ?? 'Excellent (98%)',
      systemStatus: json['system_status'] ?? 'Online',
    );
  }
}

class LiveClassWaitingGuest {
  final String requestId;
  final String guestId;
  final String guestReference;
  final String displayName;
  final String email;
  final String organization;
  final String purpose;
  final String requestStatus;
  final String requestedAtStr;
  final bool isMicMuted;
  final bool isCamOff;

  LiveClassWaitingGuest({
    required this.requestId,
    required this.guestId,
    required this.guestReference,
    required this.displayName,
    this.email = '',
    this.organization = 'External Guest',
    this.purpose = 'Guest Speaker',
    this.requestStatus = 'PENDING',
    this.requestedAtStr = '',
    this.isMicMuted = true,
    this.isCamOff = false,
  });

  factory LiveClassWaitingGuest.fromJson(Map<String, dynamic> json) {
    return LiveClassWaitingGuest(
      requestId: json['request_id'] ?? json['id'] ?? '',
      guestId: json['guest_id'] ?? '',
      guestReference: json['guest_reference'] ?? '',
      displayName: json['display_name'] ?? 'Guest',
      email: json['email'] ?? '',
      organization: json['organization'] ?? 'External Guest',
      purpose: json['purpose'] ?? 'Guest Speaker',
      requestStatus: json['request_status'] ?? 'PENDING',
      requestedAtStr: json['requested_at_str'] ?? '',
      isMicMuted: json['is_mic_muted'] ?? true,
      isCamOff: json['is_cam_off'] ?? false,
    );
  }
}

class ConductClassSessionData {
  final ActiveLiveSession activeSession;
  final JoinConductKPIs stats;
  final List<LiveParticipant> participants;
  final List<ConductUpcomingClassItem> upcomingClasses;
  final List<LiveClassQuestionItem> questions;
  final LiveClassPollItem? activePoll;
  final List<LiveClassPollItem> pollHistory;
  final LiveClassWhiteboardData? whiteboard;
  final List<LiveClassBreakoutRoomItem> breakoutRooms;
  final LiveClassEngagementMetrics engagement;
  final List<LiveClassWaitingGuest> waitingRoom;

  ConductClassSessionData({
    required this.activeSession,
    required this.stats,
    required this.participants,
    required this.upcomingClasses,
    required this.questions,
    this.activePoll,
    this.pollHistory = const [],
    this.whiteboard,
    required this.breakoutRooms,
    required this.engagement,
    this.waitingRoom = const [],
  });

  ConductClassSessionData copyWith({
    ActiveLiveSession? activeSession,
    JoinConductKPIs? stats,
    List<LiveParticipant>? participants,
    List<ConductUpcomingClassItem>? upcomingClasses,
    List<LiveClassQuestionItem>? questions,
    LiveClassPollItem? activePoll,
    List<LiveClassPollItem>? pollHistory,
    LiveClassWhiteboardData? whiteboard,
    List<LiveClassBreakoutRoomItem>? breakoutRooms,
    LiveClassEngagementMetrics? engagement,
    List<LiveClassWaitingGuest>? waitingRoom,
  }) {
    return ConductClassSessionData(
      activeSession: activeSession ?? this.activeSession,
      stats: stats ?? this.stats,
      participants: participants ?? this.participants,
      upcomingClasses: upcomingClasses ?? this.upcomingClasses,
      questions: questions ?? this.questions,
      activePoll: activePoll ?? this.activePoll,
      pollHistory: pollHistory ?? this.pollHistory,
      whiteboard: whiteboard ?? this.whiteboard,
      breakoutRooms: breakoutRooms ?? this.breakoutRooms,
      engagement: engagement ?? this.engagement,
      waitingRoom: waitingRoom ?? this.waitingRoom,
    );
  }

  factory ConductClassSessionData.fromJson(Map<String, dynamic> json) {
    return ConductClassSessionData(
      activeSession: ActiveLiveSession.fromJson(json['active_session'] ?? {}),
      stats: JoinConductKPIs.fromJson(json['stats'] ?? {}),
      participants: (json['participants'] as List? ?? [])
          .map((p) => LiveParticipant.fromJson(p))
          .toList(),
      upcomingClasses: (json['upcoming_classes'] as List? ?? [])
          .map((c) => ConductUpcomingClassItem.fromJson(c))
          .toList(),
      questions: (json['questions'] as List? ?? [])
          .map((q) => LiveClassQuestionItem.fromJson(q))
          .toList(),
      activePoll: json['active_poll'] != null
          ? LiveClassPollItem.fromJson(json['active_poll'])
          : null,
      pollHistory: (json['poll_history'] as List? ?? [])
          .map((p) => LiveClassPollItem.fromJson(p))
          .toList(),
      whiteboard: json['whiteboard'] != null
          ? LiveClassWhiteboardData.fromJson(json['whiteboard'])
          : null,
      breakoutRooms: (json['breakout_rooms'] as List? ?? [])
          .map((r) => LiveClassBreakoutRoomItem.fromJson(r))
          .toList(),
      engagement: LiveClassEngagementMetrics.fromJson(json['engagement'] ?? {}),
      waitingRoom: (json['waiting_room'] as List? ?? [])
          .map((w) => LiveClassWaitingGuest.fromJson(w))
          .toList(),
    );
  }
}

class ConductUpcomingClassItem {
  final String id;
  final String title;
  final String subject;
  final String classSection;
  final String timeStr;
  final String status;
  final bool isNext;

  ConductUpcomingClassItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.classSection,
    required this.timeStr,
    required this.status,
    required this.isNext,
  });

  factory ConductUpcomingClassItem.fromJson(Map<String, dynamic> json) {
    return ConductUpcomingClassItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? 'General',
      classSection: json['class_section'] ?? 'Class 10 - A',
      timeStr: json['time_str'] ?? '09:00 AM - 09:45 AM',
      status: json['status'] ?? 'Scheduled',
      isNext: json['is_next'] ?? false,
    );
  }
}

class LiveClassQuestionReply {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String? authorEmail;
  final String? authorPhone;
  final String answer;
  final String createdAt;

  LiveClassQuestionReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorEmail,
    this.authorPhone,
    required this.answer,
    required this.createdAt,
  });

  factory LiveClassQuestionReply.fromJson(Map<String, dynamic> json) {
    return LiveClassQuestionReply(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name'] ?? 'Instructor',
      authorRole: json['author_role'] ?? 'Teacher',
      authorEmail: json['author_email'],
      authorPhone: json['author_phone'],
      answer: json['answer'] ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author_id': authorId,
    'author_name': authorName,
    'author_role': authorRole,
    'author_email': authorEmail,
    'author_phone': authorPhone,
    'answer': answer,
    'created_at': createdAt,
  };
}

class LiveClassQuestionItem {
  final String id;
  final String authorId;
  final String author;
  final String authorRole;
  final String? authorEmail;
  final String? authorPhone;
  final String question;
  final int upvotes;
  final bool hasUpvoted;
  final String status;
  final bool answered;
  final String? answer;
  final List<LiveClassQuestionReply> answers;
  final bool isPinned;
  final String createdAt;

  LiveClassQuestionItem({
    required this.id,
    this.authorId = '',
    required this.author,
    required this.authorRole,
    this.authorEmail,
    this.authorPhone,
    required this.question,
    required this.upvotes,
    this.hasUpvoted = false,
    required this.status,
    required this.answered,
    this.answer,
    this.answers = const [],
    required this.isPinned,
    required this.createdAt,
  });

  LiveClassQuestionItem copyWith({
    String? id,
    String? authorId,
    String? author,
    String? authorRole,
    String? authorEmail,
    String? authorPhone,
    String? question,
    int? upvotes,
    bool? hasUpvoted,
    String? status,
    bool? answered,
    String? answer,
    List<LiveClassQuestionReply>? answers,
    bool? isPinned,
    String? createdAt,
  }) {
    return LiveClassQuestionItem(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      authorRole: authorRole ?? this.authorRole,
      authorEmail: authorEmail ?? this.authorEmail,
      authorPhone: authorPhone ?? this.authorPhone,
      question: question ?? this.question,
      upvotes: upvotes ?? this.upvotes,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      status: status ?? this.status,
      answered: answered ?? this.answered,
      answer: answer ?? this.answer,
      answers: answers ?? this.answers,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LiveClassQuestionItem.fromJson(Map<String, dynamic> json) {
    List<LiveClassQuestionReply> replies = [];
    if (json['answers'] is List) {
      replies = (json['answers'] as List)
          .map((a) => LiveClassQuestionReply.fromJson(a as Map<String, dynamic>))
          .toList();
    } else if (json['answer'] != null && json['answer'].toString().isNotEmpty) {
      replies = [
        LiveClassQuestionReply(
          id: 'legacy_${json['id']}',
          authorId: json['author_id']?.toString() ?? '',
          authorName: json['author_name'] ?? 'Instructor',
          authorRole: json['author_role'] ?? 'Teacher',
          authorEmail: json['author_email'],
          authorPhone: json['author_phone'],
          answer: json['answer'].toString(),
          createdAt: json['answered_at']?.toString() ?? '',
        )
      ];
    }

    return LiveClassQuestionItem(
      id: json['id'] ?? '',
      authorId: json['author_id']?.toString() ?? '',
      author: json['author'] ?? json['author_name'] ?? 'Student',
      authorRole: json['author_role'] ?? 'Student',
      authorEmail: json['author_email'],
      authorPhone: json['author_phone'],
      question: json['question'] ?? '',
      upvotes: json['upvotes'] ?? 0,
      hasUpvoted: json['has_upvoted'] == true,
      status: json['status'] ?? 'NEW',
      answered: json['answered'] == true || replies.isNotEmpty,
      answer: json['answer'] ?? (replies.isNotEmpty ? replies.last.answer : null),
      answers: replies,
      isPinned: json['is_pinned'] ?? false,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class LiveClassPollItem {
  final String id;
  final String title;
  final String question;
  final String pollType;
  final String status;
  final List<LiveClassPollOption> options;
  final int totalVotes;
  final String? correctOptionId;

  LiveClassPollItem({
    required this.id,
    required this.title,
    required this.question,
    required this.pollType,
    required this.status,
    required this.options,
    required this.totalVotes,
    this.correctOptionId,
  });

  LiveClassPollItem copyWith({
    String? id,
    String? title,
    String? question,
    String? pollType,
    String? status,
    List<LiveClassPollOption>? options,
    int? totalVotes,
    String? correctOptionId,
  }) {
    return LiveClassPollItem(
      id: id ?? this.id,
      title: title ?? this.title,
      question: question ?? this.question,
      pollType: pollType ?? this.pollType,
      status: status ?? this.status,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      correctOptionId: correctOptionId ?? this.correctOptionId,
    );
  }

  factory LiveClassPollItem.fromJson(Map<String, dynamic> json) {
    return LiveClassPollItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Live Poll',
      question: json['question'] ?? '',
      pollType: json['poll_type'] ?? 'single_choice',
      status: json['status'] ?? 'ACTIVE',
      options: (json['options'] as List? ?? [])
          .map((o) => LiveClassPollOption.fromJson(o))
          .toList(),
      totalVotes: json['total_votes'] ?? 0,
      correctOptionId: json['correct_option_id'],
    );
  }
}

class LiveClassPollOption {
  final String id;
  final String text;
  final int votes;
  final double percentage;

  LiveClassPollOption({
    required this.id,
    required this.text,
    required this.votes,
    required this.percentage,
  });

  factory LiveClassPollOption.fromJson(Map<String, dynamic> json) {
    return LiveClassPollOption(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      votes: json['votes'] ?? 0,
      percentage: (json['percentage'] != null)
          ? (json['percentage'] as num).toDouble()
          : 0.0,
    );
  }
}

class LiveClassWhiteboardData {
  final String? id;
  final Map<String, dynamic> canvasData;
  final bool teacherOnlyMode;

  LiveClassWhiteboardData({
    this.id,
    required this.canvasData,
    required this.teacherOnlyMode,
  });

  factory LiveClassWhiteboardData.fromJson(Map<String, dynamic> json) {
    return LiveClassWhiteboardData(
      id: json['id'],
      canvasData: json['canvas_data'] is Map<String, dynamic>
          ? json['canvas_data']
          : {},
      teacherOnlyMode: json['teacher_only_mode'] ?? true,
    );
  }
}

class LiveClassBreakoutRoomItem {
  final String id;
  final String name;
  final int capacity;
  final String status;
  final List<dynamic> participants;

  LiveClassBreakoutRoomItem({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    required this.participants,
  });

  factory LiveClassBreakoutRoomItem.fromJson(Map<String, dynamic> json) {
    return LiveClassBreakoutRoomItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Room',
      capacity: json['capacity'] ?? 6,
      status: json['status'] ?? 'ACTIVE',
      participants: json['participants'] is List ? json['participants'] : [],
    );
  }
}

class LiveClassEngagementMetrics {
  final int overallScore;
  final int activeParticipantsPct;
  final int interactionPct;
  final int pollResponsePct;
  final int contentFocusPct;

  LiveClassEngagementMetrics({
    required this.overallScore,
    required this.activeParticipantsPct,
    required this.interactionPct,
    required this.pollResponsePct,
    required this.contentFocusPct,
  });

  factory LiveClassEngagementMetrics.fromJson(Map<String, dynamic> json) {
    return LiveClassEngagementMetrics(
      overallScore: json['overall_score'] ?? 92,
      activeParticipantsPct: json['active_participants_pct'] ?? 92,
      interactionPct: json['interaction_pct'] ?? 88,
      pollResponsePct: json['poll_response_pct'] ?? 95,
      contentFocusPct: json['content_focus_pct'] ?? 93,
    );
  }
}


// ============================================================================
// JOIN VIA CODE & GUEST JOIN MODELS
// ============================================================================

class RecentMeetingCodeItem {
  final String id;
  final String? sessionId;
  final String meetingCode;
  final String classSubject;
  final String teacherName;
  final bool isStarred;
  final String lastJoinedStr;

  RecentMeetingCodeItem({
    required this.id,
    this.sessionId,
    required this.meetingCode,
    required this.classSubject,
    required this.teacherName,
    required this.isStarred,
    required this.lastJoinedStr,
  });

  factory RecentMeetingCodeItem.fromJson(Map<String, dynamic> json) {
    return RecentMeetingCodeItem(
      id: json['id'] ?? '',
      sessionId: json['session_id'],
      meetingCode: json['meeting_code'] ?? '',
      classSubject: json['class_subject'] ?? 'Class 10 - A\nMathematics',
      teacherName: json['teacher_name'] ?? 'Instructor',
      isStarred: json['is_starred'] ?? false,
      lastJoinedStr: json['last_joined_str'] ?? 'Today, 08:00 AM',
    );
  }

  RecentMeetingCodeItem copyWith({bool? isStarred}) {
    return RecentMeetingCodeItem(
      id: id,
      sessionId: sessionId,
      meetingCode: meetingCode,
      classSubject: classSubject,
      teacherName: teacherName,
      isStarred: isStarred ?? this.isStarred,
      lastJoinedStr: lastJoinedStr,
    );
  }
}

class GuestSessionItem {
  final String id;
  final String classSubject;
  final String subjectName;
  final String topic;
  final String scheduledDateStr;
  final String scheduledTimeStr;
  final String hostName;
  final String roomCode;
  final String status;

  GuestSessionItem({
    required this.id,
    required this.classSubject,
    required this.subjectName,
    required this.topic,
    required this.scheduledDateStr,
    required this.scheduledTimeStr,
    required this.hostName,
    required this.roomCode,
    required this.status,
  });

  factory GuestSessionItem.fromJson(Map<String, dynamic> json) {
    return GuestSessionItem(
      id: json['id'] ?? '',
      classSubject: json['class_subject'] ?? 'Class 10 - A',
      subjectName: json['subject_name'] ?? 'Mathematics',
      topic: json['topic'] ?? 'Quadratic Equations – Guest Lecture',
      scheduledDateStr: json['scheduled_date_str'] ?? 'Tue, 21 Jan 2025',
      scheduledTimeStr: json['scheduled_time_str'] ?? '10:00 AM - 10:45 AM',
      hostName: json['host_name'] ?? 'Instructor',
      roomCode: json['room_code'] ?? '10A-MATH',
      status: json['status'] ?? 'Upcoming',
    );
  }
}

class ValidatedMeetingInfo {
  final String id;
  final String title;
  final String roomCode;
  final String classSection;
  final String subject;
  final String subjectIcon;
  final String topic;
  final String? description;
  final String status;
  final bool isLive;
  final bool waitingRoomEnabled;
  final bool waitingRequired;
  final bool recordingEnabled;
  final String scheduledDate;
  final String scheduledTime;
  final int durationMinutes;
  final String meetingLink;
  final String hostName;
  final String hostRole;

  ValidatedMeetingInfo({
    required this.id,
    required this.title,
    required this.roomCode,
    required this.classSection,
    required this.subject,
    required this.subjectIcon,
    required this.topic,
    this.description,
    required this.status,
    required this.isLive,
    required this.waitingRoomEnabled,
    required this.waitingRequired,
    required this.recordingEnabled,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.durationMinutes,
    required this.meetingLink,
    required this.hostName,
    required this.hostRole,
  });

  factory ValidatedMeetingInfo.fromJson(Map<String, dynamic> json) {
    return ValidatedMeetingInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      roomCode: json['room_code'] ?? '',
      classSection: json['class_section'] ?? 'Class 10 - A',
      subject: json['subject'] ?? 'Mathematics',
      subjectIcon: json['subject_icon'] ?? '📐',
      topic: json['topic'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'live',
      isLive: json['is_live'] ?? false,
      waitingRoomEnabled: json['waiting_room_enabled'] ?? false,
      waitingRequired: json['waiting_required'] ?? false,
      recordingEnabled: json['recording_enabled'] ?? true,
      scheduledDate: json['scheduled_date'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 45,
      meetingLink: json['meeting_link'] ?? '',
      hostName: json['host_name'] ?? 'Teacher',
      hostRole: json['host_role'] ?? 'Teacher',
    );
  }
}

class GuestJoinResponse {
  final bool success;
  final String guestId;
  final String requestId;
  final String guestReference;
  final String displayName;
  final String approvalStatus;
  final String sessionId;
  final bool requiresWaitingRoom;
  final String message;

  GuestJoinResponse({
    required this.success,
    required this.guestId,
    required this.requestId,
    required this.guestReference,
    required this.displayName,
    required this.approvalStatus,
    required this.sessionId,
    required this.requiresWaitingRoom,
    required this.message,
  });

  factory GuestJoinResponse.fromJson(Map<String, dynamic> json) {
    return GuestJoinResponse(
      success: json['success'] ?? true,
      guestId: json['guest_id'] ?? '',
      requestId: json['request_id'] ?? '',
      guestReference: json['guest_reference'] ?? '',
      displayName: json['display_name'] ?? '',
      approvalStatus: json['approval_status'] ?? 'PENDING',
      sessionId: json['session_id'] ?? '',
      requiresWaitingRoom: json['requires_waiting_room'] ?? true,
      message: json['message'] ?? '',
    );
  }
}

class LiveClassAttendanceSummary {
  final double overallPct;
  final int presentCount;
  final double presentPct;
  final int absentCount;
  final double absentPct;
  final int lateCount;
  final double latePct;
  final int notJoinedCount;
  final double notJoinedPct;

  LiveClassAttendanceSummary({
    required this.overallPct,
    required this.presentCount,
    required this.presentPct,
    required this.absentCount,
    required this.absentPct,
    required this.lateCount,
    required this.latePct,
    required this.notJoinedCount,
    required this.notJoinedPct,
  });

  factory LiveClassAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return LiveClassAttendanceSummary(
      overallPct: (json['overall_pct'] ?? 92.7).toDouble(),
      presentCount: json['present_count'] ?? 39,
      presentPct: (json['present_pct'] ?? 92.7).toDouble(),
      absentCount: json['absent_count'] ?? 3,
      absentPct: (json['absent_pct'] ?? 7.3).toDouble(),
      lateCount: json['late_count'] ?? 0,
      latePct: (json['late_pct'] ?? 0.0).toDouble(),
      notJoinedCount: json['not_joined_count'] ?? 0,
      notJoinedPct: (json['not_joined_pct'] ?? 0.0).toDouble(),
    );
  }
}

class TrendPoint {
  final String date;
  final double pct;

  TrendPoint({required this.date, required this.pct});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      date: json['date'] ?? '',
      pct: (json['pct'] ?? 90.0).toDouble(),
    );
  }
}

class AutoAttendanceRules {
  final bool autoMark75Pct;
  final bool considerJoinLeave;
  final bool includeParticipation;

  AutoAttendanceRules({
    required this.autoMark75Pct,
    required this.considerJoinLeave,
    required this.includeParticipation,
  });

  factory AutoAttendanceRules.fromJson(Map<String, dynamic> json) {
    return AutoAttendanceRules(
      autoMark75Pct: json['auto_mark_75_pct'] ?? true,
      considerJoinLeave: json['consider_join_leave'] ?? true,
      includeParticipation: json['include_participation'] ?? true,
    );
  }
}

class AttendanceItem {
  final String attendanceId;
  final String studentId;
  final String rollNo;
  final String studentName;
  final String status; // 'Present', 'Absent', 'Late', 'Not Joined'
  final String joinTime;
  final String leaveTime;
  final String duration;
  final int participationPct;
  final String remarks;
  final bool manualOverride;
  final String? overrideReason;

  AttendanceItem({
    required this.attendanceId,
    required this.studentId,
    required this.rollNo,
    required this.studentName,
    required this.status,
    required this.joinTime,
    required this.leaveTime,
    required this.duration,
    required this.participationPct,
    required this.remarks,
    required this.manualOverride,
    this.overrideReason,
  });

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      attendanceId: json['attendance_id'] ?? '',
      studentId: json['student_id'] ?? '',
      rollNo: json['roll_no'] ?? '1001',
      studentName: json['student_name'] ?? '',
      status: json['status'] ?? 'Present',
      joinTime: json['join_time'] ?? '-',
      leaveTime: json['leave_time'] ?? '-',
      duration: json['duration'] ?? '-',
      participationPct: json['participation_pct'] ?? 0,
      remarks: json['remarks'] ?? '-',
      manualOverride: json['manual_override'] ?? false,
      overrideReason: json['override_reason'],
    );
  }
}

// ============================================================================
// METADATA DROPDOWNS
// ============================================================================

class MetaDropdownsData {
  final List<ClassDropdownItem> classes;
  final List<SectionDropdownItem> sections;
  final List<SubjectDropdownItem> subjects;
  final List<TeacherDropdownItem> teachers;
  final List<SessionDropdownItem> sessions;
  final List<ClassSubjectMapItem> classSubjects;

  MetaDropdownsData({
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.teachers,
    required this.sessions,
    this.classSubjects = const [],
  });

  factory MetaDropdownsData.fromJson(Map<String, dynamic> json) {
    final cls = (json['classes'] as List?)?.map((c) => ClassDropdownItem.fromJson(c)).toList() ?? [];
    final sec = (json['sections'] as List?)?.map((s) => SectionDropdownItem.fromJson(s)).toList() ?? [];
    final sub = (json['subjects'] as List?)?.map((sb) => SubjectDropdownItem.fromJson(sb)).toList() ?? [];
    final tch = (json['teachers'] as List?)?.map((t) => TeacherDropdownItem.fromJson(t)).toList() ?? [];
    final ses = (json['sessions'] as List?)?.map((se) => SessionDropdownItem.fromJson(se)).toList() ?? [];
    final clssub = (json['class_subjects'] as List?)?.map((cs) => ClassSubjectMapItem.fromJson(cs)).toList() ?? [];

    return MetaDropdownsData(
      classes: cls,
      sections: sec,
      subjects: sub,
      teachers: tch,
      sessions: ses,
      classSubjects: clssub,
    );
  }
}

class ClassSubjectMapItem {
  final String classId;
  final String? sectionId;
  final String subjectId;
  final String subjectName;
  final String subjectIcon;

  ClassSubjectMapItem({
    required this.classId,
    this.sectionId,
    required this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
  });

  factory ClassSubjectMapItem.fromJson(Map<String, dynamic> json) {
    return ClassSubjectMapItem(
      classId: json['class_id'] ?? '',
      sectionId: json['section_id'],
      subjectId: json['subject_id'] ?? '',
      subjectName: json['subject_name'] ?? '',
      subjectIcon: SubjectDropdownItem.sanitizeSubjectIcon(json['subject_icon'], json['subject_name'] ?? ''),
    );
  }
}

class ClassDropdownItem {
  final String id;
  final String name;
  final String? code;

  ClassDropdownItem({required this.id, required this.name, this.code});

  factory ClassDropdownItem.fromJson(Map<String, dynamic> json) {
    return ClassDropdownItem(id: json['id'] ?? '', name: json['name'] ?? '', code: json['code']);
  }
}

class SectionDropdownItem {
  final String id;
  final String classId;
  final String name;
  final String? code;

  SectionDropdownItem({required this.id, required this.classId, required this.name, this.code});

  factory SectionDropdownItem.fromJson(Map<String, dynamic> json) {
    return SectionDropdownItem(
      id: json['id'] ?? '',
      classId: json['class_id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'],
    );
  }
}

class SubjectDropdownItem {
  final String id;
  final String name;
  final String? icon;
  final String? classId;
  final String? className;
  final String? sectionId;

  SubjectDropdownItem({
    required this.id,
    required this.name,
    this.icon,
    this.classId,
    this.className,
    this.sectionId,
  });

  factory SubjectDropdownItem.fromJson(Map<String, dynamic> json) {
    return SubjectDropdownItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: SubjectDropdownItem.sanitizeSubjectIcon(json['icon'], json['name'] ?? ''),
      classId: json['class_id'],
      className: json['class_name'] ?? json['class'],
      sectionId: json['section_id'],
    );
  }

  static String sanitizeSubjectIcon(String? icon, String subjectName) {
    if (icon == null ||
        icon.isEmpty ||
        icon.contains('ð') ||
        icon.contains('') ||
        icon.codeUnits.any((u) => u > 0x10FFFF) ||
        icon.length > 6) {
      final lower = subjectName.toLowerCase();
      if (lower.contains('math')) return '📐';
      if (lower.contains('phys')) return '⚛';
      if (lower.contains('chem')) return '🧪';
      if (lower.contains('bio')) return '🧬';
      if (lower.contains('comp') || lower.contains('code') || lower.contains('tech')) return '💻';
      if (lower.contains('eng') || lower.contains('lit')) return '📖';
      if (lower.contains('sci')) return '🔬';
      if (lower.contains('hist') || lower.contains('geo') || lower.contains('soc')) return '🌍';
      return '📚';
    }
    return icon;
  }
}

class TeacherDropdownItem {
  final String id;
  final String fullName;
  final String? email;
  final String? role;

  TeacherDropdownItem({required this.id, required this.fullName, this.email, this.role});

  String get name => fullName;

  factory TeacherDropdownItem.fromJson(Map<String, dynamic> json) {
    return TeacherDropdownItem(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'Teacher',
    );
  }
}

class SessionDropdownItem {
  final String id;
  final String title;
  final String subjectName;
  final String classSection;
  final String dateStr;
  final String timeStr;

  SessionDropdownItem({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.classSection,
    required this.dateStr,
    required this.timeStr,
  });

  factory SessionDropdownItem.fromJson(Map<String, dynamic> json) {
    return SessionDropdownItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subjectName: json['subject_name'] ?? 'Mathematics',
      classSection: json['class_section'] ?? 'Class 10 - A',
      dateStr: json['date_str'] ?? 'Tue, 21 Jan 2025',
      timeStr: json['time_str'] ?? '08:00 AM - 08:45 AM',
    );
  }
}

// ============================================================================
// MY CLASSES MODELS (Matching Image 4)
// ============================================================================

class MyClassesDashboardData {
  final int myClassesToday;
  final int ongoingLive;
  final int upcoming;
  final int completed;
  final int totalStudents;
  final String teachingDurationToday;
  final TodayClassProgress todayProgress;
  final TeachingSummary teachingSummary;
  final List<WeeklyClassTrendDay> weeklyTrend;

  MyClassesDashboardData({
    required this.myClassesToday,
    required this.ongoingLive,
    required this.upcoming,
    required this.completed,
    required this.totalStudents,
    required this.teachingDurationToday,
    required this.todayProgress,
    required this.teachingSummary,
    required this.weeklyTrend,
  });

  factory MyClassesDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final prog = json['today_progress'] as Map<String, dynamic>? ?? {};
    final sum = json['teaching_summary'] as Map<String, dynamic>? ?? {};
    final trendList = (json['class_trend_week'] as List?)
            ?.map((e) => WeeklyClassTrendDay.fromJson(e))
            .toList() ??
        [];

    return MyClassesDashboardData(
      myClassesToday: kpis['my_classes_today'] ?? 4,
      ongoingLive: kpis['ongoing_live'] ?? 1,
      upcoming: kpis['upcoming'] ?? 2,
      completed: kpis['completed'] ?? 1,
      totalStudents: kpis['total_students'] ?? 170,
      teachingDurationToday: kpis['teaching_duration_today'] ?? '3 h 0 min',
      todayProgress: TodayClassProgress.fromJson(prog),
      teachingSummary: TeachingSummary.fromJson(sum),
      weeklyTrend: trendList,
    );
  }
}

class TodayClassProgress {
  final int totalClasses;
  final int liveCount;
  final double livePct;
  final int upcomingCount;
  final double upcomingPct;
  final int completedCount;
  final double completedPct;

  TodayClassProgress({
    required this.totalClasses,
    required this.liveCount,
    required this.livePct,
    required this.upcomingCount,
    required this.upcomingPct,
    required this.completedCount,
    required this.completedPct,
  });

  factory TodayClassProgress.fromJson(Map<String, dynamic> json) {
    return TodayClassProgress(
      totalClasses: json['total_classes'] ?? 4,
      liveCount: json['live_count'] ?? 1,
      livePct: (json['live_pct'] as num?)?.toDouble() ?? 25.0,
      upcomingCount: json['upcoming_count'] ?? 2,
      upcomingPct: (json['upcoming_pct'] as num?)?.toDouble() ?? 50.0,
      completedCount: json['completed_count'] ?? 1,
      completedPct: (json['completed_pct'] as num?)?.toDouble() ?? 25.0,
    );
  }
}

class TeachingSummary {
  final int totalClasses;
  final String totalDuration;
  final int totalStudents;
  final double avgParticipationPct;

  TeachingSummary({
    required this.totalClasses,
    required this.totalDuration,
    required this.totalStudents,
    required this.avgParticipationPct,
  });

  factory TeachingSummary.fromJson(Map<String, dynamic> json) {
    return TeachingSummary(
      totalClasses: json['total_classes'] ?? 4,
      totalDuration: json['total_duration'] ?? '3 h 0 min',
      totalStudents: json['total_students'] ?? 170,
      avgParticipationPct: (json['avg_participation_pct'] as num?)?.toDouble() ?? 92.7,
    );
  }
}

class WeeklyClassTrendDay {
  final String day;
  final int count;
  final int completed;

  WeeklyClassTrendDay({
    required this.day,
    required this.count,
    required this.completed,
  });

  factory WeeklyClassTrendDay.fromJson(Map<String, dynamic> json) {
    return WeeklyClassTrendDay(
      day: json['day'] ?? '',
      count: json['count'] ?? 0,
      completed: json['completed'] ?? 0,
    );
  }
}

class MyClassItem {
  final String id;
  final String classSection;
  final String? classId;
  final String? sectionId;
  final String? subjectId;
  final String subjectName;
  final String subjectIcon;
  final String topic;
  final String description;
  final String? teacherId;
  final String teacherName;
  final String coTeacherName;
  final String scheduledDateStr;
  final String scheduledTimeStr;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String status;
  final int viewerCount;
  final int maxParticipants;
  final String studentCountStr;
  final int attendancePercentage;
  final String roomCode;
  final String meetingLink;
  final String recordingStatus;
  final bool recordingEnabled;

  MyClassItem({
    required this.id,
    required this.classSection,
    this.classId,
    this.sectionId,
    this.subjectId,
    required this.subjectName,
    required this.subjectIcon,
    required this.topic,
    required this.description,
    this.teacherId,
    required this.teacherName,
    required this.coTeacherName,
    required this.scheduledDateStr,
    required this.scheduledTimeStr,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.viewerCount,
    required this.maxParticipants,
    required this.studentCountStr,
    required this.attendancePercentage,
    required this.roomCode,
    required this.meetingLink,
    required this.recordingStatus,
    required this.recordingEnabled,
  });

  factory MyClassItem.fromJson(Map<String, dynamic> json) {
    return MyClassItem(
      id: json['id'] ?? '',
      classSection: json['class_section'] ?? 'Class 10 - A',
      classId: json['class_id'],
      sectionId: json['section_id'],
      subjectId: json['subject_id'],
      subjectName: json['subject_name'] ?? 'Mathematics',
      subjectIcon: SubjectDropdownItem.sanitizeSubjectIcon(json['subject_icon'], json['subject_name'] ?? 'Mathematics'),
      topic: json['topic'] ?? 'Quadratic Equations – Part 1',
      description: json['description'] ?? '',
      teacherId: json['teacher_id'],
      teacherName: json['teacher_name'] ?? 'Instructor',
      coTeacherName: json['co_teacher_name'] ?? 'Assistant',
      scheduledDateStr: json['scheduled_date_str'] ?? 'Tue, 21 Jan 2025',
      scheduledTimeStr: json['scheduled_time_str'] ?? '08:00 AM - 08:45 AM (45 min)',
      startTime: json['start_time'] ?? '08:00 AM',
      endTime: json['end_time'] ?? '08:45 AM',
      durationMinutes: json['duration_minutes'] ?? 45,
      status: json['status'] ?? 'Scheduled',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 1,
      studentCountStr: json['student_count_str'] ?? '${json['viewer_count'] ?? 0} / ${json['max_participants'] ?? 1}',
      attendancePercentage: json['attendance_percentage'] ?? 93,
      roomCode: json['room_code'] ?? '10A-MATH',
      meetingLink: json['meeting_link'] ?? 'https://meet.edushamiit.com/c/10A-math',
      recordingStatus: json['recording_status'] ?? 'IDLE',
      recordingEnabled: json['recording_enabled'] ?? true,
    );
  }
}

class MyClassDetails {
  final String id;
  final String classSection;
  final String subject;
  final String subjectIcon;
  final String topic;
  final String description;
  final String dateStr;
  final String timeStr;
  final int durationMinutes;
  final String studentsCountStr;
  final int viewerCount;
  final int maxParticipants;
  final String meetingCode;
  final String meetingLink;
  final String hostName;
  final String hostRole;
  final String hostAvatar;
  final String coHostName;
  final String status;
  final bool isLive;
  final bool isRecording;
  final String recordingStatus;
  final String attendanceStatus;

  MyClassDetails({
    required this.id,
    required this.classSection,
    required this.subject,
    required this.subjectIcon,
    required this.topic,
    required this.description,
    required this.dateStr,
    required this.timeStr,
    required this.durationMinutes,
    required this.studentsCountStr,
    required this.viewerCount,
    required this.maxParticipants,
    required this.meetingCode,
    required this.meetingLink,
    required this.hostName,
    required this.hostRole,
    required this.hostAvatar,
    required this.coHostName,
    required this.status,
    required this.isLive,
    required this.isRecording,
    required this.recordingStatus,
    required this.attendanceStatus,
  });

  factory MyClassDetails.fromJson(Map<String, dynamic> json) {
    return MyClassDetails(
      id: json['id'] ?? '',
      classSection: json['class_section'] ?? 'Class 10 - A',
      subject: json['subject'] ?? 'Mathematics',
      subjectIcon: json['subject_icon'] ?? '📐',
      topic: json['topic'] ?? 'Quadratic Equations – Part 1',
      description: json['description'] ?? '',
      dateStr: json['date_str'] ?? 'Tue, 21 Jan 2025',
      timeStr: json['time_str'] ?? '08:00 AM - 08:45 AM (45 min)',
      durationMinutes: json['duration_minutes'] ?? 45,
      studentsCountStr: json['students_count_str'] ?? '${json['viewer_count'] ?? 0} / ${json['max_participants'] ?? 1}',
      viewerCount: (json['viewer_count'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 1,
      meetingCode: json['meeting_code'] ?? '10A-MATH',
      meetingLink: json['meeting_link'] ?? 'https://meet.edushamiit.com/c/10A-math',
      hostName: json['host_name'] ?? 'Instructor',
      hostRole: json['host_role'] ?? 'Teacher',
      hostAvatar: json['host_avatar'] ?? '',
      coHostName: json['co_host_name'] ?? 'Assistant',
      status: json['status'] ?? 'Live',
      isLive: json['is_live'] ?? true,
      isRecording: json['is_recording'] ?? false,
      recordingStatus: json['recording_status'] ?? 'IDLE',
      attendanceStatus: json['attendance_status'] ?? 'Marked (92.7%)',
    );
  }
}


