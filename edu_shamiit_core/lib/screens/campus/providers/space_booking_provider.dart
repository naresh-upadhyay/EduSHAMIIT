import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/space_booking_models.dart';
import '../services/space_booking_api_service.dart';

class SpaceBookingState {
  final SpaceBookingKpis kpis;
  final List<SpaceTimelineRoom> roomsTimeline;
  final SpaceBookingListResponse bookingRequests;
  final SpaceUtilizationStats utilization;
  final List<BookableRoomItem> bookableRooms;
  final DateTime selectedDate;
  final String timelineViewMode; // 'Day', 'Week', 'Month'
  final String displayMode; // 'Timeline', 'List'
  final String selectedNav; // 'My Bookings', 'Pending Requests', etc.
  final String statusFilter; // 'All', 'Pending', 'Approved', 'Rejected'
  final String selectedBuildingId;
  final String selectedSpaceType;
  final String selectedCapacity;
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
    this.bookingRequests = const SpaceBookingListResponse(items: [], totalCount: 28, page: 1, pageSize: 5, totalPages: 6),
    this.utilization = const SpaceUtilizationStats(),
    this.bookableRooms = const [],
    required this.selectedDate,
    this.timelineViewMode = 'Day',
    this.displayMode = 'Timeline',
    this.selectedNav = 'Pending Requests',
    this.statusFilter = 'All',
    this.selectedBuildingId = 'all',
    this.selectedSpaceType = 'All',
    this.selectedCapacity = 'Any Capacity',
    this.dateRangeFrom,
    this.dateRangeTo,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 5,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
  });

  SpaceBookingState copyWith({
    SpaceBookingKpis? kpis,
    List<SpaceTimelineRoom>? roomsTimeline,
    SpaceBookingListResponse? bookingRequests,
    SpaceUtilizationStats? utilization,
    List<BookableRoomItem>? bookableRooms,
    DateTime? selectedDate,
    String? timelineViewMode,
    String? displayMode,
    String? selectedNav,
    String? statusFilter,
    String? selectedBuildingId,
    String? selectedSpaceType,
    String? selectedCapacity,
    DateTime? dateRangeFrom,
    DateTime? dateRangeTo,
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
      bookableRooms: bookableRooms ?? this.bookableRooms,
      selectedDate: selectedDate ?? this.selectedDate,
      timelineViewMode: timelineViewMode ?? this.timelineViewMode,
      displayMode: displayMode ?? this.displayMode,
      selectedNav: selectedNav ?? this.selectedNav,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedBuildingId: selectedBuildingId ?? this.selectedBuildingId,
      selectedSpaceType: selectedSpaceType ?? this.selectedSpaceType,
      selectedCapacity: selectedCapacity ?? this.selectedCapacity,
      dateRangeFrom: dateRangeFrom ?? this.dateRangeFrom,
      dateRangeTo: dateRangeTo ?? this.dateRangeTo,
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
          selectedDate: DateTime(2026, 3, 15),
          dateRangeFrom: DateTime(2026, 3, 15),
          dateRangeTo: DateTime(2026, 3, 21),
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
      ]);

      state = state.copyWith(
        kpis: results[0] as SpaceBookingKpis,
        roomsTimeline: results[1] as List<SpaceTimelineRoom>,
        bookingRequests: results[2] as SpaceBookingListResponse,
        utilization: results[3] as SpaceUtilizationStats,
        bookableRooms: results[4] as List<BookableRoomItem>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
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
    ]);
    state = state.copyWith(
      kpis: results[0] as SpaceBookingKpis,
      roomsTimeline: results[1] as List<SpaceTimelineRoom>,
      utilization: results[2] as SpaceUtilizationStats,
    );
  }

  void setTimelineViewMode(String mode) {
    state = state.copyWith(timelineViewMode: mode);
  }

  void setDisplayMode(String mode) {
    state = state.copyWith(displayMode: mode);
  }

  Future<void> setSelectedNav(String nav) async {
    state = state.copyWith(selectedNav: nav);
    if (nav == 'Pending Requests') {
      await setStatusFilter('Pending');
    } else if (nav == 'Approved Bookings') {
      await setStatusFilter('Approved');
    } else if (nav == 'Rejected Bookings') {
      await setStatusFilter('Rejected');
    } else {
      await setStatusFilter('All');
    }
  }

  Future<void> setStatusFilter(String status) async {
    state = state.copyWith(statusFilter: status, currentPage: 1, isLoading: true);
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

  Future<bool> decideApproval(String bookingId, String action, {String? comments}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.decideApproval(bookingId, action, comments: comments);
      if (res['success'] == true) {
        await loadAll();
        return true;
      }
    } catch (_) {} finally {
      state = state.copyWith(isSubmitting: false);
    }
    return false;
  }

  Future<bool> submitBooking(Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _service.createOrUpdateBooking(payload);
      if (res['success'] == true) {
        await loadAll();
        return true;
      }
    } catch (_) {} finally {
      state = state.copyWith(isSubmitting: false);
    }
    return false;
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
