import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../../models/calendar_models.dart';
import 'recurrence_scope_dialog.dart';

class CreateEditScheduleDialog extends StatefulWidget {
  final ScheduleModel? initialSchedule;
  final String? defaultScheduleType;
  final DateTime? defaultDateTime;
  final int? defaultHour;
  final List<CalendarModel> calendars;
  final List<CalendarResourceModel> resources;
  final Function(
    Map<String, dynamic> payload, {
    String recurrenceScope,
    String? targetInstanceDate,
  }) onSave;

  const CreateEditScheduleDialog({
    super.key,
    this.initialSchedule,
    this.defaultScheduleType,
    this.defaultDateTime,
    this.defaultHour,
    required this.calendars,
    required this.resources,
    required this.onSave,
  });

  @override
  State<CreateEditScheduleDialog> createState() => _CreateEditScheduleDialogState();
}

class _CreateEditScheduleDialogState extends State<CreateEditScheduleDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _roomController = TextEditingController();
  final _buildingController = TextEditingController();
  final _virtualUrlController = TextEditingController();

  // State
  late String _selectedType;
  late String _selectedCalendarId;
  final String _selectedCategory = 'General';
  late Color _selectedColor;
  late String _selectedPriority;
  String _selectedVisibility = 'shared';
  late String _virtualProvider;

  List<Map<String, dynamic>> _dbRoles = [];
  List<Map<String, dynamic>> _dbClasses = [];
  final Set<String> _selectedRoleKeys = {};
  final Set<String> _selectedClassSectionKeys = {};
  final Map<String, String?> _selectedClassSectionSubjects = {};
  final List<Map<String, dynamic>> _manualIndividualUsers = [];
  bool _isLoadingRoles = false;
  bool _isLoadingClasses = false;

  Future<void> _fetchAssignableRoles() async {
    try {
      setState(() => _isLoadingRoles = true);
      final res = await ApiService().get('/calendar/assignable-roles', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final List<Map<String, dynamic>> parsedRoles = [];
        for (final item in (res['data'] as List)) {
          if (item is Map) {
            parsedRoles.add(Map<String, dynamic>.from(item));
          } else if (item != null) {
            final str = item.toString().trim();
            if (str.isNotEmpty) parsedRoles.add({'name': str, 'display_name': str});
          }
        }
        if (parsedRoles.isNotEmpty && mounted) {
          setState(() {
            _dbRoles = parsedRoles;
            _isLoadingRoles = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _dbRoles = [
          {'name': 'owner', 'display_name': 'Owner'},
          {'name': 'super_admin', 'display_name': 'Super Admin'},
          {'name': 'admin', 'display_name': 'Institution Admin'},
          {'name': 'director', 'display_name': 'Director'},
          {'name': 'principal', 'display_name': 'Academic Admin'},
          {'name': 'exam_ctrl', 'display_name': 'Examination Controller'},
          {'name': 'teacher', 'display_name': 'Teacher'},
          {'name': 'class_teacher', 'display_name': 'Class Teacher'},
          {'name': 'subject_teacher', 'display_name': 'Subject Teacher'},
          {'name': 'student', 'display_name': 'Student'},
          {'name': 'parent', 'display_name': 'Student (Parent)'},
          {'name': 'driver', 'display_name': 'Driver'},
          {'name': 'finance', 'display_name': 'Accountant'},
          {'name': 'hr', 'display_name': 'HR Manager'},
          {'name': 'library', 'display_name': 'Librarian'},
          {'name': 'security', 'display_name': 'Campus Security'},
          {'name': 'sports', 'display_name': 'Sports Coach'},
          {'name': 'support', 'display_name': 'Front Office'},
          {'name': 'transport', 'display_name': 'Transport Manager'}
        ];
        _isLoadingRoles = false;
      });
    }
  }

  Future<void> _fetchAssignableClasses() async {
    try {
      setState(() => _isLoadingClasses = true);
      final res = await ApiService().get('/calendar/assignable-classes', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final List<Map<String, dynamic>> parsedClasses = [];
        for (final item in (res['data'] as List)) {
          if (item is Map) {
            parsedClasses.add(Map<String, dynamic>.from(item));
          }
        }
        if (parsedClasses.isNotEmpty && mounted) {
          setState(() {
            _dbClasses = parsedClasses;
            _isLoadingClasses = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _dbClasses = [];
        _isLoadingClasses = false;
      });
    }
  }

  String _getClassSectionKey(Map<String, dynamic> c) {
    final cid = c['class_id']?.toString() ?? '';
    final sid = c['section_id']?.toString() ?? '';
    if (cid.isNotEmpty || sid.isNotEmpty) return '${cid}_$sid';
    return (c['display_name'] ?? c['name'] ?? '').toString();
  }

  bool _isClassSectionSelected(Map<String, dynamic> c) {
    return _selectedClassSectionKeys.contains(_getClassSectionKey(c));
  }

  void _toggleClassSection(Map<String, dynamic> c, bool enable) {
    final key = _getClassSectionKey(c);
    if (enable) {
      _selectedClassSectionKeys.add(key);
      _selectedClassSectionSubjects.putIfAbsent(key, () => null);
    } else {
      _selectedClassSectionKeys.remove(key);
      _selectedClassSectionSubjects.remove(key);
    }
  }

  bool _isRoleSelected(String roleName) {
    return _selectedRoleKeys.contains(roleName.trim().toLowerCase());
  }

  void _toggleRoleGroup(Map<String, dynamic> rObj, bool enable) {
    final roleName = (rObj['name'] ?? '').toString().trim().toLowerCase();
    if (roleName.isEmpty) return;
    if (enable) {
      _selectedRoleKeys.add(roleName);
    } else {
      _selectedRoleKeys.remove(roleName);
    }
  }

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  String _timezone = 'Asia/Kolkata';
  String? _originalInstanceDate;

  // Recurrence
  String _recurrenceFreq = 'none'; // none, daily, weekly, monthly, yearly, custom
  int _recurrenceInterval = 1;
  List<String> _recurrenceDays = [];
  String _endType = 'never'; // never, after_count, until_date
  int _endCount = 10;
  DateTime? _recurrenceEndDate;

  // People & Assignments
  final List<Map<String, dynamic>> _assignedPeople = [];
  final _searchPeopleController = TextEditingController();

  // Resources
  final List<String> _selectedResourceIds = [];

  // Reminders
  int _reminderMinutes = 15;
  String _reminderChannel = 'in_app';

  final List<Color> _colorPalette = const [
    Color(0xFF4F46E5), // Purple/Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Sky/Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Rose
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFF64748B), // Slate
  ];

  // Real Profiles from Database
  List<Map<String, dynamic>> _realUsers = [];
  bool _isLoadingUsers = false;
  String _userSearchQuery = '';

  // Dynamic Categories from Database
  List<Map<String, dynamic>> _dynamicCategories = [];

  // Transport Routes from Database
  List<Map<String, dynamic>> _transportRoutes = [];
  bool _isLoadingRoutes = false;
  String? _selectedRouteId;
  Map<String, dynamic>? _selectedRoute;

  Future<void> _fetchCategories() async {
    try {
      final res = await ApiService().get('/calendar/categories', query: {'type': 'schedule'}, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _dynamicCategories = (res['data'] as List).whereType<Map<String, dynamic>>().toList();
          });
        }
      }
    } catch (e) {
      debugPrint('[CreateEditScheduleDialog] error fetching categories: $e');
    }
  }

  Future<void> _fetchTransportRoutes() async {
    try {
      setState(() => _isLoadingRoutes = true);
      List<Map<String, dynamic>> routesList = [];

      try {
        final res = await ApiService().get('/calendar/transport-routes', useCache: false);
        if (res['success'] == true && res['data'] is List) {
          routesList = (res['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      } catch (_) {}

      if (routesList.isEmpty) {
        try {
          final fallbackRes = await ApiService().get('/transport/routes', useCache: false);
          if (fallbackRes['success'] == true && fallbackRes['data'] is List) {
            routesList = (fallbackRes['data'] as List).whereType<Map<String, dynamic>>().toList();
          }
        } catch (_) {}
      }

      // Filter: Show ONLY routes where BOTH bus (vehicle_id/bus_number) AND driver (driver_id/driver_name) are assigned
      final assignableRoutes = routesList.where((r) {
        final hasVehicle = (r['vehicle_id'] != null && r['vehicle_id'].toString().isNotEmpty) ||
            (r['bus_number'] != null && r['bus_number'].toString().isNotEmpty) ||
            (r['registration_no'] != null && r['registration_no'].toString().isNotEmpty);
        final hasDriver = (r['driver_id'] != null && r['driver_id'].toString().isNotEmpty) ||
            (r['driver_name'] != null && r['driver_name'].toString().isNotEmpty);
        return hasVehicle && hasDriver;
      }).toList();

      if (mounted) {
        setState(() {
          _transportRoutes = assignableRoutes;
          _isLoadingRoutes = false;
          if (_selectedRouteId != null && _selectedRouteId!.isNotEmpty) {
            final match = _transportRoutes.where((r) => r['id']?.toString() == _selectedRouteId).toList();
            if (match.isNotEmpty) {
              _selectedRoute = match.first;
            }
          }
        });
      }
      return;
    } catch (e) {
      debugPrint('[CreateEditScheduleDialog] error fetching transport routes: $e');
    }
    if (mounted) {
      setState(() => _isLoadingRoutes = false);
    }
  }

  Duration _getTimezoneOffset(String tz) {
    switch (tz) {
      case 'America/New_York':
        return const Duration(hours: -4);
      case 'Europe/London':
        return const Duration(hours: 1);
      case 'Asia/Dubai':
        return const Duration(hours: 4);
      case 'Asia/Kolkata':
        return const Duration(hours: 5, minutes: 30);
      case 'UTC':
        return Duration.zero;
      default:
        return const Duration(hours: 5, minutes: 30);
    }
  }

  /// Convert a UTC DateTime into the wall-clock time for [tz].
  /// Returns a DateTime whose year/month/day/hour/minute represent
  /// what a clock on the wall in [tz] would show.
  DateTime _convertUtcToTimezone(DateTime utcTime, String tz) {
    // Force into UTC space regardless of the incoming flag
    final utc = DateTime.utc(utcTime.year, utcTime.month, utcTime.day, utcTime.hour, utcTime.minute);
    final offset = _getTimezoneOffset(tz);
    return utc.add(offset);
  }

  /// Convert a naive wall-clock DateTime (representing time in [tz]) into UTC.
  DateTime _convertTimezoneToUtc(DateTime naiveTzTime, String tz) {
    // Build in UTC space so Dart never applies the browser's local offset
    final asUtc = DateTime.utc(naiveTzTime.year, naiveTzTime.month, naiveTzTime.day, naiveTzTime.hour, naiveTzTime.minute);
    final offset = _getTimezoneOffset(tz);
    return asUtc.subtract(offset);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    final init = widget.initialSchedule;
    if (init != null) {
      _selectedVisibility = init.visibility;
      _selectedRouteId = init.routeId;
    }

    _fetchCategories();
    _fetchRealProfiles('');
    _fetchAssignableRoles();
    _fetchAssignableClasses();
    _fetchTransportRoutes();

    final now = widget.defaultDateTime ?? DateTime.now();
    final defaultHour = widget.defaultHour ?? 10;

    _titleController.text = init?.title ?? '';
    _descController.text = init?.description ?? '';
    _locationController.text = init?.locationName ?? init?.locationAddress ?? '';
    _roomController.text = init?.room ?? '';
    _buildingController.text = init?.building ?? '';
    _virtualUrlController.text = init?.virtualMeetingUrl ?? '';

    _selectedType = init?.scheduleType ?? widget.defaultScheduleType ?? 'Meeting';
    _selectedCalendarId = init?.calendarId ?? (widget.calendars.isNotEmpty ? widget.calendars.first.id : '');
    _selectedColor = init?.color ?? const Color(0xFF4F46E5);
    _selectedPriority = init?.priority ?? 'normal';
    _virtualProvider = init?.virtualMeetingProvider ?? 'google_meet';

    _isAllDay = init?.isAllDay ?? false;
    _timezone = init?.timezone ?? 'Asia/Kolkata';

    if (init != null) {
      if (init.id.contains('_inst_')) {
        final parts = init.id.split('_inst_');
        if (parts.length > 1) {
          _originalInstanceDate = parts[1];
        }
      } else {
        _originalInstanceDate = DateFormat('yyyy-MM-dd').format(init.startTime.toLocal());
      }

      final utcStart = init.startTimeUtc ?? init.startTime.toUtc();
      final utcEnd = init.endTimeUtc ?? init.endTime.toUtc();

      final localStartInTz = _convertUtcToTimezone(utcStart, _timezone);
      _startDate = DateTime(localStartInTz.year, localStartInTz.month, localStartInTz.day);
      _startTime = TimeOfDay(hour: localStartInTz.hour, minute: localStartInTz.minute);

      final localEndInTz = _convertUtcToTimezone(utcEnd, _timezone);
      _endDate = DateTime(localEndInTz.year, localEndInTz.month, localEndInTz.day);
      _endTime = TimeOfDay(hour: localEndInTz.hour, minute: localEndInTz.minute);
    } else {
      _startDate = DateTime(now.year, now.month, now.day, defaultHour);
      _startTime = TimeOfDay(hour: _startDate.hour, minute: _startDate.minute);
      _endDate = _startDate.add(const Duration(hours: 1));
      _endTime = TimeOfDay(hour: _endDate.hour, minute: _endDate.minute);
    }

    if (init != null) {
      if (init.recurrenceRule != null) {
        _recurrenceFreq = init.recurrenceRule!.frequency.toLowerCase().trim();
        _recurrenceInterval = init.recurrenceRule!.interval;
        _recurrenceDays = List.from(init.recurrenceRule!.daysOfWeek);
        final rawEndType = init.recurrenceRule!.endType.toLowerCase().trim();
        _endType = (rawEndType == 'after_count' || rawEndType == 'count')
            ? 'after_count'
            : (rawEndType == 'until_date' || rawEndType == 'until' || rawEndType == 'on_date')
                ? 'until_date'
                : 'never';
        _endCount = init.recurrenceRule!.endCount ?? 10;
        _recurrenceEndDate = init.recurrenceRule!.endDate;
      } else if (init.isRecurring) {
        _recurrenceFreq = 'daily';
        _recurrenceInterval = 1;
        _endType = 'never';
        _endCount = 10;
      } else {
        _recurrenceFreq = 'none';
        _endType = 'never';
        _endCount = 10;
      }
      _selectedRoleKeys.clear();
      if (init.targetRoles.isNotEmpty) {
        _selectedRoleKeys.addAll(init.targetRoles.map((r) => r.toLowerCase().trim()));
      }

      _selectedClassSectionKeys.clear();
      _selectedClassSectionSubjects.clear();
      if (init.targetClassSections.isNotEmpty) {
        for (final tcs in init.targetClassSections) {
          final cid = tcs['class_id']?.toString() ?? '';
          final sid = tcs['section_id']?.toString() ?? '';
          final key = (cid.isNotEmpty || sid.isNotEmpty) ? '${cid}_$sid' : (tcs['display_name'] ?? '').toString();
          if (key.isNotEmpty) {
            _selectedClassSectionKeys.add(key);
            _selectedClassSectionSubjects[key] = tcs['subject_id']?.toString();
          }
        }
      }

      _manualIndividualUsers.clear();
      for (final p in init.participants) {
        final isGroup = p.userId == null || p.userId!.isEmpty;
        if (isGroup) {
          if (p.targetRole != null && p.targetRole!.isNotEmpty) {
            _selectedRoleKeys.add(p.targetRole!.toLowerCase().trim());
          }
          if (p.classId != null || p.sectionId != null) {
            final key = '${p.classId ?? ""}_${p.sectionId ?? ""}';
            if (key != '_') {
              _selectedClassSectionKeys.add(key);
              if (p.targetSubjectId != null) {
                _selectedClassSectionSubjects[key] = p.targetSubjectId;
              }
            }
          }
        } else {
          // Only manual individuals who were explicitly added (not auto-resolved class or role participants)
          final isAutoResolved = p.classId != null || p.sectionId != null || (p.targetRole != null && p.targetRole!.isNotEmpty);
          if (!isAutoResolved) {
            _manualIndividualUsers.add({
              'user_id': p.userId,
              'name': (p.fullName != null && p.fullName!.isNotEmpty) ? p.fullName! : 'Individual User',
              'role': p.role ?? 'Member',
              'email': p.email,
              'participation_role': p.participationRole,
              'permission': p.permission,
            });
          }
        }
      }
      for (final r in init.resources) {
        _selectedResourceIds.add(r.resourceId);
      }
      if (init.reminders.isNotEmpty) {
        _reminderMinutes = init.reminders.first.minutesBefore;
        _reminderChannel = init.reminders.first.channel;
      }
    }

    _searchPeopleController.addListener(() {
      final q = _searchPeopleController.text.trim();
      if (q != _userSearchQuery) {
        setState(() => _userSearchQuery = q);
        _fetchRealProfiles(q);
      }
    });
  }

  Future<void> _fetchRealProfiles(String query) async {
    try {
      setState(() => _isLoadingUsers = true);
      final res = await ApiService().get(
        '/auth/users',
        query: query.isNotEmpty ? {'search': query} : null,
        useCache: false,
      );
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).whereType<Map<String, dynamic>>().toList();
        if (mounted) {
          setState(() {
            _realUsers = list;
            _isLoadingUsers = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUsers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _roomController.dispose();
    _buildingController.dispose();
    _virtualUrlController.dispose();
    _searchPeopleController.dispose();
    super.dispose();
  }

  void _generateVirtualLink() {
    final randomId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    setState(() {
      if (_virtualProvider == 'google_meet') {
        _virtualUrlController.text = 'https://meet.google.com/edu-$randomId-shm';
      } else if (_virtualProvider == 'zoom') {
        _virtualUrlController.text = 'https://zoom.us/j/987$randomId';
      } else if (_virtualProvider == 'teams') {
        _virtualUrlController.text = 'https://teams.microsoft.com/l/meetup-join/$randomId';
      } else {
        _virtualUrlController.text = 'https://meet.edushamiit.com/$randomId';
      }
    });
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a schedule title')),
      );
      return;
    }

    final startIso = '${_startDate.year.toString().padLeft(4, '0')}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}T${(_isAllDay ? 0 : _startTime.hour).toString().padLeft(2, '0')}:${(_isAllDay ? 0 : _startTime.minute).toString().padLeft(2, '0')}:00.000';
    final endIso = '${_endDate.year.toString().padLeft(4, '0')}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}T${(_isAllDay ? 23 : _endTime.hour).toString().padLeft(2, '0')}:${(_isAllDay ? 59 : _endTime.minute).toString().padLeft(2, '0')}:00.000';

    final hexColor = '#${(_selectedColor.r * 255).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.g * 255).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.b * 255).round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();

    final targetRolesList = _selectedRoleKeys.toList();

    final targetClassSections = <Map<String, dynamic>>[];
    for (final key in _selectedClassSectionKeys) {
      final matches = _dbClasses.where((c) => _getClassSectionKey(c) == key).toList();
      if (matches.isNotEmpty) {
        final cObj = matches.first;
        final subId = _selectedClassSectionSubjects[key];
        Map<String, dynamic>? selectedSub;
        if (subId != null && cObj['subjects'] is List) {
          final subList = (cObj['subjects'] as List).whereType<Map>().toList();
          final subMatches = subList.where((s) => s['id']?.toString() == subId).toList();
          if (subMatches.isNotEmpty) selectedSub = Map<String, dynamic>.from(subMatches.first);
        }

        targetClassSections.add({
          'class_id': cObj['class_id'],
          'class_name': cObj['class_name'],
          'section_id': cObj['section_id'],
          'section_name': cObj['section_name'],
          'subject_id': subId,
          'subject_name': selectedSub?['name'],
          'display_name': cObj['display_name'] ?? '${cObj['class_name']} - ${cObj['section_name']}',
        });
      }
    }

    final targetUserIdsList = _manualIndividualUsers
        .map((u) => (u['user_id'] ?? u['id'])?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    final manualParticipants = _manualIndividualUsers.map((u) {
      return {
        'user_id': u['user_id'] ?? u['id'],
        'participant_type': 'individual',
        'participation_role': u['participation_role'] ?? 'required',
        'permission': u['permission'] ?? 'can_view',
      };
    }).toList();

    final payload = <String, dynamic>{
      'calendar_id': _selectedCalendarId,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'schedule_type': _selectedType,
      'category': _selectedCategory,
      'color': hexColor,
      'priority': _selectedPriority,
      'route_id': _selectedRouteId,
      'start_time': startIso,
      'end_time': endIso,
      'is_all_day': _isAllDay,
      'timezone': _timezone,
      'location_name': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'room': _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
      'building': _buildingController.text.trim().isNotEmpty ? _buildingController.text.trim() : null,
      'virtual_meeting_url': _virtualUrlController.text.trim().isNotEmpty ? _virtualUrlController.text.trim() : null,
      'virtual_meeting_provider': _virtualUrlController.text.trim().isNotEmpty ? _virtualProvider : null,
      'visibility': _selectedVisibility,
      'is_recurring': _recurrenceFreq != 'none',
      'target_roles': targetRolesList,
      'target_classes': <String>[],
      'target_class_sections': targetClassSections,
      'target_user_ids': targetUserIdsList,
      'participants': manualParticipants,
      'resources': _selectedResourceIds.map((rid) => {
        'resource_id': rid,
        'start_time': startIso,
        'end_time': endIso,
      }).toList(),
      'reminders': [
        {
          'minutes_before': _reminderMinutes,
          'channel': _reminderChannel,
        }
      ],
    };

    if (_recurrenceFreq != 'none') {
      List<String> days = List.from(_recurrenceDays);
      if (_recurrenceFreq == 'weekdays') {
        days = ['MO', 'TU', 'WE', 'TH', 'FR'];
      } else if ((_recurrenceFreq == 'weekly' || _recurrenceFreq == 'custom') && days.isEmpty) {
        final dayNames = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
        days = [dayNames[_startDate.weekday] ?? 'MO'];
      }
      final endCountVal = _endType == 'after_count' ? _endCount : null;
      final endDateVal = _endType == 'until_date' && _recurrenceEndDate != null
          ? '${_recurrenceEndDate!.year.toString().padLeft(4, '0')}-${_recurrenceEndDate!.month.toString().padLeft(2, '0')}-${_recurrenceEndDate!.day.toString().padLeft(2, '0')}'
          : null;

      payload['is_recurring'] = true;
      payload['frequency'] = _recurrenceFreq;
      payload['interval'] = _recurrenceInterval;
      payload['days_of_week'] = days;
      payload['end_type'] = _endType;
      payload['end_count'] = endCountVal;
      payload['end_date'] = endDateVal;
      payload['recurrence'] = {
        'frequency': _recurrenceFreq,
        'interval': _recurrenceInterval,
        'days_of_week': days,
        'end_type': _endType,
        'end_count': endCountVal,
        'end_date': endDateVal,
      };
    } else {
      payload['is_recurring'] = false;
      payload['frequency'] = 'none';
      payload['recurrence'] = null;
    }

    final isRecurringEdit = widget.initialSchedule != null &&
        (widget.initialSchedule!.isRecurring ||
            widget.initialSchedule!.recurrenceRule != null ||
            widget.initialSchedule!.recurringParentId != null ||
            widget.initialSchedule!.id.contains('_inst_'));

    if (isRecurringEdit) {
      showDialog(
        context: context,
        builder: (ctx) {
          return RecurrenceScopeDialog(
            actionTitle: 'Edit Recurring Schedule',
            onScopeSelected: (scope) {
              Navigator.of(context).pop(); // Closes CreateEditScheduleDialog (RecurrenceScopeDialog already popped itself)
              final instanceDateStr = _originalInstanceDate ?? _startDate.toIso8601String().split('T')[0];
              widget.onSave(
                payload,
                recurrenceScope: scope,
                targetInstanceDate: instanceDateStr,
              );
            },
          );
        },
      );
    } else {
      Navigator.of(context).pop(); // Close create/edit dialog
      widget.onSave(payload, recurrenceScope: 'entire_series');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final double ts = (screenWidth / 550).clamp(0.72, 1.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20, vertical: isMobile ? 12 : 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: isDesktop ? 780 : double.infinity,
        constraints: BoxConstraints(
          maxHeight: isDesktop ? 680 : (MediaQuery.sizeOf(context).height * 0.92).clamp(400.0, 700.0),
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Ultra-Premium Modal Top Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20, vertical: isMobile ? 6 : 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Gradient Icon Badge
                  if (!isMobile)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _selectedColor,
                            _selectedColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.initialSchedule != null ? Icons.edit_calendar_rounded : Icons.add_task_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  if (!isMobile) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.initialSchedule != null ? 'Edit Schedule' : 'Create Schedule',
                              style: TextStyle(
                                fontSize: (15 * ts).roundToDouble(),
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8, vertical: 1),
                              decoration: BoxDecoration(
                                color: _selectedColor.withValues(alpha: isDark ? 0.25 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _selectedType,
                                    style: TextStyle(
                                      fontSize: (10 * ts).roundToDouble(),
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : _selectedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isMobile) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Configure schedule timeline, location, participants, resources, and reminders',
                            style: TextStyle(
                              fontSize: (11 * ts).roundToDouble(),
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF64748B)),
                      tooltip: 'Close',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                  ),
                ],
              ),
            ),

            // Ultra-Premium Compact Segmented Tab Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8, vertical: isMobile ? 1 : 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 1 : 3),
                splashBorderRadius: BorderRadius.circular(6),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: EdgeInsets.symmetric(vertical: isMobile ? 1 : 2),
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                labelStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), fontWeight: FontWeight.w800),
                unselectedLabelStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          const Text('Basic Info'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          const Text('Date & Time'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat_rounded, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          const Text('Recurrence'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_outlined, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          Text(isMobile ? 'Location' : 'Location & Virtual'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          Text(isMobile ? 'People' : 'Assign People'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    height: isMobile ? 26 : 30,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_outlined, size: isMobile ? 11 : 13),
                          const SizedBox(width: 3),
                          Text(isMobile ? 'Resources' : 'Resources & Reminders'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildDateTimeTab(),
                  _buildRecurrenceTab(),
                  _buildLocationVirtualTab(),
                  _buildAssignPeopleTab(),
                  _buildResourcesRemindersTab(),
                ],
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 8 : 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: isMobile ? 6 : 8),
                      minimumSize: Size(0, isMobile ? 30 : 36),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: (11.5 * ts).roundToDouble(),
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 22, vertical: isMobile ? 6 : 8),
                      minimumSize: Size(0, isMobile ? 30 : 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 1.5,
                      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    ),
                    child: Text(
                      widget.initialSchedule != null ? (isMobile ? 'Update' : 'Update Schedule') : (isMobile ? 'Create' : 'Create Schedule'),
                      style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper: Two-column Row on desktop, stacked Column on mobile
  List<Widget> _buildTwoColumnOrStack({required bool isMob, required Widget first, required Widget second}) {
    if (isMob) {
      return [first, const SizedBox(height: 12), second];
    }
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      ),
    ];
  }

  // TAB 1: BASIC INFO
  Widget _buildBasicInfoTab() {
    final isMob = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    final labelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );
    final hintStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      color: const Color(0xFF94A3B8),
    );

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        // Title
        Text('Schedule Title *', style: labelStyle),
        const SizedBox(height: 3),
        TextField(
          controller: _titleController,
          style: itemStyle,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g., Team Sprint Review, Mathematics Class 9-A...',
            hintStyle: hintStyle,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
        ),
        SizedBox(height: isMob ? 6 : 10),

        // Type & Calendar — stack vertically on mobile
        ..._buildTwoColumnOrStack(
          isMob: isMob,
          first: Builder(
            builder: (context) {
              final List<Map<String, dynamic>> rawCatList = _dynamicCategories.isNotEmpty
                  ? _dynamicCategories
                  : [
                      {'name': 'Meeting', 'label': 'Meeting'},
                      {'name': 'Class', 'label': 'Class'},
                      {'name': 'Exam', 'label': 'Exam'},
                      {'name': 'Event', 'label': 'Event'},
                      {'name': 'Task', 'label': 'Task'},
                      {'name': 'Reminder', 'label': 'Reminder'},
                      {'name': 'Training', 'label': 'Training'},
                      {'name': 'Trip', 'label': 'Trip (Transport)'},
                      {'name': 'School Event', 'label': 'School Event'},
                      {'name': 'Leave', 'label': 'Leave'},
                    ];

              final Map<String, String> dropdownItemsMap = {};
              for (final c in rawCatList) {
                final name = c['name']?.toString() ?? '';
                final label = c['label']?.toString() ?? name;
                if (name.isNotEmpty) {
                  dropdownItemsMap[name] = label;
                }
              }

              final currentVal = _selectedType.isNotEmpty ? _selectedType : 'Meeting';
              if (!dropdownItemsMap.containsKey(currentVal)) {
                dropdownItemsMap[currentVal] = currentVal;
              }

              final dropdownItems = dropdownItemsMap.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle),
                );
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type *', style: labelStyle),
                  const SizedBox(height: 3),
                  DropdownButtonFormField<String>(
                    initialValue: currentVal,
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: inputPad,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    items: dropdownItems,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ],
              );
            },
          ),
          second: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calendar', style: labelStyle),
              const SizedBox(height: 3),
              DropdownButtonFormField<String>(
                initialValue: _selectedCalendarId.isNotEmpty ? _selectedCalendarId : null,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                items: widget.calendars.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCalendarId = val);
                },
              ),
            ],
          ),
        ),
        SizedBox(height: isMob ? 6 : 10),

        // Description
        Text('Description', style: labelStyle),
        const SizedBox(height: 3),
        TextField(
          controller: _descController,
          maxLines: 2,
          style: itemStyle,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Add agenda, meeting instructions, syllabus notes...',
            hintStyle: hintStyle,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
        ),
        SizedBox(height: isMob ? 6 : 10),

        // Color & Priority
        ..._buildTwoColumnOrStack(
          isMob: isMob,
          first: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Badge Color', style: labelStyle),
              const SizedBox(height: 3),
              Wrap(
                spacing: isMob ? 4 : 6,
                runSpacing: 4,
                children: _colorPalette.map((col) {
                  final isSel = col == _selectedColor;
                  final size = isMob ? 20.0 : 24.0;
                  return InkWell(
                    onTap: () => setState(() => _selectedColor = col),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSel ? Colors.black : Colors.transparent, width: 2),
                      ),
                      child: isSel ? Icon(Icons.check, size: isMob ? 12 : 14, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          second: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Priority', style: labelStyle),
              const SizedBox(height: 3),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                items: [
                  DropdownMenuItem(value: 'low', child: Text('Low Priority', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'normal', child: Text('Normal Priority', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'high', child: Text('High Priority', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent (Alert)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 2: DATE & TIME
  Widget _buildDateTimeTab() {
    final isMob = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    final labelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        // All Day Switch
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            dense: true,
            title: Text('All-Day Schedule', style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            subtitle: Text('Spans the full day without start/end times', style: TextStyle(fontSize: (10 * ts).roundToDouble(), color: const Color(0xFF64748B))),
            value: _isAllDay,
            onChanged: (val) => setState(() => _isAllDay = val),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const Divider(height: 12, color: Color(0xFFE2E8F0)),

        // Start Date & Time
        ..._buildTwoColumnOrStack(
          isMob: isMob,
          first: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start Date', style: labelStyle),
              const SizedBox(height: 3),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                  if (picked != null) {
                    setState(() {
                      final diff = _endDate.difference(_startDate);
                      _startDate = picked;
                      _endDate = _startDate.add(diff.isNegative ? Duration.zero : diff);
                    });
                  }
                },
                child: Container(
                  padding: inputPad,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: isMob ? 13 : 15, color: const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM yyyy').format(_startDate),
                          style: itemStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          second: _isAllDay
              ? const SizedBox()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start Time', style: labelStyle),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: Container(
                        padding: inputPad,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: isMob ? 13 : 15, color: const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _startTime.format(context),
                                style: itemStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: isMob ? 6 : 10),

        // End Date & Time
        ..._buildTwoColumnOrStack(
          isMob: isMob,
          first: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('End Date', style: labelStyle),
              const SizedBox(height: 3),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime(2035));
                  if (picked != null) setState(() => _endDate = picked);
                },
                child: Container(
                  padding: inputPad,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: isMob ? 13 : 15, color: const Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM yyyy').format(_endDate),
                          style: itemStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          second: _isAllDay
              ? const SizedBox()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('End Time', style: labelStyle),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: Container(
                        padding: inputPad,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: isMob ? 13 : 15, color: const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _endTime.format(context),
                                style: itemStyle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 4),
        Text(
          'Single session duration. To repeat, configure in Recurrence tab.',
          style: TextStyle(fontSize: (9.5 * ts).roundToDouble(), color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
        SizedBox(height: isMob ? 6 : 10),

        // Timezone
        Text('Time Zone', style: labelStyle),
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          initialValue: _timezone,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          items: [
            DropdownMenuItem(value: 'Asia/Kolkata', child: Text('Asia/Kolkata (IST, GMT+5:30)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'UTC', child: Text('UTC (Universal Time)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'America/New_York', child: Text('America/New_York (EST)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'Europe/London', child: Text('Europe/London (GMT)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'Asia/Dubai', child: Text('Asia/Dubai (GST)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
          ],
          onChanged: (newTz) {
            if (newTz != null && newTz != _timezone) {
              final oldStartNaive = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
              final oldEndNaive = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);

              final utcStart = _convertTimezoneToUtc(oldStartNaive, _timezone);
              final utcEnd = _convertTimezoneToUtc(oldEndNaive, _timezone);

              final newStartInTz = _convertUtcToTimezone(utcStart, newTz);
              final newEndInTz = _convertUtcToTimezone(utcEnd, newTz);

              setState(() {
                _timezone = newTz;
                _startDate = DateTime(newStartInTz.year, newStartInTz.month, newStartInTz.day);
                _startTime = TimeOfDay(hour: newStartInTz.hour, minute: newStartInTz.minute);
                _endDate = DateTime(newEndInTz.year, newEndInTz.month, newEndInTz.day);
                _endTime = TimeOfDay(hour: newEndInTz.hour, minute: newEndInTz.minute);
              });
            }
          },
        ),
      ],
    );
  }
  // TAB 3: RECURRENCE
  Widget _buildRecurrenceTab() {
    String previewText;
    if (_recurrenceFreq == 'none') {
      previewText = 'Single event (does not repeat)';
    } else if (_recurrenceFreq == 'daily') {
      previewText = _recurrenceInterval > 1 ? 'Repeats every $_recurrenceInterval days' : 'Repeats every day';
    } else if (_recurrenceFreq == 'weekdays') {
      previewText = 'Repeats every weekday (Monday to Friday)';
    } else if (_recurrenceFreq == 'weekly') {
      final days = _recurrenceDays.isNotEmpty ? _recurrenceDays.join(', ') : 'the scheduled day';
      previewText = _recurrenceInterval > 1 ? 'Repeats every $_recurrenceInterval weeks on $days' : 'Repeats every week on $days';
    } else if (_recurrenceFreq == 'monthly') {
      previewText = _recurrenceInterval > 1
          ? 'Repeats every $_recurrenceInterval months on the ${_startDate.day}${_getDaySuffix(_startDate.day)}'
          : 'Repeats monthly on the ${_startDate.day}${_getDaySuffix(_startDate.day)}';
    } else if (_recurrenceFreq == 'yearly') {
      previewText = _recurrenceInterval > 1
          ? 'Repeats every $_recurrenceInterval years on ${DateFormat('d MMMM').format(_startDate)}'
          : 'Repeats annually on ${DateFormat('d MMMM').format(_startDate)}';
    } else {
      previewText = 'Repeats every $_recurrenceInterval week(s)';
      if (_recurrenceDays.isNotEmpty) {
        previewText += ' on ${_recurrenceDays.join(', ')}';
      }
    }

    if (_recurrenceFreq != 'none') {
      if (_endType == 'never') {
        previewText += ' (indefinitely)';
      } else if (_endType == 'after_count') {
        previewText += ' (ends after $_endCount occurrences)';
      } else if (_endType == 'until_date' && _recurrenceEndDate != null) {
        previewText += ' (until ${DateFormat('d MMMM yyyy').format(_recurrenceEndDate!)})';
      }
    }

    final isMob = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    final labelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        Text('Repeat Frequency', style: labelStyle),
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          initialValue: _recurrenceFreq == 'biweekly' ? 'weekly' : _recurrenceFreq,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          items: [
            DropdownMenuItem(value: 'none', child: Text('Does not repeat (Single)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'daily', child: Text('Daily (Every day / N days)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'weekdays', child: Text('Every Weekday (Mon to Fri)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly (Chosen days)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly (Every month)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'yearly', child: Text('Annually (Every year)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'custom', child: Text('Custom Recurrence...', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _recurrenceFreq = val;
                if (val == 'weekdays') {
                  _recurrenceDays = ['MO', 'TU', 'WE', 'TH', 'FR'];
                  _recurrenceInterval = 1;
                } else if (val == 'weekly') {
                  if (_recurrenceDays.isEmpty) {
                    final dayNames = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
                    _recurrenceDays = [dayNames[_startDate.weekday] ?? 'MO'];
                  }
                }
              });
            }
          },
        ),

        // Day of week chips for weekly and custom
        if (_recurrenceFreq == 'weekly' || _recurrenceFreq == 'custom') ...[
          SizedBox(height: isMob ? 8 : 12),
          Text('Repeat on Days of Week', style: labelStyle),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].map((d) {
              final isSel = _recurrenceDays.contains(d);
              return FilterChip(
                label: Text(d),
                selected: isSel,
                selectedColor: const Color(0xFF4F46E5),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : const Color(0xFF0F172A),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _recurrenceDays.add(d);
                    } else {
                      _recurrenceDays.remove(d);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],

        // Repeat Interval Stepper for ALL recurring frequencies
        if (_recurrenceFreq != 'none' && _recurrenceFreq != 'weekdays') ...[
          SizedBox(height: isMob ? 8 : 12),
          Text('Repeat Interval', style: labelStyle),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('Repeat every:', style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), color: const Color(0xFF334155), fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () {
                  if (_recurrenceInterval > 1) {
                    setState(() => _recurrenceInterval--);
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text('$_recurrenceInterval', style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () {
                  setState(() => _recurrenceInterval++);
                },
              ),
              Text(
                _recurrenceFreq == 'daily'
                    ? 'day(s)'
                    : (_recurrenceFreq == 'weekly' || _recurrenceFreq == 'custom')
                        ? 'week(s)'
                        : _recurrenceFreq == 'yearly'
                            ? 'year(s)'
                            : 'month(s)',
                style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
              ),
            ],
          ),
        ],

        if (_recurrenceFreq != 'none') ...[
          SizedBox(height: isMob ? 8 : 12),
          Text('Recurrence Ends', style: labelStyle),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _endType = 'never'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    _endType == 'never' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 16,
                    color: _endType == 'never' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Never (Repeats indefinitely)', style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _endType = 'after_count'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _endType == 'after_count' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 16,
                        color: _endType == 'after_count' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text('After:', style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () {
                      setState(() {
                        _endType = 'after_count';
                        if (_endCount > 1) {
                          _endCount--;
                        }
                      });
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _endType == 'after_count' ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _endType == 'after_count' ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text('$_endCount', style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.bold, color: _endType == 'after_count' ? const Color(0xFF4338CA) : const Color(0xFF0F172A))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () {
                      setState(() {
                        _endType = 'after_count';
                        _endCount++;
                      });
                    },
                  ),
                  Text(
                    'occurrences',
                    style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recurrenceEndDate ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 1825)),
              );
              if (picked != null) {
                setState(() {
                  _endType = 'until_date';
                  _recurrenceEndDate = picked;
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    _endType == 'until_date' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 16,
                    color: _endType == 'until_date' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _recurrenceEndDate != null
                          ? 'Until ${DateFormat('d MMMM yyyy').format(_recurrenceEndDate!)}'
                          : 'On specific date...',
                      style: TextStyle(fontSize: (11.5 * ts).roundToDouble(), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Real-time Recurrence Summary Banner
          SizedBox(height: isMob ? 8 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 15, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    previewText,
                    style: TextStyle(fontSize: (10.5 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF3730A3)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // TAB 4: LOCATION & VIRTUAL
  Widget _buildLocationVirtualTab() {
    final isMob = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    const iconConstraints = BoxConstraints(minWidth: 26, minHeight: 26);
    final sectionTitleStyle = TextStyle(
      fontSize: (11.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w800,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );
    final fieldLabelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        // SECTION 1: PHYSICAL CAMPUS VENUE
        Container(
          padding: EdgeInsets.all(isMob ? 6 : 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 5),
                  Text('Physical Venue / Campus', style: sectionTitleStyle),
                ],
              ),
              const SizedBox(height: 6),

              Text('Venue / Campus Address', style: fieldLabelStyle),
              const SizedBox(height: 2),
              TextField(
                controller: _locationController,
                style: itemStyle,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'e.g. Main Campus Auditorium / Science Block',
                  hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 6),

              if (isMob) ...[
                Text('Building / Block', style: fieldLabelStyle),
                const SizedBox(height: 2),
                TextField(
                  controller: _buildingController,
                  style: itemStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'e.g. Admin Block A',
                    hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: inputPad,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Room / Lab / Hall', style: fieldLabelStyle),
                const SizedBox(height: 2),
                TextField(
                  controller: _roomController,
                  style: itemStyle,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'e.g. Conference Room 101 / Lab 2',
                    hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    contentPadding: inputPad,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Building / Block', style: fieldLabelStyle),
                          const SizedBox(height: 2),
                          TextField(
                            controller: _buildingController,
                            style: itemStyle,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g. Science Block A',
                              hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              contentPadding: inputPad,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room / Lab / Hall', style: fieldLabelStyle),
                          const SizedBox(height: 2),
                          TextField(
                            controller: _roomController,
                            style: itemStyle,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'e.g. Physics Lab 204',
                              hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              contentPadding: inputPad,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: isMob ? 6 : 10),

        // SECTION 2: VIRTUAL VIDEO MEETING
        Container(
          padding: EdgeInsets.all(isMob ? 6 : 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.videocam_rounded, size: 13, color: Color(0xFF0891B2)),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('Video Conference', style: sectionTitleStyle),
                  ),
                  InkWell(
                    onTap: _generateVirtualLink,
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text('Auto Link', style: TextStyle(fontSize: (10 * ts).roundToDouble(), fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Text('Meeting Provider', style: fieldLabelStyle),
              const SizedBox(height: 2),
              DropdownButtonFormField<String>(
                initialValue: _virtualProvider,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                items: [
                  DropdownMenuItem(value: 'google_meet', child: Text('Google Meet', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'zoom', child: Text('Zoom Meetings', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'teams', child: Text('Microsoft Teams', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Web URL', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _virtualProvider = val);
                },
              ),
              const SizedBox(height: 6),

              Text('Meeting URL / Join Link', style: fieldLabelStyle),
              const SizedBox(height: 2),
              TextField(
                controller: _virtualUrlController,
                style: TextStyle(fontSize: (10.5 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'https://meet.google.com/...',
                  hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                  suffixIcon: _virtualUrlController.text.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF4F46E5)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          tooltip: 'Copy Link',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _virtualUrlController.text.trim()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Meeting URL copied to clipboard'), duration: Duration(seconds: 2)),
                            );
                          },
                        )
                      : null,
                  suffixIconConstraints: iconConstraints,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // TAB 5: ASSIGN PEOPLE (PREMIUM CHECKBOX CARD GRID)
  Widget _buildAssignPeopleTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMob = MediaQuery.sizeOf(context).width < 600;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    final labelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    final rolesList = _dbRoles;
    final classesList = _dbClasses;

    final allRolesSelected = rolesList.isNotEmpty && rolesList.every((rObj) {
      final roleName = (rObj['name'] ?? '').toString();
      return _isRoleSelected(roleName);
    });

    final filteredUsers = _realUsers.where((u) {
      final query = _searchPeopleController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || role.contains(query);
    }).toList();

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        // 1. MASTER INST-WIDE CHECKBOX CARD - SLEEK & COMPACT
        InkWell(
          onTap: () {
            setState(() {
              if (_selectedVisibility == 'institution_wide' && allRolesSelected) {
                _selectedVisibility = 'shared';
                _selectedRoleKeys.clear();
              } else {
                _selectedVisibility = 'institution_wide';
                for (final rObj in rolesList) {
                  _toggleRoleGroup(rObj, true);
                }
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMob ? 8 : 12, vertical: isMob ? 6 : 8),
            decoration: BoxDecoration(
              color: _selectedVisibility == 'institution_wide'
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedVisibility == 'institution_wide' ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: _selectedVisibility == 'institution_wide' ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Transform.scale(
                  scale: isMob ? 0.85 : 1.0,
                  child: Checkbox(
                    value: _selectedVisibility == 'institution_wide' && allRolesSelected,
                    activeColor: const Color(0xFF10B981),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedVisibility = 'institution_wide';
                          for (final rObj in rolesList) {
                            _toggleRoleGroup(rObj, true);
                          }
                        } else {
                          _selectedVisibility = 'shared';
                          _selectedRoleKeys.clear();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.public_rounded, size: isMob ? 16 : 18, color: const Color(0xFF10B981)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Institution-Wide (All Audience)',
                        style: TextStyle(
                          fontSize: (11 * ts).roundToDouble(),
                          fontWeight: FontWeight.w800,
                          color: _selectedVisibility == 'institution_wide' ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        'Auto-invite all staff, faculty, students & parents',
                        style: TextStyle(fontSize: (9.5 * ts).roundToDouble(), color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: isMob ? 6 : 10),

        // 2. ROLE-BASED PRESETS
        Row(
          children: [
            Text('Quick Select by Role', style: labelStyle),
            if (_isLoadingRoles) ...[
              const SizedBox(width: 6),
              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
            ],
          ],
        ),
        const SizedBox(height: 3),
        if (rolesList.isEmpty)
          Text(_isLoadingRoles ? 'Loading roles...' : 'No roles loaded from database', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rolesList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMob ? 2 : 4,
              childAspectRatio: isMob ? 3.2 : 4.5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (ctx, idx) {
              final rObj = rolesList[idx];
              final roleName = (rObj['name'] ?? '').toString();
              final displayName = (rObj['display_name'] ?? rObj['name'] ?? roleName).toString();
              if (roleName.isEmpty) return const SizedBox();

              final isChecked = _isRoleSelected(roleName);

              return InkWell(
                onTap: () {
                  setState(() {
                    _toggleRoleGroup(rObj, !isChecked);
                  });
                },
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isChecked ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 0.75,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF4F46E5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          onChanged: (val) {
                            setState(() {
                              _toggleRoleGroup(rObj, val == true);
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'All $displayName',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                            color: isChecked ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 3. CLASS-SECTION PRESETS
        SizedBox(height: isMob ? 6 : 10),
        Row(
          children: [
            Text('Filter by Specific Class / Section', style: labelStyle),
            if (_isLoadingClasses) ...[
              const SizedBox(width: 6),
              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
            ],
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  final allClassesSelected = classesList.isNotEmpty && classesList.every((c) => _isClassSectionSelected(c));
                  for (final cObj in classesList) {
                    _toggleClassSection(cObj, !allClassesSelected);
                  }
                });
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              child: Text(
                (classesList.isNotEmpty && classesList.every((c) => _isClassSectionSelected(c))) ? 'Deselect All' : 'Select All',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        if (classesList.isEmpty)
          Text(_isLoadingClasses ? 'Loading classes & sections...' : 'No classes or sections available', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: classesList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMob ? 2 : 4,
              childAspectRatio: isMob ? 3.0 : 4.2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (ctx, idx) {
              final cObj = classesList[idx];
              final displayName = cObj['display_name'] ?? '${cObj['class_name'] ?? ''} - ${cObj['section_name'] ?? ''}';
              if (displayName.isEmpty) return const SizedBox();

              final isChecked = _isClassSectionSelected(cObj);

              return InkWell(
                onTap: () => setState(() => _toggleClassSection(cObj, !isChecked)),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isChecked ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 0.75,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF10B981),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          onChanged: (val) => setState(() => _toggleClassSection(cObj, val == true)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                            color: isChecked ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 3.5. CLASS-SECTION SUBJECT ALLOCATION (NEW SECTION BELOW FILTER BY CLASS/SECTION)
        if (_selectedClassSectionKeys.isNotEmpty) ...[
          SizedBox(height: isMob ? 8 : 12),
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: isMob ? 14 : 16, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text('Class-Section Subject Allocation', style: labelStyle),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Select a specific subject to schedule for that subject\'s teacher & students, or "None" for all students & teachers of the class-section.',
            style: TextStyle(fontSize: (9.5 * ts).roundToDouble(), color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          ..._dbClasses.where((c) => _isClassSectionSelected(c)).map((cObj) {
            final key = _getClassSectionKey(cObj);
            final displayName = cObj['display_name'] ?? '${cObj['class_name']} - ${cObj['section_name']}';
            final subjects = (cObj['subjects'] as List? ?? []).whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
            final currentSubjectId = _selectedClassSectionSubjects[key];

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentSubjectId != null ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: currentSubjectId != null ? 1.2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.class_outlined, size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (subjects.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${subjects.length} Subjects',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String?>(
                    initialValue: currentSubjectId,
                    isExpanded: true,
                    isDense: true,
                    style: itemStyle,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'None (All Students & Teachers of this Class-Section)',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      ...subjects.map((sub) {
                        final sId = sub['id']?.toString();
                        final sName = sub['name']?.toString() ?? 'Subject';
                        final sCode = sub['code']?.toString() ?? '';
                        final tName = sub['teacher_name']?.toString();
                        return DropdownMenuItem<String?>(
                          value: sId,
                          child: Text(
                            '$sName ($sCode)${tName != null && tName.isNotEmpty ? " • $tName" : ""}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedClassSectionSubjects[key] = val;
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],

        SizedBox(height: isMob ? 6 : 10),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        SizedBox(height: isMob ? 6 : 8),

        // 4. SEARCH & ADD INDIVIDUAL MEMBERS
        Text('Add Specific Individual', style: labelStyle),
        const SizedBox(height: 3),
        TextField(
          controller: _searchPeopleController,
          style: itemStyle,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name, email, or role...',
            hintStyle: TextStyle(fontSize: (10.5 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
            prefixIcon: Icon(Icons.search_rounded, size: isMob ? 14 : 16, color: const Color(0xFF64748B)),
            prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            suffixIcon: _isLoadingUsers
                ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 6),

        if (_searchPeopleController.text.trim().isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredUsers.take(6).length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final u = filteredUsers[idx];
                final isAdded = _manualIndividualUsers.any((m) => m['user_id'] == u['id']);

                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    child: Text(
                      (u['full_name'] != null && u['full_name'].toString().isNotEmpty) ? u['full_name'][0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  title: Text(u['full_name'] ?? 'Unknown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  subtitle: Text('${u['role'] ?? ""} • ${u['email'] ?? ""}', style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                  trailing: isAdded
                      ? const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981))
                      : IconButton(
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF4F46E5)),
                          onPressed: () {
                            setState(() {
                              final uid = u['id']?.toString();
                              if (uid != null && !_manualIndividualUsers.any((m) => m['user_id'] == uid)) {
                                _manualIndividualUsers.add({
                                  'user_id': uid,
                                  'name': u['full_name'] ?? 'User',
                                  'role': u['role'] ?? 'Member',
                                  'email': u['email'],
                                  'participation_role': 'required',
                                  'permission': 'can_view',
                                });
                              }
                            });
                          },
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],

        // 5. CURRENT AUDIENCE ROSTER
        Builder(
          builder: (ctx) {
            final totalAudienceCount = _selectedRoleKeys.length + _selectedClassSectionKeys.length + _manualIndividualUsers.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Audience Roster ($totalAudienceCount)', style: labelStyle),
                    if (totalAudienceCount > 0)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRoleKeys.clear();
                            _selectedClassSectionKeys.clear();
                            _selectedClassSectionSubjects.clear();
                            _manualIndividualUsers.clear();
                            _selectedVisibility = 'shared';
                          });
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        child: const Text('Clear All', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (totalAudienceCount == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        'No audience assigned yet. Select roles, class-sections, or search specific members above.',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else ...[
                  // A. Roles in Roster
                  ..._selectedRoleKeys.map((rKey) {
                    final rObj = rolesList.firstWhere(
                      (r) => (r['name'] ?? '').toString().toLowerCase() == rKey,
                      orElse: () => {'name': rKey, 'display_name': rKey[0].toUpperCase() + rKey.substring(1)},
                    );
                    final displayName = (rObj['display_name'] ?? rObj['name'] ?? rKey).toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.groups_rounded, size: 13, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All $displayName',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Role Broadcast • Auto-resolves all active $displayName users',
                                  style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                            onPressed: () => setState(() => _selectedRoleKeys.remove(rKey)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                    );
                  }),

                  // B. Class-Sections in Roster
                  ..._selectedClassSectionKeys.map((csKey) {
                    final cObj = classesList.firstWhere(
                      (c) => _getClassSectionKey(c) == csKey,
                      orElse: () => {'display_name': csKey, 'class_name': csKey, 'section_name': ''},
                    );
                    final clsName = (cObj['class_name'] ?? '').toString();
                    final secName = (cObj['section_name'] ?? '').toString();
                    final displayName = cObj['display_name'] ?? (secName.isNotEmpty ? '$clsName - $secName' : clsName);

                    final subId = _selectedClassSectionSubjects[csKey];
                    Map<String, dynamic>? selectedSub;
                    if (subId != null && cObj['subjects'] is List) {
                      final subList = (cObj['subjects'] as List).whereType<Map>().toList();
                      final subMatches = subList.where((s) => s['id']?.toString() == subId).toList();
                      if (subMatches.isNotEmpty) selectedSub = Map<String, dynamic>.from(subMatches.first);
                    }

                    final bool hasSub = selectedSub != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: hasSub ? const Color(0xFF4F46E5).withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: hasSub ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasSub ? Icons.menu_book_rounded : Icons.school_rounded,
                              size: 13,
                              color: hasSub ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasSub
                                      ? '$displayName • ${selectedSub['name']} (${selectedSub['code'] ?? ""})'
                                      : displayName,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                Text(
                                  hasSub
                                      ? 'Subject Offering • Teacher: ${selectedSub['teacher_name'] ?? "Assigned Subject Teacher"} • Enrolled Students'
                                      : 'Class-Section Offering • General Schedule (All Students & Section Teachers)',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: hasSub ? FontWeight.w600 : FontWeight.normal,
                                    color: hasSub ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                            onPressed: () {
                              setState(() {
                                _selectedClassSectionKeys.remove(csKey);
                                _selectedClassSectionSubjects.remove(csKey);
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                    );
                  }),

                  // C. Manual Individuals in Roster
                  ..._manualIndividualUsers.map((u) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (u['name'] != null && u['name'].toString().isNotEmpty) ? u['name'][0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name'] ?? 'Individual User',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      (u['email'] != null && u['email'].toString().isNotEmpty)
                                          ? '${u['email']} • ${u['role'] ?? "Member"}'
                                          : '${u['role'] ?? "Member"}',
                                      style: TextStyle(fontSize: 9.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                                onPressed: () => setState(() => _manualIndividualUsers.remove(u)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButton<String>(
                                  value: u['participation_role'] ?? 'required',
                                  underline: const SizedBox(),
                                  isDense: true,
                                  iconSize: 14,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  items: [
                                    DropdownMenuItem(value: 'required', child: Text('Required', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87))),
                                    DropdownMenuItem(value: 'optional', child: Text('Optional', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87))),
                                    DropdownMenuItem(value: 'fyi', child: Text('FYI', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87))),
                                  ],
                                  onChanged: (val) => setState(() => u['participation_role'] = val),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButton<String>(
                                  value: (u['permission'] == 'read_write' || u['permission'] == 'can_edit' || u['permission'] == 'can_manage') ? 'can_edit' : 'can_view',
                                  underline: const SizedBox(),
                                  isDense: true,
                                  iconSize: 14,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'can_view',
                                      child: Text('Read Only', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                    ),
                                    DropdownMenuItem(
                                      value: 'can_edit',
                                      child: Text('Can Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      u['permission'] = val == 'can_edit' ? 'can_edit' : 'can_view';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // TAB 6: RESOURCES & REMINDERS
  Widget _buildResourcesRemindersTab() {
    final isMob = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double ts = (MediaQuery.sizeOf(context).width / 550).clamp(0.70, 1.0);
    final inputPad = EdgeInsets.symmetric(horizontal: isMob ? 8 : 10, vertical: isMob ? 5 : 7);
    final labelStyle = TextStyle(
      fontSize: (10.5 * ts).roundToDouble(),
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );
    final itemStyle = TextStyle(
      fontSize: (11 * ts).roundToDouble(),
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    final hasMatchingRoute = _selectedRouteId != null && _transportRoutes.any((r) => r['id']?.toString() == _selectedRouteId);
    final effectiveRouteId = hasMatchingRoute ? _selectedRouteId : null;

    return ListView(
      padding: EdgeInsets.all(isMob ? 6 : 14),
      children: [
        // 1. ASSIGN TRANSPORT ROUTE / FLEET RUN
        Container(
          padding: EdgeInsets.all(isMob ? 8 : 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selectedRouteId != null
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.6)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: _selectedRouteId != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, size: 16, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign Transport Route', style: labelStyle),
                        Text(
                          'Creates individual daily trips for driver dashboard execution',
                          style: TextStyle(fontSize: (9.5 * ts).roundToDouble(), color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingRoutes)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                    )
                  else if (_selectedRouteId != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedRouteId = null;
                          _selectedRoute = null;
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 13, color: Color(0xFFEF4444)),
                      label: Text('Remove', style: TextStyle(fontSize: (10 * ts).roundToDouble(), color: const Color(0xFFEF4444))),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Route Dropdown Selector
              DropdownButtonFormField<String>(
                key: ValueKey('route_dropdown_${effectiveRouteId ?? "none"}_${_transportRoutes.length}'),
                initialValue: effectiveRouteId,
                isExpanded: true,
                isDense: true,
                hint: Text(
                  _isLoadingRoutes
                      ? 'Loading assigned transport routes...'
                      : (_transportRoutes.isEmpty ? 'No routes with assigned bus & driver found' : 'Select transport route to schedule...'),
                  style: TextStyle(fontSize: (11 * ts).roundToDouble(), color: const Color(0xFF94A3B8)),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: inputPad,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                ),
                items: _transportRoutes.map((r) {
                  final rId = r['id']?.toString() ?? '';
                  final rName = r['route_name']?.toString() ?? 'Route';
                  final rCode = r['route_code']?.toString() ?? '';
                  final busNo = r['bus_number']?.toString() ?? r['registration_no']?.toString() ?? '';
                  final driver = r['driver_name']?.toString() ?? '';
                  final timeSpan = '${r['start_time'] ?? ''} - ${r['end_time'] ?? ''}'.trim();

                  return DropdownMenuItem<String>(
                    value: rId,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$rName ($rCode)${busNo.isNotEmpty ? ' • Bus: $busNo' : ''}${driver.isNotEmpty ? ' • Driver: $driver' : ''}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: itemStyle,
                          ),
                        ),
                        if (timeSpan.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(timeSpan, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedRouteId = val;
                    if (val != null) {
                      final match = _transportRoutes.where((r) => r['id']?.toString() == val).toList();
                      if (match.isNotEmpty) {
                        _selectedRoute = match.first;
                        // Auto-fill title if empty or default
                        if (_titleController.text.trim().isEmpty || _titleController.text.trim() == 'Untitled Schedule') {
                          _titleController.text = '${_selectedRoute!['route_name']} (${_selectedRoute!['route_code'] ?? 'Route'})';
                        }
                        _selectedType = 'Trip';

                        // Auto-assign Driver as participant if driver profile id exists
                        final driverProfId = _selectedRoute!['driver_profile_id']?.toString();
                        final driverName = _selectedRoute!['driver_name']?.toString() ?? 'Driver';
                        if (driverProfId != null && driverProfId.isNotEmpty) {
                          final alreadyIn = _assignedPeople.any((p) => p['user_id']?.toString() == driverProfId);
                          if (!alreadyIn) {
                            _assignedPeople.add({
                              'user_id': driverProfId,
                              'name': driverName,
                              'role': 'driver',
                              'participation_role': 'required',
                              'permission': 'can_view',
                            });
                          }
                        }
                      }
                    } else {
                      _selectedRoute = null;
                    }
                  });
                },
              ),

              if (_selectedRoute != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Route Linked: ${_selectedRoute!['route_name']} • Vehicle: ${_selectedRoute!['bus_number'] ?? _selectedRoute!['registration_no'] ?? 'Unassigned'} • Driver: ${_selectedRoute!['driver_name'] ?? 'Unassigned'}',
                          style: TextStyle(fontSize: (10 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: isMob ? 8 : 12),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        SizedBox(height: isMob ? 8 : 12),

        // 2. BOOK PHYSICAL RESOURCES
        Text('Book Physical Resources', style: labelStyle),
        const SizedBox(height: 3),
        Text('Reserve classrooms, labs, auditorium, or facilities with conflict detection', style: TextStyle(fontSize: (10 * ts).roundToDouble(), color: const Color(0xFF64748B))),
        const SizedBox(height: 6),

        if (widget.resources.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text('No physical resources registered in this school.', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            ),
          )
        else
          ...widget.resources.map((res) {
            final isBooked = _selectedResourceIds.contains(res.id);
            return Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                title: Text(res.name, style: TextStyle(fontSize: (11 * ts).roundToDouble(), fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                subtitle: Text('${res.type.toUpperCase()} • Code: ${res.code} • Capacity: ${res.capacity}', style: TextStyle(fontSize: (9.5 * ts).roundToDouble(), color: const Color(0xFF64748B))),
                value: isBooked,
                dense: true,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedResourceIds.add(res.id);
                    } else {
                      _selectedResourceIds.remove(res.id);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            );
          }),

        SizedBox(height: isMob ? 8 : 12),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        SizedBox(height: isMob ? 8 : 12),

        // 3. REMINDER CONFIGURATION
        Text('Reminder Notification Timing', style: labelStyle),
        const SizedBox(height: 3),
        DropdownButtonFormField<int>(
          initialValue: _reminderMinutes,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          items: [
            DropdownMenuItem(value: 0, child: Text('At time of event', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 5, child: Text('5 minutes before', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 10, child: Text('10 minutes before', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 15, child: Text('15 minutes before (Default)', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 30, child: Text('30 minutes before', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 60, child: Text('1 hour before', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 1440, child: Text('1 day before', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _reminderMinutes = val);
          },
        ),
        SizedBox(height: isMob ? 6 : 8),

        Text('Notification Channel', style: labelStyle),
        const SizedBox(height: 3),
        DropdownButtonFormField<String>(
          initialValue: _reminderChannel,
          isExpanded: true,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            contentPadding: inputPad,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          items: [
            DropdownMenuItem(value: 'in_app', child: Text('In-App Notification & Sound', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'push', child: Text('Mobile & Web Push Notification', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'email', child: Text('Email Alert', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
            DropdownMenuItem(value: 'sms_whatsapp', child: Text('SMS / WhatsApp Alert', overflow: TextOverflow.ellipsis, maxLines: 1, style: itemStyle)),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _reminderChannel = val);
          },
        ),
      ],
    );
  }
}
