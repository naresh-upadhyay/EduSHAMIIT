import 'package:flutter/material.dart';
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
            if (str.isNotEmpty) parsedRoles.add({'name': str});
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
          {'name': 'teacher'},
          {'name': 'driver'},
          {'name': 'student'},
          {'name': 'parent'},
          {'name': 'admin'},
          {'name': 'staff'},
          {'name': 'hr'},
          {'name': 'finance'},
          {'name': 'transport'},
          {'name': 'principal'},
          {'name': 'director'},
          {'name': 'support'}
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
          } else if (item != null) {
            final str = item.toString().trim();
            if (str.isNotEmpty) parsedClasses.add({'name': str});
          }
        }
        if (parsedClasses.isNotEmpty && mounted) {
          setState(() {
            _dbClasses = parsedClasses;
            _isLoadingClasses = false;
            if (_isRoleSelected('student')) {
              _toggleStudentRole(true);
            }
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _dbClasses = [
          {'name': '10A'},
          {'name': 'IX-A'},
          {'name': 'X-A'},
          {'name': 'X-B'},
          {'name': 'Class 1-A'},
          {'name': 'Class 2-A'},
          {'name': 'Class 9-A'},
          {'name': 'Grade 11-Sci'},
          {'name': 'Grade 12-Sci'}
        ];
        _isLoadingClasses = false;
        if (_isRoleSelected('student')) {
          _toggleStudentRole(true);
        }
      });
    }
  }

  bool _isRoleSelected(String roleName) {
    final target = roleName.trim().toLowerCase();
    return _assignedPeople.any((p) {
      final isRoleBroadcast = p['user_id'] == null;
      if (!isRoleBroadcast) return false;
      final r = (p['target_role'] ?? p['role'] ?? '').toString().trim().toLowerCase();
      final n = (p['name'] ?? '').toString().trim().toLowerCase();
      final targetPlural = '${target}s';
      final allTargetPlural = 'all ${target}s';
      return r == target || n == target || n == targetPlural || n == allTargetPlural || n == 'all $target' || (target == 'student' && n.contains('student'));
    });
  }

  void _toggleRoleGroup(String roleName, bool enable) {
    final target = roleName.trim().toLowerCase();
    if (enable) {
      if (target == 'student') {
        _toggleStudentRole(true);
      } else {
        if (!_isRoleSelected(target)) {
          _assignedPeople.add({
            'user_id': null,
            'name': 'All ${roleName[0].toUpperCase()}${roleName.substring(1)}s',
            'role': target,
            'target_role': target,
            'participation_role': 'required',
            'permission': 'can_view',
          });
        }
      }
    } else {
      if (target == 'student') {
        _toggleStudentRole(false);
      } else {
        _assignedPeople.removeWhere((p) {
          if (p['user_id'] != null) return false;
          final r = (p['target_role'] ?? p['role'] ?? '').toString().trim().toLowerCase();
          final n = (p['name'] ?? '').toString().trim().toLowerCase();
          final targetPlural = '${target}s';
          final allTargetPlural = 'all ${target}s';
          return r == target || n == target || n == targetPlural || n == allTargetPlural || n == 'all $target';
        });
      }
    }
  }

  bool _isClassSelected(String className) {
    final target = className.trim().toLowerCase();
    return _assignedPeople.any((p) {
      final isClassBroadcast = p['user_id'] == null;
      if (!isClassBroadcast) return false;
      final n = (p['name'] ?? p['target_class'] ?? '').toString().trim().toLowerCase();
      return n == target;
    });
  }

  void _toggleStudentRole(bool enable) {
    if (enable) {
      // Remove any individual class group items from _assignedPeople so roster stays clean
      _assignedPeople.removeWhere((p) => (p['role'] ?? '') == 'Class Group' || _dbClasses.any((c) => (c['name'] ?? '').toString().trim().toLowerCase() == (p['name'] ?? '').toString().trim().toLowerCase()));
      // Add "All Students" role item if not present
      if (!_isRoleSelected('student')) {
        _assignedPeople.add({
          'user_id': null,
          'name': 'All Students',
          'role': 'student',
          'participation_role': 'required',
          'permission': 'can_view',
        });
      }
    } else {
      // Unselect "All Students" role item
      _assignedPeople.removeWhere((p) {
        final r = (p['role'] ?? '').toString().trim().toLowerCase();
        final n = (p['name'] ?? '').toString().trim().toLowerCase();
        return r == 'student' || n.contains('student');
      });
    }
  }

  void _toggleClassGroup(String className, bool enable) {
    final target = className.trim();
    if (enable) {
      if (!_isClassSelected(target)) {
        _assignedPeople.add({
          'user_id': null,
          'name': target,
          'role': 'Class Group',
          'participation_role': 'required',
          'permission': 'can_view',
        });
      }
      final allClassesSelected = _dbClasses.isNotEmpty && _dbClasses.every((c) => _isClassSelected((c['name'] ?? '').toString()));
      if (allClassesSelected) {
        _toggleStudentRole(true);
      }
    } else {
      _assignedPeople.removeWhere((p) => (p['name'] ?? '').toString().trim().toLowerCase() == target.toLowerCase());
      _assignedPeople.removeWhere((p) {
        final r = (p['role'] ?? '').toString().trim().toLowerCase();
        final n = (p['name'] ?? '').toString().trim().toLowerCase();
        return r == 'student' || n.contains('student');
      });
    }
  }

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  String _timezone = 'Asia/Kolkata';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchCategories();
    _fetchRealProfiles('');
    _fetchAssignableRoles();
    _fetchAssignableClasses();

    final init = widget.initialSchedule;
    if (init != null) {
      _selectedVisibility = init.visibility;
    }
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

    _startDate = init?.startTime ?? DateTime(now.year, now.month, now.day, defaultHour);
    _startTime = TimeOfDay(hour: _startDate.hour, minute: _startDate.minute);
    _endDate = init?.endTime ?? _startDate.add(const Duration(hours: 1));
    _endTime = TimeOfDay(hour: _endDate.hour, minute: _endDate.minute);
    _isAllDay = init?.isAllDay ?? false;
    _timezone = init?.timezone ?? 'Asia/Kolkata';

    if (init != null) {
      if (init.recurrenceRule != null) {
        _recurrenceFreq = init.recurrenceRule!.frequency;
        _recurrenceInterval = init.recurrenceRule!.interval;
        _recurrenceDays = List.from(init.recurrenceRule!.daysOfWeek);
        _endType = init.recurrenceRule!.endType;
        _endCount = init.recurrenceRule!.endCount ?? 10;
        _recurrenceEndDate = init.recurrenceRule!.endDate;
      } else if (init.isRecurring) {
        _recurrenceFreq = 'daily';
        _recurrenceInterval = 1;
        _endType = 'never';
        _endCount = 10;
      } else {
        _recurrenceFreq = 'none';
      }
      for (final p in init.participants) {
        final targetRole = (p.targetRole ?? p.role ?? '').trim();
        final targetClass = (p.targetClass ?? '').trim();
        final isIndividual = p.userId != null && p.userId!.isNotEmpty;
        
        String pName = (p.fullName != null && p.fullName!.isNotEmpty) ? p.fullName! : '';
        if (pName.isEmpty) {
          if (targetRole.isNotEmpty) {
            pName = 'All ${targetRole[0].toUpperCase()}${targetRole.substring(1)}s';
          } else if (targetClass.isNotEmpty) {
            pName = targetClass;
          } else {
            pName = 'User';
          }
        }

        _assignedPeople.add({
          'user_id': p.userId,
          'name': pName,
          'role': isIndividual ? (p.role ?? targetRole) : targetRole,
          'email': p.email,
          'target_role': targetRole,
          'target_class': targetClass,
          'participation_role': p.participationRole,
          'permission': p.permission,
        });
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

    final startDt = DateTime(
      _startDate.year, _startDate.month, _startDate.day,
      _isAllDay ? 0 : _startTime.hour, _isAllDay ? 0 : _startTime.minute,
    );
    final endDt = DateTime(
      _endDate.year, _endDate.month, _endDate.day,
      _isAllDay ? 23 : _endTime.hour, _isAllDay ? 59 : _endTime.minute,
    );

    final hexColor = '#${(_selectedColor.r * 255).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.g * 255).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.b * 255).round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();

    final payload = <String, dynamic>{
      'calendar_id': _selectedCalendarId,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'schedule_type': _selectedType,
      'category': _selectedCategory,
      'color': hexColor,
      'priority': _selectedPriority,
      'start_time': startDt.toIso8601String(),
      'end_time': endDt.toIso8601String(),
      'is_all_day': _isAllDay,
      'timezone': _timezone,
      'location_name': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      'room': _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
      'building': _buildingController.text.trim().isNotEmpty ? _buildingController.text.trim() : null,
      'virtual_meeting_url': _virtualUrlController.text.trim().isNotEmpty ? _virtualUrlController.text.trim() : null,
      'virtual_meeting_provider': _virtualUrlController.text.trim().isNotEmpty ? _virtualProvider : null,
      'visibility': _selectedVisibility,
      'is_recurring': _recurrenceFreq != 'none',
      'participants': _assignedPeople.map((p) {
        final userId = p['user_id']?.toString();
        final role = p['role']?.toString();
        final isClassGroup = role == 'Class Group';
        final isRoleGroup = userId == null || userId.isEmpty;

        String participantType = 'individual';
        if (isClassGroup) {
          participantType = 'class_section';
        } else if (isRoleGroup) {
          participantType = 'role';
        }

        return {
          'user_id': (userId != null && userId.isNotEmpty) ? userId : null,
          'target_role': (isRoleGroup && !isClassGroup) ? role : null,
          'target_class': isClassGroup ? p['name'] : null,
          'participant_type': participantType,
          'participation_role': p['participation_role'] ?? 'required',
          'permission': p['permission'] ?? 'can_view',
        };
      }).toList(),
      'resources': _selectedResourceIds.map((rid) => {
        'resource_id': rid,
        'start_time': startDt.toIso8601String(),
        'end_time': endDt.toIso8601String(),
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
      if (_recurrenceFreq == 'weekly' && days.isEmpty) {
        final dayNames = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
        days = [dayNames[_startDate.weekday] ?? 'MO'];
      }
      payload['is_recurring'] = true;
      payload['recurrence'] = {
        'frequency': _recurrenceFreq,
        'interval': _recurrenceInterval,
        'days_of_week': days,
        'end_type': _endType,
        'end_count': _endCount,
        'end_date': _recurrenceEndDate?.toIso8601String(),
      };
    } else {
      payload['is_recurring'] = false;
      payload['recurrence'] = null;
    }

    final isRecurringEdit = widget.initialSchedule != null &&
        (widget.initialSchedule!.isRecurring ||
            widget.initialSchedule!.recurrenceRule != null ||
            widget.initialSchedule!.recurringParentId != null);

    if (isRecurringEdit) {
      showDialog(
        context: context,
        builder: (ctx) {
          return RecurrenceScopeDialog(
            actionTitle: 'Edit Recurring Schedule',
            onScopeSelected: (scope) {
              Navigator.of(context).pop(); // Closes CreateEditScheduleDialog (RecurrenceScopeDialog already popped itself)
              final instanceDateStr = _startDate.toIso8601String().split('T')[0];
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: isDesktop ? 780 : double.infinity,
        height: isDesktop ? 680 : 700,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Gradient Icon Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedColor,
                          _selectedColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.initialSchedule != null ? Icons.edit_calendar_rounded : Icons.add_task_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.initialSchedule != null ? 'Edit Schedule' : 'Create New Schedule',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _selectedColor.withValues(alpha: isDark ? 0.25 : 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedType,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : _selectedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure schedule timeline, location, participants, resources, and reminders',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
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
                      icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF64748B)),
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),

            // Ultra-Premium Segmented Tab Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                splashBorderRadius: BorderRadius.circular(10),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(vertical: 2),
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Basic Info'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Date & Time'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.repeat_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Recurrence'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Location & Virtual'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Assign People'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.notifications_active_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Resources & Reminders'),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 3,
                      shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                    ),
                    child: Text(
                      widget.initialSchedule != null ? 'Update Schedule' : 'Create Schedule',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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

  // TAB 1: BASIC INFO
  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Title
        const Text('Schedule Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'e.g., Team Sprint Review, Mathematics Class 9-A, Route 101 Morning...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 18),

        // Type & Calendar Row
        Row(
          children: [
            Expanded(
              child: Builder(
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
                      child: Text(entry.value),
                    );
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schedule Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: currentVal,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCalendarId.isNotEmpty ? _selectedCalendarId : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    items: widget.calendars.map((c) {
                      return DropdownMenuItem(value: c.id, child: Text(c.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCalendarId = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Description
        const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add agenda, meeting instructions, syllabus notes, or trip itinerary...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 18),

        // Color & Priority
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Badge Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colorPalette.map((col) {
                      final isSel = col == _selectedColor;
                      return InkWell(
                        onTap: () => setState(() => _selectedColor = col),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSel ? Colors.black : Colors.transparent, width: 2),
                          ),
                          child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPriority,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                      DropdownMenuItem(value: 'high', child: Text('High Priority')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent (Immediate Alert)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPriority = val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // TAB 2: DATE & TIME
  Widget _buildDateTimeTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // All Day Switch
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            title: const Text('All-Day Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            subtitle: const Text('Spans the full day without specific start/end times', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            value: _isAllDay,
            onChanged: (val) => setState(() => _isAllDay = val),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const Divider(height: 24, color: Color(0xFFE2E8F0)),

        // Start Date & Time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(DateFormat('d MMMM yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isAllDay) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(_startTime.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),

        // End Date & Time
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime(2035));
                      if (picked != null) setState(() => _endDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(DateFormat('d MMMM yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isAllDay) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(_endTime.format(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Single session duration for this meeting. For repeating schedule duration, configure "Recurrence Ends" in the Recurrence tab.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 18),

        // Timezone
        const Text('Time Zone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _timezone,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          items: const [
            DropdownMenuItem(value: 'Asia/Kolkata', child: Text('Asia/Kolkata (IST, GMT+5:30)')),
            DropdownMenuItem(value: 'UTC', child: Text('UTC (Coordinated Universal Time)')),
            DropdownMenuItem(value: 'America/New_York', child: Text('America/New_York (EST)')),
            DropdownMenuItem(value: 'Europe/London', child: Text('Europe/London (GMT)')),
            DropdownMenuItem(value: 'Asia/Dubai', child: Text('Asia/Dubai (GST)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _timezone = val);
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Repeat Frequency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _recurrenceFreq == 'biweekly' ? 'weekly' : _recurrenceFreq,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('Does not repeat (Single Event)')),
            DropdownMenuItem(value: 'daily', child: Text('Daily (Repeats every day / N days)')),
            DropdownMenuItem(value: 'weekdays', child: Text('Every Weekday (Monday to Friday)')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly (Every week / N weeks on chosen days)')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly (Every month / N months)')),
            DropdownMenuItem(value: 'yearly', child: Text('Annually (Every year / N years)')),
            DropdownMenuItem(value: 'custom', child: Text('Custom Recurrence Pattern...')),
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
          const SizedBox(height: 18),
          const Text('Repeat on Days of Week', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].map((d) {
              final isSel = _recurrenceDays.contains(d);
              return FilterChip(
                label: Text(d),
                selected: isSel,
                selectedColor: const Color(0xFF4F46E5),
                labelStyle: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF0F172A)),
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

        // Repeat Interval Stepper for ALL recurring frequencies (Daily, Weekly, Monthly, Yearly, Custom)
        if (_recurrenceFreq != 'none' && _recurrenceFreq != 'weekdays') ...[
          const SizedBox(height: 18),
          const Text('Repeat Interval', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Repeat every: ', style: TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                onPressed: () {
                  if (_recurrenceInterval > 1) {
                    setState(() => _recurrenceInterval--);
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text('$_recurrenceInterval', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                onPressed: () {
                  setState(() => _recurrenceInterval++);
                },
              ),
              const SizedBox(width: 4),
              Text(
                _recurrenceFreq == 'daily'
                    ? 'day(s)'
                    : (_recurrenceFreq == 'weekly' || _recurrenceFreq == 'custom')
                        ? 'week(s)'
                        : _recurrenceFreq == 'yearly'
                            ? 'year(s)'
                            : 'month(s)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
        ],

        if (_recurrenceFreq != 'none') ...[
          const SizedBox(height: 18),
          const Text('Recurrence Ends', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _endType = 'never'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _endType == 'never' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: _endType == 'never' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  const Text('Never (Repeats indefinitely)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _endType = 'after_count'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _endType == 'after_count' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: _endType == 'after_count' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text('After $_endCount occurrences', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  if (_endType == 'after_count') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 14),
                      onPressed: () {
                        if (_endCount > 1) setState(() => _endCount--);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 14),
                      onPressed: () {
                        setState(() => _endCount++);
                      },
                    ),
                  ],
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _endType == 'until_date' ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: _endType == 'until_date' ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _recurrenceEndDate != null
                        ? 'Until ${DateFormat('d MMMM yyyy').format(_recurrenceEndDate!)}'
                        : 'On specific date...',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          // Real-time Recurrence Summary Banner
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    previewText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3730A3)),
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Physical Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            hintText: 'Search campus address, landmark, or venue...',
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _buildingController,
                decoration: InputDecoration(
                  labelText: 'Building',
                  hintText: 'e.g. Admin Block',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'Room / Lab',
                  hintText: 'e.g. Conference Room A',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 24),

        // Virtual Meeting Section
        const Text('Virtual Video Meeting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _virtualProvider,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
                items: const [
                  DropdownMenuItem(value: 'google_meet', child: Text('Google Meet')),
                  DropdownMenuItem(value: 'zoom', child: Text('Zoom')),
                  DropdownMenuItem(value: 'teams', child: Text('Microsoft Teams')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Video URL')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _virtualProvider = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _generateVirtualLink,
              icon: const Icon(Icons.videocam_rounded, size: 16),
              label: const Text('Generate Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _virtualUrlController,
          decoration: InputDecoration(
            labelText: 'Meeting URL',
            hintText: 'https://meet.google.com/...',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }

  // TAB 5: ASSIGN PEOPLE (PREMIUM CHECKBOX CARD GRID)
  Widget _buildAssignPeopleTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rolesList = _dbRoles;
    final classesList = _dbClasses;

    final allRolesSelected = rolesList.isNotEmpty && rolesList.every((rObj) {
      final roleName = (rObj['name'] ?? '').toString();
      return _isRoleSelected(roleName);
    });

    final allClassesSelected = classesList.isNotEmpty && classesList.every((cObj) {
      final className = (cObj['name'] ?? '').toString();
      return _isClassSelected(className);
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
      padding: const EdgeInsets.all(20),
      children: [
        // 1. MASTER INST-WIDE CHECKBOX CARD
        InkWell(
          onTap: () {
            setState(() {
              if (_selectedVisibility == 'institution_wide' && allRolesSelected) {
                _selectedVisibility = 'shared';
                _assignedPeople.clear();
              } else {
                _selectedVisibility = 'institution_wide';
                for (final rObj in rolesList) {
                  final roleName = (rObj['name'] ?? '').toString();
                  if (roleName.isNotEmpty) {
                    if (roleName.toLowerCase() == 'student') {
                      _toggleStudentRole(true);
                    } else if (!_isRoleSelected(roleName)) {
                      _assignedPeople.add({
                        'user_id': null,
                        'name': 'All ${roleName.toUpperCase()}s',
                        'role': roleName,
                        'participation_role': 'required',
                        'permission': 'can_view',
                      });
                    }
                  }
                }
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedVisibility == 'institution_wide'
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedVisibility == 'institution_wide' ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: _selectedVisibility == 'institution_wide' ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _selectedVisibility == 'institution_wide' && allRolesSelected,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedVisibility = 'institution_wide';
                        for (final rObj in rolesList) {
                          final roleName = (rObj['name'] ?? '').toString();
                          if (roleName.isNotEmpty) {
                            if (roleName.toLowerCase() == 'student') {
                              _toggleStudentRole(true);
                            } else if (!_isRoleSelected(roleName)) {
                              _assignedPeople.add({
                                'user_id': null,
                                'name': 'All ${roleName.toUpperCase()}s',
                                'role': roleName,
                                'participation_role': 'required',
                                'permission': 'can_view',
                              });
                            }
                          }
                        }
                      } else {
                        _selectedVisibility = 'shared';
                        _assignedPeople.clear();
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Icon(Icons.public_rounded, size: 20, color: Color(0xFF10B981)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select All (Institution-Wide Audience)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedVisibility == 'institution_wide' ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const Text(
                        'Globally opens this schedule to all students, teachers, parents, drivers, and staff across the school.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),

        // 2. TARGET SYSTEM ROLES CHECKBOX GRID
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text('Select Target Roles', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                if (_isLoadingRoles) ...[
                  const SizedBox(width: 8),
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: allRolesSelected,
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        for (final rObj in rolesList) {
                          final roleName = (rObj['name'] ?? '').toString();
                          if (roleName.isNotEmpty) {
                            if (roleName.toLowerCase() == 'student') {
                              _toggleStudentRole(true);
                            } else if (!_isRoleSelected(roleName)) {
                              _assignedPeople.add({
                                'user_id': null,
                                'name': 'All ${roleName.toUpperCase()}s',
                                'role': roleName,
                                'participation_role': 'required',
                                'permission': 'can_view',
                              });
                            }
                          }
                        }
                      } else {
                        _assignedPeople.clear();
                      }
                    });
                  },
                ),
                Text(
                  'Select All Roles',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF4F46E5)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ROLES CHECKBOX GRID CARDS
        if (rolesList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_isLoadingRoles ? 'Loading system roles...' : 'No system roles available.', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rolesList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 4.5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (ctx, idx) {
              final rObj = rolesList[idx];
              final roleName = (rObj['name'] ?? '').toString();
              if (roleName.isEmpty) return const SizedBox();

              final isChecked = _isRoleSelected(roleName);

              return InkWell(
                onTap: () {
                  setState(() {
                    _toggleRoleGroup(roleName, !isChecked);
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
                        scale: 0.8,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFF4F46E5),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          onChanged: (val) {
                            setState(() {
                              _toggleRoleGroup(roleName, val == true);
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'All ${roleName[0].toUpperCase()}${roleName.substring(1)}s',
                          style: TextStyle(
                            fontSize: 10.5,
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

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 10),

        // 3. TARGET ACADEMIC CLASSES CHECKBOX GRID
        if (_isRoleSelected('student')) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All Academic Classes are included automatically because "All Students" role is selected above.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text('Select Specific Academic Classes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  if (_isLoadingClasses) ...[
                    const SizedBox(width: 6),
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
              Row(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: allClassesSelected,
                      activeColor: const Color(0xFF10B981),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _toggleStudentRole(true);
                          } else {
                            _toggleStudentRole(false);
                          }
                        });
                      },
                    ),
                  ),
                  Text(
                    'Select All Classes',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // CLASSES CHECKBOX GRID CARDS
          if (classesList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_isLoadingClasses ? 'Loading academic classes...' : 'No academic classes available.', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: classesList.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 4.5,
                crossAxisSpacing: 6,
                mainAxisSpacing: 4,
              ),
              itemBuilder: (ctx, idx) {
                final cObj = classesList[idx];
                final className = (cObj['name'] ?? '').toString();
                if (className.isEmpty) return const SizedBox();

                final isChecked = _isClassSelected(className);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _toggleClassGroup(className, !isChecked);
                    });
                  },
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
                          scale: 0.8,
                          child: Checkbox(
                            value: isChecked,
                            activeColor: const Color(0xFF10B981),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            onChanged: (val) {
                              setState(() {
                                _toggleClassGroup(className, val == true);
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            className,
                            style: TextStyle(
                              fontSize: 10.5,
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
        ],

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),

        // 4. UNIVERSAL INSTITUTE SEARCH BAR
        Row(
          children: [
            const Icon(Icons.person_search_rounded, size: 18, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Text('Search & Add Individual Person Across Institute', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 8),

        TextField(
          controller: _searchPeopleController,
          decoration: InputDecoration(
            hintText: 'Search any person by name, email, role, or department...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
            suffixIcon: _isLoadingUsers
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                : (_searchPeopleController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16), onPressed: () => setState(() => _searchPeopleController.clear()))
                    : null),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Live Database Search Dropdown Results
        if (_realUsers.isNotEmpty && _searchPeopleController.text.trim().isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredUsers.take(6).length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final u = filteredUsers[idx];
                final userId = u['id']?.toString();
                final name = u['full_name'] ?? 'User';
                final role = u['role'] ?? 'Staff';
                final email = u['email'] ?? '';
                final avatar = u['avatar_url']?.toString();
                final isAdded = _assignedPeople.any((p) {
                  final pUserId = p['user_id']?.toString();
                  final pEmail = (p['email'] ?? '').toString().toLowerCase();
                  final targetEmail = email.toString().toLowerCase();

                  if (userId != null && userId.isNotEmpty && pUserId != null && pUserId.isNotEmpty) {
                    return pUserId == userId;
                  }
                  if (targetEmail.isNotEmpty && pEmail.isNotEmpty) {
                    return pEmail == targetEmail;
                  }
                  return false;
                });

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF4F46E5),
                      backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar == null || avatar.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    subtitle: Text('$role • $email', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                    trailing: ElevatedButton.icon(
                      onPressed: isAdded
                          ? null
                          : () {
                              setState(() {
                                _assignedPeople.add({
                                  'user_id': userId,
                                  'name': name,
                                  'role': role,
                                  'email': email,
                                  'participation_role': 'required',
                                  'permission': 'can_view',
                                });
                              });
                            },
                      icon: Icon(isAdded ? Icons.check_rounded : Icons.add_rounded, size: 14),
                      label: Text(isAdded ? 'Added' : 'Add', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdded ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : const Color(0xFF4F46E5),
                        foregroundColor: isAdded ? (isDark ? Colors.white54 : const Color(0xFF94A3B8)) : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: const Size(56, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 14),

        // 5. UNIFIED ASSIGNED ROSTER TABLE
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current Audience Roster (${_assignedPeople.length})',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            if (_assignedPeople.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _assignedPeople.clear()),
                icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFFEF4444)),
                label: const Text('Clear All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_assignedPeople.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_ind_outlined, size: 28, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                const SizedBox(height: 6),
                Text(
                  'No target audience or participants selected yet',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ],
            ),
          )
        else
          ..._assignedPeople.map((p) {
            final isClass = p['role'] == 'Class Group';
            final isRoleGroup = p['user_id'] == null && !isClass;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isRoleGroup
                          ? const Color(0xFFEEF2FF)
                          : (isClass ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRoleGroup ? Icons.people_alt_rounded : (isClass ? Icons.school_rounded : Icons.person_rounded),
                      size: 14,
                      color: isRoleGroup ? const Color(0xFF4F46E5) : (isClass ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          (p['email'] != null && p['email'].toString().isNotEmpty)
                              ? '${p['email']} • ${p['role']}'
                              : '${p['role']}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: p['participation_role'] ?? 'required',
                    underline: const SizedBox(),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: [
                      DropdownMenuItem(value: 'required', child: Text('Required', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87))),
                      DropdownMenuItem(value: 'optional', child: Text('Optional', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87))),
                      DropdownMenuItem(value: 'fyi', child: Text('FYI', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87))),
                    ],
                    onChanged: (val) {
                      setState(() => p['participation_role'] = val);
                    },
                  ),
                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButton<String>(
                      value: (p['permission'] == 'read_write' || p['permission'] == 'can_edit' || p['permission'] == 'can_manage') ? 'can_edit' : 'can_view',
                      underline: const SizedBox(),
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: [
                        DropdownMenuItem(
                          value: 'can_view',
                          child: Text('Read Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                        ),
                        DropdownMenuItem(
                          value: 'can_edit',
                          child: Text('Can Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          p['permission'] = val == 'can_edit' ? 'can_edit' : 'can_view';
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    onPressed: () {
                      setState(() => _assignedPeople.remove(p));
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }


  // TAB 6: RESOURCES & REMINDERS
  Widget _buildResourcesRemindersTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Book Physical Resources', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Reserve classrooms, labs, auditorium, or transport buses with conflict detection', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 12),

        ...widget.resources.map((res) {
          final isBooked = _selectedResourceIds.contains(res.id);
          return Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              title: Text(res.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              subtitle: Text('${res.type.toUpperCase()} • Code: ${res.code} • Capacity: ${res.capacity}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              value: isBooked,
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

        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 24),

        // Reminder Configuration
        const Text('Reminder Notification Timing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _reminderMinutes,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          items: const [
            DropdownMenuItem(value: 0, child: Text('At time of event')),
            DropdownMenuItem(value: 5, child: Text('5 minutes before')),
            DropdownMenuItem(value: 10, child: Text('10 minutes before')),
            DropdownMenuItem(value: 15, child: Text('15 minutes before (Default)')),
            DropdownMenuItem(value: 30, child: Text('30 minutes before')),
            DropdownMenuItem(value: 60, child: Text('1 hour before')),
            DropdownMenuItem(value: 1440, child: Text('1 day before')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _reminderMinutes = val);
          },
        ),
        const SizedBox(height: 16),

        const Text('Notification Channel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _reminderChannel,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
          items: const [
            DropdownMenuItem(value: 'in_app', child: Text('In-App Notification & Sound')),
            DropdownMenuItem(value: 'push', child: Text('Mobile & Web Push Notification')),
            DropdownMenuItem(value: 'email', child: Text('Email Alert')),
            DropdownMenuItem(value: 'sms_whatsapp', child: Text('SMS / WhatsApp Alert')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _reminderChannel = val);
          },
        ),
      ],
    );
  }
}
