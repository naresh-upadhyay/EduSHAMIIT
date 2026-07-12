import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_admin/app_router.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize Cache Service
  await CacheService().init();

  final container = ProviderContainer();
  // Await auth restoration before the app UI starts
  await container.read(authProvider.notifier).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EduShamiitAdminApp(),
    ),
  );
}

class EduShamiitAdminApp extends ConsumerWidget {
  const EduShamiitAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    
    return MaterialApp.router(
      title: 'EduSHAMIIT Admin Suite',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: getStudentTheme(brightness: Brightness.light),
      darkTheme: getStudentTheme(brightness: Brightness.dark),
      routerConfig: router,
    );
  }
}
