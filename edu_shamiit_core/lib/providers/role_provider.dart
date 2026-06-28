import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User role enumeration
enum UserRole {
  student,
  teacher,
  admin,
  parent,
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
        return UserRole.admin;
      case 'parent':
        return UserRole.parent;
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
  bool get isAuthenticated => role != UserRole.unknown;
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

/// Role provider
final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  return RoleNotifier();
});