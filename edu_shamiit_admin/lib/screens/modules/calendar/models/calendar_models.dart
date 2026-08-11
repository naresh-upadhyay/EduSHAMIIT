import 'dart:convert';
import 'package:flutter/material.dart';

/// Supported Calendar View Modes
enum CalendarViewMode {
  day,
  threeDay,
  week,
  month,
  year,
  agenda,
  timeline,
}

extension CalendarViewModeExt on CalendarViewMode {
  String get label {
    switch (this) {
      case CalendarViewMode.day:
        return 'Day';
      case CalendarViewMode.threeDay:
        return '3 Day';
      case CalendarViewMode.week:
        return 'Week';
      case CalendarViewMode.month:
        return 'Month';
      case CalendarViewMode.year:
        return 'Year';
      case CalendarViewMode.agenda:
        return 'Agenda';
      case CalendarViewMode.timeline:
        return 'Timeline';
    }
  }
}

/// Calendar Container Entity
class CalendarModel {
  final String id;
  final String schoolId;
  final String name;
  final String? description;
  final Color color;
  final String type; // personal, academic, transport, hr, department, school_events, custom
  final bool isSystem;
  final bool isDefault;
  final bool isArchived;
  final String? ownerId;
  final String visibility;
  final String userPermission;
  final int eventCount;
  final bool isSelected;

  CalendarModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.description,
    this.color = const Color(0xFF4F46E5),
    this.type = 'custom',
    this.isSystem = false,
    this.isDefault = false,
    this.isArchived = false,
    this.ownerId,
    this.visibility = 'shared',
    this.userPermission = 'view_details',
    this.eventCount = 0,
    this.isSelected = true,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    if (json['color'] != null) {
      try {
        final hex = json['color'].toString().replaceAll('#', '');
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return CalendarModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Calendar',
      description: json['description']?.toString(),
      color: parsedColor,
      type: json['type']?.toString() ?? 'custom',
      isSystem: json['is_system'] == true,
      isDefault: json['is_default'] == true,
      isArchived: json['is_archived'] == true,
      ownerId: json['owner_id']?.toString(),
      visibility: json['visibility']?.toString() ?? 'shared',
      userPermission: json['user_permission']?.toString() ?? 'view_details',
      eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
      isSelected: true,
    );
  }

  CalendarModel copyWith({bool? isSelected, Color? color, String? name}) {
    return CalendarModel(
      id: id,
      schoolId: schoolId,
      name: name ?? this.name,
      description: description,
      color: color ?? this.color,
      type: type,
      isSystem: isSystem,
      isDefault: isDefault,
      isArchived: isArchived,
      ownerId: ownerId,
      visibility: visibility,
      userPermission: userPermission,
      eventCount: eventCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Universal Schedule Entity
class ScheduleModel {
  final String id;
  final String schoolId;
  final String calendarId;
  final String title;
  final String? description;
  final String scheduleType; // Meeting, Class, Exam, Task, Reminder, Training, Trip, etc.
  final String category;
  final Color color;
  final String priority; // low, normal, high, urgent
  final String status; // scheduled, confirmed, pending, in_progress, completed, cancelled
  final String approvalStatus; // not_required, pending, approved, rejected
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String timezone;
  final String? locationName;
  final String? locationAddress;
  final String? building;
  final String? room;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String? virtualMeetingUrl;
  final String? virtualMeetingProvider;
  final String? recurringParentId;
  final String? organizerId;
  final String? organizerName;
  final String? organizerAvatar;
  final String? createdBy;
  final String visibility;
  final bool isRecurring;
  final RecurrenceRuleModel? recurrenceRule;
  final List<ScheduleParticipantModel> participants;
  final List<ScheduleResourceBookingModel> resources;
  final List<ScheduleReminderModel> reminders;
  final List<ScheduleCommentModel> comments;
  final String? cancellationReason;
  final String? routeId;
  final String? routeName;
  final String? routeCode;
  final String? routeStartTime;
  final String? routeEndTime;
  final String? busNumber;
  final String? driverName;
  final String? tripId;
  final String? tripStatus;

  final DateTime? startTimeUtc;
  final DateTime? endTimeUtc;

  ScheduleModel({
    required this.id,
    required this.schoolId,
    required this.calendarId,
    required this.title,
    this.description,
    this.scheduleType = 'Meeting',
    this.category = 'General',
    this.color = const Color(0xFF4F46E5),
    this.priority = 'normal',
    this.status = 'scheduled',
    this.approvalStatus = 'not_required',
    required this.startTime,
    required this.endTime,
    this.startTimeUtc,
    this.endTimeUtc,
    this.isAllDay = false,
    this.timezone = 'Asia/Kolkata',
    this.locationName,
    this.locationAddress,
    this.building,
    this.room,
    this.landmark,
    this.latitude,
    this.longitude,
    this.virtualMeetingUrl,
    this.virtualMeetingProvider,
    this.recurringParentId,
    this.organizerId,
    this.organizerName,
    this.organizerAvatar,
    this.createdBy,
    this.visibility = 'shared',
    this.isRecurring = false,
    this.recurrenceRule,
    this.participants = const [],
    this.resources = const [],
    this.reminders = const [],
    this.comments = const [],
    this.cancellationReason,
    this.routeId,
    this.routeName,
    this.routeCode,
    this.routeStartTime,
    this.routeEndTime,
    this.busNumber,
    this.driverName,
    this.tripId,
    this.tripStatus,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    if (json['color'] != null) {
      try {
        final hex = json['color'].toString().replaceAll('#', '');
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(hours: 1));
    DateTime? startUtc;
    DateTime? endUtc;
    if (json['start_time'] != null) {
      final str = json['start_time'].toString();
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        startUtc = parsed.toUtc();
        start = parsed.isUtc ? parsed.toLocal() : (str.contains('Z') || str.contains('+') || str.contains('-') ? parsed.toLocal() : parsed);
      }
    }
    if (json['end_time'] != null) {
      final str = json['end_time'].toString();
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        endUtc = parsed.toUtc();
        end = parsed.isUtc ? parsed.toLocal() : (str.contains('Z') || str.contains('+') || str.contains('-') ? parsed.toLocal() : parsed);
      }
    }

    RecurrenceRuleModel? recRule;
    if (json['recurrence'] is Map<String, dynamic>) {
      recRule = RecurrenceRuleModel.fromJson(json['recurrence']);
    } else if (json['frequency'] != null) {
      recRule = RecurrenceRuleModel.fromJson(json);
    }

    List<ScheduleParticipantModel> partList = [];
    if (json['participants'] is List) {
      partList = (json['participants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((p) => ScheduleParticipantModel.fromJson(p))
          .toList();
    }

    List<ScheduleResourceBookingModel> resList = [];
    if (json['booked_resources'] is List) {
      resList = (json['booked_resources'] as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => ScheduleResourceBookingModel.fromJson(r))
          .toList();
    } else if (json['resources'] is List) {
      resList = (json['resources'] as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => ScheduleResourceBookingModel.fromJson(r))
          .toList();
    }

    List<ScheduleReminderModel> remList = [];
    if (json['reminders'] is List) {
      remList = (json['reminders'] as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => ScheduleReminderModel.fromJson(r))
          .toList();
    }

    List<ScheduleCommentModel> commList = [];
    if (json['comments'] is List) {
      commList = (json['comments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((c) => ScheduleCommentModel.fromJson(c))
          .toList();
    }

    return ScheduleModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      calendarId: json['calendar_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Schedule',
      description: json['description']?.toString(),
      scheduleType: json['schedule_type']?.toString() ?? 'Event',
      category: json['category']?.toString() ?? 'General',
      color: parsedColor,
      priority: json['priority']?.toString() ?? 'normal',
      status: json['status']?.toString() ?? 'scheduled',
      approvalStatus: json['approval_status']?.toString() ?? 'not_required',
      startTime: start,
      endTime: end,
      startTimeUtc: startUtc,
      endTimeUtc: endUtc,
      isAllDay: json['is_all_day'] == true,
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
      locationName: json['location_name']?.toString() ?? json['room']?.toString(),
      locationAddress: json['location_address']?.toString(),
      building: json['building']?.toString(),
      room: json['room']?.toString(),
      landmark: json['landmark']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      virtualMeetingUrl: json['virtual_meeting_url']?.toString(),
      virtualMeetingProvider: json['virtual_meeting_provider']?.toString(),
      recurringParentId: json['recurring_parent_id']?.toString(),
      organizerId: json['organizer_id']?.toString(),
      organizerName: json['organizer_name']?.toString(),
      organizerAvatar: json['organizer_avatar']?.toString(),
      createdBy: json['created_by']?.toString(),
      visibility: json['visibility']?.toString() ?? 'shared',
      isRecurring: json['is_recurring'] == true || recRule != null,
      recurrenceRule: recRule,
      participants: partList,
      resources: resList,
      reminders: remList,
      comments: commList,
      cancellationReason: json['cancellation_reason']?.toString(),
      routeId: json['route_id']?.toString(),
      routeName: json['route_name']?.toString(),
      routeCode: json['route_code']?.toString(),
      routeStartTime: json['route_start_time']?.toString(),
      routeEndTime: json['route_end_time']?.toString(),
      busNumber: json['bus_number']?.toString() ?? json['registration_no']?.toString(),
      driverName: json['driver_name']?.toString(),
      tripId: json['trip_id']?.toString(),
      tripStatus: json['trip_status']?.toString(),
    );
  }

  ScheduleModel copyWith({
    String? id,
    String? schoolId,
    String? calendarId,
    String? title,
    String? description,
    String? scheduleType,
    String? category,
    Color? color,
    String? priority,
    String? status,
    String? approvalStatus,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? timezone,
    String? locationName,
    String? locationAddress,
    String? building,
    String? room,
    String? landmark,
    double? latitude,
    double? longitude,
    String? virtualMeetingUrl,
    String? virtualMeetingProvider,
    String? recurringParentId,
    String? organizerId,
    String? organizerName,
    String? organizerAvatar,
    String? createdBy,
    String? visibility,
    bool? isRecurring,
    RecurrenceRuleModel? recurrenceRule,
    List<ScheduleParticipantModel>? participants,
    List<ScheduleResourceBookingModel>? resources,
    List<ScheduleReminderModel>? reminders,
    List<ScheduleCommentModel>? comments,
    String? routeId,
    String? routeName,
    String? routeCode,
    String? routeStartTime,
    String? routeEndTime,
    String? busNumber,
    String? driverName,
    String? tripId,
    String? tripStatus,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduleType: scheduleType ?? this.scheduleType,
      category: category ?? this.category,
      color: color ?? this.color,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      timezone: timezone ?? this.timezone,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      building: building ?? this.building,
      room: room ?? this.room,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      virtualMeetingUrl: virtualMeetingUrl ?? this.virtualMeetingUrl,
      virtualMeetingProvider: virtualMeetingProvider ?? this.virtualMeetingProvider,
      recurringParentId: recurringParentId ?? this.recurringParentId,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      createdBy: createdBy ?? this.createdBy,
      visibility: visibility ?? this.visibility,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      participants: participants ?? this.participants,
      resources: resources ?? this.resources,
      reminders: reminders ?? this.reminders,
      comments: comments ?? this.comments,
      cancellationReason: cancellationReason,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      routeCode: routeCode ?? this.routeCode,
      routeStartTime: routeStartTime ?? this.routeStartTime,
      routeEndTime: routeEndTime ?? this.routeEndTime,
      busNumber: busNumber ?? this.busNumber,
      driverName: driverName ?? this.driverName,
      tripId: tripId ?? this.tripId,
      tripStatus: tripStatus ?? this.tripStatus,
    );
  }
}

/// Recurrence Rule Model
class RecurrenceRuleModel {
  final String frequency; // daily, weekly, monthly, yearly, custom
  final int interval;
  final List<String> daysOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;
  final String endType; // never, after_count, until_date
  final int? endCount;
  final DateTime? endDate;

  RecurrenceRuleModel({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.dayOfMonth,
    this.monthOfYear,
    this.endType = 'never',
    this.endCount,
    this.endDate,
  });

  factory RecurrenceRuleModel.fromJson(Map<String, dynamic> json) {
    List<String> days = [];
    if (json['days_of_week'] is List) {
      days = (json['days_of_week'] as List).map((e) => e.toString()).toList();
    } else if (json['days_of_week'] is String) {
      try {
        final parsed = jsonDecode(json['days_of_week']);
        if (parsed is List) days = parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    DateTime? endDt;
    if (json['end_date'] != null || json['rec_end_date'] != null) {
      endDt = DateTime.tryParse((json['end_date'] ?? json['rec_end_date']).toString());
    }

    return RecurrenceRuleModel(
      frequency: json['frequency']?.toString() ?? 'daily',
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      daysOfWeek: days,
      dayOfMonth: (json['day_of_month'] as num?)?.toInt(),
      monthOfYear: (json['month_of_year'] as num?)?.toInt(),
      endType: json['end_type']?.toString() ?? 'never',
      endCount: (json['end_count'] as num?)?.toInt(),
      endDate: endDt,
    );
  }
}

/// Participant Assignment Entity
class ScheduleParticipantModel {
  final String id;
  final String? userId;
  final String? fullName;
  final String? role;
  final String? targetRole;
  final String? targetClass;
  final String? email;
  final String? avatarUrl;
  final String participantType; // individual, role, department, class_section
  final String participationRole; // required, optional, fyi
  final String permission; // can_view, can_edit, can_invite, can_manage
  final String rsvpStatus; // pending, accepted, declined, tentative
  final String? declineReason;

  ScheduleParticipantModel({
    required this.id,
    this.userId,
    this.fullName,
    this.role,
    this.targetRole,
    this.targetClass,
    this.email,
    this.avatarUrl,
    this.participantType = 'individual',
    this.participationRole = 'required',
    this.permission = 'can_view',
    this.rsvpStatus = 'pending',
    this.declineReason,
  });

  factory ScheduleParticipantModel.fromJson(Map<String, dynamic> json) {
    return ScheduleParticipantModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      fullName: json['full_name']?.toString() ?? json['name']?.toString(),
      role: json['role']?.toString(),
      targetRole: json['target_role']?.toString(),
      targetClass: json['target_class']?.toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      participantType: json['participant_type']?.toString() ?? 'individual',
      participationRole: json['participation_role']?.toString() ?? 'required',
      permission: json['permission']?.toString() ?? 'can_view',
      rsvpStatus: json['rsvp_status']?.toString() ?? 'pending',
      declineReason: json['decline_reason']?.toString(),
    );
  }
}

/// Resource Booking Model
class ScheduleResourceBookingModel {
  final String id;
  final String resourceId;
  final String resourceName;
  final String resourceType;
  final String? roomNumber;
  final String status;

  ScheduleResourceBookingModel({
    required this.id,
    required this.resourceId,
    required this.resourceName,
    required this.resourceType,
    this.roomNumber,
    this.status = 'confirmed',
  });

  factory ScheduleResourceBookingModel.fromJson(Map<String, dynamic> json) {
    return ScheduleResourceBookingModel(
      id: json['id']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      resourceName: json['resource_name']?.toString() ?? json['name']?.toString() ?? 'Resource',
      resourceType: json['resource_type']?.toString() ?? json['type']?.toString() ?? 'facility',
      roomNumber: json['room_number']?.toString(),
      status: json['status']?.toString() ?? 'confirmed',
    );
  }
}

/// Bookable Resource Entity
class CalendarResourceModel {
  final String id;
  final String name;
  final String code;
  final String type; // classroom, lab, auditorium, bus, vehicle, meeting_room, projector
  final int capacity;
  final String? building;
  final String? roomNumber;
  final bool isExclusive;
  final bool isAvailable;

  CalendarResourceModel({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.capacity = 1,
    this.building,
    this.roomNumber,
    this.isExclusive = true,
    this.isAvailable = true,
  });

  factory CalendarResourceModel.fromJson(Map<String, dynamic> json) {
    return CalendarResourceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'classroom',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      building: json['building']?.toString(),
      roomNumber: json['room_number']?.toString(),
      isExclusive: json['is_exclusive'] != false,
      isAvailable: true,
    );
  }
}

/// Schedule Reminder Model
class ScheduleReminderModel {
  final String id;
  final int minutesBefore;
  final String channel;

  ScheduleReminderModel({
    required this.id,
    required this.minutesBefore,
    this.channel = 'in_app',
  });

  factory ScheduleReminderModel.fromJson(Map<String, dynamic> json) {
    return ScheduleReminderModel(
      id: json['id']?.toString() ?? '',
      minutesBefore: (json['minutes_before'] as num?)?.toInt() ?? 15,
      channel: json['channel']?.toString() ?? 'in_app',
    );
  }
}

/// Schedule Comment Model
class ScheduleCommentModel {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? role;
  final String commentText;
  final DateTime createdAt;

  ScheduleCommentModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.role,
    required this.commentText,
    required this.createdAt,
  });

  factory ScheduleCommentModel.fromJson(Map<String, dynamic> json) {
    return ScheduleCommentModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString(),
      commentText: json['comment_text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Dashboard Intelligence Summary
class CalendarSummaryModel {
  final int todayCount;
  final int weekCount;
  final Map<String, int> categories;
  final List<ScheduleModel> assignedToMe;
  final List<ScheduleModel> pendingInvitations;
  final String timezone;

  CalendarSummaryModel({
    this.todayCount = 0,
    this.weekCount = 0,
    this.categories = const {},
    this.assignedToMe = const [],
    this.pendingInvitations = const [],
    this.timezone = 'Asia/Kolkata (IST)',
  });

  factory CalendarSummaryModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> cats = {};
    if (json['categories'] is Map) {
      json['categories'].forEach((k, v) {
        cats[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    List<ScheduleModel> assigned = [];
    if (json['assigned_to_me'] is List) {
      assigned = (json['assigned_to_me'] as List)
          .whereType<Map<String, dynamic>>()
          .map((s) => ScheduleModel.fromJson(s))
          .toList();
    }

    List<ScheduleModel> pending = [];
    if (json['pending_invitations'] is List) {
      pending = (json['pending_invitations'] as List)
          .whereType<Map<String, dynamic>>()
          .map((s) => ScheduleModel.fromJson(s))
          .toList();
    }

    return CalendarSummaryModel(
      todayCount: (json['today_count'] as num?)?.toInt() ?? 0,
      weekCount: (json['week_count'] as num?)?.toInt() ?? 0,
      categories: cats,
      assignedToMe: assigned,
      pendingInvitations: pending,
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata (IST)',
    );
  }
}
