import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lookup_provider.dart';

class LookupTabsBar extends ConsumerWidget {
  const LookupTabsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lookupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedTab = state.selectedTab;

    final tabs = [
      {'id': 'all', 'label': 'All Lookup Keys'},
      {'id': 'active', 'label': 'Active'},
      {'id': 'inactive', 'label': 'Inactive'},
      {'id': 'system', 'label': 'System Keys'},
      {'id': 'custom', 'label': 'Custom Keys'},
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = selectedTab == tab['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 20),
              child: InkWell(
                onTap: () => ref.read(lookupProvider.notifier).setTab(tab['id']!),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tab['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF4F46E5)
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
