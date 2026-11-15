import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/tab_url_sync.dart';
import '../providers/hostel_provider.dart';

class HostelHeaderBar extends ConsumerWidget {
  const HostelHeaderBar({super.key});

  static const List<Map<String, dynamic>> _tabs = [
    {'title': 'Overview', 'icon': Icons.grid_view_outlined},
    {'title': 'Rooms & Allocation', 'icon': Icons.meeting_room_outlined},
    {'title': 'Hostel Students', 'icon': Icons.school_outlined},
    {'title': 'Staff Management', 'icon': Icons.badge_outlined},
    {'title': 'Fees & Billing', 'icon': Icons.receipt_long_outlined},
    {'title': 'Leave & Outing', 'icon': Icons.exit_to_app_rounded},
    {'title': 'Complaints', 'icon': Icons.report_problem_outlined},
    {'title': 'Visitors', 'icon': Icons.person_pin_circle_outlined},
    {'title': 'Reports', 'icon': Icons.assessment_outlined},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rawYears = [
      state.selectedAcademicYear,
      ...state.availableAcademicYears,
    ];
    final availableYears = <String>[];
    for (final y in rawYears) {
      final trimmed = y.trim();
      if (trimmed.isNotEmpty && !availableYears.contains(trimmed)) {
        availableYears.add(trimmed);
      }
    }
    if (availableYears.isEmpty) {
      availableYears.add('2026 - 2027');
    }
    final selectedYear = availableYears.contains(state.selectedAcademicYear.trim())
        ? state.selectedAcademicYear.trim()
        : availableYears.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;
        return Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, isMobile ? 12 : 20, isMobile ? 14 : 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title, Subtitle, Academic Year Dropdown
              if (isMobile) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hostel Management',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hostel facilities & daily operations',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedYear,
                            isDense: true,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                            items: availableYears
                                .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) notifier.selectAcademicYear(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hostel Management',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Manage hostel facilities, rooms, students, staff, and daily operations',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedYear,
                              isDense: true,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              items: availableYears
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) notifier.selectAcademicYear(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Primary Tabs Bar matching Route Management style
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = state.activeTab == index;
                        final t = _tabs[index];
                        final title = t['title'] as String;
                        final icon = t['icon'] as IconData;

                        return InkWell(
                          onTap: () {
                            notifier.selectTab(index);
                            updateTabUrl('/admin/hostel', index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.08)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
        ],
      ),
    );
      },
    );
  }
}
