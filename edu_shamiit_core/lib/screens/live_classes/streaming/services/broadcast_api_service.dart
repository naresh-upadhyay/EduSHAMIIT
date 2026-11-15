import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';
import '../models/broadcast_models.dart';

class BroadcastApiService {
  final ApiService _api = ApiService();

  Future<BroadcastOverviewData?> fetchOverview({int instituteId = 1}) async {
    try {
      final res = await _api.get(
        '/broadcasts/overview',
        query: {'institute_id': instituteId.toString()},
        useCache: false,
      );
      return BroadcastOverviewData.fromJson(res);
    } catch (e) {
      debugPrint('[BroadcastApiService] fetchOverview error: $e');
      return null;
    }
  }

  Future<bool> createBroadcast({
    required String title,
    String description = '',
    String category = 'Education',
    String privacy = 'Public',
    String streamQuality = '1080p (Full HD)',
    String bitrateMode = 'Auto (Recommended)',
    int instituteId = 1,
  }) async {
    try {
      final res = await _api.post(
        '/broadcasts/create?institute_id=$instituteId',
        {
          'title': title,
          'description': description,
          'category': category,
          'privacy': privacy,
          'streamQuality': streamQuality,
          'bitrateMode': bitrateMode,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] createBroadcast error: $e');
      return false;
    }
  }

  Future<bool> startBroadcast(int broadcastId) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/start', {});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] startBroadcast error: $e');
      return false;
    }
  }

  Future<bool> pauseBroadcast(int broadcastId) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/pause', {});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] pauseBroadcast error: $e');
      return false;
    }
  }

  Future<bool> resumeBroadcast(int broadcastId) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/resume', {});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] resumeBroadcast error: $e');
      return false;
    }
  }

  Future<bool> stopBroadcast(int broadcastId) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/stop', {});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] stopBroadcast error: $e');
      return false;
    }
  }

  Future<bool> endAndSaveBroadcast(int broadcastId) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/end-and-save', {});
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] endAndSaveBroadcast error: $e');
      return false;
    }
  }

  Future<bool> toggleDestination(int destinationId, bool isActive) async {
    try {
      final res = await _api.post('/broadcasts/destinations/$destinationId/toggle', {
        'isActive': isActive,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] toggleDestination error: $e');
      return false;
    }
  }

  Future<bool> addDestination({
    required int broadcastId,
    required String platformKey,
    required String name,
    required String rtmpUrl,
    required String streamKey,
  }) async {
    try {
      final res = await _api.post('/broadcasts/$broadcastId/destinations', {
        'platformKey': platformKey,
        'name': name,
        'rtmpUrl': rtmpUrl,
        'streamKey': streamKey,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] addDestination error: $e');
      return false;
    }
  }

  Future<List<ScheduledBroadcastItem>> fetchScheduledBroadcasts({int instituteId = 1}) async {
    try {
      final res = await _api.get(
        '/broadcasts/scheduled',
        query: {'institute_id': instituteId.toString()},
        useCache: false,
      );
      final rawList = res['data'] is List ? res['data'] as List : (res['items'] is List ? res['items'] as List : []);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(ScheduledBroadcastItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[BroadcastApiService] fetchScheduledBroadcasts error: $e');
      return [];
    }
  }

  Future<bool> scheduleBroadcast({
    required String title,
    String description = '',
    required String classSubject,
    required String scheduledTime,
    String platform = 'youtube',
    String privacy = 'Public',
    String quality = '1080p (Full HD)',
    int instituteId = 1,
  }) async {
    try {
      final res = await _api.post(
        '/broadcasts/schedule?institute_id=$instituteId',
        {
          'title': title,
          'description': description,
          'classSubject': classSubject,
          'scheduledTime': scheduledTime,
          'platform': platform,
          'privacy': privacy,
          'quality': quality,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] scheduleBroadcast error: $e');
      return false;
    }
  }

  Future<List<PastStreamItem>> fetchPastStreams({int instituteId = 1}) async {
    try {
      final res = await _api.get(
        '/broadcasts/past',
        query: {'institute_id': instituteId.toString()},
        useCache: false,
      );
      final rawList = res['data'] is List ? res['data'] as List : (res['items'] is List ? res['items'] as List : []);
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(PastStreamItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[BroadcastApiService] fetchPastStreams error: $e');
      return [];
    }
  }

  Future<StreamAnalyticsData?> fetchAnalytics({int instituteId = 1}) async {
    try {
      final res = await _api.get(
        '/broadcasts/analytics',
        query: {'institute_id': instituteId.toString()},
        useCache: false,
      );
      return StreamAnalyticsData.fromJson(res);
    } catch (e) {
      debugPrint('[BroadcastApiService] fetchAnalytics error: $e');
      return null;
    }
  }

  Future<BroadcastSettingsData?> fetchSettings({int instituteId = 1}) async {
    try {
      final res = await _api.get(
        '/broadcasts/settings',
        query: {'institute_id': instituteId.toString()},
        useCache: false,
      );
      return BroadcastSettingsData.fromJson(res);
    } catch (e) {
      debugPrint('[BroadcastApiService] fetchSettings error: $e');
      return null;
    }
  }

  Future<bool> updateSettings(BroadcastSettingsData settings, {int instituteId = 1}) async {
    try {
      final res = await _api.put(
        '/broadcasts/settings?institute_id=$instituteId',
        {
          'defaultQuality': settings.defaultQuality,
          'defaultBitrateMode': settings.defaultBitrateMode,
          'defaultPrivacy': settings.defaultPrivacy,
          'defaultCategory': settings.defaultCategory,
          'autoRecord': settings.autoRecordBroadcasts,
          'lowLatency': settings.lowLatencyMode,
          'dvrEnabled': settings.dvrEnabled,
          'chatRelay': settings.enableChatRelay,
          'customRtmpUrl': settings.customRtmpUrl,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[BroadcastApiService] updateSettings error: $e');
      return false;
    }
  }
}
