import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_academic/app_router.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/constants/app_gradients.dart';
import 'package:edu_shamiit_academic/shared/widgets/student_bottom_nav.dart';
import 'package:edu_shamiit_core/widgets/ai_fab.dart';
import 'package:edu_shamiit_core/widgets/in_app_notification_overlay.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';

/// Shell scaffold that wraps all student screens.
/// On desktop (≥1100px) shows a full sidebar with all routes.
/// On mobile/tablet shows bottom nav with 5 key routes.
class StudentShellScaffold extends ConsumerWidget {
  final Widget child;
  final String? location;

  const StudentShellScaffold({super.key, required this.child, this.location});


  // Full sidebar items (desktop) — all routes with proper icons
  static const _sidebarItems = [
    _NavItem(
        icon: Icons.dashboard_rounded,
        emoji: '🏠',
        label: 'Dashboard',
        route: '/student/dashboard'),
    _NavItem(
        icon: Icons.menu_book_rounded,
        emoji: '📚',
        label: 'Courses',
        route: '/student/courses'),
    _NavItem(
        icon: Icons.schedule_rounded,
        emoji: '🗓️',
        label: 'Timetable',
        route: '/student/timetable'),
    _NavItem(
        icon: Icons.bar_chart_rounded,
        emoji: '📊',
        label: 'Results',
        route: '/student/results'),
    _NavItem(
        icon: Icons.assignment_rounded,
        emoji: '📝',
        label: 'Homework',
        route: '/student/homework'),
    _NavItem(
        icon: Icons.fact_check_rounded,
        emoji: '📋',
        label: 'Attendance',
        route: '/student/attendance'),
    _NavItem(
        icon: Icons.quiz_rounded,
        emoji: '✍️',
        label: 'Exams',
        route: '/student/exams'),
    _NavItem(
        icon: Icons.payment_rounded,
        emoji: '💳',
        label: 'Fees',
        route: '/student/fees'),
    _NavItem(
        icon: Icons.campaign_rounded,
        emoji: '📢',
        label: 'Notices',
        route: '/student/notices'),
    _NavItem(
        icon: Icons.local_library_rounded,
        emoji: '📖',
        label: 'Library',
        route: '/student/library'),
    _NavItem(
        icon: Icons.directions_bus_rounded,
        emoji: '🚌',
        label: 'Transport',
        route: '/student/transport'),

    _NavItem(
        icon: Icons.emoji_events_rounded,
        emoji: '🏆',
        label: 'Achievements',
        route: '/student/achievements'),
    _NavItem(
        icon: Icons.videocam_rounded,
        emoji: '🔴',
        label: 'Live Classes',
        route: '/student/live-classes'),
    _NavItem(
        icon: Icons.mail_rounded,
        emoji: '✉️',
        label: 'Leave',
        route: '/student/leave-application'),
    _NavItem(
        icon: Icons.chat_rounded,
        emoji: '💬',
        label: 'Messages',
        route: '/student/messaging'),
    _NavItem(
        icon: Icons.smart_toy_rounded,
        emoji: '🤖',
        label: 'AI Chat',
        route: '/student/ai-chat'),
    _NavItem(
        icon: Icons.folder_special_rounded,
        emoji: '📁',
        label: 'Documents',
        route: '/student/documents'),
    _NavItem(
        icon: Icons.person_rounded,
        emoji: '👤',
        label: 'Profile',
        route: '/student/profile'),
    _NavItem(
        icon: Icons.settings_rounded,
        emoji: '⚙️',
        label: 'Settings',
        route: '/student/settings'),
  ];

  int _selectedIndex(String location, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (location == items[i].route) return i;
    }
    final locPath = Uri.parse(location).path;
    final locSegments = Uri.parse(locPath).pathSegments;
    int bestMatchIndex = 0;
    int maxMatchedSegments = -1;
    for (int i = 0; i < items.length; i++) {
      final routePath = Uri.parse(items[i].route).path;
      final routeSegments = Uri.parse(routePath).pathSegments;
      if (routeSegments.length <= locSegments.length) {
        bool match = true;
        for (int j = 0; j < routeSegments.length; j++) {
          if (routeSegments[j] != locSegments[j]) {
            match = false;
            break;
          }
        }
        if (match && routeSegments.length > maxMatchedSegments) {
          maxMatchedSegments = routeSegments.length;
          bestMatchIndex = i;
        }
      }
    }
    return bestMatchIndex;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).userData?['id'] as String? ?? '';
    String currentLoc = location ?? '';
    if (currentLoc.isEmpty) {
      try {
        currentLoc = GoRouterState.of(context).uri.toString();
      } catch (_) {
        try {
          currentLoc = GoRouter.of(context).routeInformationProvider.value.uri.toString();
        } catch (_) {}
      }
    }

    // Don't wrap AI chat in SelectionArea — its streaming ListView
    // causes !debugNeedsLayout assertions in SelectableRegion.
    final isAiChat = currentLoc.contains('/ai-chat');
    final isMessaging = currentLoc.contains('/messaging');
    final isExam = currentLoc.contains('/student/exams');
    final pageChild = child;

    Widget shell;

    // ── Desktop / wide: Custom sidebar with all routes ──
    if (Responsive.isDesktop(context)) {
      final selected = _selectedIndex(currentLoc, _sidebarItems);
      final isExtended = MediaQuery.sizeOf(context).width >= 1200;

      shell = Scaffold(
        body: Row(
          children: [
            // Custom sidebar
            _DesktopSidebar(
              items: _sidebarItems,
              selectedIndex: selected,
              isExtended: isExtended,
              onItemTap: (item) {
                final shellNav = studentShellKey.currentState;
                if (shellNav != null) {
                  while (shellNav.canPop()) {
                    shellNav.pop();
                  }
                }
                context.go(item.route);
              },
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
            Expanded(child: pageChild),
          ],
        ),
        floatingActionButton: (isAiChat || isMessaging || isExam) ? null : AiFab(
          gradient: AppGradients.studentPrimary,
          onPressed: () => context.push('/student/ai-chat?from=${Uri.encodeComponent(currentLoc)}'),
        ),
      );
    } else {
      // ── Mobile / tablet: bottom nav bar ──
      shell = Scaffold(
        body: child,
        bottomNavigationBar: StudentBottomNav(currentLocation: currentLoc),
        floatingActionButton: (isAiChat || isMessaging || isExam) ? null : AiFab(
          gradient: AppGradients.studentPrimary,
          onPressed: () => context.push('/student/ai-chat?from=${Uri.encodeComponent(currentLoc)}'),
        ),
      );
    }

    if (userId.isEmpty) return shell;
    return InAppNotificationOverlay(
      userId: userId,
      userRole: 'student',
      child: shell,
    );
  }
}

/// A premium custom sidebar widget for desktop view.
class _DesktopSidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final bool isExtended;
  final void Function(_NavItem) onItemTap;

  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.isExtended,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExtended ? 220 : 72,
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
      child: Column(
        children: [
          // App logo / brand
          LayoutBuilder(
            builder: (context, constraints) {
              final canShowLabel = isExtended && constraints.maxWidth > 160;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    if (canShowLabel) ...[
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'EduSHAMIIT',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          // Nav items (scrollable)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return _SidebarItem(
                  item: item,
                  isSelected: isSelected,
                  isExtended: isExtended,
                  onTap: () => onItemTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool isExtended;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.isExtended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isExtended ? 14 : 0,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isExtended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFF94A3B8),
                ),
                if (isExtended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String emoji;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon,
      required this.emoji,
      required this.label,
      required this.route});
}
