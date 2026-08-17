import '../../../../services/api_service.dart';
import '../models/notice_models.dart';

class NoticeApiService {
  final ApiService _api = ApiService();

  /// Fetch paginated list of notices with filters
  Future<Map<String, dynamic>> getNotices({
    String tab = 'all',
    String search = '',
    String category = '',
    String priority = '',
    String status = '',
    String audience = '',
    String? fromDate,
    String? toDate,
    bool? requiresAck,
    bool? isRead,
    bool? hasAttachment,
    String sortBy = 'published_at',
    String sortOrder = 'DESC',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'tab': tab,
      'search': search,
      'category': category,
      'priority': priority,
      'status': status,
      'audience': audience,
      if (fromDate != null) 'from_date': fromDate,
      if (toDate != null) 'to_date': toDate,
      if (requiresAck != null) 'requires_ack': requiresAck,
      if (isRead != null) 'is_read': isRead,
      if (hasAttachment != null) 'has_attachment': hasAttachment,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/notices', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    final notices = rawList.map((e) => NoticeModel.fromJson(Map<String, dynamic>.from(e))).toList();

    return {
      'notices': notices,
      'page': res['page'] ?? page,
      'pageSize': res['page_size'] ?? pageSize,
      'totalRecords': res['total_records'] ?? 0,
      'totalPages': res['total_pages'] ?? 1,
    };
  }

  /// Get summary analytics and engagement stats
  Future<NoticeSummaryModel> getNoticeSummary() async {
    final res = await _api.get('/notices/summary', useCache: false);
    return NoticeSummaryModel.fromJson(res);
  }

  /// Fetch dynamic roles, classes, and categories
  Future<Map<String, dynamic>> getMetadata() async {
    final res = await _api.get('/notices/metadata', useCache: false);
    return res;
  }

  /// Fetch active notice categories
  Future<List<NoticeCategoryModel>> getCategories() async {
    final res = await _api.get('/notices/categories', useCache: false);
    final list = res['data'] is List ? res['data'] as List : [];
    return list.map((e) => NoticeCategoryModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Create or update category
  Future<void> saveCategory(Map<String, dynamic> payload) async {
    await _api.post('/notices/categories', payload);
  }

  /// Get single notice detail
  Future<NoticeModel> getNoticeDetail(String id) async {
    final res = await _api.get('/notices/$id', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return NoticeModel.fromJson(data);
  }

  /// Create notice
  Future<Map<String, dynamic>> createNotice(Map<String, dynamic> payload) async {
    return await _api.post('/notices', payload);
  }

  /// Update notice
  Future<Map<String, dynamic>> updateNotice(String id, Map<String, dynamic> payload) async {
    return await _api.put('/notices/$id', payload);
  }

  /// Soft delete notice
  Future<void> deleteNotice(String id) async {
    await _api.delete('/notices/$id');
  }

  /// Publish notice immediately
  Future<void> publishNotice(String id) async {
    await _api.post('/notices/$id/publish', {});
  }

  /// Archive notice
  Future<void> archiveNotice(String id) async {
    await _api.post('/notices/$id/archive', {});
  }

  /// Restore notice to draft
  Future<void> restoreNotice(String id) async {
    await _api.post('/notices/$id/restore', {});
  }

  /// Duplicate notice
  Future<Map<String, dynamic>> duplicateNotice(String id) async {
    return await _api.post('/notices/$id/duplicate', {});
  }

  /// Acknowledge notice
  Future<void> acknowledgeNotice(String id, {String status = 'acknowledged', String? declineReason}) async {
    await _api.post('/notices/$id/acknowledge', {
      'status': status,
      if (declineReason != null) 'decline_reason': declineReason,
    });
  }

  /// Approve notice
  Future<void> approveNotice(String id) async {
    await _api.post('/notices/$id/approve', {});
  }

  /// Reject notice with mandatory reason
  Future<void> rejectNotice(String id, String reason) async {
    await _api.post('/notices/$id/reject', {'action': 'reject', 'reason': reason});
  }

  /// Request changes on notice
  Future<void> requestChanges(String id, String comment) async {
    await _api.post('/notices/$id/reject', {'action': 'request_changes', 'reason': comment});
  }

  /// Get recipient acknowledgement tracking table
  Future<Map<String, dynamic>> getAcknowledgements(String id, {String search = '', String status = '', int page = 1, int pageSize = 20}) async {
    final res = await _api.get('/notices/$id/acknowledgements', query: {
      'search': search,
      'status': status,
      'page': page,
      'page_size': pageSize,
    }, useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    final recipients = rawList.map((e) => NoticeRecipientModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final summary = res['summary'] is Map ? res['summary'] : {};
    return {
      'recipients': recipients,
      'summary': summary,
      'page': res['page'] ?? page,
      'pageSize': res['page_size'] ?? pageSize,
    };
  }

  /// Send reminder notification to pending recipients
  Future<Map<String, dynamic>> remindPendingRecipients(String id) async {
    return await _api.post('/notices/$id/remind', {});
  }

  /// Bulk actions
  Future<void> bulkAction(List<String> ids, String action) async {
    await _api.post('/notices/bulk-action', {
      'notice_ids': ids,
      'action': action,
    });
  }

  /// Bulk import notices
  Future<Map<String, dynamic>> bulkImportNotices(List<Map<String, dynamic>> notices) async {
    return await _api.post('/notices/bulk-import', {
      'notices': notices,
    });
  }
}
