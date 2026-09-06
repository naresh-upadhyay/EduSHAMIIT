import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circulation_models.dart';
import '../providers/circulation_provider.dart';

import 'dialogs/quick_issue_dialog.dart';
import 'dialogs/quick_return_dialog.dart';
import 'dialogs/renew_book_dialog.dart';
import 'dialogs/requests_management_dialog.dart';
import 'dialogs/fine_collection_dialog.dart';
import 'dialogs/circulation_barcode_dialog.dart';

class CirculationQuickActionCards extends ConsumerWidget {
  const CirculationQuickActionCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circulationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 1. Raise Issue Request Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raise Issue Request',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Members can request books. Librarian can approve or reject.',
                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.assignment_outlined, size: 15, color: Color(0xFF6366F1)),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('View Requests', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                    if (state.stats.pendingRequests > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          state.stats.pendingRequests.toString(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const RequestsManagementDialog());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Scan Barcode / ISBN Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan Barcode / ISBN',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Scan a book barcode or ISBN to issue/return quickly.',
                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 15, color: Color(0xFF6366F1)),
                label: const Text('Scan Barcode / ISBN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showDialog(context: context, builder: (_) => const CirculationBarcodeDialog());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CirculationRightPanel extends ConsumerWidget {
  const CirculationRightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Today's Activity Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Activity",
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  InkWell(
                    onTap: () => notifier.fetchActivities(),
                    child: const Text('View All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.activityFeed.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text('No circulation activity today yet.', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                  ),
                )
              else
                Column(
                  children: state.activityFeed.take(5).map((act) => _buildActivityRow(act, isDark)).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Overdue Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overdue Summary',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  InkWell(
                    onTap: () => notifier.setSubtab('OVERDUE'),
                    child: const Text('View All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.overdueSummary.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No overdue items.', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)))),
                )
              else
                Column(
                  children: state.overdueSummary.map((item) {
                    return InkWell(
                      onTap: () => notifier.setSubtab('OVERDUE'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 85,
                              child: Text(
                                item.bracket,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),

                            Expanded(
                              child: Text('${item.booksCount} Books', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ),
                            Text(item.formattedFines, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Quick Actions Grid (6 Tiles)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    label: 'Issue Book',
                    color: const Color(0xFF6366F1),
                    onTap: () => showDialog(context: context, builder: (_) => const QuickIssueDialog()),
                    isDark: isDark,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.keyboard_return_rounded,
                    label: 'Return Book',
                    color: const Color(0xFF10B981),
                    onTap: () => showDialog(context: context, builder: (_) => const QuickReturnDialog()),
                    isDark: isDark,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.autorenew_rounded,
                    label: 'Renew Book',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => showDialog(context: context, builder: (_) => const RenewBookDialog()),
                    isDark: isDark,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.assignment_late_outlined,
                    label: 'Pending Requests',
                    color: const Color(0xFFF59E0B),
                    badge: state.stats.pendingRequests > 0 ? state.stats.pendingRequests.toString() : null,
                    onTap: () => showDialog(context: context, builder: (_) => const RequestsManagementDialog()),
                    isDark: isDark,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.currency_rupee_rounded,
                    label: 'Fine Collection',
                    color: const Color(0xFFEF4444),
                    onTap: () => showDialog(context: context, builder: (_) => const FineCollectionDialog()),
                    isDark: isDark,
                  ),
                  _buildQuickActionTile(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    label: 'Print Receipt',
                    color: const Color(0xFF3B82F6),
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(CirculationActivityModel act, bool isDark) {
    IconData icon = Icons.info_outline_rounded;
    Color iconColor = const Color(0xFF6366F1);

    if (act.activityType == 'ISSUE') {
      icon = Icons.menu_book_rounded;
      iconColor = const Color(0xFF6366F1);
    } else if (act.activityType == 'RETURN') {
      icon = Icons.keyboard_return_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (act.activityType == 'RENEW') {
      icon = Icons.autorenew_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (act.activityType.contains('REQUEST')) {
      icon = Icons.assignment_outlined;
      iconColor = const Color(0xFFF59E0B);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.title,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                if (act.description != null)
                  Text(
                    act.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            act.timeAgo,
            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    String? badge,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
