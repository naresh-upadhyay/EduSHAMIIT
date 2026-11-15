import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';

class InventoryTabsBar extends ConsumerWidget {
  final ValueChanged<int>? onTabChanged;

  const InventoryTabsBar({super.key, this.onTabChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      const _TabItem(
        index: 0,
        label: 'Stock Overview',
        icon: Icons.inventory_2_outlined,
      ),
      const _TabItem(
        index: 1,
        label: 'Recent Transactions',
        icon: Icons.history_rounded,
      ),
      const _TabItem(
        index: 2,
        label: 'Purchase Orders',
        icon: Icons.shopping_cart_outlined,
      ),
      const _TabItem(
        index: 3,
        label: 'Sales Orders',
        icon: Icons.shopping_bag_outlined,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isActive = state.activeTab == tab.index;
            return InkWell(
              onTap: () {
                ref.read(inventoryProvider.notifier).setActiveTab(tab.index);
                onTabChanged?.call(tab.index);
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: isActive
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final int index;
  final String label;
  final IconData icon;

  const _TabItem({
    required this.index,
    required this.label,
    required this.icon,
  });
}
