import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/shared/widgets/student_bottom_nav.dart';

/// Shell scaffold that wraps all student screens with a persistent bottom nav bar.
/// On desktop (≥1100px) it switches to a NavigationRail on the left side.
/// Used by ShellRoute in the GoRouter configuration.
class StudentShellScaffold extends StatelessWidget {
  final Widget child;

  const StudentShellScaffold({super.key, required this.child});

  static const _navItems = [
    _NavItem(emoji: '🏠', label: 'Home', route: '/student/dashboard'),
    _NavItem(emoji: '📚', label: 'Courses', route: '/student/courses'),
    _NavItem(emoji: '📊', label: 'Results', route: '/student/results'),
    _NavItem(emoji: '🏆', label: 'Achieve', route: '/student/achievements'),
    _NavItem(emoji: '👤', label: 'Profile', route: '/student/profile'),
  ];

  int _selectedIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (location == _navItems[i].route) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selected = _selectedIndex(location);

    // ── Desktop / wide: NavigationRail on the left ──
    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            // Navigation rail
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: (index) {
                  context.go(_navItems[index].route);
                },
                extended: MediaQuery.sizeOf(context).width >= 1400,
                minWidth: 72,
                minExtendedWidth: 200,
                backgroundColor: Colors.transparent,
                indicatorColor: const Color(0xFFEEF2FF),
                selectedIconTheme: const IconThemeData(color: Color(0xFF4F46E5)),
                selectedLabelTextStyle: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
                unselectedLabelTextStyle: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('📖', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                destinations: _navItems.map((item) {
                  return NavigationRailDestination(
                    icon: Text(item.emoji, style: const TextStyle(fontSize: 20)),
                    selectedIcon: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                    label: Text(item.label),
                  );
                }).toList(),
              ),
            ),
            // Divider
            const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
            // Main content
            Expanded(child: child),
          ],
        ),
      );
    }

    // ── Mobile / tablet: bottom nav bar ──
    return Scaffold(
      body: child,
      bottomNavigationBar: const StudentBottomNav(),
    );
  }
}

class _NavItem {
  final String emoji;
  final String label;
  final String route;
  const _NavItem({required this.emoji, required this.label, required this.route});
}
