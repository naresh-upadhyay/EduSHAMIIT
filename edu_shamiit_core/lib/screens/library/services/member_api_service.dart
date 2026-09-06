import '../../../../services/api_service.dart';
import '../models/member_models.dart';

class MemberApiService {
  final ApiService _api = ApiService();

  /// Fetch aggregated KPI metrics for the Members tab
  Future<MemberStatsModel> fetchMemberStats() async {
    final res = await _api.get('/library/members/stats', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return MemberStatsModel.fromJson(data);
  }

  /// Fetch dynamic dropdown filter options (member types, classes, departments, statuses)
  Future<MemberFilterOptionsModel> fetchFilterOptions() async {
    final res = await _api.get('/library/members/filter-options', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return MemberFilterOptionsModel.fromJson(data);
  }

  /// Search existing profiles to add as a library member
  Future<List<ProfileSearchResultModel>> searchProfiles({String? query, String? role}) async {
    final queryParams = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (role != null && role.isNotEmpty && role != 'ALL') 'role': role,
    };
    final res = await _api.get('/library/members/search-users', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? (res['data'] as List) : <dynamic>[];
    return rawList.map((e) => ProfileSearchResultModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Fetch paginated, multi-filtered list of members
  Future<Map<String, dynamic>> fetchMembers({
    String? search,
    String? memberType,
    String? className,
    String? department,
    String? status,
    String? membershipFilter,
    String sortBy = 'member_code',
    String sortOrder = 'asc',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (memberType != null && memberType.isNotEmpty && memberType != 'All Member Types' && memberType != 'ALL')
        'member_type': memberType,
      if (className != null && className.isNotEmpty && className != 'All Classes' && className != 'ALL')
        'class_name': className,
      if (department != null && department.isNotEmpty && department != 'All Departments' && department != 'ALL')
        'department': department,
      if (status != null && status.isNotEmpty && status != 'Status: All' && status != 'ALL')
        'status': status,
      if (membershipFilter != null && membershipFilter.isNotEmpty && membershipFilter != 'Membership: All' && membershipFilter != 'ALL')
        'membership_filter': membershipFilter,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/library/members', query: queryParams, useCache: false);
    final rawList = res['items'] is List
        ? res['items'] as List
        : (res['data'] is List ? res['data'] as List : []);
    final members = rawList.map((e) => LibraryMemberModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final meta = res['meta'] as Map<String, dynamic>? ?? res['pagination'] as Map<String, dynamic>? ?? {};

    return {
      'members': members,
      'meta': meta,
      'total': int.tryParse(meta['total_items']?.toString() ?? meta['total']?.toString() ?? '') ?? members.length,
      'totalPages': int.tryParse(meta['total_pages']?.toString() ?? meta['pages']?.toString() ?? '') ?? 1,
    };
  }

  /// Fetch full member detail including active books, fines, history, and audit log
  Future<Map<String, dynamic>> fetchMemberDetail(String memberId) async {
    final res = await _api.get('/library/members/$memberId', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;

    final memberMap = data['member'] is Map ? Map<String, dynamic>.from(data['member']) : <String, dynamic>{};
    final currentBooksList = data['current_books'] is List ? data['current_books'] as List : [];
    final finesList = data['fines'] is List ? data['fines'] as List : [];
    final historyList = data['history'] is List ? data['history'] as List : [];
    final auditsList = data['audits'] is List ? data['audits'] as List : [];

    return {
      'member': LibraryMemberModel.fromJson(memberMap),
      'current_books': currentBooksList.map((e) => MemberBorrowItemModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      'fines': finesList.map((e) => MemberFineItemModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      'history': historyList.map((e) => MemberBorrowItemModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      'audits': auditsList.map((e) => MemberAuditModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      'summary': data['summary'] is Map ? Map<String, dynamic>.from(data['summary']) : <String, dynamic>{},
    };
  }

  /// Create a new library member linking to an existing Profile
  Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    return await _api.post('/library/members', data);
  }

  /// Update library membership parameters
  Future<Map<String, dynamic>> updateMember(String memberId, Map<String, dynamic> data) async {
    return await _api.put('/library/members/$memberId', data);
  }

  /// Renew a library membership
  Future<Map<String, dynamic>> renewMembership({
    required String memberId,
    required DateTime newExpiryDate,
    String? renewalPeriod,
    String? notes,
  }) async {
    final body = {
      'new_expiry_date': newExpiryDate.toIso8601String().split('T').first,
      if (renewalPeriod != null) 'renewal_period': renewalPeriod,
      if (notes != null) 'notes': notes,
    };
    return await _api.post('/library/members/$memberId/renew', body);
  }

  /// Suspend a library member with reason
  Future<Map<String, dynamic>> suspendMember(String memberId, {String? reason}) async {
    return await _api.post('/library/members/$memberId/suspend', {'reason': reason ?? 'Administrative suspension'});
  }

  /// Reactivate a library member
  Future<Map<String, dynamic>> activateMember(String memberId) async {
    return await _api.post('/library/members/$memberId/activate', {});
  }

  /// Soft-delete / archive a library member
  Future<Map<String, dynamic>> deleteMember(String memberId) async {
    return await _api.delete('/library/members/$memberId');
  }

  /// Perform bulk actions across multiple members
  Future<Map<String, dynamic>> bulkAction({
    required List<String> memberIds,
    required String action,
    Map<String, dynamic>? params,
  }) async {
    return await _api.post('/library/members/bulk-action', {
      'member_ids': memberIds,
      'action': action,
      if (params != null) 'params': params,
    });
  }

  /// Preview or execute CSV member imports
  Future<Map<String, dynamic>> importMembers(List<Map<String, dynamic>> records, {String mode = 'PREVIEW'}) async {
    return await _api.post('/library/members/import', {
      'records': records,
      'mode': mode,
    });
  }
}
