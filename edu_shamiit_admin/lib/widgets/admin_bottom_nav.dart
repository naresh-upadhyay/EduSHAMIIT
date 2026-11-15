import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminBottomNav extends StatelessWidget {
  final String currentLocation;
  final VoidCallback? onMenuPressed;

  const AdminBottomNav({
    super.key,
    required this.currentLocation,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.space_dashboard_rounded, 'Dashboard', '/admin/dashboard'),
            _buildNavItem(context, Icons.school_outlined, 'Schools', '/admin/schools'),
            _buildNavItem(context, Icons.people_outline_rounded, 'Users', '/admin/users'),
            _buildNavItem(context, Icons.directions_bus_rounded, 'Fleet', '/admin/vehicle-dashboard'),
            _buildActionItem(
              context,
              Icons.grid_view_rounded,
              'All Modules',
              onMenuPressed ?? () {},
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = currentLocation.startsWith(route);

    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 26,
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark ? const Color(0xFF1E2142) : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? const Color(0xFF4F46E5)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              size: 18,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'Outfit',
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.menu_open_rounded,
              color: Color(0xFF6366F1),
              size: 18,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
