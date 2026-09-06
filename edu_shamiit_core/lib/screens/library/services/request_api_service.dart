import '../../../../config/app_config.dart';
import '../../../../services/api_service.dart';
import '../models/request_models.dart';


class RequestApiService {
  final ApiService _api = ApiService();

  /// Fetch aggregated KPI metrics, request type counts, and donut distribution
  Future<RequestKpisModel> fetchRequestKpis() async {
    final res = await _api.get('/library/requests/kpis', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return RequestKpisModel.fromJson(data);
  }

  /// Fetch dropdown options for request forms and filters
  Future<RequestFilterOptionsModel> fetchRequestOptions() async {
    final res = await _api.get('/library/requests/options', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return RequestFilterOptionsModel.fromJson(data);
  }

  /// Fetch paginated, multi-filtered list of requests
  Future<Map<String, dynamic>> fetchRequests({
    String? search,
    String? subtab,
    String? requestType,
    String? status,
    String? priority,
    String? requestedByRole,
    String? dateFrom,
    String? dateTo,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (subtab != null && subtab.isNotEmpty && subtab != 'ALL') 'subtab': subtab,
      if (requestType != null && requestType.isNotEmpty && requestType != 'ALL' && requestType != 'All') 'request_type': requestType,
      if (status != null && status.isNotEmpty && status != 'ALL' && status != 'All') 'status': status,
      if (priority != null && priority.isNotEmpty && priority != 'ALL' && priority != 'All') 'priority': priority,
      if (requestedByRole != null && requestedByRole.isNotEmpty && requestedByRole != 'ALL' && requestedByRole != 'All') 'requested_by_role': requestedByRole,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/library/requests', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : (res['items'] is List ? res['items'] as List : <dynamic>[]);
    final items = rawList.map((e) => LibraryRequestItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return {
      'items': items,
      'total': int.tryParse(res['total']?.toString() ?? '0') ?? items.length,
      'page': int.tryParse(res['page']?.toString() ?? '1') ?? page,
      'page_size': int.tryParse(res['page_size']?.toString() ?? '10') ?? pageSize,
      'total_pages': int.tryParse(res['total_pages']?.toString() ?? '1') ?? 1,
    };
  }

  /// Fetch full request detail with timeline, comments, and attachments
  Future<RequestDetailModel> fetchRequestDetail(String requestId) async {
    final res = await _api.get('/library/requests/$requestId', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return RequestDetailModel.fromJson(data);
  }

  /// Create a new library request
  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) async {
    final res = await _api.post('/library/requests', payload);
    return res;
  }

  /// Transition request status (NEW -> ACTIVE -> IN_PROGRESS -> RESOLVED -> COMPLETED / REJECTED / CANCELED)
  Future<Map<String, dynamic>> transitionStatus({
    required String requestId,
    required String toStatus,
    String? reason,
    String? comment,
  }) async {
    final res = await _api.post('/library/requests/$requestId/transition', {
      'to_status': toStatus,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    return res;
  }

  /// Assign request to a librarian
  Future<Map<String, dynamic>> assignRequest({
    required String requestId,
    required String assignedTo,
    String? notes,
  }) async {
    final res = await _api.post('/library/requests/$requestId/assign', {
      'assigned_to': assignedTo,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return res;
  }

  /// Approve or reject request awaiting approval
  Future<Map<String, dynamic>> approveRequest({
    required String requestId,
    required bool approved,
    String? comments,
  }) async {
    final res = await _api.post('/library/requests/$requestId/approve', {
      'approved': approved,
      if (comments != null && comments.trim().isNotEmpty) 'comments': comments.trim(),
    });
    return res;
  }

  /// Ask or answer clarification
  Future<Map<String, dynamic>> sendClarification({
    required String requestId,
    required String message,
    bool isResponse = false,
  }) async {
    final res = await _api.post('/library/requests/$requestId/clarification', {
      'message': message.trim(),
      'is_response': isResponse,
    });
    return res;
  }

  /// Add comment
  Future<Map<String, dynamic>> addComment({
    required String requestId,
    required String comment,
    bool isInternal = false,
  }) async {
    final res = await _api.post('/library/requests/$requestId/comments', {
      'comment': comment.trim(),
      'is_internal': isInternal,
    });
    return res;
  }

  /// Add attachment
  Future<Map<String, dynamic>> addAttachment({
    required String requestId,
    required String fileName,
    required String fileUrl,
    String? mimeType,
    int fileSize = 0,
  }) async {
    final res = await _api.post('/library/requests/$requestId/attachments', {
      'file_name': fileName,
      'file_url': fileUrl,
      'mime_type': mimeType,
      'file_size': fileSize,
    });
    return res;
  }

  /// Perform bulk action
  Future<Map<String, dynamic>> bulkAction({
    required List<String> requestIds,
    required String action,
    String? assignedTo,
    String? reason,
  }) async {
    final res = await _api.post('/library/requests/bulk-action', {
      'request_ids': requestIds,
      'action': action,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (reason != null) 'reason': reason,
    });
    return res;
  }

  /// Upload a temporary attachment file while creating a new request
  Future<Map<String, dynamic>> uploadTempAttachment(List<int> bytes, String filename) async {
    final res = await _api.multipartPostBytes(
      '/library/requests/upload-temp-attachment',
      bytes,
      filename,
      'file',
    );
    return res;
  }

  /// Upload and link an attachment directly to an existing request
  Future<Map<String, dynamic>> uploadRequestAttachment({
    required String requestId,
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await _api.multipartPostBytes(
      '/library/requests/$requestId/attachments/upload',
      bytes,
      filename,
      'file',
    );
    return res;
  }

  /// Export requests CSV
  String getExportCsvUrl() {
    return '${AppConfig.apiBaseUrl}/library/requests/export';
  }
}


