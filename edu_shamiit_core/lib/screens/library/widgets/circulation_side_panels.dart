import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circulation_models.dart';
import '../providers/circulation_provider.dart';

import 'dialogs/circulation_barcode_dialog.dart';

class CirculationQuickActionCards extends ConsumerWidget {
  const CirculationQuickActionCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Scan Barcode / ISBN Card
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
}
