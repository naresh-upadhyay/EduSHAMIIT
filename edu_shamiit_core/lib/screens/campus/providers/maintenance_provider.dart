import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_models.dart';
import '../services/maintenance_api_service.dart';

class MaintenanceState {
  final MaintenanceKpis kpis;
  final MaintenanceListResponse requests;
  final MaintenanceAnalyticsData analytics;
  final List<MaintenancePlanItem> plans;
  final List<MaintenanceVendorItem> vendors;
  final bool isLoading;
  final bool isTableLoading;
  final String activeView; // all, my_requests, assigned_to_me, overdue, high_priority, scheduled, preventive, plans, assets, vendors
  final String selectedBuilding;
  final String selectedLocation;
  final String selectedType;
  final String selectedStatus;
  final String selectedPriority;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final String? sortBy;
  final String sortOrder;
  final MaintenanceRequestItem? inspectedRequest;

  const MaintenanceState({
    this.kpis = const MaintenanceKpis(),
    this.requests = const MaintenanceListResponse(),
    this.analytics = const MaintenanceAnalyticsData(),
    this.plans = const [],
    this.vendors = const [],
    this.isLoading = false,
    this.isTableLoading = false,
    this.activeView = 'all',
    this.selectedBuilding = 'all',
    this.selectedLocation = 'All',
    this.selectedType = 'All',
    this.selectedStatus = 'All',
    this.selectedPriority = 'All',
    this.dateRangeStart,
    this.dateRangeEnd,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 10,
    this.sortBy,
    this.sortOrder = 'asc',
    this.inspectedRequest,
  });

  MaintenanceState copyWith({
    MaintenanceKpis? kpis,
    MaintenanceListResponse? requests,
    MaintenanceAnalyticsData? analytics,
    List<MaintenancePlanItem>? plans,
    List<MaintenanceVendorItem>? vendors,
    bool? isLoading,
    bool? isTableLoading,
    String? activeView,
    String? selectedBuilding,
    String? selectedLocation,
    String? selectedType,
    String? selectedStatus,
    String? selectedPriority,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    String? sortBy,
    String? sortOrder,
    MaintenanceRequestItem? Function()? inspectedRequest,
  }) {
    return MaintenanceState(
      kpis: kpis ?? this.kpis,
      requests: requests ?? this.requests,
      analytics: analytics ?? this.analytics,
      plans: plans ?? this.plans,
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      isTableLoading: isTableLoading ?? this.isTableLoading,
      activeView: activeView ?? this.activeView,
      selectedBuilding: selectedBuilding ?? this.selectedBuilding,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      inspectedRequest: inspectedRequest != null ? inspectedRequest() : this.inspectedRequest,
    );
  }
}

class MaintenanceNotifier extends StateNotifier<MaintenanceState> {
  final MaintenanceApiService _api = MaintenanceApiService.instance;

  MaintenanceNotifier() : super(MaintenanceState(
    dateRangeStart: DateTime(2026, 3, 15),
    dateRangeEnd: DateTime(2026, 3, 21),
  )) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadKpis(),
      loadRequests(),
      loadAnalytics(),
      loadPlans(),
      loadVendors(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadKpis() async {
    final kpis = await _api.getKpis();
    state = state.copyWith(kpis: kpis);
  }

  Future<void> loadRequests() async {
    state = state.copyWith(isTableLoading: true);
    final res = await _api.getRequests(
      view: state.activeView,
      buildingId: state.selectedBuilding,
      location: state.selectedLocation,
      type: state.selectedType,
      status: state.selectedStatus,
      priority: state.selectedPriority,
      search: state.searchQuery,
      startDate: state.dateRangeStart,
      endDate: state.dateRangeEnd,
      page: state.currentPage,
      pageSize: state.pageSize,
      sortBy: state.sortBy,
      sortOrder: state.sortOrder,
    );

    // If inspectedRequest is not set, default to first item so right panel displays MT-0568
    MaintenanceRequestItem? inspected = state.inspectedRequest;
    if (inspected == null && res.records.isNotEmpty) {
      inspected = res.records.first;
    }

    state = state.copyWith(
      requests: res,
      isTableLoading: false,
      inspectedRequest: () => inspected,
    );
  }

  Future<void> loadAnalytics() async {
    final analytics = await _api.getAnalytics();
    state = state.copyWith(analytics: analytics);
  }

  Future<void> loadPlans() async {
    final plans = await _api.getPlans();
    state = state.copyWith(plans: plans);
  }

  Future<void> loadVendors() async {
    final vendors = await _api.getVendors();
    state = state.copyWith(vendors: vendors);
  }

  void setActiveView(String view) {
    state = state.copyWith(activeView: view, currentPage: 1);
    loadRequests();
  }

  void setBuildingFilter(String buildingId) {
    state = state.copyWith(selectedBuilding: buildingId, currentPage: 1);
    loadRequests();
  }

  void setLocationFilter(String location) {
    state = state.copyWith(selectedLocation: location, currentPage: 1);
    loadRequests();
  }

  void setTypeFilter(String type) {
    state = state.copyWith(selectedType: type, currentPage: 1);
    loadRequests();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    loadRequests();
  }

  void setPriorityFilter(String priority) {
    state = state.copyWith(selectedPriority: priority, currentPage: 1);
    loadRequests();
  }

  void setDateRange(DateTime start, DateTime end) {
    state = state.copyWith(dateRangeStart: start, dateRangeEnd: end, currentPage: 1);
    loadRequests();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    loadRequests();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    loadRequests();
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
    loadRequests();
  }

  void setSort(String field) {
    if (state.sortBy == field) {
      state = state.copyWith(sortOrder: state.sortOrder == 'asc' ? 'desc' : 'asc');
    } else {
      state = state.copyWith(sortBy: field, sortOrder: 'asc');
    }
    loadRequests();
  }

  void inspectRequest(MaintenanceRequestItem? item) {
    state = state.copyWith(inspectedRequest: () => item);
  }

  Future<bool> createRequest(Map<String, dynamic> payload) async {
    final res = await _api.createRequest(payload);
    if (res['success'] == true) {
      await loadAll();
      return true;
    }
    return false;
  }

  Future<bool> updateStatus(String requestId, String newStatus, {String? remarks, String? resolutionNotes, double? actualCost}) async {
    final res = await _api.updateStatus(requestId, newStatus, remarks: remarks, resolutionNotes: resolutionNotes, actualCost: actualCost);
    if (res['success'] == true) {
      await loadAll();
      return true;
    }
    return false;
  }

  Future<bool> assignTechnician(String requestId, {
    required String assignedToName,
    String? assignedToUserId,
    String? vendorId,
    String? vendorName,
    DateTime? scheduledAt,
    String? instructions,
  }) async {
    final res = await _api.assignTechnician(
      requestId,
      assignedToName: assignedToName,
      assignedToUserId: assignedToUserId,
      vendorId: vendorId,
      vendorName: vendorName,
      scheduledAt: scheduledAt,
      instructions: instructions,
    );
    if (res['success'] == true) {
      await loadAll();
      return true;
    }
    return false;
  }

  Future<void> exportCsv() async {
    await _api.exportCsv();
  }
}

final maintenanceProvider = StateNotifierProvider<MaintenanceNotifier, MaintenanceState>((ref) {
  return MaintenanceNotifier();
});
