import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visitor_models.dart';
import '../services/visitors_api_service.dart';

class VisitorsState {
  final int activeTab; // 0: All Visitors, 1: Scheduled Visitors, 2: Blacklisted Visitors
  final VisitorKPIs kpis;
  final ScheduledKPIs scheduledKpis;
  final BlacklistKPIs blacklistKpis;
  final List<VisitorItem> visits;
  final VisitorPagination pagination;
  final List<ScheduledAppointmentItem> appointments;
  final VisitorPagination appointmentPagination;
  final ScheduledAppointmentItem? selectedAppointment;
  final AppointmentDetail360? selectedAppointmentDetail;
  final List<BlacklistedVisitorItem> restrictions;
  final VisitorPagination restrictionPagination;
  final BlacklistedVisitorItem? selectedRestriction;
  final RestrictionDetail360? selectedRestrictionDetail;
  final VisitorAnalyticsData analytics;
  final VisitorItem? selectedVisit;
  final VisitorDetail360? selectedDetail;
  final bool isDrawerOpen;
  final String searchQuery;
  final String selectedLocation;
  final String selectedCategory;
  final String selectedStatus;
  final String selectedDateRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> availableLocations;
  final List<VisitorProfileItem> profiles;
  final VisitorPagination profilePagination;
  final bool isLoadingProfiles;
  final List<GeneratedGatePassItem> generatedPasses;
  final String visitsSortBy;
  final String visitsSortOrder;
  final String appointmentsSortBy;
  final String appointmentsSortOrder;
  final String restrictionsSortBy;
  final String restrictionsSortOrder;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const VisitorsState({
    this.activeTab = 0,
    this.kpis = const VisitorKPIs(),
    this.scheduledKpis = const ScheduledKPIs(),
    this.blacklistKpis = const BlacklistKPIs(),
    this.visits = const [],
    this.pagination = const VisitorPagination(),
    this.appointments = const [],
    this.appointmentPagination = const VisitorPagination(),
    this.selectedAppointment,
    this.selectedAppointmentDetail,
    this.restrictions = const [],
    this.restrictionPagination = const VisitorPagination(),
    this.selectedRestriction,
    this.selectedRestrictionDetail,
    this.analytics = const VisitorAnalyticsData(),
    this.selectedVisit,
    this.selectedDetail,
    this.isDrawerOpen = false,
    this.searchQuery = '',
    this.selectedLocation = 'All Locations',
    this.selectedCategory = 'All Visitor Types',
    this.selectedStatus = 'All Status',
    this.selectedDateRange = 'All Time',
    this.startDate,
    this.endDate,
    this.availableLocations = const [
      'All Locations',
      'Main Gate',
      'Reception Desk',
      'Library',
      'Science Lab',
      'Boys Hostel',
      'Girls Hostel',
      'Auditorium',
      'Admin Office',
      'Principal Office'
    ],
    this.profiles = const [],
    this.profilePagination = const VisitorPagination(),
    this.isLoadingProfiles = false,
    this.generatedPasses = const [],
    this.visitsSortBy = 'created_at',
    this.visitsSortOrder = 'DESC',
    this.appointmentsSortBy = 'scheduled_start',
    this.appointmentsSortOrder = 'DESC',
    this.restrictionsSortBy = 'created_at',
    this.restrictionsSortOrder = 'DESC',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  VisitorsState copyWith({
    int? activeTab,
    VisitorKPIs? kpis,
    ScheduledKPIs? scheduledKpis,
    BlacklistKPIs? blacklistKpis,
    List<VisitorItem>? visits,
    VisitorPagination? pagination,
    List<ScheduledAppointmentItem>? appointments,
    VisitorPagination? appointmentPagination,
    ScheduledAppointmentItem? selectedAppointment,
    AppointmentDetail360? selectedAppointmentDetail,
    List<BlacklistedVisitorItem>? restrictions,
    VisitorPagination? restrictionPagination,
    BlacklistedVisitorItem? selectedRestriction,
    RestrictionDetail360? selectedRestrictionDetail,
    VisitorAnalyticsData? analytics,
    VisitorItem? selectedVisit,
    VisitorDetail360? selectedDetail,
    bool? isDrawerOpen,
    String? searchQuery,
    String? selectedLocation,
    String? selectedCategory,
    String? selectedStatus,
    String? selectedDateRange,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    List<String>? availableLocations,
    List<VisitorProfileItem>? profiles,
    VisitorPagination? profilePagination,
    bool? isLoadingProfiles,
    List<GeneratedGatePassItem>? generatedPasses,
    String? visitsSortBy,
    String? visitsSortOrder,
    String? appointmentsSortBy,
    String? appointmentsSortOrder,
    String? restrictionsSortBy,
    String? restrictionsSortOrder,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearDetail = false,
  }) {
    return VisitorsState(
      activeTab: activeTab ?? this.activeTab,
      kpis: kpis ?? this.kpis,
      scheduledKpis: scheduledKpis ?? this.scheduledKpis,
      blacklistKpis: blacklistKpis ?? this.blacklistKpis,
      visits: visits ?? this.visits,
      pagination: pagination ?? this.pagination,
      appointments: appointments ?? this.appointments,
      appointmentPagination: appointmentPagination ?? this.appointmentPagination,
      selectedAppointment: clearDetail ? null : (selectedAppointment ?? this.selectedAppointment),
      selectedAppointmentDetail: clearDetail ? null : (selectedAppointmentDetail ?? this.selectedAppointmentDetail),
      restrictions: restrictions ?? this.restrictions,
      restrictionPagination: restrictionPagination ?? this.restrictionPagination,
      selectedRestriction: clearDetail ? null : (selectedRestriction ?? this.selectedRestriction),
      selectedRestrictionDetail: clearDetail ? null : (selectedRestrictionDetail ?? this.selectedRestrictionDetail),
      analytics: analytics ?? this.analytics,
      selectedVisit: clearDetail ? null : (selectedVisit ?? this.selectedVisit),
      selectedDetail: clearDetail ? null : (selectedDetail ?? this.selectedDetail),
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      availableLocations: availableLocations ?? this.availableLocations,
      profiles: profiles ?? this.profiles,
      profilePagination: profilePagination ?? this.profilePagination,
      isLoadingProfiles: isLoadingProfiles ?? this.isLoadingProfiles,
      generatedPasses: generatedPasses ?? this.generatedPasses,
      visitsSortBy: visitsSortBy ?? this.visitsSortBy,
      visitsSortOrder: visitsSortOrder ?? this.visitsSortOrder,
      appointmentsSortBy: appointmentsSortBy ?? this.appointmentsSortBy,
      appointmentsSortOrder: appointmentsSortOrder ?? this.appointmentsSortOrder,
      restrictionsSortBy: restrictionsSortBy ?? this.restrictionsSortBy,
      restrictionsSortOrder: restrictionsSortOrder ?? this.restrictionsSortOrder,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class VisitorsNotifier extends StateNotifier<VisitorsState> {
  final VisitorsApiService _api;

  VisitorsNotifier(this._api) : super(const VisitorsState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      fetchKPIs(),
      fetchScheduledKPIs(),
      fetchBlacklistKPIs(),
      fetchVisits(),
      fetchAppointments(),
      fetchRestrictions(),
      fetchAnalytics(),
      fetchLocations(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  void setActiveTab(int tabIndex) {
    if (state.activeTab == tabIndex) return;
    state = state.copyWith(activeTab: tabIndex);
    if (tabIndex == 0) {
      fetchVisits();
    } else if (tabIndex == 1) {
      fetchScheduledKPIs();
      fetchAppointments();
    } else if (tabIndex == 2) {
      fetchBlacklistKPIs();
      fetchRestrictions();
    }
  }

  String? _formatDateForApi(DateTime? dt) {
    if (dt == null) return null;
    return dt.isUtc ? dt.toIso8601String() : dt.toUtc().toIso8601String();
  }

  Future<void> fetchKPIs() async {
    final kpis = await _api.getKPIs(
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
      dateRangeLabel: state.selectedDateRange,
      location: state.selectedLocation,
      category: state.selectedCategory,
    );
    state = state.copyWith(kpis: kpis);
  }

  Future<void> fetchScheduledKPIs() async {
    final kpis = await _api.getScheduledKPIs(
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
    );
    state = state.copyWith(scheduledKpis: kpis);
  }

  Future<void> fetchBlacklistKPIs() async {
    final kpis = await _api.getBlacklistKPIs(
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
    );
    state = state.copyWith(blacklistKpis: kpis);
  }

  Future<void> fetchVisits({int? page, int? pageSize}) async {
    final targetPage = page ?? state.pagination.page;
    final targetPageSize = pageSize ?? state.pagination.pageSize;
    final res = await _api.getVisits(
      search: state.searchQuery,
      location: state.selectedLocation,
      category: state.selectedCategory,
      status: state.selectedStatus,
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
      page: targetPage,
      pageSize: targetPageSize,
      sortBy: state.visitsSortBy,
      sortOrder: state.visitsSortOrder,
    );
    final records = res['records'] as List<VisitorItem>;
    final rawPagination = res['pagination'] as VisitorPagination;
    final pagination = rawPagination.copyWith(
      page: targetPage,
      pageSize: targetPageSize,
    );
    VisitorItem? currentSelection;
    if (records.isNotEmpty) {
      if (state.selectedVisit != null) {
        currentSelection = records.firstWhere(
          (r) => r.id == state.selectedVisit!.id,
          orElse: () => records.first,
        );
      } else {
        currentSelection = records.first;
      }
    }

    state = state.copyWith(
      visits: records,
      pagination: pagination,
      selectedVisit: currentSelection,
      clearDetail: records.isEmpty,
    );

    if (currentSelection != null) {
      openVisitDetail(currentSelection);
    }
  }

  Future<void> fetchAppointments({int? page, int? pageSize}) async {
    final targetPage = page ?? state.appointmentPagination.page;
    final targetPageSize = pageSize ?? state.appointmentPagination.pageSize;
    final res = await _api.getAppointments(
      search: state.searchQuery,
      status: state.selectedStatus,
      location: state.selectedLocation,
      category: state.selectedCategory,
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
      page: targetPage,
      pageSize: targetPageSize,
      sortBy: state.appointmentsSortBy,
      sortOrder: state.appointmentsSortOrder,
    );
    final records = res['records'] as List<ScheduledAppointmentItem>;
    final rawPagination = res['pagination'] as VisitorPagination;
    final pagination = rawPagination.copyWith(
      page: targetPage,
      pageSize: targetPageSize,
    );
    
    ScheduledAppointmentItem? currentSelection;
    if (records.isNotEmpty) {
      if (state.selectedAppointment != null) {
        currentSelection = records.firstWhere(
          (r) => r.id == state.selectedAppointment!.id,
          orElse: () => records.first,
        );
      } else {
        currentSelection = records.first;
      }
    }

    state = state.copyWith(
      appointments: records,
      appointmentPagination: pagination,
      selectedAppointment: currentSelection,
      clearDetail: records.isEmpty,
    );

    if (currentSelection != null) {
      await openAppointmentDetail(currentSelection);
    }
  }

  Future<void> fetchRestrictions({int? page, int? pageSize}) async {
    final targetPage = page ?? state.restrictionPagination.page;
    final targetPageSize = pageSize ?? state.restrictionPagination.pageSize;
    final res = await _api.getRestrictions(
      search: state.searchQuery,
      status: state.selectedStatus,
      location: state.selectedLocation,
      category: state.selectedCategory,
      reason: state.selectedCategory,
      dateFrom: _formatDateForApi(state.startDate),
      dateTo: _formatDateForApi(state.endDate),
      page: targetPage,
      pageSize: targetPageSize,
      sortBy: state.restrictionsSortBy,
      sortOrder: state.restrictionsSortOrder,
    );
    final records = res['records'] as List<BlacklistedVisitorItem>;
    final rawPagination = res['pagination'] as VisitorPagination;
    final pagination = rawPagination.copyWith(
      page: targetPage,
      pageSize: targetPageSize,
    );

    BlacklistedVisitorItem? currentSelection;
    if (records.isNotEmpty) {
      if (state.selectedRestriction != null) {
        currentSelection = records.firstWhere(
          (r) => r.id == state.selectedRestriction!.id,
          orElse: () => records.first,
        );
      } else {
        currentSelection = records.first;
      }
    }

    state = state.copyWith(
      restrictions: records,
      restrictionPagination: pagination,
      selectedRestriction: currentSelection,
      clearDetail: records.isEmpty,
    );

    if (currentSelection != null) {
      await openRestrictionDetail(currentSelection);
    }
  }

  Future<void> openAppointmentDetail(ScheduledAppointmentItem appt) async {
    state = state.copyWith(selectedAppointment: appt);
    final detail = await _api.getAppointmentDetails(appt.id);
    if (detail != null) {
      state = state.copyWith(selectedAppointmentDetail: detail);
    }
  }

  Future<void> openRestrictionDetail(BlacklistedVisitorItem rest) async {
    state = state.copyWith(selectedRestriction: rest);
    final detail = await _api.getRestrictionDetails(rest.id);
    if (detail != null) {
      state = state.copyWith(selectedRestrictionDetail: detail);
    }
  }

  Future<void> fetchAnalytics() async {
    final an = await _api.getAnalytics();
    state = state.copyWith(analytics: an);
  }

  Future<void> fetchLocations() async {
    final locs = await _api.getLocations();
    if (locs.isNotEmpty) {
      final names = ['All Locations', ...locs.map((l) => l['location_name']?.toString() ?? '').where((s) => s.isNotEmpty)];
      state = state.copyWith(availableLocations: names.toSet().toList());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
    } else {
      fetchRestrictions(page: 1);
    }
  }

  void setLocationFilter(String location) {
    state = state.copyWith(selectedLocation: location);
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
      fetchKPIs();
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
      fetchScheduledKPIs();
    } else {
      fetchRestrictions(page: 1);
      fetchBlacklistKPIs();
    }
  }

  void sortVisits(String column) {
    final isCurrent = state.visitsSortBy == column;
    final newOrder = isCurrent && state.visitsSortOrder == 'ASC' ? 'DESC' : 'ASC';
    state = state.copyWith(visitsSortBy: column, visitsSortOrder: newOrder);
    fetchVisits(page: 1);
  }

  void sortAppointments(String column) {
    final isCurrent = state.appointmentsSortBy == column;
    final newOrder = isCurrent && state.appointmentsSortOrder == 'ASC' ? 'DESC' : 'ASC';
    state = state.copyWith(appointmentsSortBy: column, appointmentsSortOrder: newOrder);
    fetchAppointments(page: 1);
  }

  void sortRestrictions(String column) {
    final isCurrent = state.restrictionsSortBy == column;
    final newOrder = isCurrent && state.restrictionsSortOrder == 'ASC' ? 'DESC' : 'ASC';
    state = state.copyWith(restrictionsSortBy: column, restrictionsSortOrder: newOrder);
    fetchRestrictions(page: 1);
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(selectedCategory: category);
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
      fetchKPIs();
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
      fetchScheduledKPIs();
    } else {
      fetchRestrictions(page: 1);
    }
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status);
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
    } else {
      fetchRestrictions(page: 1);
    }
  }

  void setDateRangeFilter(String label, {DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) {
      state = state.copyWith(
        selectedDateRange: label,
        clearDates: true,
      );
    } else {
      state = state.copyWith(
        selectedDateRange: label,
        startDate: startDate,
        endDate: endDate,
      );
    }
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
      fetchKPIs();
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
      fetchScheduledKPIs();
    } else {
      fetchRestrictions(page: 1);
      fetchBlacklistKPIs();
    }
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedLocation: 'All Locations',
      selectedCategory: 'All Visitor Types',
      selectedStatus: 'All Status',
      selectedDateRange: 'All Time',
      clearDates: true,
    );
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
      fetchKPIs();
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
      fetchScheduledKPIs();
    } else {
      fetchRestrictions(page: 1);
      fetchBlacklistKPIs();
    }
  }

  void applyMoreFilters({
    String? location,
    String? category,
    String? status,
    String? searchQuery,
    String? dateRange,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) {
    state = state.copyWith(
      selectedLocation: location ?? state.selectedLocation,
      selectedCategory: category ?? state.selectedCategory,
      selectedStatus: status ?? state.selectedStatus,
      searchQuery: searchQuery ?? state.searchQuery,
      selectedDateRange: dateRange ?? state.selectedDateRange,
      startDate: startDate,
      endDate: endDate,
      clearDates: clearDates,
    );
    if (state.activeTab == 0) {
      fetchVisits(page: 1);
      fetchKPIs();
    } else if (state.activeTab == 1) {
      fetchAppointments(page: 1);
      fetchScheduledKPIs();
    } else {
      fetchRestrictions(page: 1);
      fetchBlacklistKPIs();
    }
  }

  void applyKpiFilter(String filterType) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (filterType == 'Checked In Today') {
      state = state.copyWith(
        activeTab: 0,
        selectedStatus: 'All Status',
        selectedDateRange: 'Today',
        startDate: todayStart,
        endDate: todayEnd,
        selectedLocation: 'All Locations',
        selectedCategory: 'All Visitor Types',
        searchQuery: '',
      );
    } else if (filterType == 'Checked Out Today') {
      state = state.copyWith(
        activeTab: 0,
        selectedStatus: 'Checked Out',
        selectedDateRange: 'Today',
        startDate: todayStart,
        endDate: todayEnd,
        selectedLocation: 'All Locations',
        selectedCategory: 'All Visitor Types',
        searchQuery: '',
      );
    } else {
      state = state.copyWith(
        activeTab: 0,
        selectedStatus: filterType,
        selectedLocation: 'All Locations',
        selectedCategory: 'All Visitor Types',
        searchQuery: '',
      );
    }
    fetchVisits(page: 1);
    fetchKPIs();
  }

  Future<void> openVisitDetail(VisitorItem item) async {
    state = state.copyWith(selectedVisit: item, isDrawerOpen: true);
    final detail = await _api.getVisitDetails(item.id);
    if (detail != null) {
      state = state.copyWith(selectedDetail: detail);
    }
  }

  void closeDrawer() {
    state = state.copyWith(isDrawerOpen: false, clearDetail: true);
  }

  Future<bool> registerVisitor(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.registerVisitor(payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visitor registered successfully!');
      await Future.wait([fetchKPIs(), fetchVisits(page: 1), fetchAnalytics()]);
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Registration failed.');
      return false;
    }
  }

  Future<bool> updateVisit(String visitId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.updateVisit(visitId, payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visitor details updated successfully!');
      await Future.wait([fetchKPIs(), fetchVisits(), fetchAnalytics()]);
      if (state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Update failed.');
      return false;
    }
  }

  Future<bool> checkInVisit(String visitId, {String entryLocation = 'Main Gate', String? remarks}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.checkInVisit(visitId, entryLocation: entryLocation, remarks: remarks);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visitor checked in successfully!');
      await Future.wait([fetchKPIs(), fetchVisits()]);
      if (state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Check-in failed.');
      return false;
    }
  }

  Future<bool> checkOutVisit(String visitId, {String exitLocation = 'Main Gate', String? remarks}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.checkOutVisit(visitId, exitLocation: exitLocation, remarks: remarks);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      await Future.wait([fetchKPIs(), fetchVisits()]);
      if (state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      }
      state = state.copyWith(successMessage: 'Visitor checked out successfully!');
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Checkout failed.');
      return false;
    }
  }

  Future<bool> bulkCheckOutVisits(List<String> visitIds, {String exitLocation = 'Main Gate', String? remarks}) async {
    if (visitIds.isEmpty) return false;
    state = state.copyWith(isLoading: true);
    final res = await _api.bulkCheckOutVisits(visitIds, exitLocation: exitLocation, remarks: remarks);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      await Future.wait([fetchKPIs(), fetchVisits()]);
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : <String, dynamic>{};
      final count = data['checked_out_count'] ?? visitIds.length;
      state = state.copyWith(successMessage: 'Successfully checked out $count visitor(s).');
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Bulk check-out failed.');
      return false;
    }
  }

  Future<bool> extendVisit(String visitId, {int extensionMinutes = 60, String? reason}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.extendVisit(visitId, extensionMinutes: extensionMinutes, reason: reason);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visit extended by $extensionMinutes minutes.');
      await Future.wait([fetchKPIs(), fetchVisits()]);
      if (state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Extension failed.');
      return false;
    }
  }

  Future<bool> cancelVisit(String visitId, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.cancelVisit(visitId, reason: reason);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visit cancelled successfully.');
      await Future.wait([fetchKPIs(), fetchVisits()]);
      if (state.selectedVisit?.id == visitId) {
        closeDrawer();
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to cancel visit.');
      return false;
    }
  }

  Future<bool> scheduleAppointment(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.scheduleAppointment(payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Appointment scheduled successfully!');
      await Future.wait([fetchKPIs(), fetchAppointments(page: 1)]);
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Scheduling failed.');
      return false;
    }
  }

  Future<bool> approveAppointment(String appointmentId) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.approveAppointment(appointmentId);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Appointment approved!');
      await Future.wait([fetchScheduledKPIs(), fetchAppointments()]);
      if (state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Approval failed.');
      return false;
    }
  }

  Future<bool> rejectAppointment(String appointmentId, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.rejectAppointment(appointmentId, reason: reason);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Appointment rejected.');
      await Future.wait([fetchScheduledKPIs(), fetchAppointments()]);
      if (state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Rejection failed.');
      return false;
    }
  }

  Future<bool> rescheduleAppointment(String appointmentId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.rescheduleAppointment(appointmentId, payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Appointment rescheduled successfully!');
      await Future.wait([fetchScheduledKPIs(), fetchAppointments()]);
      if (state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Rescheduling failed.');
      return false;
    }
  }

  Future<bool> cancelAppointment(String appointmentId, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.cancelAppointment(appointmentId, reason: reason);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Appointment cancelled successfully.');
      await Future.wait([fetchScheduledKPIs(), fetchAppointments()]);
      if (state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to cancel appointment.');
      return false;
    }
  }

  Future<bool> updateRestriction(String restrictionId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.updateRestriction(restrictionId, payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Restriction updated successfully!');
      await Future.wait([
        fetchBlacklistKPIs(),
        fetchRestrictions(),
        fetchVisits(),
        fetchAppointments(),
      ]);
      if (state.selectedRestriction?.id == restrictionId) {
        final updatedRest = state.restrictions.firstWhere(
          (r) => r.id == restrictionId,
          orElse: () => state.selectedRestriction!,
        );
        await openRestrictionDetail(updatedRest);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Update failed.');
      return false;
    }
  }

  Future<bool> createRestriction(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.createRestriction(payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Security restriction created.');
      await Future.wait([
        fetchRestrictions(page: 1),
        fetchVisits(),
        fetchAppointments(),
        fetchKPIs(),
        fetchBlacklistKPIs(),
      ]);
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to create restriction.');
      return false;
    }
  }

  Future<bool> liftRestriction(String restrictionId, String reason) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.liftRestriction(restrictionId, reason: reason);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Restriction lifted successfully.');
      await Future.wait([
        fetchRestrictions(),
        fetchVisits(),
        fetchAppointments(),
        fetchKPIs(),
        fetchBlacklistKPIs(),
      ]);
      if (state.selectedRestriction?.id == restrictionId) {
        final updatedRest = state.restrictions.firstWhere(
          (r) => r.id == restrictionId,
          orElse: () => state.selectedRestriction!,
        );
        await openRestrictionDetail(updatedRest);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to lift restriction.');
      return false;
    }
  }

  Future<bool> unblockVisitor(String visitorId, {String? reason, String? liftedByName}) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.unblockVisitor(
      visitorId,
      reason: reason ?? 'Administrative review completed; access restored',
      liftedByName: liftedByName,
    );
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visitor unblocked and access restored successfully.');
      await Future.wait([
        fetchRestrictions(),
        fetchVisits(),
        fetchAppointments(),
        fetchKPIs(),
        fetchBlacklistKPIs(),
      ]);
      if (state.selectedVisit != null && state.selectedVisit!.visitorId == visitorId) {
        await openVisitDetail(state.selectedVisit!);
      }
      if (state.selectedAppointment != null && state.selectedAppointment!.visitorId == visitorId) {
        await openAppointmentDetail(state.selectedAppointment!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to unblock visitor.');
      return false;
    }
  }

  Future<void> fetchProfiles({
    String search = '',
    String visitorType = 'All',
    int page = 1,
    int pageSize = 20,
  }) async {
    state = state.copyWith(isLoadingProfiles: true);
    final res = await _api.getProfiles(
      search: search,
      visitorType: visitorType,
      page: page,
      pageSize: pageSize,
    );
    state = state.copyWith(
      profiles: res['records'] as List<VisitorProfileItem>,
      profilePagination: res['pagination'] as VisitorPagination,
      isLoadingProfiles: false,
    );
  }

  Future<bool> createProfile(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoadingProfiles: true);
    final res = await _api.createProfile(payload);
    state = state.copyWith(isLoadingProfiles: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Visitor profile created successfully.');
      await fetchProfiles();
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to create profile.');
      return false;
    }
  }

  Future<List<GeneratedGatePassItem>> generateBatchGatePasses(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.generateBatchGatePasses(payload);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true && res['passes'] is List<GeneratedGatePassItem>) {
      final passes = res['passes'] as List<GeneratedGatePassItem>;
      state = state.copyWith(
        generatedPasses: passes,
        successMessage: res['message']?.toString() ?? 'Generated ${passes.length} gate passes.',
      );
      await Future.wait([fetchVisits(page: 1), fetchKPIs()]);
      return passes;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to generate gate passes.');
      return <GeneratedGatePassItem>[];
    }
  }

  Future<GatePassScanResult> scanGatePassImage(String base64Image) async {
    return await _api.scanGatePassImage(base64Image);
  }

  Future<GatePassScanResult> verifyGatePass(String token) async {
    return await _api.verifyGatePass(token);
  }

  Future<bool> executeScanAction(
    String passNumber, {
    required String action,
    String location = 'Main Gate',
    String? remarks,
  }) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.executeScanAction(
      passNumber,
      action: action,
      location: location,
      remarks: remarks,
    );
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(
        successMessage: res['message']?.toString() ?? 'Gate pass marked $action successfully.',
      );
      await Future.wait([
        fetchVisits(),
        fetchKPIs(),
        fetchAnalytics(),
      ]);
      return true;
    } else {
      state = state.copyWith(
        errorMessage: res['detail']?.toString() ?? 'Failed to execute $action for pass.',
      );
      return false;
    }
  }

  Future<bool> uploadDocument({
    String? visitorId,
    String? appointmentId,
    String? restrictionId,
    String? visitId,
    required String documentName,
    required String documentType,
    required String fileUrl,
    int? fileSizeBytes,
    String? verificationStatus,
  }) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.uploadDocument(
      visitorId: visitorId,
      appointmentId: appointmentId,
      restrictionId: restrictionId,
      visitId: visitId,
      documentName: documentName,
      documentType: documentType,
      fileUrl: fileUrl,
      fileSizeBytes: fileSizeBytes,
      verificationStatus: verificationStatus,
    );
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Document "$documentName" uploaded successfully!');
      if (appointmentId != null && state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      } else if (state.selectedAppointment != null && state.activeTab == 1) {
        await openAppointmentDetail(state.selectedAppointment!);
      }

      if (restrictionId != null && state.selectedRestriction?.id == restrictionId) {
        await openRestrictionDetail(state.selectedRestriction!);
      } else if (state.selectedRestriction != null && state.activeTab == 2) {
        await openRestrictionDetail(state.selectedRestriction!);
      }

      if (visitId != null && state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      } else if (state.selectedVisit != null && state.activeTab == 0) {
        await openVisitDetail(state.selectedVisit!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to upload document.');
      return false;
    }
  }

  Future<bool> deleteDocument(
    String documentId, {
    String? appointmentId,
    String? restrictionId,
    String? visitId,
  }) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.deleteDocument(documentId);
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(successMessage: 'Document removed successfully.');
      if (appointmentId != null && state.selectedAppointment?.id == appointmentId) {
        await openAppointmentDetail(state.selectedAppointment!);
      } else if (state.selectedAppointment != null && state.activeTab == 1) {
        await openAppointmentDetail(state.selectedAppointment!);
      }

      if (restrictionId != null && state.selectedRestriction?.id == restrictionId) {
        await openRestrictionDetail(state.selectedRestriction!);
      } else if (state.selectedRestriction != null && state.activeTab == 2) {
        await openRestrictionDetail(state.selectedRestriction!);
      }

      if (visitId != null && state.selectedVisit?.id == visitId) {
        await openVisitDetail(state.selectedVisit!);
      } else if (state.selectedVisit != null && state.activeTab == 0) {
        await openVisitDetail(state.selectedVisit!);
      }
      return true;
    } else {
      state = state.copyWith(errorMessage: res['detail']?.toString() ?? 'Failed to delete document.');
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkInAppointment(
    String appointmentId, {
    String entryLocation = 'Main Gate',
    String? remarks,
  }) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.checkInAppointment(
      appointmentId,
      entryLocation: entryLocation,
      remarks: remarks,
    );
    state = state.copyWith(isLoading: false);
    if (res['success'] == true) {
      state = state.copyWith(
        successMessage: res['message']?.toString() ?? 'Scheduled visitor checked in successfully!',
      );
      await Future.wait([
        fetchKPIs(),
        fetchScheduledKPIs(),
        fetchAppointments(),
        fetchVisits(page: 1),
      ]);
      return res['data'] is Map<String, dynamic>
          ? (res['data'] as Map<String, dynamic>)
          : <String, dynamic>{'pass_number': 'GP-SCHEDULED'};
    } else {
      state = state.copyWith(
        errorMessage: res['detail']?.toString() ?? 'Failed to check in appointment.',
      );
      return null;
    }
  }

  Future<List<HostSearchResultItem>> searchHosts(String query) async {
    return await _api.searchHosts(query);
  }

  Future<InstantRestrictionResult> checkInstantRestriction({String? phone, String? idNumber}) async {
    return await _api.checkInstantRestriction(phone: phone, idNumber: idNumber);
  }

  Future<Map<String, dynamic>> getExecutiveSummaryReport({String? dateFrom, String? dateTo}) async {
    return await _api.getExecutiveSummaryReport(dateFrom: dateFrom, dateTo: dateTo);
  }

  void clearNotifications() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}

final visitorsApiServiceProvider = Provider<VisitorsApiService>((ref) => VisitorsApiService());

final visitorsProvider = StateNotifierProvider<VisitorsNotifier, VisitorsState>((ref) {
  final api = ref.watch(visitorsApiServiceProvider);
  return VisitorsNotifier(api);
});
