import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'api_provider.dart';

/// Model class for course data
class CourseModel {
  final String id;
  final String name;
  final String teacher;
  final String chapters;
  final String score;
  final double progress;
  final String icon;
  final Gradient color;
  final Color accentColor;
  final List<ChapterModel>? chaptersList;

  CourseModel({
    required this.id,
    required this.name,
    required this.teacher,
    required this.chapters,
    required this.score,
    required this.progress,
    required this.icon,
    required this.color,
    required this.accentColor,
    this.chaptersList,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      teacher: json['teacher'] ?? '',
      chapters: json['chapters'] ?? '',
      score: json['score'] ?? '',
      progress: (json['progress'] ?? 0).toDouble(),
      icon: json['icon'] ?? '',
      color: json['color'] as Gradient? ??
          const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
      accentColor: json['accentColor'] as Color? ?? Colors.blue,
      chaptersList: (json['chaptersList'] as List<dynamic>?)
              ?.map((ch) => ChapterModel.fromJson(ch))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'chapters': chapters,
      'score': score,
      'progress': progress,
      'icon': icon,
      'accentColor': accentColor,
      'chaptersList': chaptersList?.map((ch) => ch.toJson()).toList(),
    };
  }
}

/// Model class for chapter data
class ChapterModel {
  final String name;
  final double progress;
  final Color statusColor;

  ChapterModel({
    required this.name,
    required this.progress,
    required this.statusColor,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      name: json['name'] ?? '',
      progress: (json['progress'] ?? 0).toDouble(),
      statusColor: json['statusColor'] as Color? ?? Colors.grey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'progress': progress,
      'statusColor': statusColor,
    };
  }
}

/// State class for courses provider
class CoursesState {
  final bool isLoading;
  final List<CourseModel> courses;
  final String? error;

  CoursesState({
    this.isLoading = false,
    this.courses = const [],
    this.error,
  });

  CoursesState copyWith({
    bool? isLoading,
    List<CourseModel>? courses,
    String? error,
  }) {
    return CoursesState(
      isLoading: isLoading ?? this.isLoading,
      courses: courses ?? this.courses,
      error: error,
    );
  }
}

/// Notifier class for courses management
class CoursesNotifier extends StateNotifier<CoursesState> {
  final ApiService _apiService;

  CoursesNotifier(this._apiService) : super(CoursesState(isLoading: true)) {
    loadCourses();
  }

  Future<void> loadCourses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.get('/student/courses');
      if (response['success'] == true) {
        final data = response['data'];
        final List<dynamic> rawList = data is List 
            ? data 
            : (data is Map ? data.values.firstWhere((v) => v is List, orElse: () => []) as List : []);
        final coursesList = rawList
            .map((course) => CourseModel.fromJson(course))
            .toList();
        state = state.copyWith(
          isLoading: false,
          courses: coursesList,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load courses',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load courses: $e',
      );
    }
  }

  Future<void> loadCourseDetails(String courseId) async {
    try {
      final response =
          await _apiService.get('/student/courses/$courseId');
      if (response['success'] == true) {
        final updatedCourse = CourseModel.fromJson(response['data']);
        final updatedCourses = List<CourseModel>.from(state.courses);
        final index = updatedCourses.indexWhere((c) => c.id == courseId);
        if (index != -1) {
          updatedCourses[index] = updatedCourse;
          state = state.copyWith(courses: updatedCourses);
        }
      }
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<bool> startLearning(String courseId) async {
    try {
      final response = await _apiService.post(
        '/student/courses/$courseId/start',
        {},
      );
      if (response['success'] == true) {
        await loadCourseDetails(courseId);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for student courses
final coursesProvider =
    StateNotifierProvider<CoursesNotifier, CoursesState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return CoursesNotifier(apiService);
  },
);