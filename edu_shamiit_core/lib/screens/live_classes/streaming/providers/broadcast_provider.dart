import 'dart:async';
import 'package:flutter/material.dart';
import '../models/broadcast_models.dart';
import '../services/broadcast_api_service.dart';

class BroadcastProvider extends ChangeNotifier {
  final BroadcastApiService _api = BroadcastApiService();

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BroadcastOverviewData? _overview;
  BroadcastOverviewData? get overview => _overview;

  List<ScheduledBroadcastItem> _scheduledList = [];
  List<ScheduledBroadcastItem> get scheduledList => _scheduledList;

  List<PastStreamItem> _pastStreams = [];
  List<PastStreamItem> get pastStreams => _pastStreams;

  StreamAnalyticsData? _analytics;
  StreamAnalyticsData? get analytics => _analytics;

  BroadcastSettingsData? _settings;
  BroadcastSettingsData? get settings => _settings;

  // Stream setup controllers
  final TextEditingController titleController = TextEditingController(text: 'Class 10 - Mathematics: Quadratic Equations');
  final TextEditingController descriptionController = TextEditingController(text: 'Live class on Quadratic Equations, formula, roots and real-life applications.');
  String selectedCategory = 'Education';
  String selectedPrivacy = 'Public';
  String selectedQuality = '1080p (Full HD)';
  String selectedBitrate = 'Auto (Recommended)';

  Timer? _tickerTimer;
  int _liveSeconds = 1638; // 27:18 default

  int get liveSeconds => _liveSeconds;

  String get formattedLiveDuration {
    final m = (_liveSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_liveSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get formattedLiveUptime {
    final h = (_liveSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_liveSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_liveSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool _isDisposed = false;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void setTabIndex(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    _safeNotifyListeners();

    if (index == 1) {
      loadScheduledBroadcasts();
    } else if (index == 2) {
      loadPastStreams();
    } else if (index == 3) {
      loadAnalytics();
    } else if (index == 4) {
      loadSettings();
    }
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_overview?.activeBroadcast?.status == 'live') {
        _liveSeconds++;
        _safeNotifyListeners();
      }
    });
  }

  Future<void> loadOverview({int instituteId = 1}) async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    final data = await _api.fetchOverview(instituteId: instituteId);
    if (data != null) {
      _overview = data;
      if (data.activeBroadcast != null) {
        titleController.text = data.activeBroadcast!.title;
        descriptionController.text = data.activeBroadcast!.description;
        selectedCategory = data.activeBroadcast!.category;
        selectedPrivacy = data.activeBroadcast!.privacy;
        selectedQuality = data.activeBroadcast!.streamQuality;
        selectedBitrate = data.activeBroadcast!.bitrateMode;
        _liveSeconds = data.activeBroadcast!.uptimeSeconds;
      }
      _startTicker();
    } else {
      _errorMessage = 'Failed to load broadcast overview';
    }

    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<bool> startBroadcast() async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.startBroadcast(_overview!.activeBroadcast!.id);
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<bool> pauseBroadcast() async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.pauseBroadcast(_overview!.activeBroadcast!.id);
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<bool> resumeBroadcast() async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.resumeBroadcast(_overview!.activeBroadcast!.id);
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<bool> stopBroadcast() async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.stopBroadcast(_overview!.activeBroadcast!.id);
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<bool> endAndSaveBroadcast() async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.endAndSaveBroadcast(_overview!.activeBroadcast!.id);
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<void> toggleDestination(int destinationId, bool isActive) async {
    final success = await _api.toggleDestination(destinationId, isActive);
    if (success && _overview != null) {
      final updatedList = _overview!.destinations.map((d) {
        if (d.id == destinationId) {
          return d.copyWith(
            isActive: isActive,
            syncStatus: isActive ? 'streaming' : 'ready',
          );
        }
        return d;
      }).toList();

      _overview = BroadcastOverviewData(
        activeBroadcast: _overview!.activeBroadcast,
        destinations: updatedList,
        analyticsPoints: _overview!.analyticsPoints,
        scheduledBroadcasts: _overview!.scheduledBroadcasts,
      );
      notifyListeners();
    }
  }

  Future<bool> addDestination({
    required String platformKey,
    required String name,
    required String rtmpUrl,
    required String streamKey,
  }) async {
    if (_overview?.activeBroadcast == null) return false;
    final success = await _api.addDestination(
      broadcastId: _overview!.activeBroadcast!.id,
      platformKey: platformKey,
      name: name,
      rtmpUrl: rtmpUrl,
      streamKey: streamKey,
    );
    if (success) {
      await loadOverview();
    }
    return success;
  }

  Future<void> loadScheduledBroadcasts({int instituteId = 1}) async {
    _isLoading = true;
    notifyListeners();
    _scheduledList = await _api.fetchScheduledBroadcasts(instituteId: instituteId);
    _isLoading = false;
    notifyListeners();
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
    final success = await _api.scheduleBroadcast(
      title: title,
      description: description,
      classSubject: classSubject,
      scheduledTime: scheduledTime,
      platform: platform,
      privacy: privacy,
      quality: quality,
      instituteId: instituteId,
    );
    if (success) {
      await loadScheduledBroadcasts(instituteId: instituteId);
      await loadOverview(instituteId: instituteId);
    }
    return success;
  }

  Future<void> loadPastStreams({int instituteId = 1}) async {
    _isLoading = true;
    _safeNotifyListeners();
    _pastStreams = await _api.fetchPastStreams(instituteId: instituteId);
    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> loadAnalytics({int instituteId = 1}) async {
    _isLoading = true;
    _safeNotifyListeners();
    _analytics = await _api.fetchAnalytics(instituteId: instituteId);
    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<void> loadSettings({int instituteId = 1}) async {
    _isLoading = true;
    _safeNotifyListeners();
    _settings = await _api.fetchSettings(instituteId: instituteId);
    _isLoading = false;
    _safeNotifyListeners();
  }

  Future<bool> updateSettings(BroadcastSettingsData settings, {int instituteId = 1}) async {
    final success = await _api.updateSettings(settings, instituteId: instituteId);
    if (success) {
      _settings = settings;
      _safeNotifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickerTimer?.cancel();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
