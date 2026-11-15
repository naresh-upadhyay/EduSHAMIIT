import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/tab_url_sync.dart';
import '../providers/visitors_provider.dart';
import 'dialogs/visitor_schedule_dialog.dart';
import 'dialogs/visitor_restriction_dialog.dart';
import 'dialogs/visitor_profiles_gate_pass_dialog.dart';
import 'dialogs/visitor_qr_scanner_dialog.dart';
import 'dialogs/visitor_date_range_dialog.dart';

class VisitorsHeaderBar extends ConsumerWidget {
  final bool isEmbedded;
  const VisitorsHeaderBar({super.key, this.isEmbedded = false});

  static const List<Map<String, dynamic>> _tabs = [
    {'name': 'All Visitors', 'icon': Icons.groups_rounded},
    {'name': 'Scheduled Visitors', 'icon': Icons.event_available_rounded},
    {'name': 'Blacklisted Visitors', 'icon': Icons.block_rounded},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        return Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 16 : 24,
            isEmbedded ? 8 : (isNarrow ? 14 : 20),
            isNarrow ? 16 : 24,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isEmbedded) ...[
                // Top Row: Icon, Title, Subtitle, Date Range Dropdown
                if (isNarrow) ...[
                  // Narrow: Stack vertically
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Visitors Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage visitors across all institute locations like Main Gate, Library, Lab, Hostel, Office etc.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => showVisitorDateRangeDialog(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.selectedDateRange,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Wide: Single row
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
                        Icons.groups_rounded,
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
                            'Visitors Management',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Manage visitors across all institute locations like Main Gate, Library, Lab, Hostel, Office etc.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Academic / Date Range Dropdown Button
                    InkWell(
                      onTap: () => showVisitorDateRangeDialog(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
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
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.selectedDateRange,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isEmbedded) SizedBox(height: isNarrow ? 12 : 18),
            ],
              // 3 Primary Tabs + Top-Right Action Button matching Route Management styling
              if (constraints.maxWidth < 980) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = state.activeTab == index;
                        final item = _tabs[index];
                        return InkWell(
                          onTap: () {
                            notifier.setActiveTab(index);
                            updateTabUrl('/admin/visitors', index);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item['icon'] as IconData,
                                  size: 14,
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  item['name'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
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
                if (state.activeTab == 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const VisitorProfilesGatePassDialog(),
                            );
                          },
                          icon: const Icon(Icons.badge_outlined, size: 15),
                          label: const Flexible(
                            child: Text(
                              'Profiles & Pass',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const VisitorQrScannerDialog(),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                          label: const Flexible(
                            child: Text(
                              'Scan QR Pass',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: Colors.white),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else if (state.activeTab == 1 || state.activeTab == 2) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (state.activeTab == 1) {
                          showDialog(
                            context: context,
                            builder: (ctx) => const VisitorScheduleDialog(),
                          );
                        } else if (state.activeTab == 2) {
                          showDialog(
                            context: context,
                            builder: (ctx) => const VisitorRestrictionDialog(),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                      label: Text(
                        state.activeTab == 1
                            ? 'Schedule Visitor'
                            : 'Add to Blocklist',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Floating Tabs row in 48px rounded container
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_tabs.length, (index) {
                          final isSelected = state.activeTab == index;
                          final item = _tabs[index];
                          return InkWell(
                            onTap: () {
                              notifier.setActiveTab(index);
                              updateTabUrl('/admin/visitors', index);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 15,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
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
                    if (state.activeTab == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => const VisitorProfilesGatePassDialog(),
                                );
                              },
                              icon: const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF2563EB)),
                              label: const Text(
                                'Visitor Profiles & Pass',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 10 : 13,
                                  vertical: isNarrow ? 9 : 11,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => const VisitorQrScannerDialog(),
                                );
                              },
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                'Scan QR Pass',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 10 : 13,
                                  vertical: isNarrow ? 9 : 11,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (state.activeTab == 1 || state.activeTab == 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (state.activeTab == 1) {
                              showDialog(
                                context: context,
                                builder: (ctx) => const VisitorScheduleDialog(),
                              );
                            } else if (state.activeTab == 2) {
                              showDialog(
                                context: context,
                                builder: (ctx) => const VisitorRestrictionDialog(),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                          label: Text(
                            state.activeTab == 1
                                ? 'Schedule Visitor'
                            : 'Add to Blocklist',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 12 : 16,
                          vertical: isNarrow ? 9 : 11,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ],
          ),
        );
      },
    );
  }
}
