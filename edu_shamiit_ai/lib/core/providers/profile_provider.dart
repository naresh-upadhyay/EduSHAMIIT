import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'api_provider.dart';

/// Model class for student profile data
class StudentProfileModel {
  final String name;
  final String className;
  final String rollNo;
  final String session;
  final String avgScore;
  final String attendance;
  final String rank;
  final String badges;
  final String gender;
  final String dob;
  final String bloodGroup;
  final String email;
  final String phone;
  final String admissionNo;
  final String nationality;
  final String religion;
  final String category;
  final String address;
  final String house;
  final String fatherName;
  final String fatherOccupation;
  final String fatherPhone;
  final String motherName;
  final String motherOccupation;
  final String motherPhone;
  final List<DocumentModel> documents;

  StudentProfileModel({
    required this.name,
    required this.className,
    required this.rollNo,
    required this.session,
    required this.avgScore,
    required this.attendance,
    required this.rank,
    required this.badges,
    required this.gender,
    required this.dob,
    required this.bloodGroup,
    required this.email,
    required this.phone,
    required this.admissionNo,
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
    required this.documents,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      name: json['name'] ?? '',
      className: json['class'] ?? '',
      rollNo: json['rollNo'] ?? '',
      session: json['session'] ?? '',
      avgScore: json['avgScore'] ?? '',
      attendance: json['attendance'] ?? '',
      rank: json['rank'] ?? '',
      badges: json['badges'] ?? '',
      gender: json['gender'] ?? '',
      dob: json['dob'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      admissionNo: json['admissionNo'] ?? '',
      nationality: json['nationality'] ?? '',
      religion: json['religion'] ?? '',
      category: json['category'] ?? '',
      address: json['address'] ?? '',
      house: json['house'] ?? '',
      fatherName: json['fatherName'] ?? '',
      fatherOccupation: json['fatherOccupation'] ?? '',
      fatherPhone: json['fatherPhone'] ?? '',
      motherName: json['motherName'] ?? '',
      motherOccupation: json['motherOccupation'] ?? '',
      motherPhone: json['motherPhone'] ?? '',
      documents: (json['documents'] as List<dynamic>?)
              ?.map((doc) => DocumentModel.fromJson(doc))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'class': className,
      'rollNo': rollNo,
      'session': session,
      'avgScore': avgScore,
      'attendance': attendance,
      'rank': rank,
      'badges': badges,
      'gender': gender,
      'dob': dob,
      'bloodGroup': bloodGroup,
      'email': email,
      'phone': phone,
      'admissionNo': admissionNo,
      'nationality': nationality,
      'religion': religion,
      'category': category,
      'address': address,
      'house': house,
      'fatherName': fatherName,
      'fatherOccupation': fatherOccupation,
      'fatherPhone': fatherPhone,
      'motherName': motherName,
      'motherOccupation': motherOccupation,
      'motherPhone': motherPhone,
      'documents': documents.map((doc) => doc.toJson()).toList(),
    };
  }
}

/// Model class for document data
class DocumentModel {
  final String name;
  final String status;
  final String? uploadDate;

  DocumentModel({
    required this.name,
    required this.status,
    this.uploadDate,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      name: json['name'] ?? '',
      status: json['status'] ?? '',
      uploadDate: json['uploadDate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'status': status,
      'uploadDate': uploadDate,
    };
  }
}

/// State class for profile provider
class ProfileState {
  final bool isLoading;
  final StudentProfileModel? profile;
  final String? error;

  ProfileState({
    this.isLoading = false,
    this.profile,
    this.error,
  });

  ProfileState copyWith({
    bool? isLoading,
    StudentProfileModel? profile,
    String? error,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: error ?? this.error,
    );
  }
}

/// Notifier class for profile management
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ApiService _apiService;

  ProfileNotifier(this._apiService) : super(ProfileState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.get('/student/profile');
      if (response['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          profile: StudentProfileModel.fromJson(response['data']),
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
        error: 'Failed to load profile: $e',
      );
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.put('/student/profile', updates);
      if (response['success'] == true) {
        // Reload profile to get updated data
        await loadProfile();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadDocument(String documentType, String filePath) async {
    try {
      final response = await _apiService.post(
        '/student/profile/documents',
        {
          'documentType': documentType,
          'filePath': filePath,
        },
      );
      if (response['success'] == true) {
        await loadProfile(); // Reload profile to get updated documents
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for student profile
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) {
    final apiService = ref.watch(apiServiceProvider);
    return ProfileNotifier(apiService);
  },
);