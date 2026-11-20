import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/space_booking_provider.dart';

class SpaceBookingLegendBarWidget extends ConsumerWidget {
  const SpaceBookingLegendBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPurpose = ref.watch(spaceBookingProvider).selectedPurpose;
    final notifier = ref.read(spaceBookingProvider.notifier);

    final badges = [
      _LegendItem(label: 'All', color: isDark ? Colors.white : const Color(0xFF0F172A)),
      _LegendItem(label: 'Academic', color: const Color(0xFF3B82F6)),
      _LegendItem(label: 'Practical / Lab', color: const Color(0xFF8B5CF6)),
      _LegendItem(label: 'Meeting', color: const Color(0xFF10B981)),
      _LegendItem(label: 'Workshop', color: const Color(0xFFF59E0B)),
      _LegendItem(label: 'Exam Setup', color: const Color(0xFFF43F5E)),
      _LegendItem(label: 'Club / Cultural', color: const Color(0xFF06B6D4)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: badges.map((b) {
            final isSelected = selectedPurpose == b.label ||
                (b.label == 'All' && (selectedPurpose.isEmpty || selectedPurpose == 'All'));
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => notifier.setPurposeFilter(b.label == 'All' ? 'All' : b.label),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? b.color.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? b.color : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: b.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        b.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : b.color)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
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

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem({required this.label, required this.color});
}
