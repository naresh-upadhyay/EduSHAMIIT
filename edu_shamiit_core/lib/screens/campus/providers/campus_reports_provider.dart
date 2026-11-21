import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_models.dart';
import '../services/campus_api_service.dart';
import '../services/campus_lookup_helper.dart';
import '../../../utils/js_helper_stub.dart'
    if (dart.library.js) '../../../utils/js_helper_web.dart';

class CampusReportsState {
  final int selectedReportType;
  final String timeRange;
  final String? selectedBuildingId;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final List<BuildingModel> buildings;
  final bool isLoading;
  final String? errorMessage;

  const CampusReportsState({
    this.selectedReportType = 0,
    this.timeRange = 'Last 30 Days',
    this.selectedBuildingId,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 10,
    this.buildings = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CampusReportsState copyWith({
    int? selectedReportType,
    String? timeRange,
    String? selectedBuildingId,
    bool clearBuilding = false,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    List<BuildingModel>? buildings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CampusReportsState(
      selectedReportType: selectedReportType ?? this.selectedReportType,
      timeRange: timeRange ?? this.timeRange,
      selectedBuildingId: clearBuilding ? null : (selectedBuildingId ?? this.selectedBuildingId),
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      buildings: buildings ?? this.buildings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class CampusReportsNotifier extends StateNotifier<CampusReportsState> {
  final CampusApiService _apiService;

  CampusReportsNotifier(this._apiService) : super(const CampusReportsState()) {
    loadBuildings();
  }

  Future<void> loadBuildings() async {
    state = state.copyWith(isLoading: true);
    try {
      final bldgs = await CampusLookupHelper.instance.getActiveBuildings();
      state = state.copyWith(buildings: bldgs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setReportType(int type) {
    state = state.copyWith(selectedReportType: type, currentPage: 1);
  }

  void setTimeRange(String range) {
    state = state.copyWith(timeRange: range, currentPage: 1);
  }

  void setBuildingId(String? buildingId) {
    state = state.copyWith(selectedBuildingId: buildingId, clearBuilding: buildingId == null, currentPage: 1);
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q, currentPage: 1);
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
  }

  void exportCsv() {
    _apiService.exportCampusReport(
      reportType: state.selectedReportType,
      buildingId: state.selectedBuildingId,
      timeRange: state.timeRange,
    );
  }

  void generateExecutiveDossier({
    required String reportTitle,
    required List<String> kpiTitles,
    required List<String> kpiValues,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    printCampusInstitutionalDossierHtml(
      reportTitle: reportTitle,
      period: state.timeRange,
      facilityScope: state.selectedBuildingId != null
          ? (state.buildings.where((b) => b.id == state.selectedBuildingId).firstOrNull?.name ?? 'Selected Building')
          : 'All Campus Infrastructure',
      kpiTitles: kpiTitles,
      kpiValues: kpiValues,
      headers: headers,
      rows: rows,
    );
  }
}

final campusReportsProvider = StateNotifierProvider<CampusReportsNotifier, CampusReportsState>((ref) {
  return CampusReportsNotifier(CampusApiService.instance);
});
