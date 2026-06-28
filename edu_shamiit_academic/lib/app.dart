import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_academic/app_router.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_core/theme/student_theme.dart';
import 'package:edu_shamiit_core/theme/teacher_theme.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/settings_provider.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_academic/shared/widgets/call_notification_overlay.dart';

class EduShamiitApp extends ConsumerWidget {
  const EduShamiitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleState = ref.watch(roleProvider);
    final router = ref.watch(routerProvider);
    final settingsState = ref.watch(settingsProvider);
    
    // Global interceptor for 401 Unauthorized API responses
    ApiService().onUnauthorized = () {
      Future.microtask(() {
        ref.read(authProvider.notifier).signOut();
      });
    };
    
    // Select theme based on user role
    ThemeData theme;
    ThemeData darkTheme;
    if (roleState.isTeacher) {
      theme = getTeacherTheme(brightness: Brightness.light);
      darkTheme = getTeacherTheme(brightness: Brightness.dark);
    } else {
      theme = getStudentTheme(brightness: Brightness.light);
      darkTheme = getStudentTheme(brightness: Brightness.dark);
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: (settingsState.settings?.darkMode ?? false) ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      // Wrap the entire app with the incoming call notification overlay
      // so call banners appear on top of any route
      builder: (context, child) {
        return CallNotificationOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
