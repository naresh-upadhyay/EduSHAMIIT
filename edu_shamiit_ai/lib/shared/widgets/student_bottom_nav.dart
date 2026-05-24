import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentBottomNav extends StatelessWidget {
  const StudentBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
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
          _buildNavItem(context, '🏠', 'Home', '/student/dashboard', location),
          _buildNavItem(context, '📚', 'Courses', '/student/courses', location),
          _buildNavItem(context, '📊', 'Results', '/student/results', location),
          _buildNavItem(context, '🏆', 'Achieve', '/student/achievements', location),
          _buildNavItem(context, '👤', 'Profile', '/student/profile', location),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String emoji, String label, String route, String currentLocation) {
    final isActive = currentLocation == route;
    return GestureDetector(
      onTap: () {
        final nav = Navigator.of(context);
        while (nav.canPop()) {
          nav.pop();
        }
        context.go(route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
