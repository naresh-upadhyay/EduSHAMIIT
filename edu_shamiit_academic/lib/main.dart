import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_academic/app.dart';
import 'package:edu_shamiit_core/services/supabase_service.dart';
import 'package:edu_shamiit_core/services/cache_service.dart';

import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import 'package:edu_shamiit_academic/core/services/call_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register auth callbacks for CallService initialization
  AuthNotifier.onLogin = (userId, baseUrl) {
    CallService.instance.initialize(userId, baseUrl);
  };
  AuthNotifier.onLogout = () {
    CallService.instance.dispose();
  };

  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize Cache Service
  await CacheService().init();

  // Lock orientation to portrait (no-op on web, skip to save startup time)
  if (!kIsWeb) {
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
  }

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
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EduShamiitApp(),
    ),
  );
}
