import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/space_booking_models.dart';
import '../services/space_booking_api_service.dart';

class SpaceBookingState {
  final SpaceBookingKpis kpis;
  final List<SpaceTimelineRoom> roomsTimeline;
  final SpaceBookingListResponse bookingRequests;
  final SpaceUtilizationStats utilization;
  final SpaceAnalyticsReport analyticsReport;
  final List<BookableRoomItem> bookableRooms;
  final DateTime selectedDate;
  final String timelineViewMode; // 'Day', 'Week', 'Month'
  final String displayMode; // 'Timeline', 'List'
  final String selectedNav; // 'My Bookings', 'Pending Requests', etc.
  final String statusFilter; // 'All', 'Pending', 'Approved', 'Rejected'
  final String selectedDomain; // 'all', 'rooms', 'facilities'
  final String selectedBuildingId;
  final String selectedFloorId;
  final String selectedRoomId;
  final String selectedSpaceType;
  final String selectedCapacity;
  final String selectedPurpose;
  final String selectedClassId;
  final String selectedDepartment;
  final DateTime? dateRangeFrom;
  final DateTime? dateRangeTo;
  final String searchQuery;
  final String sortBy;
  final String sortOrder;
  final int currentPage;
  final int pageSize;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;

  const SpaceBookingState({
    this.kpis = const SpaceBookingKpis(),
    this.roomsTimeline = const [],
    this.bookingRequests = const SpaceBookingListResponse(items: [], totalCount: 0, page: 1, pageSize: 10, totalPages: 1),
    this.utilization = const SpaceUtilizationStats(),
    this.analyticsReport = const SpaceAnalyticsReport(),
    this.bookableRooms = const [],
    required this.selectedDate,
    this.timelineViewMode = 'Day',
    this.displayMode = 'Timeline',
    this.selectedNav = 'Booking Spaces',
    this.statusFilter = 'All',
    this.selectedDomain = 'all',
    this.selectedBuildingId = 'all',
    this.selectedFloorId = 'all',
    this.selectedRoomId = 'all',
    this.selectedSpaceType = 'All',
    this.selectedCapacity = 'Any Capacity',
    this.selectedPurpose = 'All',
    this.selectedClassId = 'all',
    this.selectedDepartment = 'all',
    this.dateRangeFrom,
    this.dateRangeTo,
    this.searchQuery = '',
    this.sortBy = 'booking_date',
    this.sortOrder = 'ASC',
    this.currentPage = 1,
    this.pageSize = 10,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  SpaceBookingState copyWith({
    SpaceBookingKpis? kpis,
    List<SpaceTimelineRoom>? roomsTimeline,
    SpaceBookingListResponse? bookingRequests,
    SpaceUtilizationStats? utilization,
    SpaceAnalyticsReport? analyticsReport,
    List<BookableRoomItem>? bookableRooms,
    DateTime? selectedDate,
    String? timelineViewMode,
    String? displayMode,
    String? selectedNav,
    String? statusFilter,
    String? selectedDomain,
    String? selectedBuildingId,
    String? selectedFloorId,
    String? selectedRoomId,
    String? selectedSpaceType,
    String? selectedCapacity,
    String? selectedPurpose,
    String? selectedClassId,
    String? selectedDepartment,
    DateTime? dateRangeFrom,
    DateTime? dateRangeTo,
    bool clearDateRange = false,
    String? searchQuery,
    String? sortBy,
    String? sortOrder,
    int? currentPage,
    int? pageSize,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return SpaceBookingState(
      kpis: kpis ?? this.kpis,
      roomsTimeline: roomsTimeline ?? this.roomsTimeline,
      bookingRequests: bookingRequests ?? this.bookingRequests,
      utilization: utilization ?? this.utilization,
      analyticsReport: analyticsReport ?? this.analyticsReport,
      bookableRooms: bookableRooms ?? this.bookableRooms,
      selectedDate: selectedDate ?? this.selectedDate,
      timelineViewMode: timelineViewMode ?? this.timelineViewMode,
      displayMode: displayMode ?? this.displayMode,
      selectedNav: selectedNav ?? this.selectedNav,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedDomain: selectedDomain ?? this.selectedDomain,
      selectedBuildingId: selectedBuildingId ?? this.selectedBuildingId,
      selectedFloorId: selectedFloorId ?? this.selectedFloorId,
      selectedRoomId: selectedRoomId ?? this.selectedRoomId,
      selectedSpaceType: selectedSpaceType ?? this.selectedSpaceType,
      selectedCapacity: selectedCapacity ?? this.selectedCapacity,
      selectedPurpose: selectedPurpose ?? this.selectedPurpose,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      dateRangeFrom: clearDateRange ? null : (dateRangeFrom ?? this.dateRangeFrom),
      dateRangeTo: clearDateRange ? null : (dateRangeTo ?? this.dateRangeTo),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

class SpaceBookingNotifier extends StateNotifier<SpaceBookingState> {
  final SpaceBookingApiService _service;

  SpaceBookingNotifier(this._service)
      : super(SpaceBookingState(
          selectedDate: DateTime.now(),
          dateRangeFrom: null,
          dateRangeTo: null,
        )) {
    loadAll();
  }

  (DateTime, DateTime) _getTimelineRangeFor(DateTime date, String mode) {
    if (mode == 'Week') {
      final startOfWeek = date.subtract(Duration(days: (date.weekday - 1) % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return (startOfWeek, endOfWeek);
    } else if (mode == 'Month') {
      final startOfMonth = DateTime(date.year, date.month, 1);
      final endOfMonth = DateTime(date.year, date.month + 1, 0);
      return (startOfMonth, endOfMonth);
    } else {
      return (date, date);
    }
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final range = _getTimelineRangeFor(state.selectedDate, state.timelineViewMode);
      final results = await Future.wait([
        _service.getKpis(date: state.selectedDate),
        _service.getTimeline(
          date: state.selectedDate,
          startDate: range.$1,
          endDate: range.$2,
          buildingId: state.selectedBuildingId,
          roomType: state.selectedSpaceType,
        ),
        _service.getRequests(
          status: state.statusFilter,
          buildingId: state.selectedBuildingId,
          roomType: state.selectedSpaceType,
          purpose: state.selectedPurpose,
          search: state.searchQuery,
          dateFrom: state.dateRangeFrom,
          dateTo: state.dateRangeTo,
          sortBy: state.sortBy,
          sortOrder: state.sortOrder,
          page: state.currentPage,
          pageSize: state.pageSize,
        ),
        _service.getUtilizationStats(date: state.selectedDate),
        _service.getBookableRooms(
          buildingId: state.selectedBuildingId,
          roomType: state.selectedSpaceType,
        ),
        _service.getAnalyticsReport(
          buildingId: state.selectedBuildingId,
          timeframe: 'today',
          date: state.selectedDate,
        ),
      ]);

      state = state.copyWith(
        kpis: results[0] as SpaceBookingKpis,
        roomsTimeline: results[1] as List<SpaceTimelineRoom>,
        bookingRequests: results[2] as SpaceBookingListResponse,
        utilization: results[3] as SpaceUtilizationStats,
        bookableRooms: results[4] as List<BookableRoomItem>,
        analyticsReport: results[5] as SpaceAnalyticsReport,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadAnalyticsReport({String timeframe = 'today'}) async {
    try {
      final results = await Future.wait([
        _service.getAnalyticsReport(
          buildingId: state.selectedBuildingId,
          timeframe: timeframe,
          date: state.selectedDate,
        ),
        _service.getUtilizationStats(date: state.selectedDate),
      ]);
      state = state.copyWith(
        analyticsReport: results[0] as SpaceAnalyticsReport,
        utilization: results[1] as SpaceUtilizationStats,
      );
    } catch (_) {}
  }

  Future<void> changeDate(DateTime newDate) async {
    state = state.copyWith(selectedDate: newDate);
    final range = _getTimelineRangeFor(newDate, state.timelineViewMode);
    final results = await Future.wait([
      _service.getKpis(date: newDate),
      _service.getTimeline(
        date: newDate,
        startDate: range.$1,
        endDate: range.$2,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
      ),
      _service.getUtilizationStats(date: newDate),
      _service.getAnalyticsReport(
        buildingId: state.selectedBuildingId,
        timeframe: 'today',
        date: newDate,
      ),
    ]);
    state = state.copyWith(
      kpis: results[0] as SpaceBookingKpis,
      roomsTimeline: results[1] as List<SpaceTimelineRoom>,
      utilization: results[2] as SpaceUtilizationStats,
      analyticsReport: results[3] as SpaceAnalyticsReport,
    );
  }

  Future<void> setTimelineViewMode(String mode) async {
    state = state.copyWith(timelineViewMode: mode);
    final range = _getTimelineRangeFor(state.selectedDate, mode);
    try {
      final timeline = await _service.getTimeline(
        date: state.selectedDate,
        startDate: range.$1,
        endDate: range.$2,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
      );
      state = state.copyWith(roomsTimeline: timeline);
    } catch (_) {}
  }

  void setDisplayMode(String mode) {
    state = state.copyWith(displayMode: mode);
  }

  void jumpToToday() {
    changeDate(DateTime.now());
  }

  void nextDate() {
    if (state.timelineViewMode == 'Day') {
      changeDate(state.selectedDate.add(const Duration(days: 1)));
    } else if (state.timelineViewMode == 'Week') {
      changeDate(state.selectedDate.add(const Duration(days: 7)));
    } else if (state.timelineViewMode == 'Month') {
      final cur = state.selectedDate;
      changeDate(DateTime(cur.year, cur.month + 1, cur.day));
    } else {
      changeDate(state.selectedDate.add(const Duration(days: 1)));
    }
  }

  void previousDate() {
    if (state.timelineViewMode == 'Day') {
      changeDate(state.selectedDate.subtract(const Duration(days: 1)));
    } else if (state.timelineViewMode == 'Week') {
      changeDate(state.selectedDate.subtract(const Duration(days: 7)));
    } else if (state.timelineViewMode == 'Month') {
      final cur = state.selectedDate;
      changeDate(DateTime(cur.year, cur.month - 1, cur.day));
    } else {
      changeDate(state.selectedDate.subtract(const Duration(days: 1)));
    }
  }

  Future<void> setSelectedNav(String nav) async {
    if (nav == 'Booking Calendar' || nav == 'Booking Space') {
      state = state.copyWith(selectedNav: 'Booking Spaces');
      return;
    } else if (nav == 'Pending Requests') {
      state = state.copyWith(selectedNav: 'Booking Requests', statusFilter: 'Pending');
      await setStatusFilter('Pending', updateNav: false);
      return;
    } else if (nav == 'Approved Bookings') {
      state = state.copyWith(selectedNav: 'Booking Requests', statusFilter: 'Approved');
      await setStatusFilter('Approved', updateNav: false);
      return;
    } else if (nav == 'Rejected Bookings') {
      state = state.copyWith(selectedNav: 'Booking Requests', statusFilter: 'Rejected');
      await setStatusFilter('Rejected', updateNav: false);
      return;
    } else if (nav == 'My Bookings') {
      state = state.copyWith(selectedNav: 'Booking Requests', statusFilter: 'All');
      await setStatusFilter('All', updateNav: false);
      return;
    } else if (nav == 'Booking Requests') {
      state = state.copyWith(selectedNav: 'Booking Requests');
      await setStatusFilter(state.statusFilter, updateNav: false);
      return;
    }
    state = state.copyWith(selectedNav: nav);
  }

  Future<void> setStatusFilter(String status, {bool updateNav = true}) async {
    final nav = updateNav ? 'Booking Requests' : state.selectedNav;
    state = state.copyWith(statusFilter: status, selectedNav: nav, currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setSorting(String column) async {
    String newOrder = 'ASC';
    if (state.sortBy.toLowerCase() == column.toLowerCase()) {
      newOrder = (state.sortOrder.toUpperCase() == 'ASC') ? 'DESC' : 'ASC';
    }
    state = state.copyWith(sortBy: column, sortOrder: newOrder, currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query, currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setBuildingFilter(String? buildingId) async {
    state = state.copyWith(selectedBuildingId: buildingId ?? 'all', currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setSpaceTypeFilter(String? spaceType) async {
    state = state.copyWith(selectedSpaceType: spaceType ?? 'All', currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setPurposeFilter(String? purpose) async {
    state = state.copyWith(selectedPurpose: purpose ?? 'All', currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setRequestsDateRange(DateTime? from, DateTime? to) async {
    state = state.copyWith(
      dateRangeFrom: from,
      dateRangeTo: to,
      clearDateRange: from == null && to == null,
      currentPage: 1,
      isLoading: true,
    );
    await _reloadRequests();
  }

  Future<void> clearAllRequestsFilters() async {
    state = state.copyWith(
      searchQuery: '',
      selectedBuildingId: 'all',
      selectedSpaceType: 'All',
      selectedPurpose: 'All',
      clearDateRange: true,
      sortBy: 'booking_date',
      sortOrder: 'ASC',
      currentPage: 1,
      isLoading: true,
    );
    await _reloadRequests();
  }

  Future<void> clearDateRangeFilter() async {
    state = state.copyWith(clearDateRange: true, currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> resetFilters() async {
    state = state.copyWith(
      clearDateRange: true,
      selectedDomain: 'all',
      selectedBuildingId: 'all',
      selectedFloorId: 'all',
      selectedRoomId: 'all',
      selectedSpaceType: 'All',
      selectedCapacity: 'Any Capacity',
      selectedPurpose: 'All',
      selectedClassId: 'all',
      selectedDepartment: 'all',
      statusFilter: 'All',
      searchQuery: '',
      sortBy: 'booking_date',
      sortOrder: 'ASC',
      currentPage: 1,
      isLoading: true,
    );
    await loadAll();
  }

  Future<void> applyQuickFilters({
    String? domain,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? spaceType,
    String? purpose,
    String? classId,
    String? department,
    String? capacity,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    state = state.copyWith(
      selectedDomain: domain ?? state.selectedDomain,
      selectedBuildingId: buildingId ?? state.selectedBuildingId,
      selectedFloorId: floorId ?? state.selectedFloorId,
      selectedRoomId: roomId ?? state.selectedRoomId,
      selectedSpaceType: spaceType ?? state.selectedSpaceType,
      selectedPurpose: purpose ?? state.selectedPurpose,
      selectedClassId: classId ?? state.selectedClassId,
      selectedDepartment: department ?? state.selectedDepartment,
      selectedCapacity: capacity ?? state.selectedCapacity,
      statusFilter: status ?? state.statusFilter,
      dateRangeFrom: dateFrom ?? state.dateRangeFrom,
      dateRangeTo: dateTo ?? state.dateRangeTo,
      currentPage: 1,
      isLoading: true,
    );

    final range = _getTimelineRangeFor(state.selectedDate, state.timelineViewMode);
    final results = await Future.wait([
      _service.getTimeline(
        date: state.selectedDate,
        startDate: range.$1,
        endDate: range.$2,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
      ),
      _service.getRequests(
        status: state.statusFilter,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
        purpose: state.selectedPurpose,
        search: state.searchQuery,
        dateFrom: state.dateRangeFrom,
        dateTo: state.dateRangeTo,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: 1,
        pageSize: state.pageSize,
      ),
    ]);

    state = state.copyWith(
      roomsTimeline: results[0] as List<SpaceTimelineRoom>,
      bookingRequests: results[1] as SpaceBookingListResponse,
      isLoading: false,
    );
  }

  Future<void> setPage(int page) async {
    if (page < 1 || page > state.bookingRequests.totalPages) return;
    state = state.copyWith(currentPage: page, isLoading: true);
    await _reloadRequests();
  }

  Future<void> setPageSize(int size) async {
    state = state.copyWith(pageSize: size, currentPage: 1, isLoading: true);
    await _reloadRequests();
  }

  Future<void> _reloadRequests() async {
    try {
      final res = await _service.getRequests(
        status: state.statusFilter,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
        purpose: state.selectedPurpose,
        search: state.searchQuery,
        dateFrom: state.dateRangeFrom,
        dateTo: state.dateRangeTo,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.currentPage,
        pageSize: state.pageSize,
      );
      state = state.copyWith(bookingRequests: res, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<Map<String, dynamic>> decideApprovalDetailed(String bookingId, String action, {String? comments}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.decideApproval(bookingId, action, comments: comments);
      await loadAll();
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> decideApproval(String bookingId, String action, {String? comments}) async {
    final res = await decideApprovalDetailed(bookingId, action, comments: comments);
    return res['success'] == true;
  }

  Future<bool> deleteBooking(String bookingId, {bool deleteSeries = false, String? reason}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.deleteBooking(bookingId, deleteSeries: deleteSeries, reason: reason);
      if (res['success'] == true) {
        await loadAll();
        return true;
      }
    } catch (_) {} finally {
      state = state.copyWith(isSubmitting: false);
    }
    return false;
  }

  Future<Map<String, dynamic>> submitBooking(Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.createOrUpdateBooking(payload);
      if (res['success'] == true) {
        final dateStr = payload['booking_date'] ?? payload['start_date'];
        if (dateStr != null && dateStr.toString().isNotEmpty) {
          final dt = DateTime.tryParse(dateStr.toString());
          if (dt != null) {
            state = state.copyWith(selectedDate: dt);
          }
        }
        await loadAll();
        return res;
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<Map<String, dynamic>> submitRecurringBooking(Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.createRecurringBooking(payload);
      if (res['success'] == true) {
        final dateStr = payload['start_date'] ?? payload['booking_date'];
        if (dateStr != null && dateStr.toString().isNotEmpty) {
          final dt = DateTime.tryParse(dateStr.toString());
          if (dt != null) {
            state = state.copyWith(selectedDate: dt);
          }
        }
        await loadAll();
        return res;
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void exportCsv() {
    _service.exportCsv(
      status: state.statusFilter,
      buildingId: state.selectedBuildingId,
    );
  }
}

final spaceBookingProvider = StateNotifierProvider<SpaceBookingNotifier, SpaceBookingState>((ref) {
  return SpaceBookingNotifier(SpaceBookingApiService.instance);
});
