import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_admin/app_router.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';

void main() async {
  usePathUrlStrategy();
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
    final systemConfig = ref.watch(systemConfigProvider);

    Color? customPrimary;
    if (systemConfig != null) {
      try {
        final hex = systemConfig.primaryColor.replaceAll('#', '');
        customPrimary = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    ThemeMode themeMode = ThemeMode.dark;
    if (systemConfig != null) {
      if (systemConfig.theme == "Light") {
        themeMode = ThemeMode.light;
      } else if (systemConfig.theme == "Dark") {
        themeMode = ThemeMode.dark;
      } else if (systemConfig.theme == "System Mode" || systemConfig.theme == "System") {
        themeMode = ThemeMode.system;
      }
    }

    return MaterialApp.router(
      title: systemConfig?.systemTitle ?? 'EduSHAMIIT Admin Suite',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: getStudentTheme(brightness: Brightness.light, primaryColor: customPrimary),
      darkTheme: getStudentTheme(brightness: Brightness.dark, primaryColor: customPrimary),
      routerConfig: router,
    );
  }
}
