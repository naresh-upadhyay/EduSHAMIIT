import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'api_provider.dart';

/// Model class for live class data
class LiveClassModel {
  final String id;
  final String subject;
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

  LiveClassModel({
    required this.id,
    required this.subject,
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
  });

  factory LiveClassModel.fromJson(Map<String, dynamic> json) {
    return LiveClassModel(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'teacher': teacher,
      'started': started,
      'viewers': viewers,
      'time': time,
      'timeUntil': timeUntil,
      'date': date,
      'icon': icon,
      'isLive': isLive,
      'type': type,
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.get('/student/live-classes');
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
}

/// Provider for live classes
final liveClassesProvider =
    StateNotifierProvider<LiveClassesNotifier, LiveClassesState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return LiveClassesNotifier(apiService);
  },
);