import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style matching SHAMIIT Deep Navy theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF030A1C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ShamiitPaymentBridgeApp());
}

class ShamiitPaymentBridgeApp extends StatelessWidget {
  const ShamiitPaymentBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHAMIIT Payment Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
