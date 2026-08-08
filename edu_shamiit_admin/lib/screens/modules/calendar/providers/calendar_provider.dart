import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/calendar_models.dart';

class CalendarState {
  final bool isLoading;
  final String? error;
  final CalendarViewMode viewMode;
  final DateTime selectedDate;
  final List<CalendarModel> calendars;
  final List<ScheduleModel> schedules;
  final List<CalendarResourceModel> resources;
  final CalendarSummaryModel summary;
  final String searchQuery;
  final String selectedCategory;
  final String selectedStatus;
  final String selectedPriority;
  final String? activeCalendarId;
  final Set<String> activeFilterPills;
  final bool onlyAssignedToMe;
  final bool isRightPanelOpen;
  final List<Map<String, dynamic>> scheduleCategories;

  CalendarState({
    this.isLoading = false,
    this.error,
    this.viewMode = CalendarViewMode.week,
    required this.selectedDate,
    this.calendars = const [],
    this.schedules = const [],
    this.resources = const [],
    required this.summary,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.selectedStatus = 'All',
    this.selectedPriority = 'All',
    this.activeCalendarId,
    this.activeFilterPills = const {'my_schedule', 'assigned_to_me', 'team_schedule', 'department', 'public_holidays'},
    this.onlyAssignedToMe = false,
    this.isRightPanelOpen = true,
    this.scheduleCategories = const [],
  });

  CalendarState copyWith({
    bool? isLoading,
    String? error,
    CalendarViewMode? viewMode,
    DateTime? selectedDate,
    List<CalendarModel>? calendars,
    List<ScheduleModel>? schedules,
    List<CalendarResourceModel>? resources,
    CalendarSummaryModel? summary,
    String? searchQuery,
    String? selectedCategory,
    String? selectedStatus,
    String? selectedPriority,
    String? activeCalendarId,
    bool clearActiveCalendarId = false,
    Set<String>? activeFilterPills,
    bool? onlyAssignedToMe,
    bool? isRightPanelOpen,
    List<Map<String, dynamic>>? scheduleCategories,
  }) {
    return CalendarState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      viewMode: viewMode ?? this.viewMode,
      selectedDate: selectedDate ?? this.selectedDate,
      calendars: calendars ?? this.calendars,
      schedules: schedules ?? this.schedules,
      resources: resources ?? this.resources,
      summary: summary ?? this.summary,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      activeCalendarId: clearActiveCalendarId ? null : (activeCalendarId ?? this.activeCalendarId),
      activeFilterPills: activeFilterPills ?? this.activeFilterPills,
      onlyAssignedToMe: onlyAssignedToMe ?? this.onlyAssignedToMe,
      isRightPanelOpen: isRightPanelOpen ?? this.isRightPanelOpen,
      scheduleCategories: scheduleCategories ?? this.scheduleCategories,
    );
  }


  /// Formatted date range label for the header (e.g., '26 May – 1 Jun 2025')
  String get formattedDateRange {
    switch (viewMode) {
      case CalendarViewMode.day:
        return DateFormat('d MMMM yyyy').format(selectedDate);
      case CalendarViewMode.threeDay:
        final end3 = selectedDate.add(const Duration(days: 2));
        if (selectedDate.month == end3.month) {
          return '${selectedDate.day} – ${end3.day} ${DateFormat('MMMM yyyy').format(selectedDate)}';
        }
        return '${DateFormat('d MMM').format(selectedDate)} – ${DateFormat('d MMM yyyy').format(end3)}';
      case CalendarViewMode.week:
        final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        if (monday.month == sunday.month) {
          return '${monday.day} – ${sunday.day} ${DateFormat('MMMM yyyy').format(monday)}';
        } else if (monday.year == sunday.year) {
          return '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM yyyy').format(sunday)}';
        }
        return '${DateFormat('d MMM yyyy').format(monday)} – ${DateFormat('d MMM yyyy').format(sunday)}';
      case CalendarViewMode.month:
        return DateFormat('MMMM yyyy').format(selectedDate);
      case CalendarViewMode.year:
        return DateFormat('yyyy').format(selectedDate);
      case CalendarViewMode.agenda:
      case CalendarViewMode.timeline:
        final startW = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        final endW = startW.add(const Duration(days: 6));
        return '${DateFormat('d MMM').format(startW)} – ${DateFormat('d MMM yyyy').format(endW)}';
    }
  }
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(
          CalendarState(
            selectedDate: DateTime.now(),
            summary: CalendarSummaryModel(),
          ),
        ) {
    loadAll();
  }

  final ApiService _api = ApiService();
  List<ScheduleModel> _rawSchedules = [];

  /// Initial full sync
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.wait([
      fetchCalendars(),
      fetchScheduleCategories(),
      fetchSchedules(),
      fetchSummary(),
      fetchResources(),
    ]);
    state = state.copyWith(isLoading: false);
  }


  /// Apply local filters over raw schedules for 0ms instantaneous UI updates
  List<ScheduleModel> _filterSchedules(List<ScheduleModel> raw) {
    return raw.where((s) {
      // 1. Specific Calendar Filter (Dropdown)
      if (state.activeCalendarId != null &&
          state.activeCalendarId!.isNotEmpty &&
          state.activeCalendarId != 'all' &&
          state.activeCalendarId != 'All Calendars') {
        if (s.calendarId != state.activeCalendarId) return false;
      }

      // 2. Priority Filter
      if (state.selectedPriority != 'All' && state.selectedPriority.isNotEmpty) {
        if (s.priority.toLowerCase() != state.selectedPriority.toLowerCase()) return false;
      }

      // 3. Status Filter
      if (state.selectedStatus != 'All' && state.selectedStatus.isNotEmpty) {
        if (s.status.toLowerCase() != state.selectedStatus.toLowerCase()) return false;
      }

      // 4. Category Filter
      if (state.selectedCategory != 'All' && state.selectedCategory.isNotEmpty) {
        final cat = state.selectedCategory.toLowerCase();
        final match = s.category.toLowerCase().contains(cat) || s.scheduleType.toLowerCase().contains(cat);
        if (!match) return false;
      }

      // 5. Search Query
      if (state.searchQuery.isNotEmpty) {
        final q = state.searchQuery.toLowerCase();
        final match = s.title.toLowerCase().contains(q) ||
            (s.description ?? '').toLowerCase().contains(q) ||
            (s.locationName ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }

      // 6. Header Filter Pills:
      if (state.activeFilterPills.isEmpty) return false;

      // Strict calendar ID filtering: if a schedule has a calendarId, enforce activeFilterPills state
      if (s.calendarId.isNotEmpty) {
        return state.activeFilterPills.contains(s.calendarId);
      }

      bool matchesPill = false;

      if (state.activeFilterPills.contains('my_schedule')) {
        if (s.scheduleType == 'Event' ||
            s.scheduleType == 'Meeting' ||
            s.category == 'Meetings' ||
            s.category == 'General') {
          matchesPill = true;
        }
      }

      if (!matchesPill && state.activeFilterPills.contains('assigned_to_me')) {
        if (s.participants.isNotEmpty || s.scheduleType == 'Task' || s.category == 'Tasks') {
          matchesPill = true;
        }
      }

      if (!matchesPill && state.activeFilterPills.contains('team_schedule')) {
        if (s.scheduleType == 'Class' ||
            s.scheduleType == 'Exam' ||
            s.scheduleType == 'Training' ||
            s.category == 'Classes' ||
            s.category == 'Training' ||
            s.category == 'Exams') {
          matchesPill = true;
        }
      }

      if (!matchesPill && state.activeFilterPills.contains('department')) {
        if (s.category == 'HR' ||
            s.category == 'Transport' ||
            s.scheduleType == 'Trip' ||
            s.scheduleType == 'Bus Route') {
          matchesPill = true;
        }
      }

      if (!matchesPill && state.activeFilterPills.contains('public_holidays')) {
        if (s.category == 'School Events' ||
            s.category == 'Holidays' ||
            s.title.toLowerCase().contains('holiday') ||
            s.title.toLowerCase().contains('yoga') ||
            s.title.toLowerCase().contains('vacation') ||
            s.title.toLowerCase().contains('day')) {
          matchesPill = true;
        }
      }

      return matchesPill;
    }).toList();
  }


  /// Change Calendar View Mode
  void setViewMode(CalendarViewMode mode) {
    state = state.copyWith(viewMode: mode);
    fetchSchedules();
  }

  /// Date Navigation Controls
  void goToToday() {
    state = state.copyWith(selectedDate: DateTime.now());
    fetchSchedules();
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    fetchSchedules();
  }

  void previousPeriod() {
    DateTime next;
    switch (state.viewMode) {
      case CalendarViewMode.day:
        next = state.selectedDate.subtract(const Duration(days: 1));
        break;
      case CalendarViewMode.threeDay:
        next = state.selectedDate.subtract(const Duration(days: 3));
        break;
      case CalendarViewMode.week:
      case CalendarViewMode.timeline:
      case CalendarViewMode.agenda:
        next = state.selectedDate.subtract(const Duration(days: 7));
        break;
      case CalendarViewMode.month:
        next = DateTime(state.selectedDate.year, state.selectedDate.month - 1, state.selectedDate.day);
        break;
      case CalendarViewMode.year:
        next = DateTime(state.selectedDate.year - 1, state.selectedDate.month, state.selectedDate.day);
        break;
    }
    state = state.copyWith(selectedDate: next);
    fetchSchedules();
  }

  void nextPeriod() {
    DateTime next;
    switch (state.viewMode) {
      case CalendarViewMode.day:
        next = state.selectedDate.add(const Duration(days: 1));
        break;
      case CalendarViewMode.threeDay:
        next = state.selectedDate.add(const Duration(days: 3));
        break;
      case CalendarViewMode.week:
      case CalendarViewMode.timeline:
      case CalendarViewMode.agenda:
        next = state.selectedDate.add(const Duration(days: 7));
        break;
      case CalendarViewMode.month:
        next = DateTime(state.selectedDate.year, state.selectedDate.month + 1, state.selectedDate.day);
        break;
      case CalendarViewMode.year:
        next = DateTime(state.selectedDate.year + 1, state.selectedDate.month, state.selectedDate.day);
        break;
    }
    state = state.copyWith(selectedDate: next);
    fetchSchedules();
  }

  /// Toggle Filter Pills (My Schedule, Assigned to Me, Team Schedule, Department, Public Holidays)
  void toggleFilterPill(String pillId) {
    final updated = Set<String>.from(state.activeFilterPills);
    if (updated.contains(pillId)) {
      updated.remove(pillId);
    } else {
      updated.add(pillId);
    }
    final onlyAssigned = updated.contains('assigned_to_me') && updated.length == 1;
    state = state.copyWith(activeFilterPills: updated, onlyAssignedToMe: onlyAssigned);
    // Instant local filter update
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  /// Select All or Deselect All calendar filter pills
  void selectAllCalendars(bool selectAll) {
    if (selectAll) {
      final allIds = state.calendars.map((c) => c.id).toSet();
      allIds.addAll({'my_schedule', 'assigned_to_me', 'team_schedule', 'department', 'public_holidays'});
      state = state.copyWith(activeFilterPills: allIds);
    } else {
      state = state.copyWith(activeFilterPills: <String>{});
    }
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }


  /// Set Active Specific Calendar Filter
  void setActiveCalendarId(String? calId) {
    final shouldClear = calId == null || calId == 'all' || calId == 'All Calendars' || calId.isEmpty;
    state = state.copyWith(
      activeCalendarId: shouldClear ? null : calId,
      clearActiveCalendarId: shouldClear,
    );
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  /// Search & Filter Settings
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(selectedCategory: category);
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status);
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  void setPriorityFilter(String priority) {
    state = state.copyWith(selectedPriority: priority);
    state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
    fetchSchedules();
  }

  void toggleAssignedToMe() {
    state = state.copyWith(onlyAssignedToMe: !state.onlyAssignedToMe);
    fetchSchedules();
  }

  void toggleRightPanel() {
    state = state.copyWith(isRightPanelOpen: !state.isRightPanelOpen);
  }

  // ==========================================================================
  // API INTEGRATIONS
  // ==========================================================================

  /// Fetch dynamic schedule categories/types from public.schedule_categories database table
  Future<void> fetchScheduleCategories() async {
    try {
      final res = await _api.get('/calendar/categories', query: {'type': 'schedule'}, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).whereType<Map<String, dynamic>>().toList();
        state = state.copyWith(scheduleCategories: list);
      }
    } catch (e) {
      debugPrint('[CalendarProvider] fetchScheduleCategories error: $e');
    }
  }

  /// Fetch list of accessible calendars
  Future<void> fetchCalendars() async {

    try {
      final res = await _api.get('/calendars', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((c) => CalendarModel.fromJson(c))
            .toList();

        final allCalIds = list.map((c) => c.id).toSet();
        final newActivePills = Set<String>.from(state.activeFilterPills)..addAll(allCalIds);

        state = state.copyWith(
          calendars: list,
          activeFilterPills: newActivePills,
        );
      }
    } catch (e) {
      debugPrint('[CalendarProvider] fetchCalendars error: $e');
    }
  }


  /// Fetch schedules for current active view and date range
  Future<void> fetchSchedules() async {
    try {
      DateTime start;
      DateTime end;

      switch (state.viewMode) {
        case CalendarViewMode.day:
          start = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 0, 0, 0);
          end = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 23, 59, 59);
          break;
        case CalendarViewMode.threeDay:
          start = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 0, 0, 0);
          end = start.add(const Duration(days: 3, microseconds: -1));
          break;
        case CalendarViewMode.week:
        case CalendarViewMode.timeline:
        case CalendarViewMode.agenda:
          final monday = state.selectedDate.subtract(Duration(days: state.selectedDate.weekday - 1));
          start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
          end = start.add(const Duration(days: 7, microseconds: -1));
          break;
        case CalendarViewMode.month:
          start = DateTime(state.selectedDate.year, state.selectedDate.month, 1, 0, 0, 0)
              .subtract(const Duration(days: 7));
          end = DateTime(state.selectedDate.year, state.selectedDate.month + 1, 0, 23, 59, 59)
              .add(const Duration(days: 7));
          break;
        case CalendarViewMode.year:
          start = DateTime(state.selectedDate.year, 1, 1, 0, 0, 0);
          end = DateTime(state.selectedDate.year, 12, 31, 23, 59, 59);
          break;
      }

      Map<String, dynamic> queryParams = {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
        'limit': 500,
      };

      if (state.activeCalendarId != null &&
          state.activeCalendarId!.isNotEmpty &&
          state.activeCalendarId != 'all' &&
          state.activeCalendarId != 'All Calendars') {
        queryParams['calendar_id'] = state.activeCalendarId;
      }
      if (state.searchQuery.isNotEmpty) {
        queryParams['search'] = state.searchQuery;
      }
      if (state.selectedCategory != 'All') {
        queryParams['category'] = state.selectedCategory;
      }
      if (state.selectedPriority != 'All') {
        queryParams['priority'] = state.selectedPriority;
      }
      if (state.selectedStatus != 'All') {
        queryParams['status'] = state.selectedStatus;
      }
      if (state.onlyAssignedToMe) {
        queryParams['assigned_to_me'] = 'true';
      }

      final res = await _api.get('/schedules', query: queryParams, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((s) => ScheduleModel.fromJson(s))
            .toList();
        _rawSchedules = list;
        state = state.copyWith(schedules: _filterSchedules(_rawSchedules));
      }
    } catch (e) {
      debugPrint('[CalendarProvider] fetchSchedules error: $e');
    }
  }

  /// Fetch summary counters for right-hand intelligence panel
  Future<void> fetchSummary() async {
    try {
      final res = await _api.get('/calendar/summary', useCache: false);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final sum = CalendarSummaryModel.fromJson(res['data']);
        state = state.copyWith(summary: sum);
      }
    } catch (e) {
      debugPrint('[CalendarProvider] fetchSummary error: $e');
    }
  }

  /// Fetch bookable resources
  Future<void> fetchResources() async {
    try {
      final res = await _api.get('/calendar/resources', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((r) => CalendarResourceModel.fromJson(r))
            .toList();
        state = state.copyWith(resources: list);
      }
    } catch (e) {
      debugPrint('[CalendarProvider] fetchResources error: $e');
    }
  }

  /// Create new schedule
  Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/schedules', payload);
      if (res['success'] == true) {
        await Future.wait([fetchSchedules(), fetchSummary()]);
        return {'success': true, 'message': 'Schedule created successfully'};
      }
      return {'success': false, 'error': res['error'] ?? res['detail'] ?? 'Failed to create schedule'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update existing schedule (supports drag/drop and modal edit with Google Calendar scopes)
  Future<Map<String, dynamic>> updateSchedule(
    String scheduleId,
    Map<String, dynamic> payload, {
    String recurrenceScope = 'entire_series',
    String? targetInstanceDate,
  }) async {
    try {
      String query = '?recurrence_scope=$recurrenceScope';
      if (targetInstanceDate != null && targetInstanceDate.isNotEmpty) {
        query += '&target_instance_date=$targetInstanceDate';
      }
      final res = await _api.patch('/schedules/$scheduleId$query', payload);
      if (res['success'] == true) {
        await Future.wait([fetchSchedules(), fetchSummary()]);
        return {'success': true, 'message': 'Schedule updated successfully'};
      }
      return {'success': false, 'error': res['error'] ?? res['detail'] ?? 'Failed to update schedule'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Soft delete schedule with Google Calendar recurrence scopes
  Future<bool> deleteSchedule(
    String scheduleId, {
    String recurrenceScope = 'entire_series',
    String? targetInstanceDate,
  }) async {
    try {
      String query = '?recurrence_scope=$recurrenceScope';
      if (targetInstanceDate != null && targetInstanceDate.isNotEmpty) {
        query += '&target_instance_date=$targetInstanceDate';
      }
      final res = await _api.delete('/schedules/$scheduleId$query');
      if (res['success'] == true) {
        await Future.wait([fetchSchedules(), fetchSummary()]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CalendarProvider] deleteSchedule error: $e');
      return false;
    }
  }

  /// Duplicate schedule
  Future<bool> duplicateSchedule(String scheduleId) async {
    try {
      final res = await _api.post('/schedules/$scheduleId/duplicate', {});
      if (res['success'] == true) {
        await Future.wait([fetchSchedules(), fetchSummary()]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CalendarProvider] duplicateSchedule error: $e');
      return false;
    }
  }

  /// Respond to RSVP (Accept, Decline, Tentative)
  Future<bool> submitRSVP(String scheduleId, String status, {String? declineReason}) async {
    try {
      final res = await _api.post('/schedules/$scheduleId/rsvp', {
        'status': status,
        if (declineReason != null) 'decline_reason': declineReason,
      });
      if (res['success'] == true) {
        await Future.wait([fetchSchedules(), fetchSummary()]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CalendarProvider] submitRSVP error: $e');
      return false;
    }
  }

  /// Add Discussion Comment
  Future<ScheduleCommentModel?> addComment(String scheduleId, String commentText) async {
    try {
      final res = await _api.post('/schedules/$scheduleId/comments', {
        'comment_text': commentText,
      });
      if (res['success'] == true && res['data'] != null) {
        final comment = ScheduleCommentModel.fromJson(res['data']);
        final parentId = scheduleId.split('_inst_')[0];
        final updatedList = state.schedules.map((s) {
          if (s.id == scheduleId || s.id == parentId) {
            final updatedComments = List<ScheduleCommentModel>.from(s.comments)..add(comment);
            return s.copyWith(comments: updatedComments);
          }
          return s;
        }).toList();
        state = state.copyWith(schedules: updatedList);
        return comment;
      }
      return null;
    } catch (e) {
      debugPrint('[CalendarProvider] addComment error: $e');
      return null;
    }
  }

  /// Fetch fresh schedule details including live RSVPs and discussion comments
  Future<ScheduleModel?> fetchScheduleDetails(String scheduleId) async {
    try {
      final res = await _api.get('/schedules/$scheduleId');
      if (res['success'] == true && res['data'] != null) {
        final liveSchedule = ScheduleModel.fromJson(res['data']);
        final parentId = scheduleId.split('_inst_')[0];
        final updatedList = state.schedules.map((s) {
          if (s.id == scheduleId || s.id == parentId) {
            return liveSchedule;
          }
          return s;
        }).toList();
        state = state.copyWith(schedules: updatedList);
        return liveSchedule;
      }
      return null;
    } catch (e) {
      debugPrint('[CalendarProvider] fetchScheduleDetails error: $e');
      return null;
    }
  }

  /// Create new custom calendar
  Future<bool> createCalendar(String name, String color, String type) async {
    try {
      final res = await _api.post('/calendars', {
        'name': name,
        'color': color,
        'type': type,
        'visibility': 'shared',
      });
      if (res['success'] == true) {
        await fetchCalendars();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[CalendarProvider] createCalendar error: $e');
      return false;
    }
  }
}

/// Main Provider instance
final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});
