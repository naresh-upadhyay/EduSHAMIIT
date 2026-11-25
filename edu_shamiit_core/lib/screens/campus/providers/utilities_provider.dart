import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/campus_api_service.dart';

class UtilitiesState {
  final Map<String, dynamic> kpis;
  final List<Map<String, dynamic>> readingLogs;
  final int activeCategory; // 0: Electrical & Solar, 1: Water & RO, 2: Internet & Fiber, 3: Gas & HVAC
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final int? sortCol;
  final bool sortAsc;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, dynamic>? latestAnomaly;
  final double tariffKwh;
  final double tariffDiesel;

  const UtilitiesState({
    this.kpis = const {},
    this.readingLogs = const [],
    this.activeCategory = 0,
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalCount = 0,
    this.sortCol = 0,
    this.sortAsc = false,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.latestAnomaly,
    this.tariffKwh = 9.50,
    this.tariffDiesel = 89.00,
  });

  UtilitiesState copyWith({
    Map<String, dynamic>? kpis,
    List<Map<String, dynamic>>? readingLogs,
    int? activeCategory,
    int? currentPage,
    int? pageSize,
    int? totalCount,
    int? sortCol,
    bool? sortAsc,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, dynamic>? latestAnomaly,
    bool clearAnomaly = false,
    double? tariffKwh,
    double? tariffDiesel,
  }) {
    return UtilitiesState(
      kpis: kpis ?? this.kpis,
      readingLogs: readingLogs ?? this.readingLogs,
      activeCategory: activeCategory ?? this.activeCategory,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      sortCol: sortCol ?? this.sortCol,
      sortAsc: sortAsc ?? this.sortAsc,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      latestAnomaly: clearAnomaly ? null : (latestAnomaly ?? this.latestAnomaly),
      tariffKwh: tariffKwh ?? this.tariffKwh,
      tariffDiesel: tariffDiesel ?? this.tariffDiesel,
    );
  }
}

class UtilitiesNotifier extends StateNotifier<UtilitiesState> {
  final CampusApiService _apiService;

  UtilitiesNotifier(this._apiService) : super(const UtilitiesState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final kpis = await _apiService.getUtilitiesKpis();

      String? uType;
      switch (state.activeCategory) {
        case 0:
          uType = null; // show all or filter if needed
          break;
        case 1:
          uType = 'Water';
          break;
        case 2:
          uType = 'Internet';
          break;
        case 3:
          uType = 'Gas / HVAC';
          break;
      }

      const colKeys = ['recorded_at', 'utility_name', 'reading_value', 'location', 'recorded_by', 'status'];
      final sortColKey = (state.sortCol != null && state.sortCol! >= 0 && state.sortCol! < colKeys.length)
          ? colKeys[state.sortCol!]
          : 'recorded_at';

      final res = await _apiService.getUtilityReadings(
        utilityType: uType,
        sortBy: sortColKey,
        sortOrder: state.sortAsc ? 'asc' : 'desc',
        page: state.currentPage,
        pageSize: state.pageSize,
      );

      final list = (res['data'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final total = (res['total_count'] as num?)?.toInt() ?? list.length;

      // Check anomalies
      Map<String, dynamic>? anomaly;
      try {
        final anomRes = await _apiService.getUtilityAnomalies();
        if (anomRes['success'] == true && anomRes['is_anomaly'] == true) {
          anomaly = anomRes;
        }
      } catch (_) {}

      state = state.copyWith(
        kpis: kpis,
        readingLogs: list,
        totalCount: total,
        latestAnomaly: anomaly,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setActiveCategory(int index) {
    state = state.copyWith(activeCategory: index, currentPage: 1);
    loadData();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    loadData();
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
    loadData();
  }

  void setSorting(int? col, bool asc) {
    state = state.copyWith(sortCol: col, sortAsc: asc, currentPage: 1);
    loadData();
  }

  Future<bool> logReading(Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _apiService.logUtilityReading(payload);
      if (res['success'] == true) {
        await loadData();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final utilitiesProvider = StateNotifierProvider<UtilitiesNotifier, UtilitiesState>((ref) {
  return UtilitiesNotifier(CampusApiService.instance);
});
