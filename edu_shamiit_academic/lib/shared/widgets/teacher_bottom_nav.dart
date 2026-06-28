import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_academic/app_router.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';

class TeacherBottomNav extends StatelessWidget {
  final String? currentLocation;
  const TeacherBottomNav({super.key, this.currentLocation});

  @override
  Widget build(BuildContext context) {
    String location = currentLocation ?? '';
    if (location.isEmpty) {
      try {
        location = GoRouterState.of(context).uri.toString();
      } catch (_) {
        try {
          location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
        } catch (_) {}
      }
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: StudentColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, '🏠', 'Home', '/teacher/dashboard', location),
          _buildNavItem(context, '📖', 'Classes', '/teacher/my-classes', location),
          _buildNavItem(context, '📊', 'Grades', '/teacher/gradebook', location),
          _buildNavItem(context, '📝', 'Tasks', '/teacher/homework', location),
          _buildNavItem(context, '👤', 'Profile', '/teacher/profile', location),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String emoji, String label, String route, String currentLocation) {
    final isActive = currentLocation == route;
    return GestureDetector(
      onTap: () {
        final shellNav = teacherShellKey.currentState;
        if (shellNav != null) {
          while (shellNav.canPop()) {
            shellNav.pop();
          }
        }
        context.go(route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 22, color: isActive ? StudentColors.primary : StudentColors.text3)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
