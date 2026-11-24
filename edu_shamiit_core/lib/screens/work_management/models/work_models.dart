import 'package:intl/intl.dart';

class WorkItemModel {
  final String id;
  final String itemNumber;
  final String title;
  final String description;
  final String workType; // EPIC, STORY, TASK, BUG, ISSUE, HOMEWORK, etc.
  final String priority; // CRITICAL, URGENT, HIGH, MEDIUM, LOW
  final String status; // NEW, ACTIVE, IN_PROGRESS, RESOLVED, COMPLETED, BLOCKED
  final String category;
  final int progressPercentage;
  final double rank;
  final double estimatedHours;
  final double remainingHours;
  final double actualHours;
  final double storyPoints;
  final String? severity;
  final String? reason;
  final String? boardId;
  final String? boardName;
  final String? sprintId;
  final String? startDate;
  final String? dueDate;
  final String? dueDateFmt;
  final String? startDateFmt;
  final String? completedDateStr;
  final bool isOverdue;
  final List<WorkAssigneeModel> assignees;
  final String? reporterName;
  final String? reporterAvatar;
  final int checklistTotal;
  final int checklistCompleted;
  final int commentsCount;
  final int attachmentsCount;
  final List<WorkItemModel> children;
  final List<WorkDependencyModel> dependencies;
  final String? parentId;
  final String? parentCode;
  final String? parentTitle;
  final List<String> labels;
  final List<WorkChecklistModel> checklists;
  final List<WorkAttachmentModel> attachments;
  final List<WorkCommentModel> comments;
  final List<WorkActivityModel> activity;
  final String? teamId;
  final String? teamName;
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
  final String? targetRole;
  final String? assignmentMode;

  const WorkItemModel({
    required this.id,
    required this.itemNumber,
    required this.title,
    this.description = '',
    required this.workType,
    required this.priority,
    required this.status,
    this.category = 'General',
    this.progressPercentage = 0,
    this.rank = 1000.0,
    this.estimatedHours = 0.0,
    this.remainingHours = 0.0,
    this.actualHours = 0.0,
    this.storyPoints = 0.0,
    this.severity = 'Medium',
    this.reason,
    this.boardId,
    this.boardName,
    this.sprintId,
    this.startDate,
    this.dueDate,
    this.dueDateFmt,
    this.startDateFmt,
    this.completedDateStr,
    this.isOverdue = false,
    this.assignees = const [],
    this.reporterName,
    this.reporterAvatar,
    this.checklistTotal = 0,
    this.checklistCompleted = 0,
    this.commentsCount = 0,
    this.attachmentsCount = 0,
    this.children = const [],
    this.dependencies = const [],
    this.parentId,
    this.parentCode,
    this.parentTitle,
    this.labels = const [],
    this.checklists = const [],
    this.attachments = const [],
    this.comments = const [],
    this.activity = const [],
    this.teamId,
    this.teamName,
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.targetRole,
    this.assignmentMode,
  });

  factory WorkItemModel.fromJson(Map<String, dynamic> json) {
    List<WorkAssigneeModel> assigneesList = [];
    if (json['assignees'] != null && json['assignees'] is List) {
      assigneesList = (json['assignees'] as List)
          .map((a) => WorkAssigneeModel.fromJson(a))
          .toList();
    } else if (json['assignee_name'] != null && json['assignee_name'].toString().isNotEmpty) {
      assigneesList.add(WorkAssigneeModel(
        id: json['assignee_id']?.toString() ?? '',
        userId: json['assignee_id']?.toString() ?? '',
        fullName: json['assignee_name'].toString(),
        avatarUrl: json['assignee_avatar']?.toString(),
        role: json['assignee_role']?.toString() ?? 'staff',
      ));
    }

    List<WorkItemModel> childrenList = [];
    if (json['children'] != null && json['children'] is List) {
      childrenList = (json['children'] as List)
          .map((c) => WorkItemModel.fromJson(c))
          .toList();
    }

    List<WorkChecklistModel> clList = [];
    if (json['checklists'] != null && json['checklists'] is List) {
      clList = (json['checklists'] as List)
          .map((cl) => WorkChecklistModel.fromJson(cl))
          .toList();
    }

    List<WorkAttachmentModel> atList = [];
    if (json['attachments'] != null && json['attachments'] is List) {
      atList = (json['attachments'] as List)
          .map((at) => WorkAttachmentModel.fromJson(at))
          .toList();
    }

    List<WorkCommentModel> cmList = [];
    if (json['comments'] != null && json['comments'] is List) {
      cmList = (json['comments'] as List)
          .map((cm) => WorkCommentModel.fromJson(cm))
          .toList();
    }

    List<WorkActivityModel> acList = [];
    final rawActivity = json['activity'] ?? json['activity_logs'];
    if (rawActivity is List) {
      acList = rawActivity
          .map((ac) => WorkActivityModel.fromJson(ac))
          .toList();
    }

    List<WorkDependencyModel> depList = [];
    if (json['dependencies'] != null && json['dependencies'] is List) {
      depList = (json['dependencies'] as List)
          .map((d) => WorkDependencyModel.fromJson(d))
          .toList();
    }

    List<String> lbls = [];
    if (json['labels'] != null && json['labels'] is List) {
      lbls = (json['labels'] as List).map((l) => l.toString()).toList();
    }

    return WorkItemModel(
      id: json['id']?.toString() ?? '',
      itemNumber: json['item_number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      workType: json['work_type']?.toString().toUpperCase() ?? 'TASK',
      priority: json['priority']?.toString().toUpperCase() ?? 'MEDIUM',
      status: json['status']?.toString().toUpperCase() ?? 'NEW',
      category: json['category']?.toString() ?? 'General',
      progressPercentage: (json['progress_percentage'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toDouble() ?? 1000.0,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0.0,
      storyPoints: (json['story_points'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity']?.toString() ?? 'Medium',
      reason: json['reason']?.toString(),
      boardId: json['board_id']?.toString(),
      boardName: json['board_name']?.toString() ?? json['board']?.toString(),
      sprintId: json['sprint_id']?.toString(),
      startDate: json['start_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      dueDateFmt: json['due_date_fmt']?.toString() ?? json['due_date_str']?.toString(),
      startDateFmt: json['start_date_fmt']?.toString(),
      completedDateStr: json['completed_date_str']?.toString(),
      isOverdue: json['is_overdue'] == true,
      assignees: assigneesList,
      reporterName: json['reporter_name']?.toString(),
      reporterAvatar: json['reporter_avatar']?.toString(),
      checklistTotal: (json['checklist_total'] as num?)?.toInt() ?? (json['checklists_count'] as num?)?.toInt() ?? clList.length,
      checklistCompleted: (json['checklist_completed'] as num?)?.toInt() ?? (json['checklists_completed_count'] as num?)?.toInt() ?? clList.where((c) => c.isCompleted).length,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? cmList.length,
      attachmentsCount: (json['attachments_count'] as num?)?.toInt() ?? atList.length,
      children: childrenList,
      dependencies: depList,
      parentId: json['parent_id']?.toString(),
      parentCode: json['parent_code']?.toString(),
      parentTitle: json['parent_title']?.toString(),
      labels: lbls,
      checklists: clList,
      attachments: atList,
      comments: cmList,
      activity: acList,
      teamId: json['team_id']?.toString(),
      teamName: json['team_name']?.toString() ?? json['team']?.toString(),
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString() ?? json['class']?.toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString() ?? json['section']?.toString(),
      targetRole: json['target_role']?.toString(),
      assignmentMode: json['assignment_mode']?.toString(),
    );
  }

  WorkItemModel copyWith({
    String? title,
    String? description,
    String? category,
    String? workType,
    String? status,
    int? progressPercentage,
    double? rank,
    String? priority,
    double? estimatedHours,
    double? remainingHours,
    double? actualHours,
    double? storyPoints,
    String? boardId,
    String? boardName,
    String? sprintId,
    List<WorkAssigneeModel>? assignees,
    List<WorkChecklistModel>? checklists,
    List<WorkItemModel>? children,
    String? teamId,
    String? teamName,
    bool clearTeam = false,
    String? classId,
    String? className,
    String? sectionId,
    String? sectionName,
    String? targetRole,
    String? assignmentMode,
    String? parentId,
    String? parentCode,
    String? parentTitle,
  }) {
    return WorkItemModel(
      id: id,
      itemNumber: itemNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      workType: workType ?? this.workType,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      rank: rank ?? this.rank,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      remainingHours: remainingHours ?? this.remainingHours,
      actualHours: actualHours ?? this.actualHours,
      storyPoints: storyPoints ?? this.storyPoints,
      severity: severity,
      reason: reason,
      boardId: boardId ?? this.boardId,
      boardName: boardName ?? this.boardName,
      sprintId: sprintId ?? this.sprintId,
      startDate: startDate,
      dueDate: dueDate,
      dueDateFmt: dueDateFmt,
      startDateFmt: startDateFmt,
      completedDateStr: completedDateStr,
      isOverdue: isOverdue,
      assignees: assignees ?? this.assignees,
      reporterName: reporterName,
      reporterAvatar: reporterAvatar,
      checklistTotal: checklists != null ? checklists.length : checklistTotal,
      checklistCompleted: checklists != null ? checklists.where((c) => c.isCompleted).length : checklistCompleted,
      commentsCount: commentsCount,
      attachmentsCount: attachmentsCount,
      children: children ?? this.children,
      dependencies: dependencies,
      parentId: parentId ?? this.parentId,
      parentCode: parentCode ?? this.parentCode,
      parentTitle: parentTitle ?? this.parentTitle,
      labels: labels,
      checklists: checklists ?? this.checklists,
      attachments: attachments,
      comments: comments,
      activity: activity,
      teamId: clearTeam ? null : (teamId ?? this.teamId),
      teamName: clearTeam ? null : (teamName ?? this.teamName),
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      targetRole: targetRole ?? this.targetRole,
      assignmentMode: assignmentMode ?? this.assignmentMode,
    );
  }
}

class WorkBoardModel {
  final String id;
  final String name;
  final String code;
  final String description;
  final String boardType;
  final bool isActive;

  const WorkBoardModel({
    required this.id,
    required this.name,
    required this.code,
    this.description = '',
    this.boardType = 'KANBAN',
    this.isActive = true,
  });

  factory WorkBoardModel.fromJson(Map<String, dynamic> json) {
    return WorkBoardModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      boardType: json['board_type']?.toString() ?? 'KANBAN',
      isActive: json['is_active'] != false,
    );
  }
}

class WorkSprintModel {
  final String id;
  final String name;
  final int sprintNumber;
  final String goal;
  final String status;
  final String? teamId;
  final String teamName;
  final String? boardId;
  final String? boardName;
  final String startDateFmt;
  final String endDateFmt;
  final String? startDate;
  final String? endDate;
  final int? _durationDays;
  final double capacityHours;
  final double totalPoints;
  final String? ownerName;
  final String capacityUnit;
  final int workingDays;
  final double workingHoursPerDay;
  final String color;
  final int totalItems;
  final int completedItems;

  const WorkSprintModel({
    required this.id,
    required this.name,
    this.sprintNumber = 1,
    this.goal = '',
    this.status = 'PLANNED',
    this.teamId,
    this.teamName = 'All Teams',
    this.boardId,
    this.boardName,
    this.startDateFmt = '',
    this.endDateFmt = '',
    this.startDate,
    this.endDate,
    int? durationDays,
    this.capacityHours = 160.0,
    this.totalPoints = 0.0,
    this.ownerName,
    this.capacityUnit = 'HOURS',
    this.workingDays = 10,
    this.workingHoursPerDay = 8.0,
    this.color = '#2563EB',
    this.totalItems = 0,
    this.completedItems = 0,
  }) : _durationDays = durationDays;

  double get progressPercentage =>
      totalItems > 0 ? ((completedItems / totalItems) * 100).clamp(0.0, 100.0) : 0.0;

  int get durationDays => computedDurationDays;

  int get computedDurationDays {
    if (startDate != null && endDate != null && startDate!.isNotEmpty && endDate!.isNotEmpty) {
      final s = DateTime.tryParse(startDate!);
      final e = DateTime.tryParse(endDate!);
      if (s != null && e != null) {
        final sDate = DateTime(s.year, s.month, s.day);
        final eDate = DateTime(e.year, e.month, e.day);
        final diff = eDate.difference(sDate).inDays + 1;
        if (diff > 0) return diff;
      }
    }
    if (startDateFmt.isNotEmpty && endDateFmt.isNotEmpty) {
      try {
        final df = DateFormat('MMM dd, yyyy');
        final s = df.parse(startDateFmt.trim());
        final e = df.parse(endDateFmt.trim());
        final diff = e.difference(s).inDays + 1;
        if (diff > 0) return diff;
      } catch (_) {}
    }
    return (_durationDays != null && _durationDays! > 0) ? _durationDays! : 14;
  }

  String get displayLabel {
    final s = status.toUpperCase();
    if (s == 'ACTIVE') return '$name (Active)';
    if (s == 'PLANNED') return '$name (Planned)';
    if (s == 'COMPLETED') return '$name (Completed)';
    if (s == 'CLOSED') return '$name (Closed)';
    return '$name ($status)';
  }

  factory WorkSprintModel.fromJson(Map<String, dynamic> json) {
    int duration = (json['duration_days'] as num?)?.toInt() ?? 0;
    final sStr = json['start_date']?.toString();
    final eStr = json['end_date']?.toString();
    if (sStr != null && eStr != null && sStr.isNotEmpty && eStr.isNotEmpty) {
      final s = DateTime.tryParse(sStr);
      final e = DateTime.tryParse(eStr);
      if (s != null && e != null) {
        final sDate = DateTime(s.year, s.month, s.day);
        final eDate = DateTime(e.year, e.month, e.day);
        final diff = eDate.difference(sDate).inDays + 1;
        if (diff > 0) duration = diff;
      }
    }
    if (duration <= 0) {
      final sFmt = json['start_date_fmt']?.toString() ?? '';
      final eFmt = json['end_date_fmt']?.toString() ?? '';
      if (sFmt.isNotEmpty && eFmt.isNotEmpty) {
        try {
          final df = DateFormat('MMM dd, yyyy');
          final s = df.parse(sFmt.trim());
          final e = df.parse(eFmt.trim());
          final diff = e.difference(s).inDays + 1;
          if (diff > 0) duration = diff;
        } catch (_) {}
      }
    }
    if (duration <= 0) duration = 14;

    return WorkSprintModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sprintNumber: (json['sprint_number'] as num?)?.toInt() ?? 1,
      goal: json['goal']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'PLANNED',
      teamId: json['team_id']?.toString(),
      teamName: json['team_name']?.toString() ?? 'All Teams',
      boardId: json['board_id']?.toString(),
      boardName: json['board_name']?.toString() ?? json['board']?.toString(),
      startDateFmt: json['start_date_fmt']?.toString() ?? '',
      endDateFmt: json['end_date_fmt']?.toString() ?? '',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      durationDays: duration,
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 160.0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0.0,
      ownerName: json['owner_name']?.toString(),
      capacityUnit: json['capacity_unit']?.toString() ?? 'HOURS',
      workingDays: (json['working_days'] as num?)?.toInt() ?? 10,
      workingHoursPerDay: (json['working_hours_per_day'] as num?)?.toDouble() ?? 8.0,
      color: json['color']?.toString() ?? '#2563EB',
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      completedItems: (json['completed_items'] as num?)?.toInt() ?? 0,
    );
  }

  WorkSprintModel copyWith({
    String? id,
    String? name,
    int? sprintNumber,
    String? goal,
    String? status,
    String? teamId,
    String? teamName,
    String? boardId,
    String? boardName,
    String? startDateFmt,
    String? endDateFmt,
    String? startDate,
    String? endDate,
    int? durationDays,
    double? capacityHours,
    double? totalPoints,
    String? ownerName,
    String? capacityUnit,
    int? workingDays,
    double? workingHoursPerDay,
    String? color,
    int? totalItems,
    int? completedItems,
  }) {
    return WorkSprintModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sprintNumber: sprintNumber ?? this.sprintNumber,
      goal: goal ?? this.goal,
      status: status ?? this.status,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      boardId: boardId ?? this.boardId,
      boardName: boardName ?? this.boardName,
      startDateFmt: startDateFmt ?? this.startDateFmt,
      endDateFmt: endDateFmt ?? this.endDateFmt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      capacityHours: capacityHours ?? this.capacityHours,
      totalPoints: totalPoints ?? this.totalPoints,
      ownerName: ownerName ?? this.ownerName,
      capacityUnit: capacityUnit ?? this.capacityUnit,
      workingDays: workingDays ?? this.workingDays,
      workingHoursPerDay: workingHoursPerDay ?? this.workingHoursPerDay,
      color: color ?? this.color,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
    );
  }
}

class SprintMemberModel {
  final String userId;
  final String fullName;
  final String? email;
  final String role;
  final String? avatarUrl;
  final String? department;
  final double availableHours;
  final int assignedItemsCount;
  final double plannedHours;
  final double completedHours;
  final double remainingHours;
  final int workloadPct;

  const SprintMemberModel({
    required this.userId,
    required this.fullName,
    this.email,
    this.role = 'Member',
    this.avatarUrl,
    this.department,
    this.availableHours = 80.0,
    this.assignedItemsCount = 0,
    this.plannedHours = 0.0,
    this.completedHours = 0.0,
    this.remainingHours = 0.0,
    this.workloadPct = 0,
  });

  factory SprintMemberModel.fromJson(Map<String, dynamic> json) {
    return SprintMemberModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Member',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'Member',
      avatarUrl: json['avatar_url']?.toString(),
      department: json['department']?.toString(),
      availableHours: (json['available_hours'] as num?)?.toDouble() ?? 80.0,
      assignedItemsCount: (json['assigned_items_count'] as num?)?.toInt() ?? 0,
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 0.0,
      completedHours: (json['completed_hours'] as num?)?.toDouble() ?? 0.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 0.0,
      workloadPct: (json['workload_pct'] as num?)?.toInt() ?? 0,
    );
  }
}

class SprintBlockerModel {
  final String id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String? expectedResolutionDate;
  final String? ownerId;
  final String? ownerName;
  final String? workItemId;
  final String? workItemNumber;
  final String? workItemTitle;
  final String? createdAt;

  const SprintBlockerModel({
    required this.id,
    required this.title,
    this.description = '',
    this.severity = 'HIGH',
    this.status = 'OPEN',
    this.expectedResolutionDate,
    this.ownerId,
    this.ownerName,
    this.workItemId,
    this.workItemNumber,
    this.workItemTitle,
    this.createdAt,
  });

  factory SprintBlockerModel.fromJson(Map<String, dynamic> json) {
    return SprintBlockerModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      severity: json['severity']?.toString().toUpperCase() ?? 'HIGH',
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      expectedResolutionDate: json['expected_resolution_date']?.toString(),
      ownerId: json['owner_id']?.toString(),
      ownerName: json['owner_name']?.toString(),
      workItemId: json['work_item_id']?.toString(),
      workItemNumber: json['work_item_number']?.toString(),
      workItemTitle: json['work_item_title']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class SprintRetroEntryModel {
  final String id;
  final String content;
  final int votes;
  final String? createdByName;
  final String category;

  const SprintRetroEntryModel({
    required this.id,
    required this.content,
    this.votes = 0,
    this.createdByName,
    this.category = 'WENT_WELL',
  });

  factory SprintRetroEntryModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroEntryModel(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      createdByName: json['created_by_name']?.toString(),
      category: json['category']?.toString().toUpperCase() ?? 'WENT_WELL',
    );
  }
}

class SprintActionItemModel {
  final String id;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String? dueDate;
  final String? ownerName;

  const SprintActionItemModel({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'MEDIUM',
    this.status = 'OPEN',
    this.dueDate,
    this.ownerName,
  });

  factory SprintActionItemModel.fromJson(Map<String, dynamic> json) {
    return SprintActionItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString().toUpperCase() ?? 'MEDIUM',
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      dueDate: json['due_date']?.toString(),
      ownerName: json['owner_name']?.toString(),
    );
  }
}

class WorkAssigneeModel {
  final String id;
  final String userId;
  final String fullName;
  final String role;
  final String? email;
  final String? department;
  final String? className;
  final String? sectionName;
  final String? rollNumber;
  final String? avatarUrl;
  final String roleType;

  const WorkAssigneeModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.role = 'staff',
    this.email,
    this.department,
    this.className,
    this.sectionName,
    this.rollNumber,
    this.avatarUrl,
    this.roleType = 'PRIMARY',
  });

  factory WorkAssigneeModel.fromJson(Map<String, dynamic> json) {
    return WorkAssigneeModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Team Member',
      role: json['role']?.toString() ?? 'staff',
      email: json['email']?.toString(),
      department: json['department']?.toString(),
      className: json['class_name']?.toString() ?? json['class']?.toString(),
      sectionName: json['section_name']?.toString() ?? json['section']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      roleType: json['role_type']?.toString() ?? 'PRIMARY',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'role': role,
      'email': email,
      'department': department,
      'class_name': className,
      'section_name': sectionName,
      'roll_number': rollNumber,
      'avatar_url': avatarUrl,
      'role_type': roleType,
    };
  }
}

class WorkAcademicSectionModel {
  final String id;
  final String name;
  final String? code;

  const WorkAcademicSectionModel({
    required this.id,
    required this.name,
    this.code,
  });

  factory WorkAcademicSectionModel.fromJson(Map<String, dynamic> json) {
    return WorkAcademicSectionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
    );
  }
}

class WorkAcademicClassModel {
  final String id;
  final String name;
  final String? code;
  final List<WorkAcademicSectionModel> sections;

  const WorkAcademicClassModel({
    required this.id,
    required this.name,
    this.code,
    this.sections = const [],
  });

  factory WorkAcademicClassModel.fromJson(Map<String, dynamic> json) {
    final rawSec = json['sections'];
    List<WorkAcademicSectionModel> secList = [];
    if (rawSec is List) {
      secList = rawSec.map((e) => WorkAcademicSectionModel.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return WorkAcademicClassModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      sections: secList,
    );
  }
}

class WorkChecklistModel {
  final String id;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const WorkChecklistModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  factory WorkChecklistModel.fromJson(Map<String, dynamic> json) {
    return WorkChecklistModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      isCompleted: json['is_completed'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  WorkChecklistModel copyWith({bool? isCompleted}) {
    return WorkChecklistModel(
      id: id,
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder,
    );
  }
}

class WorkAttachmentModel {
  final String id;
  final String fileName;
  final String fileUrl;
  final int fileSizeBytes;
  final String fileType;
  final String fileSizeFmt;
  final String? uploadedByName;
  final String? createdAt;

  const WorkAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.fileSizeBytes = 0,
    this.fileType = 'pdf',
    this.fileSizeFmt = '1.0 MB',
    this.uploadedByName,
    this.createdAt,
  });

  factory WorkAttachmentModel.fromJson(Map<String, dynamic> json) {
    return WorkAttachmentModel(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      fileUrl: json['file_url']?.toString() ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      fileType: json['file_type']?.toString() ?? 'pdf',
      fileSizeFmt: json['file_size_fmt']?.toString() ?? '1.2 MB',
      uploadedByName: json['uploaded_by_name']?.toString() ?? 'User',
      createdAt: json['created_at']?.toString(),
    );
  }
}

class WorkCommentModel {
  final String id;
  final String commentText;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String createdAt;
  final String timeAgo;

  const WorkCommentModel({
    required this.id,
    required this.commentText,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    this.createdAt = '',
    this.timeAgo = 'Recently',
  });

  factory WorkCommentModel.fromJson(Map<String, dynamic> json) {
    return WorkCommentModel(
      id: json['id']?.toString() ?? '',
      commentText: json['comment_text']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Staff Member',
      authorAvatar: json['author_avatar']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? 'Recently',
    );
  }
}

class WorkActivityModel {
  final String id;
  final String actionType;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;
  final String message;
  final String actorName;
  final String? actorAvatar;
  final String createdAt;
  final String timeAgo;

  const WorkActivityModel({
    required this.id,
    required this.actionType,
    this.fieldName,
    this.oldValue,
    this.newValue,
    required this.message,
    required this.actorName,
    this.actorAvatar,
    this.createdAt = '',
    this.timeAgo = 'Recently',
  });

  factory WorkActivityModel.fromJson(Map<String, dynamic> json) {
    return WorkActivityModel(
      id: json['id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? '',
      fieldName: json['field_name']?.toString(),
      oldValue: json['old_value']?.toString(),
      newValue: json['new_value']?.toString(),
      message: json['message']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'System',
      actorAvatar: json['actor_avatar']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? 'Recently',
    );
  }
}

class WorkDependencyModel {
  final String id;
  final String linkedItemId;
  final String itemNumber;
  final String title;
  final String workType;
  final String status;
  final String priority;
  final String dependencyType; // RELATED, PARENT, CHILD, BLOCKS, BLOCKED_BY

  const WorkDependencyModel({
    required this.id,
    required this.linkedItemId,
    required this.itemNumber,
    required this.title,
    required this.workType,
    required this.status,
    this.priority = 'MEDIUM',
    this.dependencyType = 'RELATED',
  });

  factory WorkDependencyModel.fromJson(Map<String, dynamic> json) {
    return WorkDependencyModel(
      id: json['id']?.toString() ?? '',
      linkedItemId: json['linked_item_id']?.toString() ?? '',
      itemNumber: json['item_number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      workType: json['work_type']?.toString().toUpperCase() ?? 'TASK',
      status: json['status']?.toString().toUpperCase() ?? 'NEW',
      priority: json['priority']?.toString().toUpperCase() ?? 'MEDIUM',
      dependencyType: json['dependency_type']?.toString().toUpperCase() ?? 'RELATED',
    );
  }
}

class KanbanColumnModel {
  final String statusKey;
  final String name;
  final String color;
  final int count;
  final List<WorkItemModel> items;

  const KanbanColumnModel({
    required this.statusKey,
    required this.name,
    required this.color,
    required this.count,
    required this.items,
  });

  factory KanbanColumnModel.fromJson(Map<String, dynamic> json) {
    List<WorkItemModel> itemsList = [];
    if (json['items'] != null && json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((i) => WorkItemModel.fromJson(i))
          .toList();
    }
    return KanbanColumnModel(
      statusKey: json['status_key']?.toString().toUpperCase() ?? 'NEW',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#2563EB',
      count: (json['count'] as num?)?.toInt() ?? itemsList.length,
      items: itemsList,
    );
  }

  KanbanColumnModel copyWith({List<WorkItemModel>? items, int? count}) {
    return KanbanColumnModel(
      statusKey: statusKey,
      name: name,
      color: color,
      count: count ?? (items != null ? items.length : this.count),
      items: items ?? this.items,
    );
  }
}

class BurndownPointModel {
  final String label;
  final double ideal;
  final double remaining;

  double get idealRemaining => ideal;
  double get actualRemaining => remaining;

  const BurndownPointModel({
    required this.label,
    required this.ideal,
    required this.remaining,
  });

  factory BurndownPointModel.fromJson(Map<String, dynamic> json) {
    return BurndownPointModel(
      label: json['label']?.toString() ?? json['date_label']?.toString() ?? '',
      ideal: (json['ideal'] ?? json['ideal_remaining'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] ?? json['actual_remaining'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BacklogEpicModel {
  final String id;
  final String itemNumber;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String category;
  final String? teamName;
  final double estimatedHours;
  final double storyPoints;
  final String? startDate;
  final String? dueDate;
  final int count;
  final bool isSelected;

  const BacklogEpicModel({
    required this.id,
    required this.itemNumber,
    required this.title,
    this.description = '',
    this.status = 'NEW',
    this.priority = 'MEDIUM',
    this.category = 'General',
    this.teamName,
    this.estimatedHours = 0.0,
    this.storyPoints = 0.0,
    this.startDate,
    this.dueDate,
    this.count = 0,
    this.isSelected = false,
  });

  factory BacklogEpicModel.fromJson(Map<String, dynamic> json) {
    return BacklogEpicModel(
      id: json['id']?.toString() ?? '',
      itemNumber: json['item_number']?.toString() ?? json['epic_number']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'NEW',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      category: json['category']?.toString() ?? 'General',
      teamName: json['team_name']?.toString(),
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0.0,
      storyPoints: (json['story_points'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      count: (json['items_count'] as num?)?.toInt() ??
          (json['count'] as num?)?.toInt() ??
          (json['total_items_count'] as num?)?.toInt() ??
          (json['total_items'] as num?)?.toInt() ??
          0,
      isSelected: json['is_selected'] == true,
    );
  }

  BacklogEpicModel copyWith({
    String? id,
    String? itemNumber,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? category,
    String? teamName,
    double? estimatedHours,
    double? storyPoints,
    String? startDate,
    String? dueDate,
    int? count,
    bool? isSelected,
  }) {
    return BacklogEpicModel(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      teamName: teamName ?? this.teamName,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      storyPoints: storyPoints ?? this.storyPoints,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      count: count ?? this.count,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  WorkItemModel toWorkItem() {
    return WorkItemModel(
      id: id,
      itemNumber: itemNumber,
      title: title,
      description: description,
      workType: 'EPIC',
      status: status,
      priority: priority,
      category: category,
      teamName: teamName,
      estimatedHours: estimatedHours,
      storyPoints: storyPoints,
      startDate: startDate,
      dueDate: dueDate,
      startDateFmt: startDate,
      dueDateFmt: dueDate,
      children: const [],
      assignees: const [],
    );
  }
}

class SprintCapacityTeamModel {
  final String id;
  final String name;
  final String? department;
  final String icon;
  final String? leadName;
  final int membersCount;
  final bool isSelected;

  const SprintCapacityTeamModel({
    required this.id,
    required this.name,
    this.department,
    this.icon = 'groups',
    this.leadName,
    this.membersCount = 0,
    this.isSelected = false,
  });

  factory SprintCapacityTeamModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityTeamModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString(),
      icon: json['icon']?.toString() ?? 'groups',
      leadName: json['lead_name']?.toString(),
      membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
      isSelected: json['is_selected'] == true,
    );
  }
}

class SprintCapacityKpisModel {
  final int teamMembers;
  final double totalCapacityHours;
  final double plannedWorkHours;
  final double actualWorkHours;
  final double remainingCapacityHours;
  final double utilizationPct;
  final double overAllocationHours;
  final int overloadedMembersCount;

  const SprintCapacityKpisModel({
    this.teamMembers = 0,
    this.totalCapacityHours = 0.0,
    this.plannedWorkHours = 0.0,
    this.actualWorkHours = 0.0,
    this.remainingCapacityHours = 0.0,
    this.utilizationPct = 0.0,
    this.overAllocationHours = 0.0,
    this.overloadedMembersCount = 0,
  });

  factory SprintCapacityKpisModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityKpisModel(
      teamMembers: (json['team_members'] as num?)?.toInt() ?? 0,
      totalCapacityHours: (json['total_capacity_hours'] as num?)?.toDouble() ?? 0.0,
      plannedWorkHours: (json['planned_work_hours'] as num?)?.toDouble() ?? 0.0,
      actualWorkHours: (json['actual_work_hours'] as num?)?.toDouble() ?? 0.0,
      remainingCapacityHours: (json['remaining_capacity_hours'] as num?)?.toDouble() ?? 0.0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
      overAllocationHours: (json['over_allocation_hours'] as num?)?.toDouble() ?? 0.0,
      overloadedMembersCount: (json['overloaded_members_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SprintCapacityMemberModel {
  final String id;
  final String userId;
  final String fullName;
  final String? email;
  final String role;
  final String? avatarUrl;
  final String? department;
  final String? teamId;
  final String? teamName;
  final double capacityHours;
  final double plannedHours;
  final double actualHours;
  final double remainingHours;
  final double utilizationPct;
  final int workItemsCount;
  final String status;
  final double dailyWorkingHours;
  final int workingDays;
  final double daysOff;
  final double? overrideValue;
  final String? overrideReason;
  final String? notes;

  const SprintCapacityMemberModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.role = 'Member',
    this.avatarUrl,
    this.department,
    this.teamId,
    this.teamName,
    this.capacityHours = 40.0,
    this.plannedHours = 0.0,
    this.actualHours = 0.0,
    this.remainingHours = 0.0,
    this.utilizationPct = 0.0,
    this.workItemsCount = 0,
    this.status = 'Balanced',
    this.dailyWorkingHours = 8.0,
    this.workingDays = 10,
    this.daysOff = 0.0,
    this.overrideValue,
    this.overrideReason,
    this.notes,
  });

  factory SprintCapacityMemberModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityMemberModel(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Member',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'Member',
      avatarUrl: json['avatar_url']?.toString(),
      department: json['department']?.toString(),
      teamId: json['team_id']?.toString(),
      teamName: json['team_name']?.toString(),
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 40.0,
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 0.0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
      workItemsCount: (json['work_items_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Balanced',
      dailyWorkingHours: (json['daily_working_hours'] as num?)?.toDouble() ?? 8.0,
      workingDays: (json['working_days'] as num?)?.toInt() ?? 10,
      daysOff: (json['days_off'] as num?)?.toDouble() ?? 0.0,
      overrideValue: (json['override_value'] as num?)?.toDouble(),
      overrideReason: json['override_reason']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class SprintCapacityDailyPointModel {
  final String fullDate;
  final String dateFmt;
  final double capacityHours;
  final double plannedHours;
  final double actualHours;
  final double idealRemaining;
  final double remainingHours;
  final double completedHours;

  const SprintCapacityDailyPointModel({
    required this.fullDate,
    required this.dateFmt,
    required this.capacityHours,
    required this.plannedHours,
    required this.actualHours,
    this.idealRemaining = 0.0,
    this.remainingHours = 0.0,
    this.completedHours = 0.0,
  });

  factory SprintCapacityDailyPointModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityDailyPointModel(
      fullDate: json['full_date']?.toString() ?? '',
      dateFmt: json['date_fmt']?.toString() ?? '',
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 0.0,
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 0.0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0.0,
      idealRemaining: (json['ideal_remaining'] as num?)?.toDouble() ?? 0.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 0.0,
      completedHours: (json['completed_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SprintCapacityUtilizationModel {
  final double plannedHours;
  final double availableHours;
  final double totalCapacityHours;
  final double plannedPct;
  final double availablePct;

  const SprintCapacityUtilizationModel({
    this.plannedHours = 0.0,
    this.availableHours = 0.0,
    this.totalCapacityHours = 0.0,
    this.plannedPct = 0.0,
    this.availablePct = 0.0,
  });

  factory SprintCapacityUtilizationModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityUtilizationModel(
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 0.0,
      availableHours: (json['available_hours'] as num?)?.toDouble() ?? 0.0,
      totalCapacityHours: (json['total_capacity_hours'] as num?)?.toDouble() ?? 0.0,
      plannedPct: (json['planned_pct'] as num?)?.toDouble() ?? 0.0,
      availablePct: (json['available_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SprintCapacitySummaryModel {
  final String totalTeamCapacity;
  final String plannedCommittedWork;
  final String actualWorkCompleted;
  final String remainingCapacity;
  final String utilization;
  final String overAllocation;

  const SprintCapacitySummaryModel({
    this.totalTeamCapacity = '0 h',
    this.plannedCommittedWork = '0 h',
    this.actualWorkCompleted = '0 h',
    this.remainingCapacity = '0 h',
    this.utilization = '0%',
    this.overAllocation = '0 h',
  });

  factory SprintCapacitySummaryModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacitySummaryModel(
      totalTeamCapacity: json['total_team_capacity']?.toString() ?? '0 h',
      plannedCommittedWork: json['planned_committed_work']?.toString() ?? '0 h',
      actualWorkCompleted: json['actual_work_completed']?.toString() ?? '0 h',
      remainingCapacity: json['remaining_capacity']?.toString() ?? '0 h',
      utilization: json['utilization']?.toString() ?? '0%',
      overAllocation: json['over_allocation']?.toString() ?? '0 h',
    );
  }
}

class SprintCapacityInsightModel {
  final String type;
  final String icon;
  final String text;

  const SprintCapacityInsightModel({
    required this.type,
    required this.icon,
    required this.text,
  });

  factory SprintCapacityInsightModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityInsightModel(
      type: json['type']?.toString() ?? 'INFO',
      icon: json['icon']?.toString() ?? 'info',
      text: json['text']?.toString() ?? '',
    );
  }
}

class SprintCapacityPaginationModel {
  final int page;
  final int limit;
  final int totalMembers;
  final int totalPages;

  const SprintCapacityPaginationModel({
    this.page = 1,
    this.limit = 10,
    this.totalMembers = 0,
    this.totalPages = 1,
  });

  factory SprintCapacityPaginationModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacityPaginationModel(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

class SprintCapacitySprintItemModel {
  final String id;
  final String name;
  final String status;
  final String startDate;
  final String endDate;
  final bool isSelected;

  const SprintCapacitySprintItemModel({
    required this.id,
    required this.name,
    this.status = 'ACTIVE',
    this.startDate = '',
    this.endDate = '',
    this.isSelected = false,
  });

  factory SprintCapacitySprintItemModel.fromJson(Map<String, dynamic> json) {
    return SprintCapacitySprintItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      isSelected: json['is_selected'] == true || json['is_current'] == true,
    );
  }
}

class SprintCapacityDashboardModel {
  final String sprintId;
  final String sprintName;
  final String sprintDuration;
  final int sprintDays;
  final int workingDays;
  final String boardName;
  final String selectedTeam;
  final String? selectedTeamId;
  final SprintCapacityKpisModel kpis;
  final List<SprintCapacityTeamModel> teams;
  final List<SprintCapacityMemberModel> members;
  final List<SprintCapacityDailyPointModel> dailyChart;
  final List<SprintCapacityDailyPointModel> burndownChart;
  final List<Map<String, dynamic>> availableRoles;
  final SprintCapacityUtilizationModel utilization;
  final SprintCapacitySummaryModel summary;
  final List<SprintCapacityInsightModel> insights;
  final SprintCapacityPaginationModel pagination;
  final List<SprintCapacitySprintItemModel> sprints;

  const SprintCapacityDashboardModel({
    required this.sprintId,
    required this.sprintName,
    required this.sprintDuration,
    this.sprintDays = 14,
    this.workingDays = 10,
    required this.boardName,
    required this.selectedTeam,
    this.selectedTeamId,
    required this.kpis,
    required this.teams,
    required this.members,
    required this.dailyChart,
    this.burndownChart = const [],
    this.availableRoles = const [],
    required this.utilization,
    required this.summary,
    required this.insights,
    this.pagination = const SprintCapacityPaginationModel(),
    this.sprints = const [],
  });

  SprintCapacityDashboardModel copyWith({
    String? sprintId,
    String? sprintName,
    String? sprintDuration,
    int? sprintDays,
    int? workingDays,
    String? boardName,
    String? selectedTeam,
    String? selectedTeamId,
    SprintCapacityKpisModel? kpis,
    List<SprintCapacityTeamModel>? teams,
    List<SprintCapacityMemberModel>? members,
    List<SprintCapacityDailyPointModel>? dailyChart,
    List<SprintCapacityDailyPointModel>? burndownChart,
    List<Map<String, dynamic>>? availableRoles,
    SprintCapacityUtilizationModel? utilization,
    SprintCapacitySummaryModel? summary,
    List<SprintCapacityInsightModel>? insights,
    SprintCapacityPaginationModel? pagination,
    List<SprintCapacitySprintItemModel>? sprints,
  }) {
    return SprintCapacityDashboardModel(
      sprintId: sprintId ?? this.sprintId,
      sprintName: sprintName ?? this.sprintName,
      sprintDuration: sprintDuration ?? this.sprintDuration,
      sprintDays: sprintDays ?? this.sprintDays,
      workingDays: workingDays ?? this.workingDays,
      boardName: boardName ?? this.boardName,
      selectedTeam: selectedTeam ?? this.selectedTeam,
      selectedTeamId: selectedTeamId ?? this.selectedTeamId,
      kpis: kpis ?? this.kpis,
      teams: teams ?? this.teams,
      members: members ?? this.members,
      dailyChart: dailyChart ?? this.dailyChart,
      burndownChart: burndownChart ?? this.burndownChart,
      availableRoles: availableRoles ?? this.availableRoles,
      utilization: utilization ?? this.utilization,
      summary: summary ?? this.summary,
      insights: insights ?? this.insights,
      pagination: pagination ?? this.pagination,
      sprints: sprints ?? this.sprints,
    );
  }

  factory SprintCapacityDashboardModel.fromJson(Map<String, dynamic> json) {
    final kpisJson = json['kpis'] as Map<String, dynamic>? ?? {};
    final utilJson = json['capacity_utilization'] as Map<String, dynamic>? ?? {};
    final summaryJson = json['capacity_summary'] as Map<String, dynamic>? ?? {};
    final paginationJson = json['pagination'] as Map<String, dynamic>? ?? {};

    final rawDaily = (json['daily_chart'] as List<dynamic>? ?? [])
        .map((d) => SprintCapacityDailyPointModel.fromJson(d as Map<String, dynamic>))
        .toList();
    final rawBurndown = (json['burndown_chart'] as List<dynamic>? ?? [])
        .map((d) => SprintCapacityDailyPointModel.fromJson(d as Map<String, dynamic>))
        .toList();

    return SprintCapacityDashboardModel(
      sprintId: json['sprint_id']?.toString() ?? '',
      sprintName: json['sprint_name']?.toString() ?? 'Sprint',
      sprintDuration: json['sprint_duration']?.toString() ?? '',
      sprintDays: (json['sprint_days'] as num?)?.toInt() ?? 14,
      workingDays: (json['working_days'] as num?)?.toInt() ?? 10,
      boardName: json['board_name']?.toString() ?? 'Work Board',
      selectedTeam: json['selected_team']?.toString() ?? 'All Teams',
      selectedTeamId: json['selected_team_id']?.toString(),
      kpis: SprintCapacityKpisModel.fromJson(kpisJson),
      teams: (json['teams'] as List<dynamic>? ?? [])
          .map((t) => SprintCapacityTeamModel.fromJson(t as Map<String, dynamic>))
          .toList(),
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => SprintCapacityMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      dailyChart: rawDaily,
      burndownChart: rawBurndown.isNotEmpty ? rawBurndown : rawDaily,
      availableRoles: (json['available_roles'] as List<dynamic>? ?? [])
          .map((r) => r is Map<String, dynamic> ? r : {'name': r.toString(), 'label': r.toString()})
          .toList(),
      utilization: SprintCapacityUtilizationModel.fromJson(utilJson),
      summary: SprintCapacitySummaryModel.fromJson(summaryJson),
      insights: (json['insights'] as List<dynamic>? ?? [])
          .map((i) => SprintCapacityInsightModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      pagination: SprintCapacityPaginationModel.fromJson(paginationJson),
      sprints: (json['sprints'] as List<dynamic>? ?? [])
          .map((s) => SprintCapacitySprintItemModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ============================================================================
// ENTERPRISE SPRINT TEAM MANAGEMENT MODELS
// ============================================================================

class TeamKpisModel {
  final int totalTeams;
  final int totalMembers;
  final double totalCapacityHours;
  final double allocatedWorkHours;
  final double capacityUtilizationPct;
  final int activeTeams;
  final int inactiveTeams;

  const TeamKpisModel({
    this.totalTeams = 6,
    this.totalMembers = 42,
    this.totalCapacityHours = 1680.0,
    this.allocatedWorkHours = 1521.0,
    this.capacityUtilizationPct = 90.5,
    this.activeTeams = 6,
    this.inactiveTeams = 0,
  });

  factory TeamKpisModel.fromJson(Map<String, dynamic> json) {
    return TeamKpisModel(
      totalTeams: (json['total_teams'] as num?)?.toInt() ?? 0,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalCapacityHours: (json['total_capacity_hours'] as num?)?.toDouble() ?? 0.0,
      allocatedWorkHours: (json['allocated_work_hours'] as num?)?.toDouble() ?? 0.0,
      capacityUtilizationPct: (json['capacity_utilization_pct'] as num?)?.toDouble() ?? 0.0,
      activeTeams: (json['active_teams'] as num?)?.toInt() ?? 0,
      inactiveTeams: (json['inactive_teams'] as num?)?.toInt() ?? 0,
    );
  }
}

class TeamLeadModel {
  final String? id;
  final String name;
  final String? email;
  final String? avatarUrl;

  const TeamLeadModel({
    this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory TeamLeadModel.fromJson(Map<String, dynamic> json) {
    return TeamLeadModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'Unassigned',
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class TeamMemberItemModel {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String role;
  final String? designation;
  final String? avatarUrl;
  final double capacityHours;
  final double dailyHours;
  final bool isLead;
  final String? joinedAt;

  const TeamMemberItemModel({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    required this.role,
    this.designation,
    this.avatarUrl,
    this.capacityHours = 40.0,
    this.dailyHours = 8.0,
    this.isLead = false,
    this.joinedAt,
  });

  factory TeamMemberItemModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberItemModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Member',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'Developer',
      designation: json['designation']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 40.0,
      dailyHours: (json['daily_hours'] as num?)?.toDouble() ?? 8.0,
      isLead: json['is_lead'] == true,
      joinedAt: json['joined_at']?.toString(),
    );
  }
}

class TeamActivityItemModel {
  final String id;
  final String activityType;
  final String description;
  final String actorName;
  final String createdAt;

  const TeamActivityItemModel({
    required this.id,
    required this.activityType,
    required this.description,
    required this.actorName,
    required this.createdAt,
  });

  factory TeamActivityItemModel.fromJson(Map<String, dynamic> json) {
    return TeamActivityItemModel(
      id: json['id']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? 'UPDATE',
      description: json['description']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'Dr. Rajesh Verma',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class TeamWorkItemModel {
  final String id;
  final String itemKey;
  final String title;
  final String type;
  final String priority;
  final String status;
  final int progressPercentage;
  final String assigneeName;
  final String? assigneeAvatar;
  final String? sprintId;
  final String? sprintName;

  const TeamWorkItemModel({
    required this.id,
    required this.itemKey,
    required this.title,
    required this.type,
    required this.priority,
    required this.status,
    required this.progressPercentage,
    required this.assigneeName,
    this.assigneeAvatar,
    this.sprintId,
    this.sprintName,
  });

  factory TeamWorkItemModel.fromJson(Map<String, dynamic> json) {
    return TeamWorkItemModel(
      id: json['id']?.toString() ?? '',
      itemKey: json['item_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'TASK',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      status: json['status']?.toString() ?? 'NEW',
      progressPercentage: (json['progress_percentage'] as num?)?.toInt() ?? 0,
      assigneeName: json['assignee_name']?.toString() ?? 'Unassigned',
      assigneeAvatar: json['assignee_avatar']?.toString(),
      sprintId: json['sprint_id']?.toString(),
      sprintName: json['sprint_name']?.toString() ?? 'Backlog',
    );
  }
}

class TeamDirectoryItemModel {
  final String id;
  final String name;
  final String teamKey;
  final String department;
  final String description;
  final String icon;
  final String color;
  final String status;
  final bool isActive;
  final List<String> tags;
  final String goal;
  final String? createdAt;
  final String? updatedAt;
  final TeamLeadModel lead;
  final int memberCount;
  final List<TeamMemberItemModel> members;
  final double capacityHours;
  final double plannedHours;
  final double remainingHours;
  final double utilizationPct;

  const TeamDirectoryItemModel({
    required this.id,
    required this.name,
    required this.teamKey,
    required this.department,
    required this.description,
    required this.icon,
    required this.color,
    required this.status,
    required this.isActive,
    required this.tags,
    required this.goal,
    this.createdAt,
    this.updatedAt,
    required this.lead,
    required this.memberCount,
    required this.members,
    required this.capacityHours,
    required this.plannedHours,
    required this.remainingHours,
    required this.utilizationPct,
  });

  factory TeamDirectoryItemModel.fromJson(Map<String, dynamic> json) {
    final leadJson = json['lead'] as Map<String, dynamic>? ?? {};
    final membersList = (json['members'] as List<dynamic>? ?? [])
        .map((m) => TeamMemberItemModel.fromJson(m as Map<String, dynamic>))
        .toList();
    final tagsList = (json['tags'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList();

    return TeamDirectoryItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      teamKey: json['team_key']?.toString() ?? 'DCT',
      department: json['department']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'layers',
      color: json['color']?.toString() ?? '#2563EB',
      status: json['status']?.toString() ?? 'ACTIVE',
      isActive: json['is_active'] != false,
      tags: tagsList,
      goal: json['goal']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      lead: TeamLeadModel.fromJson(leadJson),
      memberCount: (json['member_count'] as num?)?.toInt() ?? membersList.length,
      members: membersList,
      capacityHours: (json['capacity_hours'] as num?)?.toDouble() ?? 280.0,
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 257.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 23.0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 91.8,
    );
  }
}

class TeamDirectoryResponseModel {
  final bool success;
  final String? sprintId;
  final TeamKpisModel kpis;
  final int totalCount;
  final int page;
  final int limit;
  final List<TeamDirectoryItemModel> teams;

  const TeamDirectoryResponseModel({
    required this.success,
    this.sprintId,
    required this.kpis,
    required this.totalCount,
    this.page = 1,
    this.limit = 10,
    required this.teams,
  });

  factory TeamDirectoryResponseModel.fromJson(Map<String, dynamic> json) {
    final kpisJson = json['kpis'] as Map<String, dynamic>? ?? {};
    final teamsList = (json['teams'] as List<dynamic>? ?? [])
        .map((t) => TeamDirectoryItemModel.fromJson(t as Map<String, dynamic>))
        .toList();

    return TeamDirectoryResponseModel(
      success: json['success'] == true,
      sprintId: json['sprint_id']?.toString(),
      kpis: TeamKpisModel.fromJson(kpisJson),
      totalCount: (json['total_count'] as num?)?.toInt() ?? teamsList.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      teams: teamsList,
    );
  }
}

class TeamDetailCapacityModel {
  final double totalCapacityHours;
  final double plannedHours;
  final double remainingHours;
  final double utilizationPct;

  const TeamDetailCapacityModel({
    this.totalCapacityHours = 280.0,
    this.plannedHours = 257.0,
    this.remainingHours = 23.0,
    this.utilizationPct = 91.8,
  });

  factory TeamDetailCapacityModel.fromJson(Map<String, dynamic> json) {
    return TeamDetailCapacityModel(
      totalCapacityHours: (json['total_capacity_hours'] as num?)?.toDouble() ?? 280.0,
      plannedHours: (json['planned_hours'] as num?)?.toDouble() ?? 257.0,
      remainingHours: (json['remaining_hours'] as num?)?.toDouble() ?? 23.0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 91.8,
    );
  }
}

class TeamDetailModel {
  final String id;
  final String name;
  final String teamKey;
  final String department;
  final String description;
  final String icon;
  final String color;
  final bool isActive;
  final String status;
  final List<String> tags;
  final String goal;
  final String? createdAt;
  final String? updatedAt;
  final TeamLeadModel lead;
  final TeamDetailCapacityModel capacity;
  final List<TeamMemberItemModel> members;
  final List<TeamActivityItemModel> activities;
  final List<TeamWorkItemModel> workItems;

  const TeamDetailModel({
    required this.id,
    required this.name,
    required this.teamKey,
    required this.department,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.status,
    required this.tags,
    required this.goal,
    this.createdAt,
    this.updatedAt,
    required this.lead,
    required this.capacity,
    required this.members,
    required this.activities,
    required this.workItems,
  });

  factory TeamDetailModel.fromJson(Map<String, dynamic> json) {
    final leadJson = json['lead'] as Map<String, dynamic>? ?? {};
    final capJson = json['capacity'] as Map<String, dynamic>? ?? {};
    final memList = (json['members'] as List<dynamic>? ?? [])
        .map((m) => TeamMemberItemModel.fromJson(m as Map<String, dynamic>))
        .toList();
    final actList = (json['activities'] as List<dynamic>? ?? [])
        .map((a) => TeamActivityItemModel.fromJson(a as Map<String, dynamic>))
        .toList();
    final wiList = (json['work_items'] as List<dynamic>? ?? [])
        .map((w) => TeamWorkItemModel.fromJson(w as Map<String, dynamic>))
        .toList();
    final tagsList = (json['tags'] as List<dynamic>? ?? [])
        .map((t) => t.toString())
        .toList();

    return TeamDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      teamKey: json['team_key']?.toString() ?? 'DCT',
      department: json['department']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'layers',
      color: json['color']?.toString() ?? '#2563EB',
      isActive: json['is_active'] != false,
      status: json['status']?.toString() ?? 'ACTIVE',
      tags: tagsList,
      goal: json['goal']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      lead: TeamLeadModel.fromJson(leadJson),
      capacity: TeamDetailCapacityModel.fromJson(capJson),
      members: memList,
      activities: actList,
      workItems: wiList,
    );
  }
}

// ============================================================================
// Sprint Retrospective Enterprise Models
// ============================================================================

class SprintRetroHeaderModel {
  final String id;
  final String sprintId;
  final String title;
  final String status;
  final String sessionDateFormatted;
  final String? facilitatorId;
  final String facilitatorName;
  final String? facilitatorAvatar;
  final int participantCount;
  final int totalParticipants;
  final int participationPct;
  final int durationMinutes;
  final String sprintGoal;
  final String summary;
  final String? meetingLink;
  final String visibility;
  final String? notes;

  const SprintRetroHeaderModel({
    required this.id,
    required this.sprintId,
    this.title = 'Sprint Retrospective',
    this.status = 'COMPLETED',
    this.sessionDateFormatted = '',
    this.facilitatorId,
    this.facilitatorName = 'Facilitator',
    this.facilitatorAvatar,
    this.participantCount = 7,
    this.totalParticipants = 7,
    this.participationPct = 100,
    this.durationMinutes = 60,
    this.sprintGoal = '',
    this.summary = '',
    this.meetingLink,
    this.visibility = 'TEAM',
    this.notes,
  });

  factory SprintRetroHeaderModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroHeaderModel(
      id: json['id']?.toString() ?? '',
      sprintId: json['sprint_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sprint Retrospective',
      status: json['status']?.toString().toUpperCase() ?? 'COMPLETED',
      sessionDateFormatted: json['session_date_formatted']?.toString() ?? '',
      facilitatorId: json['facilitator_id']?.toString(),
      facilitatorName: json['facilitator_name']?.toString() ?? 'Neha Sharma',
      facilitatorAvatar: json['facilitator_avatar']?.toString(),
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 7,
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 7,
      participationPct: (json['participation_pct'] as num?)?.toInt() ?? 100,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      sprintGoal: json['sprint_goal']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      meetingLink: json['meeting_link']?.toString(),
      visibility: json['visibility']?.toString() ?? 'TEAM',
      notes: json['notes']?.toString(),
    );
  }
}

class SprintRetroOverviewModel {
  final String sprintId;
  final String sprintName;
  final String status;
  final String dateRange;
  final String teamName;
  final String completedWork;
  final String sprintGoal;

  const SprintRetroOverviewModel({
    required this.sprintId,
    this.sprintName = 'Sprint 8',
    this.status = 'Completed',
    this.dateRange = '',
    this.teamName = 'Digital Campus Team',
    this.completedWork = '29 of 42 (68%)',
    this.sprintGoal = '',
  });

  factory SprintRetroOverviewModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroOverviewModel(
      sprintId: json['sprint_id']?.toString() ?? '',
      sprintName: json['sprint_name']?.toString() ?? 'Sprint 8',
      status: json['status']?.toString() ?? 'Completed',
      dateRange: json['date_range']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? 'Digital Campus Team',
      completedWork: json['completed_work']?.toString() ?? '29 of 42 (68%)',
      sprintGoal: json['sprint_goal']?.toString() ?? '',
    );
  }
}

class SprintRetroEntryItemModel {
  final String id;
  final String category;
  final String content;
  final int votes;
  final bool hasVoted;
  final int commentsCount;
  final bool isPinned;
  final int displayOrder;
  final String? teamId;
  final String? teamName;
  final String? authorId;
  final String authorName;
  final String? authorAvatar;
  final String createdAt;

  const SprintRetroEntryItemModel({
    required this.id,
    required this.category,
    required this.content,
    this.votes = 0,
    this.hasVoted = false,
    this.commentsCount = 0,
    this.isPinned = false,
    this.displayOrder = 0,
    this.teamId,
    this.teamName,
    this.authorId,
    this.authorName = 'Team Member',
    this.authorAvatar,
    this.createdAt = '',
  });

  factory SprintRetroEntryItemModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroEntryItemModel(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString().toUpperCase() ?? 'WENT_WELL',
      content: json['content']?.toString() ?? '',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      hasVoted: json['has_voted'] == true,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      teamId: json['team_id']?.toString(),
      teamName: json['team_name']?.toString(),
      authorId: json['author_id']?.toString(),
      authorName: json['author_name']?.toString() ?? 'Team Member',
      authorAvatar: json['author_avatar']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  SprintRetroEntryItemModel copyWith({
    String? category,
    String? content,
    int? votes,
    bool? hasVoted,
    int? commentsCount,
    bool? isPinned,
    String? teamId,
    String? teamName,
  }) {
    return SprintRetroEntryItemModel(
      id: id,
      category: category ?? this.category,
      content: content ?? this.content,
      votes: votes ?? this.votes,
      hasVoted: hasVoted ?? this.hasVoted,
      commentsCount: commentsCount ?? this.commentsCount,
      isPinned: isPinned ?? this.isPinned,
      displayOrder: displayOrder,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
    );
  }
}

class SprintRetroCommentModel {
  final String id;
  final String entryId;
  final String content;
  final String? authorId;
  final String authorName;
  final String? authorAvatar;
  final String createdAt;
  final bool isOwner;

  const SprintRetroCommentModel({
    required this.id,
    required this.entryId,
    required this.content,
    this.authorId,
    this.authorName = 'Team Member',
    this.authorAvatar,
    this.createdAt = '',
    this.isOwner = false,
  });

  factory SprintRetroCommentModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroCommentModel(
      id: json['id']?.toString() ?? '',
      entryId: json['entry_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      authorId: json['author_id']?.toString(),
      authorName: json['author_name']?.toString() ?? 'Team Member',
      authorAvatar: json['author_avatar']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      isOwner: json['is_owner'] == true,
    );
  }
}

class SprintRetroCategoryColumnModel {
  final String title;
  final String key;
  final int count;
  final List<SprintRetroEntryItemModel> entries;

  const SprintRetroCategoryColumnModel({
    required this.title,
    required this.key,
    required this.count,
    required this.entries,
  });

  factory SprintRetroCategoryColumnModel.fromJson(Map<String, dynamic> json) {
    final list = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => SprintRetroEntryItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SprintRetroCategoryColumnModel(
      title: json['title']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? list.length,
      entries: list,
    );
  }

  SprintRetroCategoryColumnModel copyWith({
    String? title,
    String? key,
    int? count,
    List<SprintRetroEntryItemModel>? entries,
  }) {
    return SprintRetroCategoryColumnModel(
      title: title ?? this.title,
      key: key ?? this.key,
      count: count ?? (entries?.length ?? this.count),
      entries: entries ?? this.entries,
    );
  }
}

class SprintRetroActionItemModel {
  final String id;
  final String itemKey;
  final String title;
  final String? description;
  final String? teamId;
  final String? teamName;
  final String? ownerId;
  final String ownerName;
  final String? ownerEmail;
  final String? ownerAvatar;
  final String priority;
  final String dueDate;
  final String status;
  final int progressPercentage;
  final String? linkedWorkItemId;
  final String? linkedWorkItemKey;
  final String? linkedWorkItemType;
  final String createdAt;

  const SprintRetroActionItemModel({
    required this.id,
    required this.itemKey,
    required this.title,
    this.description,
    this.teamId,
    this.teamName,
    this.ownerId,
    this.ownerName = 'Unassigned',
    this.ownerEmail,
    this.ownerAvatar,
    this.priority = 'MEDIUM',
    this.dueDate = '',
    this.status = 'OPEN',
    this.progressPercentage = 0,
    this.linkedWorkItemId,
    this.linkedWorkItemKey,
    this.linkedWorkItemType,
    this.createdAt = '',
  });

  factory SprintRetroActionItemModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroActionItemModel(
      id: json['id']?.toString() ?? '',
      itemKey: json['item_key']?.toString() ?? 'RA-001',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      teamId: json['team_id']?.toString(),
      teamName: json['team_name']?.toString(),
      ownerId: json['owner_id']?.toString(),
      ownerName: json['owner_name']?.toString() ?? 'Unassigned',
      ownerEmail: json['owner_email']?.toString(),
      ownerAvatar: json['owner_avatar']?.toString(),
      priority: json['priority']?.toString().toUpperCase() ?? 'MEDIUM',
      dueDate: json['due_date']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      progressPercentage: (json['progress_percentage'] as num?)?.toInt() ?? 0,
      linkedWorkItemId: json['linked_work_item_id']?.toString(),
      linkedWorkItemKey: json['linked_work_item_key']?.toString(),
      linkedWorkItemType: json['linked_work_item_type']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  SprintRetroActionItemModel copyWith({
    String? title,
    String? description,
    String? teamId,
    String? teamName,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? ownerAvatar,
    String? priority,
    String? dueDate,
    String? status,
    int? progressPercentage,
    String? linkedWorkItemId,
    String? linkedWorkItemKey,
    String? linkedWorkItemType,
  }) {
    return SprintRetroActionItemModel(
      id: id,
      itemKey: itemKey,
      title: title ?? this.title,
      description: description ?? this.description,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      linkedWorkItemId: linkedWorkItemId ?? this.linkedWorkItemId,
      linkedWorkItemKey: linkedWorkItemKey ?? this.linkedWorkItemKey,
      linkedWorkItemType: linkedWorkItemType ?? this.linkedWorkItemType,
      createdAt: createdAt,
    );
  }
}

class SprintRetroParticipantModel {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String role;
  final String attendanceStatus;

  const SprintRetroParticipantModel({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.avatarUrl,
    this.role = 'Member',
    this.attendanceStatus = 'ATTENDED',
  });

  factory SprintRetroParticipantModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroParticipantModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Member',
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'Member',
      attendanceStatus: json['attendance_status']?.toString().toUpperCase() ?? 'ATTENDED',
    );
  }
}

class SprintRetroHistoryItemModel {
  final String id;
  final String milestone;
  final String description;
  final String actorName;
  final String createdAt;

  const SprintRetroHistoryItemModel({
    required this.id,
    required this.milestone,
    required this.description,
    required this.actorName,
    required this.createdAt,
  });

  factory SprintRetroHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroHistoryItemModel(
      id: json['id']?.toString() ?? '',
      milestone: json['milestone']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? 'Facilitator',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class SprintRetroFeedbackItemModel {
  final String id;
  final String? userId;
  final String category;
  final int rating;
  final String? content;
  final String? suggestedImprovement;
  final bool isAnonymous;
  final String userName;
  final String createdAt;

  const SprintRetroFeedbackItemModel({
    required this.id,
    this.userId,
    required this.category,
    required this.rating,
    this.content,
    this.suggestedImprovement,
    this.isAnonymous = false,
    this.userName = 'Team Member',
    this.createdAt = '',
  });

  factory SprintRetroFeedbackItemModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroFeedbackItemModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['author_id']?.toString(),
      category: json['category']?.toString() ?? 'General',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      content: json['content']?.toString(),
      suggestedImprovement: json['suggested_improvement']?.toString(),
      isAnonymous: json['is_anonymous'] == true,
      userName: json['author_name']?.toString() ?? json['user_name']?.toString() ?? (json['is_anonymous'] == true ? 'Anonymous Contributor' : 'Team Member'),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class SprintRetroFeedbackStatsModel {
  final int totalFeedback;
  final double avgRating;
  final int sentimentPct;

  const SprintRetroFeedbackStatsModel({
    this.totalFeedback = 0,
    this.avgRating = 5.0,
    this.sentimentPct = 95,
  });

  factory SprintRetroFeedbackStatsModel.fromJson(Map<String, dynamic> json) {
    return SprintRetroFeedbackStatsModel(
      totalFeedback: (json['total_feedback'] as num?)?.toInt() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 5.0,
      sentimentPct: (json['sentiment_pct'] as num?)?.toInt() ?? 95,
    );
  }
}

class SprintRetroWorkspaceModel {
  final SprintRetroHeaderModel retrospective;
  final SprintRetroOverviewModel sprintOverview;
  final SprintRetroCategoryColumnModel wentWell;
  final SprintRetroCategoryColumnModel didNotGoWell;
  final SprintRetroCategoryColumnModel shouldImprove;
  final List<SprintRetroActionItemModel> actionItems;
  final List<SprintRetroParticipantModel> participants;
  final List<SprintRetroHistoryItemModel> history;
  final List<SprintRetroFeedbackItemModel> feedback;
  final SprintRetroFeedbackStatsModel feedbackStats;
  final List<SprintCapacityTeamModel> availableTeams;
  final List<SprintCapacitySprintItemModel> availableSprints;

  const SprintRetroWorkspaceModel({
    required this.retrospective,
    required this.sprintOverview,
    required this.wentWell,
    required this.didNotGoWell,
    required this.shouldImprove,
    required this.actionItems,
    required this.participants,
    required this.history,
    required this.feedback,
    required this.feedbackStats,
    this.availableTeams = const [],
    this.availableSprints = const [],
  });

  factory SprintRetroWorkspaceModel.fromJson(Map<String, dynamic> json) {
    final retroJson = (json['retrospective'] as Map<String, dynamic>?) ?? {};
    final overviewJson = (json['sprint_overview'] as Map<String, dynamic>?) ?? {};
    final catJson = (json['categories'] as Map<String, dynamic>?) ?? {};

    final wentWellJson = (catJson['went_well'] as Map<String, dynamic>?) ?? (json['went_well'] as Map<String, dynamic>?) ?? {};
    final wentPoorlyJson = (catJson['did_not_go_well'] as Map<String, dynamic>?) ?? (json['did_not_go_well'] as Map<String, dynamic>?) ?? {};
    final shouldImproveJson = (catJson['should_improve'] as Map<String, dynamic>?) ?? (json['should_improve'] as Map<String, dynamic>?) ?? {};

    final actList = (json['action_items'] as List<dynamic>? ?? [])
        .map((a) => SprintRetroActionItemModel.fromJson(a as Map<String, dynamic>))
        .toList();

    final partList = (json['participants'] as List<dynamic>? ?? [])
        .map((p) => SprintRetroParticipantModel.fromJson(p as Map<String, dynamic>))
        .toList();

    final histList = (json['history'] as List<dynamic>? ?? [])
        .map((h) => SprintRetroHistoryItemModel.fromJson(h as Map<String, dynamic>))
        .toList();

    final feedList = (json['feedback'] as List<dynamic>? ?? [])
        .map((f) => SprintRetroFeedbackItemModel.fromJson(f as Map<String, dynamic>))
        .toList();

    final feedStats = (json['feedback_stats'] as Map<String, dynamic>?) ?? {};

    final teamsList = (json['available_teams'] as List<dynamic>? ?? [])
        .map((t) => SprintCapacityTeamModel.fromJson(t as Map<String, dynamic>))
        .toList();

    final sprintsList = (json['available_sprints'] as List<dynamic>? ?? [])
        .map((s) => SprintCapacitySprintItemModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return SprintRetroWorkspaceModel(
      retrospective: SprintRetroHeaderModel.fromJson(retroJson),
      sprintOverview: SprintRetroOverviewModel.fromJson(overviewJson),
      wentWell: SprintRetroCategoryColumnModel.fromJson(wentWellJson),
      didNotGoWell: SprintRetroCategoryColumnModel.fromJson(wentPoorlyJson),
      shouldImprove: SprintRetroCategoryColumnModel.fromJson(shouldImproveJson),
      actionItems: actList,
      participants: partList,
      history: histList,
      feedback: feedList,
      feedbackStats: SprintRetroFeedbackStatsModel.fromJson(feedStats),
      availableTeams: teamsList,
      availableSprints: sprintsList,
    );
  }

  SprintRetroWorkspaceModel copyWith({
    SprintRetroHeaderModel? retrospective,
    SprintRetroOverviewModel? sprintOverview,
    SprintRetroCategoryColumnModel? wentWell,
    SprintRetroCategoryColumnModel? didNotGoWell,
    SprintRetroCategoryColumnModel? shouldImprove,
    List<SprintRetroActionItemModel>? actionItems,
    List<SprintRetroParticipantModel>? participants,
    List<SprintRetroHistoryItemModel>? history,
    List<SprintRetroFeedbackItemModel>? feedback,
    SprintRetroFeedbackStatsModel? feedbackStats,
    List<SprintCapacityTeamModel>? availableTeams,
    List<SprintCapacitySprintItemModel>? availableSprints,
  }) {
    return SprintRetroWorkspaceModel(
      retrospective: retrospective ?? this.retrospective,
      sprintOverview: sprintOverview ?? this.sprintOverview,
      wentWell: wentWell ?? this.wentWell,
      didNotGoWell: didNotGoWell ?? this.didNotGoWell,
      shouldImprove: shouldImprove ?? this.shouldImprove,
      actionItems: actionItems ?? this.actionItems,
      participants: participants ?? this.participants,
      history: history ?? this.history,
      feedback: feedback ?? this.feedback,
      feedbackStats: feedbackStats ?? this.feedbackStats,
      availableTeams: availableTeams ?? this.availableTeams,
      availableSprints: availableSprints ?? this.availableSprints,
    );
  }
}
