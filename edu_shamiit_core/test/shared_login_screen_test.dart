import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/screens/auth/login_screen.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier() : super(AuthState());

  bool signInCalled = false;
  String? lastEmail;
  String? lastPassword;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> signIn({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    state = AuthState(isAuthenticated: true, role: UserRole.admin);
    return true;
  }

  @override
  Future<bool> signInWithOtp({
    required String email,
    required String otp,
    UserRole? role,
  }) async {
    return true;
  }

  @override
  Future<void> updateUserData(Map<String, dynamic> patch) async {}

  @override
  Future<void> signOut() async {
    state = AuthState();
  }

  @override
  Future<bool> refreshToken() async => true;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedLoginScreen Tests', () {
    testWidgets('renders email, password field, remember me checkbox, and login button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final fakeAuth = FakeAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeAuth),
          ],
          child: const MaterialApp(
            home: SharedLoginScreen(isAdmin: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Login to Your Account'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Remember me'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('loads remembered credentials from SharedPreferences on initialization', (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me_state': true,
        'remembered_email': 'saved_user@shamiit.com',
        'remembered_password': 'secret_password_123',
      });

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final fakeAuth = FakeAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeAuth),
          ],
          child: const MaterialApp(
            home: SharedLoginScreen(isAdmin: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Email and password controllers should contain the remembered values
      expect(find.text('saved_user@shamiit.com'), findsOneWidget);
      expect(find.text('secret_password_123'), findsOneWidget);

      // Checkbox should be checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('toggling Remember Me updates SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me_state': false,
      });

      await tester.binding.setSurfaceSize(const Size(1400, 900));
      final fakeAuth = FakeAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeAuth),
          ],
          child: const MaterialApp(
            home: SharedLoginScreen(isAdmin: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially unchecked
      var checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap the Remember me checkbox or row
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('remember_me_state'), isTrue);

      // Tap again to uncheck
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(prefs.getBool('remember_me_state'), isFalse);
    });

    testWidgets('pressing Enter on password field triggers onFieldSubmitted and calls signIn', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final fakeAuth = FakeAuthNotifier();
      bool loginSuccessCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeAuth),
          ],
          child: MaterialApp(
            home: SharedLoginScreen(
              isAdmin: true,
              onLoginSuccess: () {
                loginSuccessCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid email and password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'admin@shamiit.com');
      await tester.enterText(textFields.at(1), 'supersecret123');
      await tester.pumpAndSettle();

      // Check remember me so credentials get saved
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();

      // Submit password field with Enter/Done action
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(fakeAuth.signInCalled, isTrue);
      expect(fakeAuth.lastEmail, 'admin@shamiit.com');
      expect(fakeAuth.lastPassword, 'supersecret123');
      expect(loginSuccessCalled, isTrue);

      // Verify that Remember Me saved to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('remembered_email'), 'admin@shamiit.com');
      expect(prefs.getString('remembered_password'), 'supersecret123');
      expect(prefs.getBool('remember_me_state'), isTrue);
    });
  });
}
