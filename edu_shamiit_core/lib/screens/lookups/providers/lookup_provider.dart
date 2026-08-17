import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lookup_models.dart';
import '../services/lookup_api_service.dart';

class LookupState {
  final List<LookupKeyModel> keys;
  final LookupKeyModel? selectedKey;
  final LookupStatsModel stats;
  final LookupUsageModel usage;
  final List<LookupValueModel> values;
  final bool isOwner;

  final String selectedTab; // 'all', 'active', 'inactive', 'system', 'custom'
  final String searchQuery;
  final String statusFilter; // '', 'ACTIVE', 'INACTIVE'
  final String createdByFilter; // 'all', 'my_keys', 'others', 'system'
  final String keyTypeFilter; // '', 'SYSTEM', 'CUSTOM'

  final int keysPage;
  final int keysPageSize;
  final int keysTotalRecords;
  final int keysTotalPages;

  final int valuesPage;
  final int valuesPageSize;
  final int valuesTotalRecords;
  final int valuesTotalPages;

  final bool isKeysLoading;
  final bool isDetailLoading;
  final bool isValuesLoading;
  final bool isSaving;
  final String? errorMessage;

  const LookupState({
    this.keys = const [],
    this.selectedKey,
    this.stats = const LookupStatsModel(),
    this.usage = const LookupUsageModel(),
    this.values = const [],
    this.isOwner = false,
    this.selectedTab = 'all',
    this.searchQuery = '',
    this.statusFilter = '',
    this.createdByFilter = 'all',
    this.keyTypeFilter = '',
    this.keysPage = 1,
    this.keysPageSize = 10,
    this.keysTotalRecords = 0,
    this.keysTotalPages = 1,
    this.valuesPage = 1,
    this.valuesPageSize = 10,
    this.valuesTotalRecords = 0,
    this.valuesTotalPages = 1,
    this.isKeysLoading = false,
    this.isDetailLoading = false,
    this.isValuesLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  LookupState copyWith({
    List<LookupKeyModel>? keys,
    LookupKeyModel? selectedKey,
    bool clearSelectedKey = false,
    LookupStatsModel? stats,
    LookupUsageModel? usage,
    List<LookupValueModel>? values,
    bool? isOwner,
    String? selectedTab,
    String? searchQuery,
    String? statusFilter,
    String? createdByFilter,
    String? keyTypeFilter,
    int? keysPage,
    int? keysPageSize,
    int? keysTotalRecords,
    int? keysTotalPages,
    int? valuesPage,
    int? valuesPageSize,
    int? valuesTotalRecords,
    int? valuesTotalPages,
    bool? isKeysLoading,
    bool? isDetailLoading,
    bool? isValuesLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LookupState(
      keys: keys ?? this.keys,
      selectedKey: clearSelectedKey ? null : (selectedKey ?? this.selectedKey),
      stats: stats ?? this.stats,
      usage: usage ?? this.usage,
      values: values ?? this.values,
      isOwner: isOwner ?? this.isOwner,
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      createdByFilter: createdByFilter ?? this.createdByFilter,
      keyTypeFilter: keyTypeFilter ?? this.keyTypeFilter,
      keysPage: keysPage ?? this.keysPage,
      keysPageSize: keysPageSize ?? this.keysPageSize,
      keysTotalRecords: keysTotalRecords ?? this.keysTotalRecords,
      keysTotalPages: keysTotalPages ?? this.keysTotalPages,
      valuesPage: valuesPage ?? this.valuesPage,
      valuesPageSize: valuesPageSize ?? this.valuesPageSize,
      valuesTotalRecords: valuesTotalRecords ?? this.valuesTotalRecords,
      valuesTotalPages: valuesTotalPages ?? this.valuesTotalPages,
      isKeysLoading: isKeysLoading ?? this.isKeysLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isValuesLoading: isValuesLoading ?? this.isValuesLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LookupNotifier extends StateNotifier<LookupState> {
  final LookupApiService _service = LookupApiService();
  Timer? _debounceTimer;

  LookupNotifier() : super(const LookupState()) {
    loadKeys();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Load Lookup Keys List
  Future<void> loadKeys({bool preserveSelection = true}) async {
    state = state.copyWith(isKeysLoading: true, clearError: true);
    try {
      final res = await _service.getLookupKeys(
        tab: state.selectedTab,
        search: state.searchQuery,
        status: state.statusFilter,
        createdBy: state.createdByFilter,
        keyType: state.keyTypeFilter,
        page: state.keysPage,
        pageSize: state.keysPageSize,
      );

      final keysList = res['keys'] as List<LookupKeyModel>;
      final currentSelected = state.selectedKey;
      LookupKeyModel? targetKey;

      if (!preserveSelection || currentSelected == null || !keysList.any((k) => k.id == currentSelected.id)) {
        targetKey = keysList.isNotEmpty ? keysList.first : null;
      } else {
        // Refresh reference with updated counts
        targetKey = keysList.firstWhere((k) => k.id == currentSelected.id, orElse: () => keysList.first);
      }

      state = state.copyWith(
        keys: keysList,
        selectedKey: targetKey,
        clearSelectedKey: targetKey == null,
        keysTotalRecords: res['totalRecords'] ?? 0,
        keysTotalPages: res['totalPages'] ?? 1,
        isKeysLoading: false,
      );

      if (targetKey != null) {
        await selectKey(targetKey.id);
      } else {
        state = state.copyWith(
          values: [],
          stats: const LookupStatsModel(),
          usage: const LookupUsageModel(),
          isOwner: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isKeysLoading: false, errorMessage: e.toString());
    }
  }

  /// Select a Key and load its details and values
  Future<void> selectKey(String keyId) async {
    state = state.copyWith(isDetailLoading: true, isValuesLoading: true, clearError: true);
    try {
      // 1. Fetch Key Detail & Stats
      final detailRes = await _service.getLookupKeyDetail(keyId);
      final key = detailRes['key'] as LookupKeyModel;
      final stats = detailRes['stats'] as LookupStatsModel;
      final usage = detailRes['usage'] as LookupUsageModel;

      // 2. Fetch Key Values
      final valuesRes = await _service.getLookupValues(
        keyId,
        page: state.valuesPage,
        pageSize: state.valuesPageSize,
      );
      final values = valuesRes['values'] as List<LookupValueModel>;
      final isOwner = valuesRes['isOwner'] == true;

      state = state.copyWith(
        selectedKey: key,
        stats: stats,
        usage: usage,
        values: values,
        isOwner: isOwner,
        valuesTotalRecords: valuesRes['totalRecords'] ?? 0,
        valuesTotalPages: valuesRes['totalPages'] ?? 1,
        isDetailLoading: false,
        isValuesLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDetailLoading: false,
        isValuesLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Load Values for current key
  Future<void> loadValues({String? search, String? status, int? page}) async {
    if (state.selectedKey == null) return;
    state = state.copyWith(isValuesLoading: true, clearError: true);
    try {
      final p = page ?? state.valuesPage;
      final res = await _service.getLookupValues(
        state.selectedKey!.id,
        search: search ?? '',
        status: status ?? '',
        page: p,
        pageSize: state.valuesPageSize,
      );

      state = state.copyWith(
        values: res['values'] as List<LookupValueModel>,
        isOwner: res['isOwner'] == true,
        valuesPage: p,
        valuesTotalRecords: res['totalRecords'] ?? 0,
        valuesTotalPages: res['totalPages'] ?? 1,
        isValuesLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isValuesLoading: false, errorMessage: e.toString());
    }
  }

  /// Tab Change
  void setTab(String tab) {
    if (state.selectedTab == tab) return;
    state = state.copyWith(selectedTab: tab, keysPage: 1);
    loadKeys(preserveSelection: false);
  }

  /// Search with Debounce
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(keysPage: 1);
      loadKeys(preserveSelection: false);
    });
  }

  /// Status Filter
  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status, keysPage: 1);
    loadKeys(preserveSelection: false);
  }

  /// Created By Filter
  void setCreatedByFilter(String filter) {
    state = state.copyWith(createdByFilter: filter, keysPage: 1);
    loadKeys(preserveSelection: false);
  }

  /// Key Type Filter
  void setKeyTypeFilter(String keyType) {
    state = state.copyWith(keyTypeFilter: keyType, keysPage: 1);
    loadKeys(preserveSelection: false);
  }

  /// Pagination for Keys
  void setKeysPage(int page) {
    if (page == state.keysPage) return;
    state = state.copyWith(keysPage: page);
    loadKeys(preserveSelection: false);
  }

  /// Pagination for Values
  void setValuesPage(int page) {
    if (page == state.valuesPage) return;
    loadValues(page: page);
  }

  // ==========================================================================
  // CRUD MUTATIONS (Creator-Owned / Backend Enforced)
  // ==========================================================================

  /// Create Lookup Key
  Future<bool> createLookupKey(Map<String, dynamic> payload) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final res = await _service.createLookupKey(payload);
      state = state.copyWith(isSaving: false);
      final newKeyId = res['data']?['id']?.toString();
      await loadKeys(preserveSelection: false);
      if (newKeyId != null) {
        await selectKey(newKeyId);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Update Lookup Key
  Future<bool> updateLookupKey(String lookupId, Map<String, dynamic> payload) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.updateLookupKey(lookupId, payload, version: state.selectedKey?.version);
      state = state.copyWith(isSaving: false);
      await loadKeys(preserveSelection: true);
      await selectKey(lookupId);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Delete / Deactivate Lookup Key
  Future<Map<String, dynamic>> deleteLookupKey(String lookupId, {bool forceDeactivate = false}) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final res = await _service.deleteLookupKey(lookupId, forceDeactivate: forceDeactivate);
      state = state.copyWith(isSaving: false);
      await loadKeys(preserveSelection: false);
      return res;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Add Value
  Future<bool> addValue(Map<String, dynamic> payload) async {
    if (state.selectedKey == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.createLookupValue(state.selectedKey!.id, payload);
      state = state.copyWith(isSaving: false);
      await selectKey(state.selectedKey!.id);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Bulk Add Values
  Future<Map<String, dynamic>> bulkAddValues(List<Map<String, dynamic>> values) async {
    if (state.selectedKey == null) return {'success': false, 'error': 'No lookup selected'};
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final res = await _service.bulkCreateLookupValues(state.selectedKey!.id, values);
      state = state.copyWith(isSaving: false);
      await selectKey(state.selectedKey!.id);
      return res;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Update Value
  Future<bool> updateValue(String valueId, Map<String, dynamic> payload) async {
    if (state.selectedKey == null) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _service.updateLookupValue(state.selectedKey!.id, valueId, payload);
      state = state.copyWith(isSaving: false);
      await selectKey(state.selectedKey!.id);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Delete / Deactivate Value
  Future<Map<String, dynamic>> deleteValue(String valueId, {bool forceDeactivate = false}) async {
    if (state.selectedKey == null) return {'success': false};
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final res = await _service.deleteLookupValue(state.selectedKey!.id, valueId, forceDeactivate: forceDeactivate);
      state = state.copyWith(isSaving: false);
      await selectKey(state.selectedKey!.id);
      return res;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Reorder Values Sequence
  Future<bool> reorderValues(List<String> orderedIds) async {
    if (state.selectedKey == null) return false;
    try {
      await _service.reorderLookupValues(state.selectedKey!.id, orderedIds);
      await loadValues();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Import Values from CSV
  Future<Map<String, dynamic>> importValues({String? csvContent, List<Map<String, dynamic>>? values}) async {
    if (state.selectedKey == null) return {'success': false};
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final res = await _service.importLookupValues(state.selectedKey!.id, csvContent: csvContent, values: values);
      state = state.copyWith(isSaving: false);
      await selectKey(state.selectedKey!.id);
      return res;
    } catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.toString());
      rethrow;
    }
  }

  /// Fetch Audit Logs for current selected key
  Future<List<LookupAuditModel>> getAuditLogs() async {
    if (state.selectedKey == null) return [];
    return await _service.getLookupAuditLogs(state.selectedKey!.id);
  }
}

final lookupProvider = StateNotifierProvider<LookupNotifier, LookupState>((ref) {
  return LookupNotifier();
});
