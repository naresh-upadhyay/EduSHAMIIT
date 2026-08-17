import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notice_provider.dart';

class NoticeTabsBar extends ConsumerWidget {
  final String userRole;

  const NoticeTabsBar({
    super.key,
    required this.userRole,
  });

  List<Map<String, String>> getTabsForRole(String role) {
    final r = role.toLowerCase();
    final isAdmin = r == 'super_admin' || r == 'admin' || r == 'principal' || r == 'vice_principal' || r == 'director';
    final isStaff = r == 'teacher' || r == 'class_teacher' || r == 'transport_manager' || r == 'accountant' || r == 'hr' || r == 'librarian';

    if (isAdmin) {
      return [
        {'id': 'all', 'label': 'All Notices'},
        {'id': 'my', 'label': 'My Notices'},
        {'id': 'school', 'label': 'School Notices'},
        {'id': 'department', 'label': 'Department Notices'},
        {'id': 'drafts', 'label': 'Drafts'},
        {'id': 'scheduled', 'label': 'Scheduled'},
        {'id': 'pending_approval', 'label': 'Pending Approval'},
        {'id': 'expired', 'label': 'Expired'},
        {'id': 'archived', 'label': 'Archived'},
      ];
    } else if (isStaff) {
      return [
        {'id': 'all', 'label': 'All Notices'},
        {'id': 'my', 'label': 'My Notices'},
        {'id': 'school', 'label': 'School Notices'},
        {'id': 'department', 'label': 'Department Notices'},
        {'id': 'drafts', 'label': 'Drafts'},
        {'id': 'scheduled', 'label': 'Scheduled'},
        {'id': 'pending_approval', 'label': 'Pending Approval'},
        {'id': 'expired', 'label': 'Expired'},
      ];
    } else {
      // Student / Parent
      return [
        {'id': 'all', 'label': 'All Notices'},
        {'id': 'school', 'label': 'School Notices'},
        {'id': 'department', 'label': 'Class / Grade'},
        {'id': 'expired', 'label': 'Past Notices'},
      ];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = getTabsForRole(userRole);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
            final isSelected = state.activeTab == tab['id'];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: InkWell(
                onTap: () => ref.read(noticeProvider.notifier).setTab(tab['id']!),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected && !isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tab['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
