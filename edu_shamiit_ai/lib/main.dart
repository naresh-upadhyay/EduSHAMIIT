import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/app.dart';
import 'package:edu_shamiit_ai/core/services/supabase_service.dart';
import 'package:edu_shamiit_ai/core/services/cache_service.dart';
import 'package:edu_shamiit_ai/core/services/call_service.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize Cache Service
  await CacheService().init();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Riverpod container
  final container = ProviderContainer();
  
  // Await auth restoration before the app UI even starts.
  // This is critical for Flutter Web so duplicate tabs or refreshes 
  // immediately know the user is authenticated before the router redirects.
  await container.read(authProvider.notifier).initialize();
  
  // Sync the role provider with the restored auth state
  final authState = container.read(authProvider);
  if (authState.isAuthenticated) {
    container.read(roleProvider.notifier).setRole(authState.role);
    // Initialize CallService for authenticated user
    final userId = authState.userData?['id'] as String? ?? '';
    if (userId.isNotEmpty) {
      await CallService.instance.initialize(userId, AppConfig.baseUrl);
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EduShamiitApp(),
    ),
  );
}
