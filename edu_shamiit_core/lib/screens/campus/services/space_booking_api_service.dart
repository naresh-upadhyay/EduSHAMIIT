import 'package:intl/intl.dart';
import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/space_booking_models.dart';

class SpaceBookingApiService {
  static final SpaceBookingApiService instance = SpaceBookingApiService._internal();
  SpaceBookingApiService._internal();

  final ApiService _api = ApiService();

  /// 1. Space Booking Dashboard KPIs
  Future<SpaceBookingKpis> getKpis({DateTime? date}) async {
    try {
      final query = <String, dynamic>{};
      if (date != null) {
        query['target_date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      final res = await _api.get('/v1/space-bookings/kpis', query: query, useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return SpaceBookingKpis.fromJson(res['data']);
      }
    } catch (_) {}
    return const SpaceBookingKpis();
  }

  /// 2. Availability Timeline Grid (Supports Date Range: Day, Week, Month)
  Future<List<SpaceTimelineRoom>> getTimeline({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? buildingId,
    String? roomType,
  }) async {
    try {
      final query = <String, dynamic>{};
      final sDate = startDate ?? date;
      final eDate = endDate ?? sDate;
      if (sDate != null) {
        query['start_date'] = '${sDate.year}-${sDate.month.toString().padLeft(2, '0')}-${sDate.day.toString().padLeft(2, '0')}';
      }
      if (eDate != null) {
        query['end_date'] = '${eDate.year}-${eDate.month.toString().padLeft(2, '0')}-${eDate.day.toString().padLeft(2, '0')}';
      }
      if (date != null) {
        query['target_date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
        query['building_id'] = buildingId;
      }
      if (roomType != null && roomType.isNotEmpty && roomType != 'All') {
        query['room_type'] = roomType;
      }

      final res = await _api.get('/v1/space-bookings/timeline', query: query, useCache: false);
      if (res['rooms'] is List) {
        return (res['rooms'] as List)
            .map((e) => SpaceTimelineRoom.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 3. Paged Booking Requests Table
  Future<SpaceBookingListResponse> getRequests({
    String? status,
    String? buildingId,
    String? roomType,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (status != null && status.isNotEmpty && status != 'All') {
        query['status'] = status;
      }
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
        query['building_id'] = buildingId;
      }
      if (roomType != null && roomType.isNotEmpty && roomType != 'All') {
        query['room_type'] = roomType;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (dateFrom != null) {
        query['date_from'] = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      }
      if (dateTo != null) {
        query['date_to'] = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      }

      final res = await _api.get('/v1/space-bookings/requests', query: query, useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return SpaceBookingListResponse.fromJson(res['data']);
      }
    } catch (_) {}
    return const SpaceBookingListResponse(items: [], totalCount: 0, page: 1, pageSize: 5, totalPages: 1);
  }

  /// 4. Detailed Booking Inspection
  Future<Map<String, dynamic>?> getDetails(String bookingId) async {
    try {
      final res = await _api.get('/v1/space-bookings/details/$bookingId', useCache: false);
      return res['data'] as Map<String, dynamic>?;
    } catch (_) {}
    return null;
  }

  /// 5. Create or Update Booking
  Future<Map<String, dynamic>> createOrUpdateBooking(Map<String, dynamic> payload) async {
    final res = await _api.post('/v1/space-bookings/book', payload);
    return res;
  }

  /// 5b. Generate Recurring Booking Series
  Future<Map<String, dynamic>> createRecurringBooking(Map<String, dynamic> payload) async {
    final res = await _api.post('/v1/space-bookings/recurring', payload);
    return res;
  }

  /// 6. Approve / Reject / Cancel Booking Decision
  Future<Map<String, dynamic>> decideApproval(String bookingId, String action, {String? comments}) async {
    final res = await _api.post('/v1/space-bookings/decision/$bookingId', {
      'action': action,
      'comments': comments,
    });
    return res;
  }

  /// 7. Check-In & Check-Out Execution
  Future<Map<String, dynamic>> checkinCheckout(String bookingId, String action, {String? condition, String? remarks}) async {
    final res = await _api.post('/v1/space-bookings/checkin-checkout/$bookingId', {
      'action': action,
      'condition': condition ?? 'Good',
      'remarks': remarks,
    });
    return res;
  }

  /// 8. Space Utilization Stats (Donut Chart)
  Future<SpaceUtilizationStats> getUtilizationStats({DateTime? date}) async {
    try {
      final query = <String, dynamic>{};
      if (date != null) {
        query['target_date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      final res = await _api.get('/v1/space-bookings/utilization', query: query, useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return SpaceUtilizationStats.fromJson(res['data']);
      }
    } catch (_) {}
    return const SpaceUtilizationStats();
  }

  /// 9. Bookable Rooms list for booking dropdowns
  Future<List<BookableRoomItem>> getBookableRooms({String? buildingId, String? roomType}) async {
    try {
      final query = <String, dynamic>{};
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
        query['building_id'] = buildingId;
      }
      if (roomType != null && roomType.isNotEmpty && roomType != 'All') {
        query['room_type'] = roomType;
      }
      final res = await _api.get('/v1/space-bookings/bookable-rooms', query: query, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .map((e) => BookableRoomItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 10. Streaming CSV Export
  void exportCsv({String? status, String? buildingId}) {
    String url = '/v1/space-bookings/export?';
    if (status != null && status.isNotEmpty) url += '&status=$status';
    if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
      url += '&building_id=$buildingId';
    }
    getDownloadHelper().downloadFile(
      '${AppConfig.apiBaseUrl}$url',
      'space_bookings_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  /// 11. Dynamic Requesters Search & Select
  Future<List<SpaceRequesterProfile>> getRequesters({String? search, String? role}) async {
    try {
      final query = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (role != null && role.isNotEmpty && role != 'All') {
        query['role'] = role;
      }
      final res = await _api.get('/v1/space-bookings/requesters', query: query, useCache: false);
      if (res['data'] is List) {
        return (res['data'] as List)
            .map((e) => SpaceRequesterProfile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// 12. Full Visual Analytics & Usage Report
  Future<SpaceAnalyticsReport> getAnalyticsReport({String? buildingId, String timeframe = 'today', DateTime? date}) async {
    try {
      final query = <String, dynamic>{
        'timeframe': timeframe,
      };
      if (date != null) {
        query['target_date'] = DateFormat('yyyy-MM-dd').format(date);
      }
      if (buildingId != null && buildingId.isNotEmpty && buildingId != 'all') {
        query['building_id'] = buildingId;
      }
      final res = await _api.get('/v1/space-bookings/analytics-report', query: query, useCache: false);
      if (res['data'] is Map<String, dynamic>) {
        return SpaceAnalyticsReport.fromJson(res['data']);
      }
    } catch (_) {}
    return const SpaceAnalyticsReport();
  }

  /// 13. Delete / Cancel Space Booking
  Future<Map<String, dynamic>> deleteBooking(String bookingId, {bool deleteSeries = false, String? reason}) async {
    String url = '/v1/space-bookings/$bookingId?delete_series=$deleteSeries';
    if (reason != null && reason.isNotEmpty) {
      url += '&reason=${Uri.encodeComponent(reason)}';
    }
    final res = await _api.delete(url);
    return res;
  }

  /// 14. Real-time Slot Availability & Conflict Check
  Future<Map<String, dynamic>> checkSlotAvailability({
    required String roomId,
    required DateTime date,
    required String startTime,
    required String endTime,
    int setupMinutes = 0,
    int cleanupMinutes = 0,
    String? excludeBookingId,
  }) async {
    try {
      final query = <String, dynamic>{
        'room_id': roomId,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'start_time': startTime,
        'end_time': endTime,
        'setup_minutes': setupMinutes,
        'cleanup_minutes': cleanupMinutes,
      };
      if (excludeBookingId != null && excludeBookingId.isNotEmpty) {
        query['exclude_booking_id'] = excludeBookingId;
      }
      final res = await _api.get('/v1/space-bookings/check-slot', query: query, useCache: false);
      if (res is Map<String, dynamic>) {
        return res;
      }
    } catch (_) {}
    return {'has_conflict': false, 'status': 'FREE', 'message': 'Slot is free'};
  }
}
