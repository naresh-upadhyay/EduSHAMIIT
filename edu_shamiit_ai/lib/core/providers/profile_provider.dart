import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

// ─────────────────────────────────────────────
// Model classes
// ─────────────────────────────────────────────

class DocumentModel {
  final String id;
  final String type;
  final String fileName;
  final String fileUrl;
  final String status; // 'pending', 'verified', 'rejected'

  DocumentModel({
    required this.id,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    required this.status,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id']?.toString() ?? '',
      type: json['document_type']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      fileUrl: json['file_url']?.toString() ?? '',
      status: json['verification_status']?.toString() ?? 'pending',
    );
  }
}

class StudentProfileModel {
  final String id;
  final String name;
  final String className;
  final String rollNumber;
  final String session;
  final String? avatarUrl;

  // Stats
  final String avgScore;
  final String attendancePct;
  final String rank;
  final String badges;

  // Personal info
  final String gender;
  final String dateOfBirth;
  final String bloodGroup;
  final String email;
  final String phone;
  final String admissionNumber;
  final String nationality;
  final String religion;
  final String category;
  final String address;
  final String house;

  // Guardian info
  final String fatherName;
  final String fatherOccupation;
  final String fatherPhone;
  final String motherName;
  final String motherOccupation;
  final String motherPhone;
  final String localGuardian;

  // Gamification
  final int xpPoints;
  final int learningStreak;

  // Documents
  final List<DocumentModel> documents;

  StudentProfileModel({
    required this.id,
    required this.name,
    required this.className,
    required this.rollNumber,
    required this.session,
    this.avatarUrl,
    required this.avgScore,
    required this.attendancePct,
    required this.rank,
    required this.badges,
    required this.gender,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.email,
    required this.phone,
    required this.admissionNumber,
    required this.nationality,
    required this.religion,
    required this.category,
    required this.address,
    required this.house,
    required this.fatherName,
    required this.fatherOccupation,
    required this.fatherPhone,
    required this.motherName,
    required this.motherOccupation,
    required this.motherPhone,
    required this.localGuardian,
    required this.xpPoints,
    required this.learningStreak,
    required this.documents,
  });

  /// Parse from the GET /student/profile response data map.
  /// Backend now returns flat keys (name, class, roll_number, etc.)
  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] ?? '').toString();
    int i(String key) => int.tryParse(json[key]?.toString() ?? '') ?? 0;

    return StudentProfileModel(
      id:               s('id'),
      name:             s('name'),
      className:        s('class'),
      rollNumber:       s('roll_number'),
      session:          s('session'),
      avatarUrl:        json['avatar_url'] as String?,

      avgScore:         s('avg_score'),
      attendancePct:    s('attendance_pct'),
      rank:             s('rank'),
      badges:           s('badges'),

      gender:           s('gender'),
      dateOfBirth:      s('date_of_birth'),
      bloodGroup:       s('blood_group'),
      email:            s('email'),
      phone:            s('phone'),
      admissionNumber:  s('admission_number'),
      nationality:      s('nationality'),
      religion:         s('religion'),
      category:         s('category'),
      address:          s('address'),
      house:            s('house'),

      fatherName:       s('father_name'),
      fatherOccupation: s('father_occupation'),
      fatherPhone:      s('father_phone'),
      motherName:       s('mother_name'),
      motherOccupation: s('mother_occupation'),
      motherPhone:      s('mother_phone'),
      localGuardian:    s('local_guardian'),

      xpPoints:         i('xp_points'),
      learningStreak:   i('learning_streak'),
      
      documents:        (json['documents'] as List<dynamic>?)
                            ?.map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
                            .toList() ??
                        [],
    );
  }

  StudentProfileModel copyWith({String? avatarUrl}) {
    return StudentProfileModel(
      id:               id,
      name:             name,
      className:        className,
      rollNumber:       rollNumber,
      session:          session,
      avatarUrl:        avatarUrl ?? this.avatarUrl,
      avgScore:         avgScore,
      attendancePct:    attendancePct,
      rank:             rank,
      badges:           badges,
      gender:           gender,
      dateOfBirth:      dateOfBirth,
      bloodGroup:       bloodGroup,
      email:            email,
      phone:            phone,
      admissionNumber:  admissionNumber,
      nationality:      nationality,
      religion:         religion,
      category:         category,
      address:          address,
      house:            house,
      fatherName:       fatherName,
      fatherOccupation: fatherOccupation,
      fatherPhone:      fatherPhone,
      motherName:       motherName,
      motherOccupation: motherOccupation,
      motherPhone:      motherPhone,
      localGuardian:    localGuardian,
      xpPoints:         xpPoints,
      learningStreak:   learningStreak,
      documents:        documents,
    );
  }
}

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────

class ProfileState {
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingAvatar;
  final bool isUploadingDocument;
  final StudentProfileModel? profile;
  final String? error;

  ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.isUploadingDocument = false,
    this.profile,
    this.error,
  });

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingAvatar,
    bool? isUploadingDocument,
    StudentProfileModel? profile,
    String? error,
  }) {
    return ProfileState(
      isLoading:           isLoading           ?? this.isLoading,
      isSaving:            isSaving            ?? this.isSaving,
      isUploadingAvatar:   isUploadingAvatar   ?? this.isUploadingAvatar,
      isUploadingDocument: isUploadingDocument ?? this.isUploadingDocument,
      profile:             profile             ?? this.profile,
      error:               error               ?? this.error,
    );
  }
}

// ─────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ApiService _api;

  ProfileNotifier(this._api, {bool skipLoad = false}) : super(ProfileState(isLoading: !skipLoad)) {
    if (!skipLoad) {
      loadProfile();
    }
  }

  // ── Load ──────────────────────────────────────────────────────────
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/student/profile', useCache: false);
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          profile: StudentProfileModel.fromJson(data),
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

  // ── Update ────────────────────────────────────────────────────────
  /// Updates editable profile fields via PUT /student/profile.
  /// [updates] must use backend snake_case keys (full_name, phone, etc.)
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(isSaving: true);
    try {
      final response = await _api.put('/student/profile', updates);
      if (response['success'] == true) {
        await loadProfile();
        state = state.copyWith(isSaving: false);
        return true;
      }
      state = state.copyWith(isSaving: false);
      return false;
    } catch (e) {
      state = state.copyWith(isSaving: false);
      return false;
    }
  }

  // ── Avatar upload ─────────────────────────────────────────────────
  Future<bool> uploadAvatar(Uint8List bytes, String filename) async {
    state = state.copyWith(isUploadingAvatar: true);
    try {
      final response =
          await _api.multipartPostBytes('/student/profile/avatar', bytes, filename, 'avatar');
      if (response['success'] == true) {
        final newUrl = response['data']?['avatar_url'] as String?;
        if (newUrl != null && state.profile != null) {
          state = state.copyWith(
            isUploadingAvatar: false,
            profile: state.profile!.copyWith(avatarUrl: newUrl),
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

  // ── Document upload ───────────────────────────────────────────────
  Future<bool> uploadDocument(Uint8List bytes, String filename, String documentType) async {
    state = state.copyWith(isUploadingDocument: true);
    try {
      final response = await _api.multipartPostBytes(
        '/student/profile/document',
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

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) {
    // Watch authentication state. When user logs in/out, this provider is recreated.
    final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
    
    if (!isAuthenticated) {
      return ProfileNotifier(ref.watch(apiServiceProvider), skipLoad: true);
    }
    
    return ProfileNotifier(ref.watch(apiServiceProvider));
  },
);