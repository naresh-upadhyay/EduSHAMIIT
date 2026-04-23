import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/app_router.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/theme/student_theme.dart';
import 'package:edu_shamiit_ai/core/theme/teacher_theme.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

class EduShamiitApp extends ConsumerWidget {
  const EduShamiitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleState = ref.watch(roleProvider);
    final router = ref.watch(routerProvider);
    
    // Global interceptor for 401 Unauthorized API responses
    ApiService().onUnauthorized = () {
      Future.microtask(() {
        ref.read(authProvider.notifier).signOut();
      });
    };
    
    // Select theme based on user role
    ThemeData theme;
    if (roleState.isTeacher) {
      theme = getTeacherTheme();
    } else {
      theme = getStudentTheme();
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}