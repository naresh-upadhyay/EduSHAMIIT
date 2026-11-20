import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/safety_compliance_models.dart';
import '../services/safety_compliance_api_service.dart';

final safetyComplianceApiServiceProvider = Provider<SafetyComplianceApiService>((ref) {
  return SafetyComplianceApiService.instance;
});

class SafetyComplianceState {
  final SafetyComplianceKpis kpis;
  final int activeSubTab; // 0: Inspections, 1: Incidents, 2: Certificates, 3: Drills
  final String activeView; // 'all', 'overdue_inspections', 'critical_incidents', 'expiring_certs', 'conducted_drills'
  final SafetyListResponse<SafetyInspectionItem> inspections;
  final SafetyListResponse<SafetyIncidentItem> incidents;
  final SafetyListResponse<ComplianceCertificateItem> certificates;
  final SafetyListResponse<SafetyDrillItem> drills;
  
  final String selectedCategory;
  final String selectedStatus;
  final String selectedBuildingId;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final dynamic selectedItem;

  const SafetyComplianceState({
    this.kpis = const SafetyComplianceKpis(),
    this.activeSubTab = 0,
    this.activeView = 'all',
    this.inspections = const SafetyListResponse(),
    this.incidents = const SafetyListResponse(),
    this.certificates = const SafetyListResponse(),
    this.drills = const SafetyListResponse(),
    this.selectedCategory = 'All',
    this.selectedStatus = 'All',
    this.selectedBuildingId = 'all',
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 10,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.selectedItem,
  });

  SafetyComplianceState copyWith({
    SafetyComplianceKpis? kpis,
    int? activeSubTab,
    String? activeView,
    SafetyListResponse<SafetyInspectionItem>? inspections,
    SafetyListResponse<SafetyIncidentItem>? incidents,
    SafetyListResponse<ComplianceCertificateItem>? certificates,
    SafetyListResponse<SafetyDrillItem>? drills,
    String? selectedCategory,
    String? selectedStatus,
    String? selectedBuildingId,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    dynamic selectedItem,
    bool clearSelectedItem = false,
  }) {
    return SafetyComplianceState(
      kpis: kpis ?? this.kpis,
      activeSubTab: activeSubTab ?? this.activeSubTab,
      activeView: activeView ?? this.activeView,
      inspections: inspections ?? this.inspections,
      incidents: incidents ?? this.incidents,
      certificates: certificates ?? this.certificates,
      drills: drills ?? this.drills,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedBuildingId: selectedBuildingId ?? this.selectedBuildingId,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      selectedItem: clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
    );
  }
}

class SafetyComplianceNotifier extends StateNotifier<SafetyComplianceState> {
  final SafetyComplianceApiService _api;

  SafetyComplianceNotifier(this._api) : super(const SafetyComplianceState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _api.getKpis(),
        _api.getInspections(
          category: state.selectedCategory,
          status: state.selectedStatus,
          buildingId: state.selectedBuildingId,
          search: state.searchQuery,
          page: state.currentPage,
          pageSize: state.pageSize,
        ),
        _api.getIncidents(
          status: state.selectedStatus,
          search: state.searchQuery,
          page: 1,
          pageSize: 10,
        ),
        _api.getCertificates(
          category: state.selectedCategory,
          status: state.selectedStatus,
          search: state.searchQuery,
          page: 1,
          pageSize: 10,
        ),
        _api.getDrills(page: 1, pageSize: 10),
      ]);

      state = state.copyWith(
        kpis: results[0] as SafetyComplianceKpis,
        inspections: results[1] as SafetyListResponse<SafetyInspectionItem>,
        incidents: results[2] as SafetyListResponse<SafetyIncidentItem>,
        certificates: results[3] as SafetyListResponse<ComplianceCertificateItem>,
        drills: results[4] as SafetyListResponse<SafetyDrillItem>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setActiveSubTab(int index) {
    state = state.copyWith(activeSubTab: index, currentPage: 1);
    refreshActiveSubTab();
  }

  void setActiveView(String view) {
    state = state.copyWith(activeView: view, currentPage: 1);
    if (view == 'all') {
      state = state.copyWith(selectedStatus: 'All', selectedCategory: 'All');
    } else if (view == 'overdue_inspections') {
      state = state.copyWith(activeSubTab: 0, selectedStatus: 'Needs Attention');
    } else if (view == 'critical_incidents') {
      state = state.copyWith(activeSubTab: 1, selectedStatus: 'Reported');
    } else if (view == 'expiring_certs') {
      state = state.copyWith(activeSubTab: 2, selectedStatus: 'Expiring Soon');
    } else if (view == 'conducted_drills') {
      state = state.copyWith(activeSubTab: 3, selectedStatus: 'Completed');
    }
    refreshActiveSubTab();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    refreshActiveSubTab();
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category, currentPage: 1);
    refreshActiveSubTab();
  }

  void setStatus(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    refreshActiveSubTab();
  }

  void setBuildingId(String buildingId) {
    state = state.copyWith(selectedBuildingId: buildingId, currentPage: 1);
    refreshActiveSubTab();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    refreshActiveSubTab();
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
    refreshActiveSubTab();
  }

  void selectItem(dynamic item) {
    state = state.copyWith(selectedItem: item);
  }

  void clearSelectedItem() {
    state = state.copyWith(clearSelectedItem: true);
  }

  Future<void> refreshActiveSubTab() async {
    state = state.copyWith(isLoading: true);
    try {
      if (state.activeSubTab == 0) {
        final res = await _api.getInspections(
          category: state.selectedCategory,
          status: state.selectedStatus,
          buildingId: state.selectedBuildingId,
          search: state.searchQuery,
          page: state.currentPage,
          pageSize: state.pageSize,
        );
        state = state.copyWith(inspections: res, isLoading: false);
      } else if (state.activeSubTab == 1) {
        final res = await _api.getIncidents(
          status: state.selectedStatus,
          search: state.searchQuery,
          page: state.currentPage,
          pageSize: state.pageSize,
        );
        state = state.copyWith(incidents: res, isLoading: false);
      } else if (state.activeSubTab == 2) {
        final res = await _api.getCertificates(
          category: state.selectedCategory,
          status: state.selectedStatus,
          search: state.searchQuery,
          page: state.currentPage,
          pageSize: state.pageSize,
        );
        state = state.copyWith(certificates: res, isLoading: false);
      } else {
        final res = await _api.getDrills(
          status: state.selectedStatus,
          page: state.currentPage,
          pageSize: state.pageSize,
        );
        state = state.copyWith(drills: res, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> saveInspection(Map<String, dynamic> payload, {String? inspectionId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.saveInspection(payload, inspectionId: inspectionId);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteInspection(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.deleteInspection(id);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> saveIncident(Map<String, dynamic> payload, {String? incidentId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.saveIncident(payload, incidentId: incidentId);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteIncident(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.deleteIncident(id);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> saveCertificate(Map<String, dynamic> payload, {String? certificateId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.saveCertificate(payload, certificateId: certificateId);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteCertificate(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.deleteCertificate(id);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> saveDrill(Map<String, dynamic> payload, {String? drillId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.saveDrill(payload, drillId: drillId);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteDrill(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.deleteDrill(id);
      state = state.copyWith(isSubmitting: false);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> exportData(String type) async {
    await _api.exportCsv(type);
  }
}

final safetyComplianceProvider = StateNotifierProvider<SafetyComplianceNotifier, SafetyComplianceState>((ref) {
  final api = ref.watch(safetyComplianceApiServiceProvider);
  return SafetyComplianceNotifier(api);
});
