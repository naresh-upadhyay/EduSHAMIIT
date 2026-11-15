class LiveBroadcastItem {
  final int id;
  final String broadcastCode;
  final String title;
  final String description;
  final String category;
  final String privacy;
  final String streamQuality;
  final String bitrateMode;
  final String status;
  final int uptimeSeconds;
  final int currentViewers;
  final int totalViews;
  final int likesCount;
  final String streamHealth;
  final String resolution;
  final int actualBitrateKbps;
  final int actualFps;
  final String? recordingUrl;

  const LiveBroadcastItem({
    required this.id,
    required this.broadcastCode,
    required this.title,
    required this.description,
    required this.category,
    required this.privacy,
    required this.streamQuality,
    required this.bitrateMode,
    required this.status,
    required this.uptimeSeconds,
    required this.currentViewers,
    required this.totalViews,
    required this.likesCount,
    required this.streamHealth,
    required this.resolution,
    required this.actualBitrateKbps,
    required this.actualFps,
    this.recordingUrl,
  });

  factory LiveBroadcastItem.fromJson(Map<String, dynamic> json) {
    return LiveBroadcastItem(
      id: json['id'] as int? ?? 1,
      broadcastCode: json['broadcastCode'] as String? ?? 'BC-LIVE',
      title: json['title'] as String? ?? 'Class 10 - Mathematics: Quadratic Equations',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Education',
      privacy: json['privacy'] as String? ?? 'Public',
      streamQuality: json['streamQuality'] as String? ?? '1080p (Full HD)',
      bitrateMode: json['bitrateMode'] as String? ?? 'Auto (Recommended)',
      status: json['status'] as String? ?? 'live',
      uptimeSeconds: json['uptimeSeconds'] as int? ?? 1638,
      currentViewers: json['currentViewers'] as int? ?? 426,
      totalViews: json['totalViews'] as int? ?? 1248,
      likesCount: json['likesCount'] as int? ?? 267,
      streamHealth: json['streamHealth'] as String? ?? 'Excellent',
      resolution: json['resolution'] as String? ?? '1080p',
      actualBitrateKbps: json['actualBitrateKbps'] as int? ?? 4500,
      actualFps: json['actualFps'] as int? ?? 30,
      recordingUrl: json['recordingUrl'] as String?,
    );
  }

  String get formattedUptime {
    final h = (uptimeSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((uptimeSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (uptimeSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class BroadcastDestinationItem {
  final int id;
  final String platformKey;
  final String destinationName;
  final String rtmpUrl;
  final String streamKey;
  final bool isActive;
  final bool isConnected;
  final String syncStatus;
  final int viewers;

  const BroadcastDestinationItem({
    required this.id,
    required this.platformKey,
    required this.destinationName,
    required this.rtmpUrl,
    required this.streamKey,
    required this.isActive,
    required this.isConnected,
    required this.syncStatus,
    required this.viewers,
  });

  factory BroadcastDestinationItem.fromJson(Map<String, dynamic> json) {
    return BroadcastDestinationItem(
      id: json['id'] as int? ?? 0,
      platformKey: json['platformKey'] as String? ?? 'custom_rtmp',
      destinationName: json['destinationName'] as String? ?? 'Custom Platform',
      rtmpUrl: json['rtmpUrl'] as String? ?? '',
      streamKey: json['streamKey'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? false,
      syncStatus: json['syncStatus'] as String? ?? 'ready',
      viewers: json['viewers'] as int? ?? 0,
    );
  }

  BroadcastDestinationItem copyWith({
    bool? isActive,
    bool? isConnected,
    String? syncStatus,
  }) {
    return BroadcastDestinationItem(
      id: id,
      platformKey: platformKey,
      destinationName: destinationName,
      rtmpUrl: rtmpUrl,
      streamKey: streamKey,
      isActive: isActive ?? this.isActive,
      isConnected: isConnected ?? this.isConnected,
      syncStatus: syncStatus ?? this.syncStatus,
      viewers: viewers,
    );
  }
}

class AnalyticsPoint {
  final String minuteMark;
  final int viewerCount;

  const AnalyticsPoint({
    required this.minuteMark,
    required this.viewerCount,
  });

  factory AnalyticsPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsPoint(
      minuteMark: json['minuteMark'] as String? ?? '00:00',
      viewerCount: json['viewerCount'] as int? ?? 0,
    );
  }
}

class ScheduledBroadcastItem {
  final int id;
  final String broadcastCode;
  final String title;
  final String? description;
  final String classSubject;
  final String scheduledDate;
  final String scheduledTime;
  final String platform;
  final String? privacy;
  final String? quality;
  final String status;

  const ScheduledBroadcastItem({
    required this.id,
    required this.broadcastCode,
    required this.title,
    this.description,
    required this.classSubject,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.platform,
    this.privacy,
    this.quality,
    required this.status,
  });

  factory ScheduledBroadcastItem.fromJson(Map<String, dynamic> json) {
    return ScheduledBroadcastItem(
      id: json['id'] as int? ?? 0,
      broadcastCode: json['broadcastCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      classSubject: json['classSubject'] as String? ?? '',
      scheduledDate: json['scheduledDate'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      platform: json['platform'] as String? ?? 'youtube',
      privacy: json['privacy'] as String?,
      quality: json['quality'] as String?,
      status: json['status'] as String? ?? 'scheduled',
    );
  }
}

class PastStreamItem {
  final int id;
  final String broadcastCode;
  final String title;
  final String classSubject;
  final String streamedOn;
  final double durationMinutes;
  final int totalViews;
  final int peakViewers;
  final int likes;
  final String? recordingUrl;
  final String status;

  const PastStreamItem({
    required this.id,
    required this.broadcastCode,
    required this.title,
    required this.classSubject,
    required this.streamedOn,
    required this.durationMinutes,
    required this.totalViews,
    required this.peakViewers,
    required this.likes,
    this.recordingUrl,
    required this.status,
  });

  factory PastStreamItem.fromJson(Map<String, dynamic> json) {
    return PastStreamItem(
      id: json['id'] as int? ?? 0,
      broadcastCode: json['broadcastCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      classSubject: json['classSubject'] as String? ?? '',
      streamedOn: json['streamedOn'] as String? ?? '',
      durationMinutes: (json['durationMinutes'] as num? ?? 45.0).toDouble(),
      totalViews: json['totalViews'] as int? ?? 0,
      peakViewers: json['peakViewers'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      recordingUrl: json['recordingUrl'] as String?,
      status: json['status'] as String? ?? 'ended',
    );
  }
}

class StreamAnalyticsData {
  final int totalBroadcasts;
  final double totalWatchHours;
  final int totalViews;
  final double avgEngagementPct;
  final List<Map<String, dynamic>> platformBreakdown;

  const StreamAnalyticsData({
    required this.totalBroadcasts,
    required this.totalWatchHours,
    required this.totalViews,
    required this.avgEngagementPct,
    required this.platformBreakdown,
  });

  factory StreamAnalyticsData.fromJson(Map<String, dynamic> json) {
    return StreamAnalyticsData(
      totalBroadcasts: json['totalBroadcasts'] as int? ?? 12,
      totalWatchHours: (json['totalWatchHours'] as num? ?? 482.5).toDouble(),
      totalViews: json['totalViews'] as int? ?? 18450,
      avgEngagementPct: (json['avgEngagementPct'] as num? ?? 88.5).toDouble(),
      platformBreakdown: (json['platformBreakdown'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class BroadcastSettingsData {
  final int id;
  final String defaultQuality;
  final String defaultBitrateMode;
  final String defaultPrivacy;
  final String defaultCategory;
  final bool autoRecordBroadcasts;
  final bool lowLatencyMode;
  final bool dvrEnabled;
  final bool enableChatRelay;
  final String customRtmpUrl;
  final String customStreamKey;

  const BroadcastSettingsData({
    required this.id,
    required this.defaultQuality,
    required this.defaultBitrateMode,
    required this.defaultPrivacy,
    required this.defaultCategory,
    required this.autoRecordBroadcasts,
    required this.lowLatencyMode,
    required this.dvrEnabled,
    required this.enableChatRelay,
    required this.customRtmpUrl,
    required this.customStreamKey,
  });

  factory BroadcastSettingsData.fromJson(Map<String, dynamic> json) {
    return BroadcastSettingsData(
      id: json['id'] as int? ?? 1,
      defaultQuality: json['defaultQuality'] as String? ?? '1080p (Full HD)',
      defaultBitrateMode: json['defaultBitrateMode'] as String? ?? 'Auto (Recommended)',
      defaultPrivacy: json['defaultPrivacy'] as String? ?? 'Public',
      defaultCategory: json['defaultCategory'] as String? ?? 'Education',
      autoRecordBroadcasts: json['autoRecordBroadcasts'] as bool? ?? true,
      lowLatencyMode: json['lowLatencyMode'] as bool? ?? true,
      dvrEnabled: json['dvrEnabled'] as bool? ?? true,
      enableChatRelay: json['enableChatRelay'] as bool? ?? true,
      customRtmpUrl: json['customRtmpUrl'] as String? ?? 'rtmp://live.edushamiit.internal/stream',
      customStreamKey: json['customStreamKey'] as String? ?? 'shamiit_live_key_sec_884920',
    );
  }
}

class BroadcastOverviewData {
  final LiveBroadcastItem? activeBroadcast;
  final List<BroadcastDestinationItem> destinations;
  final List<AnalyticsPoint> analyticsPoints;
  final List<ScheduledBroadcastItem> scheduledBroadcasts;

  const BroadcastOverviewData({
    this.activeBroadcast,
    required this.destinations,
    required this.analyticsPoints,
    required this.scheduledBroadcasts,
  });

  factory BroadcastOverviewData.fromJson(Map<String, dynamic> json) {
    return BroadcastOverviewData(
      activeBroadcast: json['activeBroadcast'] != null
          ? LiveBroadcastItem.fromJson(json['activeBroadcast'] as Map<String, dynamic>)
          : null,
      destinations: (json['destinations'] as List<dynamic>?)
              ?.map((e) => BroadcastDestinationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      analyticsPoints: (json['analyticsPoints'] as List<dynamic>?)
              ?.map((e) => AnalyticsPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      scheduledBroadcasts: (json['scheduledBroadcasts'] as List<dynamic>?)
              ?.map((e) => ScheduledBroadcastItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
