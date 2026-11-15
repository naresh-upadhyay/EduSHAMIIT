import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';

class InventoryKpiCards extends ConsumerWidget {
  const InventoryKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final overview = state.overview;

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Prepare card definitions according to activeTab
    List<_KpiData> cards;
    if (state.activeTab == 2) {
      // TAB 2: Purchase Orders Tab
      int poTotalStatic = (state.poKPIs['total_pos'] as num?)?.toInt() ?? state.poTotal;
      int poDelivered = (state.poKPIs['completed_pos'] as num?)?.toInt() ?? 0;
      int poPending = (state.poKPIs['pending_pos'] as num?)?.toInt() ?? 0;
      double poSpend = (state.poKPIs['total_spend'] as num?)?.toDouble() ?? (state.overview?.totalPurchaseValue ?? 0.0);

      // Fallback to status distribution counts if KPIs wasn't fully populated
      if (poTotalStatic == 0 && state.poStatusDistribution.isNotEmpty) {
        double distSpend = 0.0;
        int distTotal = 0;
        int distDelivered = 0;
        int distPending = 0;
        for (final it in state.poStatusDistribution) {
          final st = (it['status'] as String? ?? '').toLowerCase();
          final cnt = (it['count'] as num?)?.toInt() ?? 0;
          final amt = (it['total_amount'] as num?)?.toDouble() ?? 0.0;
          distSpend += amt;
          distTotal += cnt;
          if (st.contains('deliv') || st.contains('receiv') || st.contains('complet')) {
            distDelivered += cnt;
          } else if (st.contains('pend') || st.contains('part') || st.contains('proc')) {
            distPending += cnt;
          }
        }
        poTotalStatic = distTotal;
        if (poSpend == 0.0) poSpend = distSpend;
        if (poDelivered == 0) poDelivered = distDelivered;
        if (poPending == 0) poPending = distPending;
      }

      if (poTotalStatic == 0) poTotalStatic = state.overview?.totalPurchaseOrders ?? 0;
      if (poSpend == 0.0) poSpend = state.overview?.totalPurchaseValue ?? 0.0;
      if (poDelivered == 0) poDelivered = state.overview?.dynamicTotalPurchaseOrders ?? 0;
      if (poPending == 0) poPending = state.overview?.pendingPurchaseOrders ?? 0;

      final isAllSelected = state.selectedPoStatus == null && state.poSearchQuery.isEmpty && state.selectedPoSupplierId == null;
      final isDeliveredSelected = state.selectedPoStatus != null && state.selectedPoStatus!.toLowerCase().contains('deliv');
      final isPendingSelected = state.selectedPoStatus != null && (state.selectedPoStatus!.toLowerCase().contains('pend') || state.selectedPoStatus!.toLowerCase().contains('part'));

      cards = [
        _KpiData(
          icon: Icons.shopping_bag_rounded,
          iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          title: 'Total Purchase Orders',
          value: '$poTotalStatic',
          badgeText: isAllSelected ? 'All POs' : 'All Orders',
          isPositive: true,
          isSelected: isAllSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setPoStatus(null);
            ref.read(inventoryProvider.notifier).setPoSearch('');
            ref.read(inventoryProvider.notifier).setPoSupplier(null);
          },
        ),
        _KpiData(
          icon: Icons.currency_rupee_rounded,
          iconBg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
          iconColor: const Color(0xFF9333EA),
          title: 'Total Purchase Value',
          value: currencyFmt.format(poSpend),
          badgeText: 'Spend',
          isPositive: true,
          isSelected: false,
          onTap: () {
            ref.read(inventoryProvider.notifier).setPoStatus(null);
          },
        ),
        _KpiData(
          icon: Icons.check_circle_rounded,
          iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'Delivered Orders',
          value: '$poDelivered',
          badgeText: 'Fulfilled',
          isPositive: true,
          isSelected: isDeliveredSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setPoStatus('Delivered');
          },
        ),
        _KpiData(
          icon: Icons.access_time_filled_rounded,
          iconBg: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          title: 'Pending Orders',
          value: '$poPending',
          badgeText: 'Pending',
          isPositive: false,
          isSelected: isPendingSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setPoStatus('Pending');
          },
        ),
      ];
    } else if (state.activeTab == 3) {
      // TAB 3: Sales Orders Tab
      int soTotalStatic = (state.soKPIs['total_orders'] as num?)?.toInt() ?? state.soTotal;
      int soDelivered = (state.soKPIs['completed_orders'] as num?)?.toInt() ?? 0;
      int soPending = (state.soKPIs['pending_orders'] as num?)?.toInt() ?? 0;
      double soRev = (state.soKPIs['total_sales_value'] as num?)?.toDouble() ?? (state.overview?.totalSalesValue ?? 0.0);

      if (soTotalStatic == 0 && state.soStatusDistribution.isNotEmpty) {
        double distRev = 0.0;
        int distTotal = 0;
        int distDelivered = 0;
        int distPending = 0;
        for (final it in state.soStatusDistribution) {
          final st = (it['status'] as String? ?? '').toLowerCase();
          final cnt = (it['count'] as num?)?.toInt() ?? 0;
          final amt = (it['total_amount'] as num?)?.toDouble() ?? 0.0;
          distRev += amt;
          distTotal += cnt;
          if (st.contains('deliv') || st.contains('complet')) {
            distDelivered += cnt;
          } else if (st.contains('pend') || st.contains('proc')) {
            distPending += cnt;
          }
        }
        soTotalStatic = distTotal;
        if (soRev == 0.0) soRev = distRev;
        if (soDelivered == 0) soDelivered = distDelivered;
        if (soPending == 0) soPending = distPending;
      }

      if (soTotalStatic == 0) soTotalStatic = state.overview?.totalSalesOrders ?? 0;
      if (soRev == 0.0) soRev = state.overview?.totalSalesValue ?? 0.0;
      if (soDelivered == 0) soDelivered = state.overview?.completedSalesOrders ?? 0;
      if (soPending == 0) soPending = state.overview?.pendingSalesOrders ?? 0;

      final isAllSelected = state.selectedSoStatus == null && state.soSearchQuery.isEmpty && state.selectedSoCustomerId == null;
      final isDeliveredSelected = state.selectedSoStatus != null && state.selectedSoStatus!.toLowerCase().contains('deliv');
      final isPendingSelected = state.selectedSoStatus != null && (state.selectedSoStatus!.toLowerCase().contains('pend') || state.selectedSoStatus!.toLowerCase().contains('proc'));

      cards = [
        _KpiData(
          icon: Icons.shopping_cart_rounded,
          iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          title: 'Total Sales Orders',
          value: '$soTotalStatic',
          badgeText: isAllSelected ? 'All SOs' : 'All Orders',
          isPositive: true,
          isSelected: isAllSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setSoStatus(null);
            ref.read(inventoryProvider.notifier).setSoSearch('');
            ref.read(inventoryProvider.notifier).setSoCustomer(null);
          },
        ),
        _KpiData(
          icon: Icons.currency_rupee_rounded,
          iconBg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
          iconColor: const Color(0xFF9333EA),
          title: 'Total Sales Revenue',
          value: currencyFmt.format(soRev),
          badgeText: 'Revenue',
          isPositive: true,
          isSelected: false,
          onTap: () {
            ref.read(inventoryProvider.notifier).setSoStatus(null);
          },
        ),
        _KpiData(
          icon: Icons.check_circle_rounded,
          iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'Completed Orders',
          value: '$soDelivered',
          badgeText: 'Fulfilled',
          isPositive: true,
          isSelected: isDeliveredSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setSoStatus('Delivered');
          },
        ),
        _KpiData(
          icon: Icons.access_time_filled_rounded,
          iconBg: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          title: 'Pending Orders',
          value: '$soPending',
          badgeText: 'Pending',
          isPositive: false,
          isSelected: isPendingSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setSoStatus('Pending');
          },
        ),
      ];
    } else if (state.activeTab == 1) {
      // TAB 1: Recent Transactions Tab
      int txInflow = 0;
      int txOutflow = 0;
      int txAdjust = 0;
      int txTotalStatic = 0;

      for (final it in state.txTypeDistribution) {
        final t = (it['type'] as String? ?? '').toLowerCase();
        final cnt = (it['count'] as num?)?.toInt() ?? 0;
        txTotalStatic += cnt;
        if (t.contains('in') || t.contains('purch')) {
          txInflow += cnt;
        } else if (t.contains('out') || t.contains('sale')) {
          txOutflow += cnt;
        } else if (t.contains('adjust') || t.contains('transfer')) {
          txAdjust += cnt;
        }
      }
      if (txTotalStatic == 0) txTotalStatic = state.transactionsTotal;

      final isAllSelected = state.selectedTxType == null && state.txSearchQuery.isEmpty && state.selectedTxItemId == null && state.selectedTxStoreId == null;
      final isInflowSelected = state.selectedTxType != null && (state.selectedTxType!.toLowerCase().contains('in') || state.selectedTxType!.toLowerCase().contains('purch'));
      final isOutflowSelected = state.selectedTxType != null && (state.selectedTxType!.toLowerCase().contains('out') || state.selectedTxType!.toLowerCase().contains('sale'));
      final isAdjustSelected = state.selectedTxType != null && (state.selectedTxType!.toLowerCase().contains('adjust') || state.selectedTxType!.toLowerCase().contains('transfer'));

      cards = [
        _KpiData(
          icon: Icons.swap_horiz_rounded,
          iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          title: 'Total Movements',
          value: '$txTotalStatic',
          badgeText: 'All Events',
          isPositive: true,
          isSelected: isAllSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setTxType(null);
            ref.read(inventoryProvider.notifier).setTxSearch('');
            ref.read(inventoryProvider.notifier).setTxStore(null);
          },
        ),
        _KpiData(
          icon: Icons.arrow_downward_rounded,
          iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'Inflow Events',
          value: '$txInflow',
          badgeText: 'Stock In',
          isPositive: true,
          isSelected: isInflowSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setTxType('Purchase');
          },
        ),
        _KpiData(
          icon: Icons.arrow_upward_rounded,
          iconBg: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          title: 'Outflow Events',
          value: '$txOutflow',
          badgeText: 'Stock Out',
          isPositive: false,
          isSelected: isOutflowSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setTxType('Sale');
          },
        ),
        _KpiData(
          icon: Icons.tune_rounded,
          iconBg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
          iconColor: const Color(0xFF9333EA),
          title: 'Stock Adjustments',
          value: '$txAdjust',
          badgeText: 'Audits',
          isPositive: true,
          isSelected: isAdjustSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setTxType('Stock Adjustment');
          },
        ),
      ];
    } else {
      // TAB 0: Stock Overview / Items Tab
      final isAllSelected = state.selectedStatus == null && state.itemSearchQuery.isEmpty && state.selectedCategory == null && state.selectedStoreId == null;
      final isLowSelected = state.selectedStatus != null && (state.selectedStatus!.toLowerCase().contains('low') || state.selectedStatus!.toLowerCase().contains('out'));
      final totalItemsStatic = overview?.totalItems ?? state.itemsTotal;
      final totalStockVal = overview?.totalStockValue ?? 0.0;
      final pendingPurchVal = overview?.pendingPurchaseValue ?? 0.0;
      final lowStockCount = overview?.lowStockItems ?? 0;

      cards = [
        _KpiData(
          icon: Icons.inventory_2_rounded,
          iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          title: 'Total Items',
          value: '$totalItemsStatic',
          badgeText: isAllSelected ? 'All Items' : 'Active Catalog',
          isPositive: true,
          isSelected: isAllSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setItemStatus(null);
            ref.read(inventoryProvider.notifier).setItemCategory(null);
            ref.read(inventoryProvider.notifier).setItemStore(null);
            ref.read(inventoryProvider.notifier).setItemSearch('');
          },
        ),
        _KpiData(
          icon: Icons.currency_rupee_rounded,
          iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          title: 'Total Stock Value',
          value: currencyFmt.format(totalStockVal),
          badgeText: 'Valuation',
          isPositive: true,
          isSelected: false,
          onTap: () {
            ref.read(inventoryProvider.notifier).loadOverview();
          },
        ),
        _KpiData(
          icon: Icons.shopping_cart_rounded,
          iconBg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFFAF5FF),
          iconColor: const Color(0xFF9333EA),
          title: 'Pending Purchase',
          value: currencyFmt.format(pendingPurchVal),
          badgeText: 'Backlog',
          isPositive: true,
          isSelected: false,
          onTap: () {
            ref.read(inventoryProvider.notifier).setActiveTab(2);
            ref.read(inventoryProvider.notifier).setPoStatus('Pending');
          },
        ),
        _KpiData(
          icon: Icons.warning_amber_rounded,
          iconBg: isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.4) : const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          title: 'Low Stock Items',
          value: '$lowStockCount',
          badgeText: lowStockCount > 0 ? 'Needs Reorder' : 'Healthy',
          isPositive: false,
          isSelected: isLowSelected,
          onTap: () {
            ref.read(inventoryProvider.notifier).setItemStatus('LOW_STOCK');
          },
        ),
      ];
    }

    if (screenWidth < 640) {
      // Mobile 1 column
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildCard(c, isDark),
                ))
            .toList(),
      );
    } else if (screenWidth < 1100) {
      // Tablet 2 columns
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildCard(cards[0], isDark)),
              const SizedBox(width: 14),
              Expanded(child: _buildCard(cards[1], isDark)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildCard(cards[2], isDark)),
              const SizedBox(width: 14),
              Expanded(child: _buildCard(cards[3], isDark)),
            ],
          ),
        ],
      );
    }

    // Desktop 4 columns
    return Row(
      children: [
        Expanded(child: _buildCard(cards[0], isDark)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(cards[1], isDark)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(cards[2], isDark)),
        const SizedBox(width: 16),
        Expanded(child: _buildCard(cards[3], isDark)),
      ],
    );
  }

  Widget _buildCard(_KpiData card, bool isDark) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: card.onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: card.iconColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: card.isSelected
                  ? card.iconColor
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: card.isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: card.isSelected
                    ? card.iconColor.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: card.isSelected ? 12 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Square Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: card.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  card.icon,
                  color: card.iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            card.value,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              fontFamily: 'Inter',
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Percentage / status badge chip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: card.isPositive
                                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                                : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card.badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: card.isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
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

class _KpiData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String value;
  final String badgeText;
  final bool isPositive;
  final bool isSelected;
  final VoidCallback? onTap;

  _KpiData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.badgeText,
    required this.isPositive,
    this.isSelected = false,
    this.onTap,
  });
}
