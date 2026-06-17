import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/app_router.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/shared/widgets/teacher_bottom_nav.dart';
import 'package:edu_shamiit_ai/shared/widgets/ai_fab.dart';
import 'package:edu_shamiit_ai/shared/widgets/in_app_notification_overlay.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';

/// Shell scaffold that wraps all teacher screens.
/// On desktop (≥1100px) shows a full sidebar with all routes.
/// On mobile/tablet shows bottom nav with 5 key routes.
class TeacherShellScaffold extends ConsumerWidget {
  final Widget child;
  final String? location;

  const TeacherShellScaffold({super.key, required this.child, this.location});

  // Full sidebar items (desktop) — all teacher routes
  static const _sidebarItems = [
    _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/teacher/dashboard'),
    _NavItem(
        icon: Icons.class_rounded,
        label: 'My Classes',
        route: '/teacher/my-classes'),
    _NavItem(
        icon: Icons.schedule_rounded,
        label: 'Timetable',
        route: '/teacher/timetable'),
    _NavItem(
        icon: Icons.fact_check_rounded,
        label: 'Attendance',
        route: '/teacher/attendance'),
    _NavItem(
        icon: Icons.assignment_rounded,
        label: 'Homework',
        route: '/teacher/homework'),
    _NavItem(
        icon: Icons.grading_rounded,
        label: 'Gradebook',
        route: '/teacher/gradebook'),
    _NavItem(
        icon: Icons.rate_review_rounded,
        label: 'Grading',
        route: '/teacher/grading'),
    _NavItem(icon: Icons.quiz_rounded, label: 'Exams', route: '/teacher/exams'),
    _NavItem(
        icon: Icons.upload_file_rounded,
        label: 'Submissions',
        route: '/teacher/submissions'),
    _NavItem(
        icon: Icons.campaign_rounded,
        label: 'Notices',
        route: '/teacher/notices'),
    _NavItem(
        icon: Icons.videocam_rounded,
        label: 'Live Classes',
        route: '/teacher/live-classes'),

    _NavItem(
        icon: Icons.people_rounded,
        label: 'Students',
        route: '/teacher/student-directory'),
    _NavItem(icon: Icons.mail_rounded, label: 'Leave', route: '/teacher/leave'),
    _NavItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Salary',
        route: '/teacher/salary'),
    _NavItem(
        icon: Icons.smart_toy_rounded,
        label: 'AI Chat',
        route: '/teacher/ai-chat'),
    _NavItem(
        icon: Icons.folder_special_rounded,
        label: 'Documents',
        route: '/teacher/documents'),
    _NavItem(
        icon: Icons.chat_bubble_rounded,
        label: 'Messages',
        route: '/teacher/messaging'),
    _NavItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        route: '/teacher/profile'),
    _NavItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: '/teacher/settings'),
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
    final isAiChat = currentLoc.endsWith('/ai-chat');
    final isMessaging = currentLoc.contains('/messaging');
    final pageChild = child;

    Widget shell;

    // ── Desktop / wide: Custom sidebar with all routes ──
    if (Responsive.isDesktop(context)) {
      final selected = _selectedIndex(currentLoc, _sidebarItems);
      final isExtended = MediaQuery.sizeOf(context).width >= 1200;

      shell = Scaffold(
        body: Row(
          children: [
            _TeacherSidebar(
              items: _sidebarItems,
              selectedIndex: selected,
              isExtended: isExtended,
              onItemTap: (item) {
                final shellNav = teacherShellKey.currentState;
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
        floatingActionButton: (isAiChat || isMessaging) ? null : AiFab(
          gradient: AppGradients.studentPrimary,
          onPressed: () => context.push('/teacher/ai-chat'),
        ),
      );
    } else {
      // ── Mobile / tablet: bottom nav bar ──
      shell = Scaffold(
        body: child,
        bottomNavigationBar: TeacherBottomNav(currentLocation: currentLoc),
        floatingActionButton: (isAiChat || isMessaging) ? null : AiFab(
          gradient: AppGradients.studentPrimary,
          onPressed: () => context.push('/teacher/ai-chat'),
        ),
      );
    }

    if (userId.isEmpty) return shell;
    return InAppNotificationOverlay(
      userId: userId,
      userRole: 'teacher',
      child: shell,
    );
  }
}

class _TeacherSidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final bool isExtended;
  final void Function(_NavItem) onItemTap;

  const _TeacherSidebar({
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
        color: StudentColors.surface,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Row(
              mainAxisAlignment: isExtended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('👨‍🏫', style: TextStyle(fontSize: 20)),
                  ),
                ),
                if (isExtended) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'Teacher Portal',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onItemTap(item),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: isExtended ? 14 : 0,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEEF2FF)
                              : Colors.transparent,
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
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(
      {required this.icon, required this.label, required this.route});
}
