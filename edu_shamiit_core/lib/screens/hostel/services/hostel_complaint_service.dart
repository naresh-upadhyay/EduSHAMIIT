import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/hostel_complaint_models.dart';

class HostelComplaintService {
  final ApiService _api = ApiService();

  /// Retrieve top 6 KPI overview cards
  Future<ComplaintKpiData> getOverview({String academicYear = '2026 - 2027'}) async {
    try {
      final res = await _api.get(
        '/hostel/complaints/overview',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      final data = (res['data'] is Map<String, dynamic>) ? res['data'] as Map<String, dynamic> : res;
      return ComplaintKpiData.fromJson(data);
    } catch (_) {}
    return const ComplaintKpiData();
  }

  /// Paginated list of complaints with search, multi-filter, and sorting
  Future<Map<String, dynamic>> getComplaints({
    String? search,
    String? hostel,
    String? category,
    String? priority,
    String? status,
    String? subtab,
    String? fromDate,
    String? toDate,
    int page = 1,
    int pageSize = 10,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String academicYear = '2026 - 2027',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (hostel != null && hostel.trim().isNotEmpty && hostel != 'All Hostels') query['hostel'] = hostel.trim();
      if (category != null && category.trim().isNotEmpty && category != 'All Categories') query['category'] = category.trim();
      if (priority != null && priority.trim().isNotEmpty && priority != 'All Priorities') query['priority'] = priority.trim();
      if (status != null && status.trim().isNotEmpty && status != 'All Status') query['status'] = status.trim();
      if (subtab != null && subtab.trim().isNotEmpty && subtab != 'All Complaints') query['subtab'] = subtab.trim();
      if (fromDate != null && fromDate.trim().isNotEmpty) query['from_date'] = fromDate.trim();
      if (toDate != null && toDate.trim().isNotEmpty) query['to_date'] = toDate.trim();

      final res = await _api.get('/hostel/complaints', query: query, useCache: false);
      final data = (res['data'] is Map<String, dynamic>) ? res['data'] as Map<String, dynamic> : res;
      final rawList = data['records'] as List<dynamic>? ?? [];
      final items = <HostelComplaintItem>[];
      for (int i = 0; i < rawList.length; i++) {
        final itemMap = rawList[i] as Map<String, dynamic>;
        items.add(HostelComplaintItem.fromJson(itemMap, index: (page - 1) * pageSize + i + 1));
      }

      final pagination = data['pagination'] is Map<String, dynamic>
          ? ComplaintPagination.fromJson(data['pagination'] as Map<String, dynamic>)
          : ComplaintPagination(totalRecords: items.length, page: page, pageSize: pageSize);

      return {
        'records': items,
        'pagination': pagination,
      };
    } catch (_) {}
    return {
      'records': <HostelComplaintItem>[],
      'pagination': ComplaintPagination(page: page, pageSize: pageSize),
    };
  }

  /// Retrieve full 360-degree complaint details
  Future<HostelComplaintDetail360?> getComplaintById(String id) async {
    try {
      final res = await _api.get('/hostel/complaints/$id', useCache: false);
      final data = (res['data'] is Map<String, dynamic>) ? res['data'] as Map<String, dynamic> : res;
      if (data['success'] == true || data['complaint'] != null) {
        return HostelComplaintDetail360.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Submit new complaint
  Future<Map<String, dynamic>> createComplaint(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/hostel/complaints', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Assign complaint
  Future<Map<String, dynamic>> assignComplaint(
    String id, {
    required String assignedUserId,
    String? assignedUserName,
    String? assignedUserRole,
    String? notes,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/assign', {
        'assigned_user_id': assignedUserId,
        if (assignedUserName != null) 'assigned_user_name': assignedUserName,
        if (assignedUserRole != null) 'assigned_user_role': assignedUserRole,
        if (notes != null) 'notes': notes,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update complaint status
  Future<Map<String, dynamic>> updateStatus(
    String id, {
    required String status,
    String? reason,
    String? resolutionSummary,
    String? resolutionType,
    List<dynamic>? partsUsed,
    double? cost,
    String? equipmentStatus,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/status', {
        'status': status,
        if (reason != null) 'reason': reason,
        if (resolutionSummary != null) 'resolution_summary': resolutionSummary,
        if (resolutionType != null) 'resolution_type': resolutionType,
        if (partsUsed != null) 'parts_used': partsUsed,
        if (cost != null) 'resolution_cost': cost,
        if (equipmentStatus != null) 'equipment_status_after': equipmentStatus,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Resolve complaint
  Future<Map<String, dynamic>> resolveComplaint(
    String id, {
    required String resolutionSummary,
    String resolutionType = 'Repaired',
    List<dynamic>? partsUsed,
    double? cost,
    String? equipmentStatus,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/resolve', {
        'status': 'RESOLVED',
        'resolution_summary': resolutionSummary,
        'resolution_type': resolutionType,
        if (partsUsed != null) 'parts_used': partsUsed,
        if (cost != null) 'resolution_cost': cost,
        if (equipmentStatus != null) 'equipment_status_after': equipmentStatus,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Formally complete complaint
  Future<Map<String, dynamic>> completeComplaint(String id) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/complete', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reopen complaint
  Future<Map<String, dynamic>> reopenComplaint(String id, {String? reason}) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/reopen', {
        'reason': reason ?? 'Issue reported unresolved',
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reject complaint
  Future<Map<String, dynamic>> rejectComplaint(String id, {required String reason}) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/reject', {
        'reason': reason,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancel complaint
  Future<Map<String, dynamic>> cancelComplaint(String id, {String? reason}) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/cancel', {
        'reason': reason ?? 'Canceled by resident',
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Post comment or internal note
  Future<Map<String, dynamic>> addComment(
    String id, {
    required String message,
    String commentType = 'PUBLIC_UPDATE',
    List<dynamic>? attachments,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/comments', {
        'message': message,
        'comment_type': commentType,
        'attachments': attachments ?? [],
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Submit resident feedback
  Future<Map<String, dynamic>> submitFeedback(
    String id, {
    required int rating,
    int? quality,
    int? responseTime,
    int? staffBehavior,
    String? comment,
    bool isSatisfied = true,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/$id/feedback', {
        'rating': rating,
        if (quality != null) 'resolution_quality': quality,
        if (responseTime != null) 'response_time_rating': responseTime,
        if (staffBehavior != null) 'staff_behavior_rating': staffBehavior,
        if (comment != null) 'comment': comment,
        'is_satisfied': isSatisfied,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Execute bulk operations
  Future<Map<String, dynamic>> bulkAction({
    required List<String> complaintIds,
    required String action,
    String? userId,
    String? userName,
    String? priority,
    String? status,
    String? notes,
  }) async {
    try {
      final res = await _api.post('/hostel/complaints/bulk-action', {
        'complaint_ids': complaintIds,
        'action': action,
        if (userId != null) 'assigned_user_id': userId,
        if (userName != null) 'assigned_user_name': userName,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      });
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Export complaints to CSV bytes
  Future<List<int>?> exportComplaintsCsv({
    String academicYear = '2026 - 2027',
    String? search,
    String? hostel,
    String? category,
    String? priority,
    String? status,
    String? subtab,
  }) async {
    final params = <String, String>{
      'academic_year': academicYear,
      if (search != null && search.isNotEmpty) 'search': search,
      if (hostel != null && hostel != 'All Hostels') 'hostel': hostel,
      if (category != null && category != 'All Categories') 'category': category,
      if (priority != null && priority != 'All Priorities') 'priority': priority,
      if (status != null && status != 'All Status') 'status': status,
      if (subtab != null && subtab != 'All Complaints') 'subtab': subtab,
    };
    final uri = Uri(path: '/hostel/complaints/export', queryParameters: params);
    return await _api.getRawBytes(uri.toString());
  }

  /// Upload photo or file attachment for complaints (real cross-platform multipart)
  Future<String?> uploadAttachment(List<int> bytes, String filename) async {
    try {
      final res = await _api.multipartPostBytes(
        '/hostel/complaints/upload-attachment',
        bytes,
        filename,
        'file',
      );
      if (res['data'] is Map<String, dynamic> && res['data']['url'] != null) {
        return res['data']['url'] as String;
      }
      if (res['url'] != null) {
        return res['url'] as String;
      }
    } catch (_) {}
    return null;
  }

  /// Upload photo or file attachment and directly link to an existing complaint
  Future<Map<String, dynamic>> uploadAttachmentToComplaint(
    String complaintId,
    List<int> bytes,
    String filename,
  ) async {
    return await _api.multipartPostBytes(
      '/hostel/complaints/$complaintId/attachments/upload',
      bytes,
      filename,
      'file',
    );
  }
}

