import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// User role enumeration
enum UserRole {
  student,
  teacher,
  admin,
  parent,
  superAdmin,
  director,
  principal,
  finance,
  hr,
  transport,
  library,
  security,
  sports,
  support,
  driver,
  hostel,
  examCtrl,
  unknown,
}

/// Extension to get role string
extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.admin:
        return 'admin';
      case UserRole.parent:
        return 'parent';
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.director:
        return 'director';
      case UserRole.principal:
        return 'principal';
      case UserRole.finance:
        return 'finance';
      case UserRole.hr:
        return 'hr';
      case UserRole.transport:
        return 'transport';
      case UserRole.library:
        return 'library';
      case UserRole.security:
        return 'security';
      case UserRole.sports:
        return 'sports';
      case UserRole.support:
        return 'support';
      case UserRole.driver:
        return 'driver';
      case UserRole.hostel:
        return 'hostel';
      case UserRole.examCtrl:
        return 'exam_ctrl';
      case UserRole.unknown:
        return 'unknown';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'teacher':
        return UserRole.teacher;
      case 'admin':
      case 'administrator':
      case 'institution_admin':
      case 'institutionadmin':
      case 'school_admin':
        return UserRole.admin;
      case 'parent':
        return UserRole.parent;
      case 'super_admin':
      case 'superadmin':
      case 'super admin':
      case 'super-admin':
        return UserRole.superAdmin;
      case 'director':
        return UserRole.director;
      case 'principal':
        return UserRole.principal;
      case 'finance':
        return UserRole.finance;
      case 'hr':
        return UserRole.hr;
      case 'transport':
        return UserRole.transport;
      case 'library':
      case 'librarian':
        return UserRole.library;
      case 'security':
        return UserRole.security;
      case 'sports':
        return UserRole.sports;
      case 'support':
        return UserRole.support;
      case 'driver':
        return UserRole.driver;
      case 'hostel':
        return UserRole.hostel;
      case 'exam_ctrl':
      case 'exam':
        return UserRole.examCtrl;
      default:
        return UserRole.unknown;
    }
  }
}

/// Role provider state
class RoleState {
  final UserRole role;
  final bool isLoading;
  final String? error;

  RoleState({
    this.role = UserRole.unknown,
    this.isLoading = false,
    this.error,
  });

  RoleState copyWith({
    UserRole? role,
    bool? isLoading,
    String? error,
  }) {
    return RoleState(
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isStudent => role == UserRole.student;
  bool get isTeacher => role == UserRole.teacher;
  bool get isAdmin => role == UserRole.admin;
  bool get isParent => role == UserRole.parent;
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isDirector => role == UserRole.director;
  bool get isPrincipal => role == UserRole.principal;
  bool get isFinance => role == UserRole.finance;
  bool get isHr => role == UserRole.hr;
  bool get isTransport => role == UserRole.transport;
  bool get isLibrary => role == UserRole.library;
  bool get isSecurity => role == UserRole.security;
  bool get isSports => role == UserRole.sports;
  bool get isSupport => role == UserRole.support;
  bool get isDriver => role == UserRole.driver;
  bool get isHostel => role == UserRole.hostel;
  bool get isExamCtrl => role == UserRole.examCtrl;
  bool get isAuthenticated => role != UserRole.unknown;

  /// Returns true if the user role is an administrative role or librarian with full CRUD permissions
  bool get isLibraryAdmin =>
      isSuperAdmin || isAdmin || isDirector || isPrincipal || isLibrary;
}

/// Role provider notifier
class RoleNotifier extends StateNotifier<RoleState> {
  RoleNotifier() : super(RoleState());

  /// Set user role
  void setRole(UserRole role) {
    state = state.copyWith(role: role, isLoading: false, error: null);
  }

  /// Set role from string
  void setRoleFromString(String role) {
    setRole(UserRoleExtension.fromString(role));
  }

  /// Set loading state
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Set error
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Reset to unknown
  void reset() {
    state = RoleState();
  }
}

/// Role provider - synchronized with authProvider
final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  final notifier = RoleNotifier();

  final authState = ref.watch(authProvider);
  if (authState.role != UserRole.unknown) {
    notifier.setRole(authState.role);
  } else if (authState.userData?['role'] != null) {
    notifier.setRoleFromString(authState.userData!['role'].toString());
  } else if (!authState.isAuthenticated) {
    notifier.reset();
  }

  return notifier;
});

/// Dedicated provider to check if the current user has library administrative & full CRUD permissions
final isLibraryAdminProvider = Provider<bool>((ref) {
  final roleState = ref.watch(roleProvider);
  if (roleState.isLibraryAdmin) return true;

  final authState = ref.watch(authProvider);
  if (authState.role == UserRole.superAdmin ||
      authState.role == UserRole.admin ||
      authState.role == UserRole.director ||
      authState.role == UserRole.principal ||
      authState.role == UserRole.library) {
    return true;
  }

  final roleStr = authState.userData?['role']?.toString().toLowerCase().trim() ?? '';
  return roleStr == 'super_admin' ||
      roleStr == 'superadmin' ||
      roleStr == 'super admin' ||
      roleStr == 'super-admin' ||
      roleStr == 'admin' ||
      roleStr == 'administrator' ||
      roleStr == 'institution_admin' ||
      roleStr == 'school_admin' ||
      roleStr == 'principal' ||
      roleStr == 'director' ||
      roleStr == 'library' ||
      roleStr == 'librarian';
});