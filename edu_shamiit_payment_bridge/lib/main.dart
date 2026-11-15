import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/main_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching EduSHAMIIT Deep Navy theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EduShamiitPaymentBridgeApp());
}

class EduShamiitPaymentBridgeApp extends StatelessWidget {
  const EduShamiitPaymentBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduSHAMIIT Payment Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainNavigationShell(),
    );
  }
}
