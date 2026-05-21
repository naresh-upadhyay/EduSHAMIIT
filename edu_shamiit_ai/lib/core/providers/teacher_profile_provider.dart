import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/teacher_models.dart';
import '../services/api_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

class TeacherProfileState {
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingAvatar;
  final bool isUploadingDocument;
  final TeacherProfile? profile;
  final String? error;

  TeacherProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.isUploadingDocument = false,
    this.profile,
    this.error,
  });

  TeacherProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingAvatar,
    bool? isUploadingDocument,
    TeacherProfile? profile,
    String? error,
  }) {
    return TeacherProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      isUploadingDocument: isUploadingDocument ?? this.isUploadingDocument,
      profile: profile ?? this.profile,
      error: error ?? this.error,
    );
  }
}

class TeacherProfileNotifier extends StateNotifier<TeacherProfileState> {
  final ApiService _api;

  TeacherProfileNotifier(this._api, {bool skipLoad = false})
      : super(TeacherProfileState(isLoading: !skipLoad)) {
    if (!skipLoad) {
      loadProfile();
    }
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/teacher/profile', useCache: false);
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final profileData = data['profile'] as Map<String, dynamic>? ?? data;
        state = state.copyWith(
          isLoading: false,
          profile: TeacherProfile.fromJson(profileData),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load profile',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isSaving: true);
    try {
      final response = await _api.patch('/teacher/profile', updates);
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final profileData = data['profile'] as Map<String, dynamic>? ?? data;
        state = state.copyWith(
          isSaving: false,
          profile: TeacherProfile.fromJson(profileData),
        );
        return true;
      }
      state = state.copyWith(isSaving: false);
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return false;
    }
  }

  Future<bool> uploadAvatar(Uint8List bytes, String filename) async {
    state = state.copyWith(isUploadingAvatar: true);
    try {
      final response = await _api.multipartPostBytes(
        '/teacher/profile/avatar',
        bytes,
        filename,
        'avatar',
      );
      if (response['success'] == true) {
        final newUrl = response['data']?['avatar_url'] as String?;
        if (newUrl != null && state.profile != null) {
          state = state.copyWith(
            isUploadingAvatar: false,
            profile: state.profile!.copyWith(profileImageUrl: newUrl),
          );
        } else {
          await loadProfile();
        }
        return true;
      }
      state = state.copyWith(isUploadingAvatar: false);
      return false;
    } catch (e) {
      state = state.copyWith(isUploadingAvatar: false);
      return false;
    }
  }

  Future<bool> uploadDocument(Uint8List bytes, String filename, String documentType) async {
    state = state.copyWith(isUploadingDocument: true);
    try {
      final response = await _api.multipartPostBytes(
        '/teacher/profile/document',
        bytes,
        filename,
        'document',
        fields: {'document_type': documentType},
      );
      if (response['success'] == true) {
        await loadProfile();
        state = state.copyWith(isUploadingDocument: false);
        return true;
      }
      state = state.copyWith(isUploadingDocument: false);
      return false;
    } catch (e) {
      state = state.copyWith(isUploadingDocument: false);
      return false;
    }
  }
}

final teacherProfileProvider =
    StateNotifierProvider<TeacherProfileNotifier, TeacherProfileState>((ref) {
  final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
  final api = ref.watch(apiServiceProvider);

  if (!isAuthenticated) {
    return TeacherProfileNotifier(api, skipLoad: true);
  }

  return TeacherProfileNotifier(api);
});
