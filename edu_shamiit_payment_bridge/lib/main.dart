import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching EduSHAMIIT Deep Navy theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EduShamiitPaymentBridgeApp());
}

class EduShamiitPaymentBridgeApp extends StatefulWidget {
  const EduShamiitPaymentBridgeApp({super.key});

  @override
  State<EduShamiitPaymentBridgeApp> createState() => _EduShamiitPaymentBridgeAppState();
}

class _EduShamiitPaymentBridgeAppState extends State<EduShamiitPaymentBridgeApp> {
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final apiService = ApiService();
      await apiService.init();
      final loggedIn = await apiService.isLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[Bootstrap] Error during app initialization: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduSHAMIIT Payment Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: !_isInitialized
          ? const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E3A8A),
                ),
              ),
            )
          : (_isLoggedIn ? const MainNavigationShell() : const LoginScreen()),
    );
  }
}
