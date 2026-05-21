import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class ParentBottomNav extends StatelessWidget {
  const ParentBottomNav({super.key});

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
          _buildNavItem(context, '🏠', 'Home', '/parent/dashboard', location),
          _buildNavItem(context, '📊', 'Progress', '/parent/results', location),
          _buildNavItem(context, '💳', 'Fees', '/parent/fees', location),
          _buildNavItem(
              context, '💬', 'Messages', '/parent/messaging', location),
          _buildNavItem(context, '👤', 'Profile', '/parent/profile', location),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String emoji, String label,
      String route, String currentLocation) {
    final isActive = currentLocation == route;
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFF0FDFA) : Colors.transparent,
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
              color:
                  isActive ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
