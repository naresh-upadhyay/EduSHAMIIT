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
  final String selectedBuildingId;
  final String selectedSpaceType;
  final String selectedCapacity;
  final String selectedPurpose;
  final DateTime? dateRangeFrom;
  final DateTime? dateRangeTo;
  final String searchQuery;
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
    this.selectedBuildingId = 'all',
    this.selectedSpaceType = 'All',
    this.selectedCapacity = 'Any Capacity',
    this.selectedPurpose = 'All',
    this.dateRangeFrom,
    this.dateRangeTo,
    this.searchQuery = '',
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
    String? selectedBuildingId,
    String? selectedSpaceType,
    String? selectedCapacity,
    String? selectedPurpose,
    DateTime? dateRangeFrom,
    DateTime? dateRangeTo,
    bool clearDateRange = false,
    String? searchQuery,
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
      selectedBuildingId: selectedBuildingId ?? this.selectedBuildingId,
      selectedSpaceType: selectedSpaceType ?? this.selectedSpaceType,
      selectedCapacity: selectedCapacity ?? this.selectedCapacity,
      selectedPurpose: selectedPurpose ?? this.selectedPurpose,
      dateRangeFrom: clearDateRange ? null : (dateRangeFrom ?? this.dateRangeFrom),
      dateRangeTo: clearDateRange ? null : (dateRangeTo ?? this.dateRangeTo),
      searchQuery: searchQuery ?? this.searchQuery,
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

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _service.getKpis(date: state.selectedDate),
        _service.getTimeline(
          date: state.selectedDate,
          buildingId: state.selectedBuildingId,
          roomType: state.selectedSpaceType,
        ),
        _service.getRequests(
          status: state.statusFilter,
          buildingId: state.selectedBuildingId,
          roomType: state.selectedSpaceType,
          search: state.searchQuery,
          dateFrom: state.dateRangeFrom,
          dateTo: state.dateRangeTo,
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
    final results = await Future.wait([
      _service.getKpis(date: newDate),
      _service.getTimeline(
        date: newDate,
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

  void setTimelineViewMode(String mode) {
    state = state.copyWith(timelineViewMode: mode);
  }

  void setDisplayMode(String mode) {
    state = state.copyWith(displayMode: mode);
  }

  void setPurposeFilter(String purpose) {
    state = state.copyWith(selectedPurpose: purpose);
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
    final res = await _service.getRequests(
      status: status,
      buildingId: state.selectedBuildingId,
      roomType: state.selectedSpaceType,
      search: state.searchQuery,
      dateFrom: state.dateRangeFrom,
      dateTo: state.dateRangeTo,
      page: 1,
      pageSize: state.pageSize,
    );
    state = state.copyWith(bookingRequests: res, isLoading: false);
  }

  Future<void> clearDateRangeFilter() async {
    state = state.copyWith(clearDateRange: true, currentPage: 1, isLoading: true);
    final res = await _service.getRequests(
      status: state.statusFilter,
      buildingId: state.selectedBuildingId,
      roomType: state.selectedSpaceType,
      search: state.searchQuery,
      dateFrom: null,
      dateTo: null,
      page: 1,
      pageSize: state.pageSize,
    );
    state = state.copyWith(bookingRequests: res, isLoading: false);
  }

  Future<void> resetFilters() async {
    state = state.copyWith(
      clearDateRange: true,
      selectedBuildingId: null,
      selectedSpaceType: 'All',
      selectedCapacity: 'Any Capacity',
      selectedPurpose: 'All',
      searchQuery: '',
      currentPage: 1,
      isLoading: true,
    );
    await loadAll();
  }

  Future<void> applyQuickFilters({
    String? buildingId,
    String? spaceType,
    String? capacity,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    state = state.copyWith(
      selectedBuildingId: buildingId ?? state.selectedBuildingId,
      selectedSpaceType: spaceType ?? state.selectedSpaceType,
      selectedCapacity: capacity ?? state.selectedCapacity,
      dateRangeFrom: dateFrom ?? state.dateRangeFrom,
      dateRangeTo: dateTo ?? state.dateRangeTo,
      currentPage: 1,
      isLoading: true,
    );

    final results = await Future.wait([
      _service.getTimeline(
        date: state.selectedDate,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
      ),
      _service.getRequests(
        status: state.statusFilter,
        buildingId: state.selectedBuildingId,
        roomType: state.selectedSpaceType,
        search: state.searchQuery,
        dateFrom: state.dateRangeFrom,
        dateTo: state.dateRangeTo,
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
    final res = await _service.getRequests(
      status: state.statusFilter,
      buildingId: state.selectedBuildingId,
      roomType: state.selectedSpaceType,
      search: state.searchQuery,
      dateFrom: state.dateRangeFrom,
      dateTo: state.dateRangeTo,
      page: page,
      pageSize: state.pageSize,
    );
    state = state.copyWith(bookingRequests: res, isLoading: false);
  }

  Future<void> setPageSize(int size) async {
    state = state.copyWith(pageSize: size, currentPage: 1, isLoading: true);
    final res = await _service.getRequests(
      status: state.statusFilter,
      buildingId: state.selectedBuildingId,
      roomType: state.selectedSpaceType,
      search: state.searchQuery,
      dateFrom: state.dateRangeFrom,
      dateTo: state.dateRangeTo,
      page: 1,
      pageSize: size,
    );
    state = state.copyWith(bookingRequests: res, isLoading: false);
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
