import '../../../../services/api_service.dart';
import '../models/circulation_models.dart';

class CirculationApiService {
  final ApiService _api = ApiService();

  /// Fetch aggregated KPI metrics for the circulation screen
  Future<CirculationStatsModel> fetchCirculationStats() async {
    final res = await _api.get('/library/circulation/stats', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return CirculationStatsModel.fromJson(data);
  }

  /// Fetch dynamic dropdown filter options
  Future<CirculationFilterOptionsModel> fetchFilterOptions() async {
    final res = await _api.get('/library/circulation/filter-options', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return CirculationFilterOptionsModel.fromJson(data);
  }

  /// Fetch today's chronological circulation activities
  Future<List<CirculationActivityModel>> fetchCirculationActivity({int limit = 10}) async {
    final res = await _api.get('/library/circulation/activity', query: {'limit': limit}, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    return rawList.map((e) => CirculationActivityModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Fetch overdue bracket summary
  Future<List<OverdueSummaryModel>> fetchOverdueSummary() async {
    final res = await _api.get('/library/circulation/overdue-summary', useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    return rawList.map((e) => OverdueSummaryModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Scan barcode or accession number or member ID
  Future<ScanResultModel> scanLookup(String code) async {
    final res = await _api.get('/library/circulation/scan', query: {'code': code.trim()}, useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return ScanResultModel.fromJson(data);
  }

  /// Fetch paginated, multi-filtered list of circulation transactions
  Future<Map<String, dynamic>> fetchTransactions({
    String? search,
    String? searchIn,
    String? subtab,
    String? status,
    String? transactionType,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (searchIn != null && searchIn.isNotEmpty && searchIn != 'All Transactions') 'search_in': searchIn,
      if (subtab != null && subtab.isNotEmpty && subtab != 'ALL') 'subtab': subtab,
      if (status != null && status.isNotEmpty && status != 'All' && status != 'ALL') 'status': status,
      if (transactionType != null && transactionType.isNotEmpty && transactionType != 'All' && transactionType != 'ALL')
        'transaction_type': transactionType,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/library/transactions', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    final items = rawList.map((e) => LibraryTransactionModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return {
      'items': items,
      'total': res['total'] ?? items.length,
      'page': res['page'] ?? page,
      'page_size': res['page_size'] ?? pageSize,
      'total_pages': res['total_pages'] ?? 1,
      'counts': res['counts'] is Map ? Map<String, dynamic>.from(res['counts'] as Map) : <String, dynamic>{},
    };
  }

  /// Fetch complete transaction detail including audit timeline
  Future<Map<String, dynamic>> fetchTransactionDetail(String transactionId) async {
    final res = await _api.get('/library/transactions/$transactionId', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return Map<String, dynamic>.from(data);
  }

  /// Issue one or multiple books atomically
  Future<Map<String, dynamic>> issueBooks({
    required String memberId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final body = {
      'member_id': memberId,
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    return await _api.post('/library/transactions/issue', body);
  }

  /// Process return of books with fine & condition handling
  Future<Map<String, dynamic>> returnBooks({
    required List<Map<String, dynamic>> items,
    bool collectFine = false,
    String paymentMethod = 'CASH',
    String? paymentRef,
  }) async {
    final body = {
      'items': items,
      'collect_fine': collectFine,
      'payment_method': paymentMethod,
      if (paymentRef != null && paymentRef.isNotEmpty) 'payment_ref': paymentRef,
    };
    return await _api.post('/library/transactions/return', body);
  }

  /// Renew an active loan
  Future<Map<String, dynamic>> renewBook({
    required String borrowId,
    String? newDueDate,
    String? reason,
  }) async {
    final body = {
      if (newDueDate != null && newDueDate.isNotEmpty) 'new_due_date': newDueDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    return await _api.post('/library/transactions/$borrowId/renew', body);
  }

  /// Perform bulk action across selected transactions
  Future<Map<String, dynamic>> bulkAction({
    required List<String> borrowIds,
    required String action,
    Map<String, dynamic>? params,
  }) async {
    final body = {
      'borrow_ids': borrowIds,
      'action': action,
      'params': params ?? {},
    };
    return await _api.post('/library/transactions/bulk-action', body);
  }

  /// List issue & renewal requests
  Future<Map<String, dynamic>> fetchRequests({String? status, int page = 1, int pageSize = 10}) async {
    final query = <String, dynamic>{
      if (status != null && status != 'ALL') 'status': status,
      'page': page,
      'page_size': pageSize,
    };
    final res = await _api.get('/library/requests', query: query, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    final items = rawList.map((e) => LibraryRequestModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return {
      'items': items,
      'total': res['total'] ?? items.length,
      'page': res['page'] ?? page,
      'page_size': res['page_size'] ?? pageSize,
    };
  }

  /// Create new issue request
  Future<Map<String, dynamic>> createRequest({
    required String memberId,
    required String bookId,
    String requestType = 'ISSUE',
    String? reason,
    String? requestedDueDate,
  }) async {
    final body = {
      'member_id': memberId,
      'book_id': bookId,
      'request_type': requestType,
      if (reason != null) 'reason': reason,
      if (requestedDueDate != null) 'requested_due_date': requestedDueDate,
    };
    return await _api.post('/library/requests', body);
  }

  /// Process request (Approve, Reject, Issue)
  Future<Map<String, dynamic>> processRequest({
    required String requestId,
    required String action,
    String? rejectionReason,
    String? copyId,
  }) async {
    final body = {
      'action': action,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (copyId != null) 'copy_id': copyId,
    };
    return await _api.post('/library/requests/$requestId/process', body);
  }

  /// List library fines
  Future<List<Map<String, dynamic>>> fetchFines({String? status, String? memberId}) async {
    final query = <String, dynamic>{
      if (status != null && status != 'ALL') 'status': status,
      if (memberId != null) 'member_id': memberId,
    };
    final res = await _api.get('/library/fines', query: query, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Collect fine payment
  Future<Map<String, dynamic>> collectFine({
    required String fineId,
    required double amount,
    String paymentMethod = 'CASH',
    String? reference,
    String? notes,
  }) async {
    final body = {
      'amount': amount,
      'payment_method': paymentMethod,
      if (reference != null) 'transaction_reference': reference,
      if (notes != null) 'notes': notes,
    };
    return await _api.post('/library/fines/$fineId/collect', body);
  }

  /// Waive fine
  Future<Map<String, dynamic>> waiveFine({
    required String fineId,
    required double amount,
    required String reason,
  }) async {
    final body = {
      'amount': amount,
      'reason': reason,
    };
    return await _api.post('/library/fines/$fineId/waive', body);
  }
}

