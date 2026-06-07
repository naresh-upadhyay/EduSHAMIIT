import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'api_provider.dart';

/// Model class for live class data
class LiveClassModel {
  final String id;
  final String subject;
  final String? title;
  final String? description;
  final String? subjectName;
  final String teacher;
  final String? started;
  final int? viewers;
  final String? time;
  final String? timeUntil; // Renamed from 'in' to avoid reserved keyword
  final String? date;
  final String icon;
  final Gradient? color;
  final bool isLive;
  final String type; // 'live', 'upcoming', 'recorded'
  final String? streamUrl;
  final String? recordingUrl;
  final String platform; // 'Zoom', 'Google Meet', 'YouTube', 'In-App', etc.
  final String? meetingLink;

  LiveClassModel({
    required this.id,
    required this.subject,
    this.title,
    this.description,
    this.subjectName,
    required this.teacher,
    this.started,
    this.viewers,
    this.time,
    this.timeUntil,
    this.date,
    required this.icon,
    this.color,
    this.isLive = false,
    required this.type,
    this.streamUrl,
    this.recordingUrl,
    this.platform = 'In-App',
    this.meetingLink,
  });

  factory LiveClassModel.fromJson(Map<String, dynamic> json) {
    return LiveClassModel(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      title: json['title'],
      description: json['description'],
      subjectName: json['subject_name'] ?? json['subject_name_db'],
      teacher: json['teacher'] ?? '',
      started: json['started'],
      viewers: json['viewers'],
      time: json['time'],
      timeUntil: json['timeUntil'] ?? json['in'], // Support both field names
      date: json['date'],
      icon: json['icon'] ?? '',
      color: json['color'] as Gradient?,
      isLive: json['isLive'] ?? false,
      type: json['type'] ?? 'recorded',
      streamUrl: json['stream_url'],
      recordingUrl: json['recording_url'],
      platform: json['platform'] ?? 'In-App',
      meetingLink: json['meeting_link'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'title': title,
      'description': description,
      'subject_name': subjectName,
      'teacher': teacher,
      'started': started,
      'viewers': viewers,
      'time': time,
      'timeUntil': timeUntil,
      'date': date,
      'icon': icon,
      'isLive': isLive,
      'type': type,
      'stream_url': streamUrl,
      'recording_url': recordingUrl,
      'platform': platform,
      'meeting_link': meetingLink,
    };
  }
}

/// State class for live classes provider
class LiveClassesState {
  final bool isLoading;
  final List<LiveClassModel> liveNow;
  final List<LiveClassModel> upcoming;
  final List<LiveClassModel> recorded;
  final String? error;

  LiveClassesState({
    this.isLoading = false,
    this.liveNow = const [],
    this.upcoming = const [],
    this.recorded = const [],
    this.error,
  });

  LiveClassesState copyWith({
    bool? isLoading,
    List<LiveClassModel>? liveNow,
    List<LiveClassModel>? upcoming,
    List<LiveClassModel>? recorded,
    String? error,
  }) {
    return LiveClassesState(
      isLoading: isLoading ?? this.isLoading,
      liveNow: liveNow ?? this.liveNow,
      upcoming: upcoming ?? this.upcoming,
      recorded: recorded ?? this.recorded,
      error: error,
    );
  }
}

/// Notifier class for live classes management
class LiveClassesNotifier extends StateNotifier<LiveClassesState> {
  final ApiService _apiService;

  LiveClassesNotifier(this._apiService) : super(LiveClassesState(isLoading: true)) {
    loadLiveClasses();
  }

  Future<void> loadLiveClasses() async {
    if (state.liveNow.isEmpty && state.upcoming.isEmpty && state.recorded.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/live-classes', useCache: false);
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          liveNow: (data['live'] as List<dynamic>?)
                  ?.map((cls) => LiveClassModel.fromJson(cls))
                  .toList() ??
              [],
          upcoming: (data['upcoming'] as List<dynamic>?)
                  ?.map((cls) => LiveClassModel.fromJson(cls))
                  .toList() ??
              [],
          recorded: (data['recorded'] as List<dynamic>?)
                  ?.map((cls) => LiveClassModel.fromJson(cls))
                  .toList() ??
              [],
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load live classes',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load live classes: $e',
      );
    }
  }

  Future<bool> joinClass(String classId) async {
    try {
      final response = await _apiService.post(
        '/student/live-classes/$classId/join',
        {},
      );
      if (response['success'] == true) {
        // Update viewer count
        final updatedLive = state.liveNow.map((cls) {
          if (cls.id == classId) {
            return LiveClassModel(
              id: cls.id,
              subject: cls.subject,
              teacher: cls.teacher,
              started: cls.started,
              viewers: (cls.viewers ?? 0) + 1,
              icon: cls.icon,
              color: cls.color,
              isLive: cls.isLive,
              type: cls.type,
              time: cls.time,
              timeUntil: cls.timeUntil,
              date: cls.date,
              streamUrl: cls.streamUrl,
              recordingUrl: cls.recordingUrl,
            );
          }
          return cls;
        }).toList();
        state = state.copyWith(liveNow: updatedLive);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> playRecording(String recordingId) async {
    try {
      final response = await _apiService.get(
        '/student/live-classes/recordings/$recordingId',
      );
      if (response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setReminder(String classId) async {
    try {
      final response = await _apiService.post(
        '/student/live-classes/$classId/reminder',
        {},
      );
      if (response['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(String classId) async {
    try {
      final response = await _apiService.get('/student/live-classes/$classId/comments');
      if (response['success'] == true) {
        final list = response['data']['comments'] as List<dynamic>?;
        return list?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> postComment(String classId, String text, {String? parentId}) async {
    try {
      final response = await _apiService.post(
        '/student/live-classes/$classId/comments',
        {
          'comment': text,
          if (parentId != null) 'parent_id': parentId,
        },
      );
      if (response['success'] == true) {
        return Map<String, dynamic>.from(response['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Provider for live classes
final liveClassesProvider =
    StateNotifierProvider<LiveClassesNotifier, LiveClassesState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return LiveClassesNotifier(apiService);
  },
);