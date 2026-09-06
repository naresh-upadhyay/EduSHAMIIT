import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/request_provider.dart';

class RequestKpiCards extends ConsumerWidget {
  const RequestKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final kpis = state.kpis;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        18,
        isDesktop ? 28 : 16,
        14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isNarrow = width < 900;
          final isMobile = width < 600;

          int crossAxisCount = 6;
          if (isMobile) {
            crossAxisCount = 2;
          } else if (isNarrow) {
            crossAxisCount = 3;
          }

          final cardWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard(
                title: 'Total Requests',
                value: kpis.totalRequests,
                icon: Icons.all_inbox_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                isSelected: state.selectedStatus == 'ALL',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('ALL'),
              ),
              _buildMetricCard(
                title: 'New Requests',
                value: kpis.newRequests,
                icon: Icons.mark_email_unread_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF2563EB),
                isSelected: state.selectedStatus == 'NEW',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('NEW'),
              ),
              _buildMetricCard(
                title: 'In Progress',
                value: kpis.inProgress,
                icon: Icons.autorenew_rounded,
                iconBg: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF16A34A),
                isSelected: state.selectedStatus == 'IN_PROGRESS',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('IN_PROGRESS'),
              ),
              _buildMetricCard(
                title: 'Resolved',
                value: kpis.resolved,
                icon: Icons.check_circle_outline_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                isSelected: state.selectedStatus == 'RESOLVED',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('RESOLVED'),
              ),
              _buildMetricCard(
                title: 'Rejected',
                value: kpis.rejected,
                icon: Icons.cancel_outlined,
                iconBg: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFDC2626),
                isSelected: state.selectedStatus == 'REJECTED',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('REJECTED'),
              ),
              _buildMetricCard(
                title: 'Cancelled',
                value: kpis.cancelled,
                icon: Icons.remove_circle_outline_rounded,
                iconBg: const Color(0xFFF8FAFC),
                iconColor: const Color(0xFF64748B),
                isSelected: state.selectedStatus == 'CANCELED',
                width: cardWidth,
                isDark: isDark,
                onTap: () => notifier.setStatusFilter('CANCELED'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int value,
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
                      value.toString(),
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
