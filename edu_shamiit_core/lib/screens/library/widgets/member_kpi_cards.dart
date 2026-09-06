import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/member_provider.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';

class MemberKpiCards extends ConsumerWidget {
  const MemberKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberProvider);
    final notifier = ref.read(memberProvider.notifier);
    final stats = state.stats;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);
    final formatter = NumberFormat('#,###');
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final cards = [
      _MemberKpiCardItem(
        label: 'Total Members',
        value: formatter.format(stats.totalMembers),
        subtitle: 'All library members',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF6366F1), // Royal Indigo / Purple
        filterStatus: 'Status: All',
        membershipFilter: 'Membership: All',
        isSelected: state.selectedStatus == 'Status: All' && state.selectedMembershipFilter == 'Membership: All',
      ),
      _MemberKpiCardItem(
        label: 'Active Members',
        value: formatter.format(stats.activeMembers),
        subtitle: 'Currently active',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF10B981), // Emerald
        filterStatus: 'ACTIVE',
        membershipFilter: 'Membership: All',
        isSelected: state.selectedStatus == 'ACTIVE',
      ),
      _MemberKpiCardItem(
        label: 'New This Month',
        value: formatter.format(stats.newThisMonth),
        subtitle: 'Newly registered',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF3B82F6), // Sky Blue
        filterStatus: 'Status: All',
        membershipFilter: 'Membership: All',
        isSelected: false,
      ),
      _MemberKpiCardItem(
        label: 'Members With Books',
        value: formatter.format(stats.membersWithBooks),
        subtitle: 'Currently issued',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFFF59E0B), // Amber / Gold
        filterStatus: 'Status: All',
        membershipFilter: 'HAS_ACTIVE_BOOKS',
        isSelected: state.selectedMembershipFilter == 'HAS_ACTIVE_BOOKS',
      ),
      _MemberKpiCardItem(
        label: 'Total Outstanding',
        value: currencyFormatter.format(stats.totalOutstandingFine),
        subtitle: 'Total unpaid fines',
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFFEF4444), // Coral Red
        filterStatus: 'Status: All',
        membershipFilter: 'HAS_FINES',
        isSelected: state.selectedMembershipFilter == 'HAS_FINES',
      ),
    ];


    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        20,
        isDesktop ? 28 : 16,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Desktop >= 960px: 5 cards in a single row
          if (width >= 960) {
            return Row(
              children: cards.map((item) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildCard(context, item, notifier, isDark),
                  ),
                );
              }).toList(),
            );
          }

          // Smaller screens: horizontal scroll
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards.map((item) {
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildCard(context, item, notifier, isDark),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    _MemberKpiCardItem item,
    MemberNotifier notifier,
    bool isDark,
  ) {
    final bgColor = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = item.isSelected
        ? item.color
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return InkWell(
      onTap: () {
        if (item.filterStatus != null) {
          notifier.setStatus(item.filterStatus!);
        }
        if (item.membershipFilter != null) {
          notifier.setMembershipFilter(item.membershipFilter!);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: item.isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: item.isSelected
                  ? item.color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Square
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Metrics (Value + Label + Subtitle)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberKpiCardItem {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? filterStatus;
  final String? membershipFilter;
  final bool isSelected;

  const _MemberKpiCardItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.filterStatus,
    this.membershipFilter,
    this.isSelected = false,
  });
}
