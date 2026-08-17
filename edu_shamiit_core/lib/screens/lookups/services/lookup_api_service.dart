import '../../../../services/api_service.dart';
import '../models/lookup_models.dart';

class LookupApiService {
  final ApiService _api = ApiService();

  /// Fetch paginated list of lookup keys with search, filters, and tab selection
  Future<Map<String, dynamic>> getLookupKeys({
    String tab = 'all',
    String search = '',
    String status = '',
    String createdBy = 'all',
    String keyType = '',
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'tab': tab,
      'search': search,
      'status': status,
      'created_by': createdBy,
      'key_type': keyType,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/lookups', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    final keys = rawList.map((e) => LookupKeyModel.fromJson(Map<String, dynamic>.from(e))).toList();

    return {
      'keys': keys,
      'page': res['page'] ?? page,
      'pageSize': res['page_size'] ?? pageSize,
      'totalRecords': res['total_records'] ?? 0,
      'totalPages': res['total_pages'] ?? 1,
    };
  }

  /// Get full details, statistics, and cross-module usage for a single lookup key
  Future<Map<String, dynamic>> getLookupKeyDetail(String lookupId) async {
    final res = await _api.get('/lookups/$lookupId', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    final key = LookupKeyModel.fromJson(data);
    final stats = LookupStatsModel.fromJson(data['stats'] as Map<String, dynamic>?);
    final usage = LookupUsageModel.fromJson(data['usage'] as Map<String, dynamic>?);

    return {
      'key': key,
      'stats': stats,
      'usage': usage,
    };
  }

  /// Fetch paginated values for a lookup key
  Future<Map<String, dynamic>> getLookupValues(
    String lookupId, {
    String search = '',
    String status = '',
    String sortBy = 'sort_order',
    String sortOrder = 'ASC',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'search': search,
      'status': status,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/lookups/$lookupId/values', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    final values = rawList.map((e) => LookupValueModel.fromJson(Map<String, dynamic>.from(e))).toList();

    return {
      'values': values,
      'isOwner': res['is_owner'] == true,
      'page': res['page'] ?? page,
      'pageSize': res['page_size'] ?? pageSize,
      'totalRecords': res['total_records'] ?? 0,
      'totalPages': res['total_pages'] ?? 1,
    };
  }

  /// Create a new lookup key + initial values
  Future<Map<String, dynamic>> createLookupKey(Map<String, dynamic> payload) async {
    return await _api.post('/lookups', payload);
  }

  /// Update an existing lookup key (Creator/Owner only, with optimistic locking)
  Future<Map<String, dynamic>> updateLookupKey(String lookupId, Map<String, dynamic> payload, {int? version}) async {
    final body = {...payload};
    if (version != null) body['version'] = version;
    return await _api.patch('/lookups/$lookupId', body);
  }

  /// Delete or deactivate a lookup key
  Future<Map<String, dynamic>> deleteLookupKey(String lookupId, {bool forceDeactivate = false}) async {
    return await _api.delete('/lookups/$lookupId?force_deactivate=$forceDeactivate');
  }

  /// Add a single value to a lookup key
  Future<Map<String, dynamic>> createLookupValue(String lookupId, Map<String, dynamic> payload) async {
    return await _api.post('/lookups/$lookupId/values', payload);
  }

  /// Bulk add values to a lookup key
  Future<Map<String, dynamic>> bulkCreateLookupValues(String lookupId, List<Map<String, dynamic>> values) async {
    return await _api.post('/lookups/$lookupId/values/bulk', {'values': values});
  }

  /// Update a single lookup value
  Future<Map<String, dynamic>> updateLookupValue(String lookupId, String valueId, Map<String, dynamic> payload) async {
    return await _api.patch('/lookups/$lookupId/values/$valueId', payload);
  }

  /// Delete or deactivate a single lookup value
  Future<Map<String, dynamic>> deleteLookupValue(String lookupId, String valueId, {bool forceDeactivate = false}) async {
    return await _api.delete('/lookups/$lookupId/values/$valueId?force_deactivate=$forceDeactivate');
  }

  /// Reorder values within a lookup key
  Future<Map<String, dynamic>> reorderLookupValues(String lookupId, List<String> orderedIds) async {
    return await _api.patch('/lookups/$lookupId/values/reorder', {'ordered_value_ids': orderedIds});
  }

  /// Import values from CSV string or parsed payload
  Future<Map<String, dynamic>> importLookupValues(String lookupId, {String? csvContent, List<Map<String, dynamic>>? values}) async {
    return await _api.post('/lookups/$lookupId/import', {
      if (csvContent != null) 'csv_content': csvContent,
      if (values != null) 'values': values,
    });
  }

  /// Get audit trail log events for a lookup key
  Future<List<LookupAuditModel>> getLookupAuditLogs(String lookupId) async {
    final res = await _api.get('/lookups/$lookupId/audit-logs', useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    return rawList.map((e) => LookupAuditModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
