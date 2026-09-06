import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/circulation_provider.dart';

class CirculationKpiCards extends ConsumerWidget {
  const CirculationKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    final stats = state.stats;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        18,
        isDesktop ? 28 : 16,
        14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          int crossAxisCount = 6;
          if (totalWidth < 650) {
            crossAxisCount = 2;
          } else if (totalWidth < 1050) {
            crossAxisCount = 3;
          } else if (totalWidth < 1450) {
            crossAxisCount = 6;
          } else {
            crossAxisCount = 7;
          }

          final cardWidth = (totalWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // 1. Total Issue / Return Transactions
              _buildMetricCard(
                title: 'Total Issue / Return',
                value: stats.totalTransactions.toString(),
                icon: Icons.all_inbox_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                isSelected: state.subtab == 'ALL',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab('ALL');
                },
              ),

              // 2. Books Issued Today
              _buildMetricCard(
                title: 'Books Issued Today',
                value: stats.booksIssuedToday.toString(),
                icon: Icons.assignment_turned_in_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: const Color(0xFF6366F1),
                isSelected: state.subtab == 'ISSUED_TODAY',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'ISSUED_TODAY' ? 'ALL' : 'ISSUED_TODAY');
                },
              ),

              // 3. Books Returned Today
              _buildMetricCard(
                title: 'Books Returned Today',
                value: stats.booksReturnedToday.toString(),
                icon: Icons.assignment_return_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF10B981),
                isSelected: state.subtab == 'RETURNED_TODAY',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'RETURNED_TODAY' ? 'ALL' : 'RETURNED_TODAY');
                },
              ),

              // 4. Currently Issued
              _buildMetricCard(
                title: 'Currently Issued',
                value: stats.currentlyIssued.toString(),
                icon: Icons.menu_book_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF3B82F6),
                isSelected: state.subtab == 'ISSUED',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'ISSUED' ? 'ALL' : 'ISSUED');
                },
              ),

              // 5. Overdue Books
              _buildMetricCard(
                title: 'Overdue Books',
                value: stats.overdueBooks.toString(),
                icon: Icons.warning_amber_rounded,
                iconBg: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFEF4444),
                isSelected: state.subtab == 'OVERDUE',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'OVERDUE' ? 'ALL' : 'OVERDUE');
                },
              ),

              // 6. Pending Requests
              _buildMetricCard(
                title: 'Pending Requests',
                value: stats.pendingRequests.toString(),
                icon: Icons.assignment_late_rounded,
                iconBg: const Color(0xFFFFFBEB),
                iconColor: const Color(0xFFF59E0B),
                isSelected: state.subtab == 'REQUESTS',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'REQUESTS' ? 'ALL' : 'REQUESTS');
                },
              ),

              // 7. Total Fines
              _buildMetricCard(
                title: 'Total Fines',
                value: stats.formattedTotalFines,
                icon: Icons.currency_rupee_rounded,
                iconBg: const Color(0xFFF5F3FF),
                iconColor: const Color(0xFF8B5CF6),
                isSelected: state.subtab == 'FINES',
                width: cardWidth,
                isDark: isDark,
                onTap: () {
                  notifier.setSubtab(state.subtab == 'FINES' ? 'ALL' : 'FINES');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isSelected,
    required double width,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),

              // Title & Value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
