import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';

class InventoryHeaderBar extends ConsumerWidget {
  final VoidCallback? onNewPurchase;
  final VoidCallback? onCreatePO;
  final VoidCallback? onCreateSO;
  final VoidCallback? onReceiveStock;
  final VoidCallback? onIssueStock;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onTransferStock;

  const InventoryHeaderBar({
    super.key,
    this.onNewPurchase,
    this.onCreatePO,
    this.onCreateSO,
    this.onReceiveStock,
    this.onIssueStock,
    this.onAdjustStock,
    this.onTransferStock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Global Search & User Profile Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              // Search input
              Expanded(
                child: Container(
                  height: 40,
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    onChanged: (val) {
                      if (state.activeTab == 0) {
                        ref.read(inventoryProvider.notifier).setItemSearch(val);
                      } else if (state.activeTab == 1) {
                        ref.read(inventoryProvider.notifier).setTxSearch(val);
                      } else if (state.activeTab == 2) {
                        ref.read(inventoryProvider.notifier).setPoSearch(val);
                      } else {
                        ref.read(inventoryProvider.notifier).setSoSearch(val);
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      hintText: 'Search items, suppliers, or purchase orders...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontFamily: 'Inter',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Right action icons
              if (!isCompact) ...[
                IconButton(
                  icon: const Icon(Icons.campaign_outlined, size: 22),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  onPressed: () {},
                  tooltip: 'Announcements',
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, size: 22),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      onPressed: () {},
                      tooltip: 'Notifications',
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '3',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, size: 22),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  onPressed: () {},
                  tooltip: 'Help',
                ),
                const SizedBox(width: 8),
              ],

              // User Profile Avatar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF2563EB),
                      child: Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            'Greenwood High School',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Module Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          child: Row(
            children: [
              // 3D Box Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        fontFamily: 'Inter',
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Manage stock, purchases, sales and inventory across the institute',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),

              // Contextual Action Button matching screenshots
              _buildActionButton(context, state.activeTab),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, int activeTab) {
    if (activeTab == 2) {
      // Tab 3: Purchase Orders
      return ElevatedButton.icon(
        onPressed: onCreatePO,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text(
          'Create Purchase Order',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else if (activeTab == 3) {
      // Tab 4: Sales Orders
      return ElevatedButton.icon(
        onPressed: onCreateSO,
        icon: const Icon(Icons.add, size: 18, color: Colors.white),
        label: const Text(
          'Create Sales Order',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      );
    } else {
      // Tab 1 & 2: + New Purchase with PopupMenu for quick actions
      return PopupMenuButton<String>(
        onSelected: (val) {
          if (val == 'new_po') onNewPurchase?.call();
          if (val == 'receive') onReceiveStock?.call();
          if (val == 'issue') onIssueStock?.call();
          if (val == 'adjust') onAdjustStock?.call();
          if (val == 'transfer') onTransferStock?.call();
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'new_po',
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 18, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('New Purchase Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'receive',
            child: Row(
              children: [
                Icon(Icons.archive_outlined, size: 18, color: Color(0xFF10B981)),
                SizedBox(width: 10),
                Text('Receive Direct Stock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'issue',
            child: Row(
              children: [
                Icon(Icons.unarchive_outlined, size: 18, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Text('Issue Stock to Dept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'transfer',
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF8B5CF6)),
                SizedBox(width: 10),
                Text('Inter-Store Transfer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'adjust',
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text('Stock Adjustment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 17, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'New Purchase',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
            ],
          ),
        ),
      );
    }
  }
}
