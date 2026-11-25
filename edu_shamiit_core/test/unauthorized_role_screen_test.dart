import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/screens/auth/unauthorized_role_screen.dart';
import 'package:edu_shamiit_core/screens/auth/not_found_screen.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  MockAuthNotifier(super.initial);

  bool signOutCalled = false;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> signIn({
    required String email,
    required String password,
    UserRole? role,
  }) async =>
      true;

  @override
  Future<bool> signInWithOtp({
    required String email,
    required String otp,
    UserRole? role,
  }) async =>
      true;

  @override
  Future<void> updateUserData(Map<String, dynamic> patch) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    state = AuthState();
  }

  @override
  Future<bool> refreshToken() async => true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedUnauthorizedRoleScreen Tests', () {
    testWidgets(
        'renders user info, role badge, and explanation for unauthorized user',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      final mockAuth = MockAuthNotifier(
        AuthState(
          isAuthenticated: true,
          role: UserRole.admin,
          userData: {
            'name': 'Principal Skinner',
            'email': 'admin@school.com',
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => mockAuth),
          ],
          child: const MaterialApp(
            home: SharedUnauthorizedRoleScreen(
              appName: 'Academic Portal',
              allowedRolesDescription: 'Teachers, Students, and Parents',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Principal Skinner'), findsOneWidget);
      expect(find.text('admin@school.com'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Logout & Login with Another Account'), findsOneWidget);
      expect(find.text('Switch Account'), findsOneWidget);
    });

    testWidgets(
        'clicking Logout & Login with Another Account triggers signOut()',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      final mockAuth = MockAuthNotifier(
        AuthState(
          isAuthenticated: true,
          role: UserRole.superAdmin,
          userData: {
            'name': 'Super Administrator',
            'email': 'superadmin@shamiit.com',
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => mockAuth),
          ],
          child: const MaterialApp(
            home: SharedUnauthorizedRoleScreen(
              appName: 'Academic Portal',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout & Login with Another Account'));
      await tester.pumpAndSettle();

      expect(mockAuth.signOutCalled, isTrue);
    });

    testWidgets('clicking Switch Account triggers signOut()', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      final mockAuth = MockAuthNotifier(
        AuthState(
          isAuthenticated: true,
          role: UserRole.finance,
          userData: {
            'name': 'Finance Officer',
            'email': 'finance@shamiit.com',
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => mockAuth),
          ],
          child: const MaterialApp(
            home: SharedUnauthorizedRoleScreen(
              appName: 'Academic Portal',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Switch Account'));
      await tester.pumpAndSettle();

      expect(mockAuth.signOutCalled, isTrue);
    });
  });

  group('SharedNotFoundScreen Tests', () {
    testWidgets(
        'renders clean 404 with Logout & Switch Account option when authenticated',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      final mockAuth = MockAuthNotifier(
        AuthState(
          isAuthenticated: true,
          role: UserRole.admin,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => mockAuth),
          ],
          child: const MaterialApp(
            home: SharedNotFoundScreen(
              path: '/admin/dashboard',
              appName: 'Academic Portal',
              isAcademicApp: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page Not Found'), findsOneWidget);
      expect(find.textContaining('/admin/dashboard'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);
      expect(find.text('Logout & Switch Account'), findsOneWidget);

      await tester.tap(find.text('Logout & Switch Account'));
      await tester.pumpAndSettle();

      expect(mockAuth.signOutCalled, isTrue);
    });
  });
}
