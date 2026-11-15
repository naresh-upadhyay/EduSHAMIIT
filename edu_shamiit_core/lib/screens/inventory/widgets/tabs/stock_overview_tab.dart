import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../../services/inventory_api_service.dart';

class StockOverviewTab extends ConsumerStatefulWidget {
  final Function(InventoryItem item)? onEditItem;
  final Function(InventoryItem item)? onViewItem;
  final VoidCallback? onNewPurchase;
  final VoidCallback? onAddStock;
  final VoidCallback? onIssueStock;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onTransferStock;
  final VoidCallback? onViewAllActivities;
  final VoidCallback? onViewAllLowStock;
  final Function(String activityId)? onViewActivity;

  const StockOverviewTab({
    super.key,
    this.onEditItem,
    this.onViewItem,
    this.onNewPurchase,
    this.onAddStock,
    this.onIssueStock,
    this.onAdjustStock,
    this.onTransferStock,
    this.onViewAllActivities,
    this.onViewAllLowStock,
    this.onViewActivity,
  });

  @override
  ConsumerState<StockOverviewTab> createState() => _StockOverviewTabState();
}

class _StockOverviewTabState extends ConsumerState<StockOverviewTab> {
  int? _getItemSortColumnIndex(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'item_name':
      case 'name': return 2;
      case 'category': return 3;
      case 'unit': return 4;
      case 'current_stock': return 5;
      case 'min_stock': return 6;
      case 'status': return 7;
      default: return null;
    }
  }
  String _timeRange = 'Last 6 Months';
  bool _isGridView = false;
  final Set<String> _selectedItemIds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Analytics Cards Row (Charts & Low Stock)
          _buildTopAnalyticsRow(context, state, isDark, screenWidth),
          const SizedBox(height: 24),

          // 2. Main Workspace (Table + Right Side Panel)
          if (screenWidth >= 1200)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 74% - Filter Toolbar + Items Table + Pagination
                Expanded(
                  flex: 74,
                  child: _buildItemsWorkspace(context, state, isDark),
                ),
                const SizedBox(width: 24),
                // Right 26% - Quick Actions & Recent Activities
                Expanded(
                  flex: 26,
                  child: _buildRightSidePanel(context, state, isDark),
                ),
              ],
            )
          else ...[
            _buildItemsWorkspace(context, state, isDark),
            const SizedBox(height: 24),
            _buildRightSidePanel(context, state, isDark),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TOP ROW: Stock Line Chart, Category Donut Chart, Low Stock Card
  // -------------------------------------------------------------
  Widget _buildTopAnalyticsRow(
    BuildContext context,
    InventoryState state,
    bool isDark,
    double screenWidth,
  ) {
    if (screenWidth < 1100) {
      return Column(
        children: [
          _buildStockLineChartCard(state, isDark),
          const SizedBox(height: 16),
          _buildCategoryDonutCard(state, isDark),
          const SizedBox(height: 16),
          _buildLowStockAlertsCard(state, isDark),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock Overview Chart
        Expanded(
          flex: 42,
          child: _buildStockLineChartCard(state, isDark),
        ),
        const SizedBox(width: 20),
        // Category Wise Stock
        Expanded(
          flex: 32,
          child: _buildCategoryDonutCard(state, isDark),
        ),
        const SizedBox(width: 20),
        // Low Stock Alerts
        Expanded(
          flex: 26,
          child: _buildLowStockAlertsCard(state, isDark),
        ),
      ],
    );
  }

  Widget _buildStockLineChartCard(InventoryState state, bool isDark) {
    final trends = state.overview?.monthlyTrend ?? [];
    List<String> months = [];
    List<FlSpot> totalStockSpots = [];
    List<FlSpot> issuedSpots = [];
    double maxY = 3.5;
    double scale = 100000.0;
    String unit = 'L';

    if (trends.isNotEmpty) {
      double maxVal = 0.0;
      for (final t in trends) {
        if (t.totalStock > maxVal) maxVal = t.totalStock;
        if (t.issued > maxVal) maxVal = t.issued;
      }
      if (maxVal > 50000) {
        scale = 100000.0;
        unit = 'L';
      } else {
        scale = 1000.0;
        unit = 'k';
      }
      maxY = maxVal > 0 ? (maxVal / scale) * 1.35 : 3.5;
      if (maxY < 1.0) maxY = 1.0;

      for (int i = 0; i < trends.length; i++) {
        months.add(trends[i].month);
        totalStockSpots.add(FlSpot(i.toDouble(), trends[i].totalStock / scale));
        issuedSpots.add(FlSpot(i.toDouble(), trends[i].issued / scale));
      }
    } else {
      months = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
      totalStockSpots = const [FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0)];
      issuedSpots = const [FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0)];
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stock Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _timeRange,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    items: ['Last 6 Months', 'Last 30 Days', 'Last 1 Year']
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _timeRange = val);
                        String intervalKey = '6m';
                        if (val == 'Last 30 Days') intervalKey = '30d';
                        if (val == 'Last 1 Year') intervalKey = '1y';
                        ref.read(inventoryProvider.notifier).setOverviewInterval(intervalKey);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendDot(const Color(0xFF2563EB), 'Total Stock', isDark),
              const SizedBox(width: 14),
              _buildLegendDot(const Color(0xFF10B981), 'Issued', isDark),
            ],
          ),
          const SizedBox(height: 10),

          // fl_chart LineChart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY > 4 ? (maxY / 3).roundToDouble() : 1.0,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return Text('0', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)));
                        return Text('${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}$unit', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontFamily: 'Inter'));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(
                            months[idx],
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (months.length > 1 ? months.length - 1 : 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Total Stock Line (Blue)
                  LineChartBarData(
                    spots: totalStockSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF2563EB),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFF2563EB),
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    ),
                  ),
                  // Issued Line (Green)
                  LineChartBarData(
                    spots: issuedSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF10B981),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3.5,
                        color: const Color(0xFF10B981),
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDonutCard(InventoryState state, bool isDark) {
    final categories = state.overview?.categoryStock ?? [];
    final topPct = categories.isNotEmpty ? '${categories.first.percentage.toStringAsFixed(0)}%' : '0%';

    final List<PieChartSectionData> sections = [];
    if (categories.isNotEmpty) {
      for (final cat in categories) {
        Color secColor = const Color(0xFF2563EB);
        try {
          final hex = cat.colorHex.replaceAll('#', '');
          secColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {}
        sections.add(
          PieChartSectionData(
            value: cat.percentage > 0 ? cat.percentage : 1.0,
            color: secColor,
            radius: 20,
            showTitle: false,
          ),
        );
      }
    } else {
      sections.add(
        PieChartSectionData(
          value: 100,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          radius: 20,
          showTitle: false,
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Wise Stock',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Donut Chart with center percentage
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38,
                          sections: sections,
                        ),
                      ),
                      Text(
                        topPct,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Legend on Right
                Expanded(
                  flex: 6,
                  child: categories.isEmpty
                      ? Center(
                          child: Text(
                            'No items in stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: categories.take(4).map((c) {
                            Color secColor = const Color(0xFF2563EB);
                            try {
                              final hex = c.colorHex.replaceAll('#', '');
                              secColor = Color(int.parse('FF$hex', radix: 16));
                            } catch (_) {}
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildDonutLegendRow(secColor, c.category, '${c.percentage.toStringAsFixed(0)}%', isDark),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendRow(Color color, String label, String pct, bool isDark) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          pct,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildLowStockAlertsCard(InventoryState state, bool isDark) {
    final overviewAlerts = state.overview?.lowStockAlerts ?? [];
    final alerts = overviewAlerts.isNotEmpty
        ? overviewAlerts
        : state.items
            .where((i) => i.isLowStock || i.isOutOfStock)
            .map((i) => InventoryLowStockAlert(
                  id: i.id,
                  itemName: i.name,
                  category: i.categoryName,
                  currentStock: i.currentStock,
                  minStock: i.minStock,
                  unit: i.uomCode,
                  alertText: i.isOutOfStock ? 'Out of Stock' : 'Only ${i.currentStock.toInt()} ${i.uomCode} Left',
                  sku: i.sku,
                  severity: i.isOutOfStock ? 'critical' : 'warning',
                ))
            .take(5)
            .toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low Stock Alerts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
              ),
              InkWell(
                onTap: () {
                  ref.read(inventoryProvider.notifier).setItemStatus('LOW_STOCK');
                  widget.onViewAllLowStock?.call();
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Text(
                      'All stock levels healthy. No alerts.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final alert = alerts[i];
                      return _buildLowStockRow(state, alert, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockRow(InventoryState state, InventoryLowStockAlert alert, bool isDark) {
    final isCritical = alert.isOutOfStock || alert.severity == 'critical';
    final alertColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final alertBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final match = state.items.where((it) => it.id == alert.id || it.name.toLowerCase() == alert.itemName.toLowerCase()).firstOrNull;
          if (match != null) {
            widget.onViewItem?.call(match);
          } else {
            ref.read(inventoryProvider.notifier).setItemSearch(alert.itemName);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // Icon Container / Thumbnail
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? alertColor.withValues(alpha: 0.15) : alertBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCritical ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                  color: alertColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              // Name and Left Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.itemName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                        fontFamily: 'Inter',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          isCritical
                              ? 'Out of Stock (${alert.currentStock.toInt()} ${alert.unit})'
                              : 'Only ${alert.currentStock.toInt()} ${alert.unit} Left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: alertColor,
                            fontFamily: 'Inter',
                          ),
                        ),
                        if (alert.minStock > 0) ...[
                          Text(
                            ' • Min: ${alert.minStock}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // LEFT WORKSPACE: Filter Toolbar, Table, Pagination
  // -------------------------------------------------------------
  Widget _buildItemsWorkspace(BuildContext context, InventoryState state, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Toolbar
          _buildFilterToolbar(context, state, isDark),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Items Table or Grid View
          if (_selectedItemIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedItemIds.length} items selected',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E40AF), fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export Selected'),
                    onPressed: () async {
                      try {
                        await ref.read(inventoryApiServiceProvider).exportCsv('items', selectedIds: _selectedItemIds.toList());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Exported ${_selectedItemIds.length} items successfully.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Export error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedItemIds.clear()),
                    child: const Text('Clear Selection'),
                  ),
                ],
              ),
            ),
          if (state.isLoadingItems && state.items.isEmpty)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.items.isEmpty)
            _buildEmptyState(isDark)
          else
            _isGridView
                ? _buildItemsGrid(context, state, isDark)
                : _buildItemsTable(context, state, isDark),

          // Pagination Bar
          _buildPaginationBar(context, state, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(BuildContext context, InventoryState state, bool isDark) {
    final metadata = state.metadata;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          Container(
            width: 280,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: TextField(
              onChanged: (val) {
                ref.read(inventoryProvider.notifier).setItemSearch(val);
              },
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                hintText: 'Search items by name, category...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontFamily: 'Inter',
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),

          // Categories Dropdown (Dynamic from Universal Lookups)
          _buildDropdownFilter(
            label: 'All Categories',
            value: state.selectedCategory,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
              ...?metadata?.itemCategories.map(
                (c) {
                  final text = c.lookupValue.isNotEmpty ? c.lookupValue : c.lookupCode;
                  return DropdownMenuItem<String?>(
                    value: text,
                    child: Text(text),
                  );
                },
              ),
            ],
            onChanged: (val) => ref.read(inventoryProvider.notifier).setItemCategory(val),
            isDark: isDark,
          ),

          // Stores Dropdown
          _buildDropdownFilter(
            label: 'All Stores',
            value: state.selectedStoreId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Stores')),
              ...?metadata?.stores.map(
                (s) => DropdownMenuItem<String?>(
                  value: s.storeId,
                  child: Text(s.storeName),
                ),
              ),
            ],
            onChanged: (val) => ref.read(inventoryProvider.notifier).setItemStore(val),
            isDark: isDark,
          ),

          // Status Dropdown
          _buildDropdownFilter(
            label: 'All Status',
            value: state.selectedStatus,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Status')),
              ...?metadata?.itemStatuses.map(
                (st) {
                  final text = st.lookupValue.isNotEmpty ? st.lookupValue : st.lookupCode;
                  return DropdownMenuItem<String?>(
                    value: text,
                    child: Text(text),
                  );
                },
              ),
            ],
            onChanged: (val) => ref.read(inventoryProvider.notifier).setItemStatus(val),
            isDark: isDark,
          ),

          // Filter Button (Blue Outline)
          OutlinedButton.icon(
            onPressed: () {
              ref.read(inventoryProvider.notifier).loadItems();
            },
            icon: const Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF2563EB)),
            label: const Text(
              'Filter',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
                fontFamily: 'Inter',
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Grid / List View Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  color: _isGridView
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => setState(() => _isGridView = true),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: 'Grid View',
                ),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                  color: !_isGridView
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => setState(() => _isGridView = false),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: 'List View',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    final uniqueItems = <T?, DropdownMenuItem<T?>>{};
    for (final it in items) {
      uniqueItems.putIfAbsent(it.value, () => it);
    }
    final safeItems = uniqueItems.values.toList();
    final matchedValue = safeItems.any((i) => i.value == value)
        ? value
        : (safeItems.any((i) => i.value != null && value != null && i.value.toString().toLowerCase() == value.toString().toLowerCase())
            ? safeItems.firstWhere((i) => i.value != null && value != null && i.value.toString().toLowerCase() == value.toString().toLowerCase()).value
            : null);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: matchedValue,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          items: safeItems,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, InventoryState state, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              horizontalMargin: 16,
              columnSpacing: 18,
              sortColumnIndex: _getItemSortColumnIndex(state.itemsSortBy),
              sortAscending: state.itemsSortAscending,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              ),
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: _selectedItemIds.length == state.items.length && state.items.isNotEmpty,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItemIds.addAll(state.items.map((e) => e.itemId));
                        } else {
                          _selectedItemIds.clear();
                        }
                      });
                    },
                  ),
                ),
                const DataColumn(label: Text('#', style: _headerStyle)),
                DataColumn(
                  label: const Text('Item Name', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('item_name'),
                ),
                DataColumn(
                  label: const Text('Category', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('category'),
                ),
                DataColumn(
                  label: const Text('Unit', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('unit'),
                ),
                DataColumn(
                  label: const Text('Current Stock', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('current_stock'),
                ),
                DataColumn(
                  label: const Text('Min Stock', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('min_stock'),
                ),
                DataColumn(
                  label: const Text('Status', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortItems('status'),
                ),
                const DataColumn(label: Text('Action', style: _headerStyle)),
              ],
              rows: state.items.asMap().entries.map((entry) {
                final index = (state.itemPage - 1) * state.itemPageSize + entry.key + 1;
                final item = entry.value;
                final isSelected = _selectedItemIds.contains(item.itemId);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(item.itemId);
                      } else {
                        _selectedItemIds.remove(item.itemId);
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedItemIds.add(item.itemId);
                            } else {
                              _selectedItemIds.remove(item.itemId);
                            }
                          });
                        },
                      ),
                    ),
                    DataCell(Text('$index', style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(item.categoryName, style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(Text(item.uomName, style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(
                      Text(
                        '${item.currentStock.toInt()}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${item.minStockLevel.toInt()}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(item.stockStatus)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                            onPressed: () => widget.onViewItem?.call(item),
                            tooltip: 'View Details',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17, color: Color(0xFF64748B)),
                            onPressed: () => widget.onEditItem?.call(item),
                            tooltip: 'Edit Item',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                              const PopupMenuItem(value: 'transfer', child: Text('Transfer Store')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Item', style: TextStyle(color: Colors.red))),
                            ],
                            onSelected: (val) {
                              if (val == 'adjust') widget.onAdjustStock?.call();
                              if (val == 'transfer') widget.onTransferStock?.call();
                              if (val == 'delete') _confirmDeleteItem(context, item);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsGrid(BuildContext context, InventoryState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.1,
        ),
        itemCount: state.items.length,
        itemBuilder: (context, i) {
          final item = state.items[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(item.stockStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: ${item.sku} • ${item.categoryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock: ${item.currentStock.toInt()} ${item.uomCode}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                        ),
                        Text(
                          'Price: ₹${item.purchasePrice}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: () => widget.onEditItem?.call(item),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'IN_STOCK':
      case 'IN STOCK':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        text = 'In Stock';
        break;
      case 'LOW_STOCK':
      case 'LOW STOCK':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        text = 'Low Stock';
        break;
      case 'OUT_OF_STOCK':
      case 'OUT OF STOCK':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        text = 'Out of Stock';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No inventory items found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search or filters to see more results.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(BuildContext context, InventoryState state, bool isDark) {
    final start = (state.itemPage - 1) * state.itemPageSize + 1;
    final end = (state.itemPage * state.itemPageSize).clamp(0, state.totalItemsCount);
    final totalPages = (state.totalItemsCount / state.itemPageSize).ceil().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // "Showing 1 - 5 of 246 items"
          Text(
            'Showing $start - $end of ${state.totalItemsCount} items',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),

          // Pagination Buttons: « 1 2 3 4 5 ... 50 »
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_left,
                onTap: state.itemPage > 1 ? () => ref.read(inventoryProvider.notifier).setItemPage(state.itemPage - 1) : null,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._buildPageNumbers(state.itemPage, totalPages, isDark),
              const SizedBox(width: 6),
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_right,
                onTap: state.itemPage < totalPages ? () => ref.read(inventoryProvider.notifier).setItemPage(state.itemPage + 1) : null,
                isDark: isDark,
              ),
            ],
          ),

          // Rows per page dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page: ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.itemPageSize,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    items: [5, 10, 25, 50]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                '$s',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(inventoryProvider.notifier).setItemPageSize(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int currentPage, int totalPages, bool isDark) {
    List<Widget> list = [];
    const maxButtons = 5;
    int startPage = (currentPage - 2).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    for (int p = startPage; p <= endPage; p++) {
      final isCurrent = p == currentPage;
      list.add(
        InkWell(
          onTap: () => ref.read(inventoryProvider.notifier).setItemPage(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      );
    }

    if (endPage < totalPages) {
      list.add(
        Container(
          width: 24,
          alignment: Alignment.center,
          child: Text('...', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
        ),
      );
      list.add(
        InkWell(
          onTap: () => ref.read(inventoryProvider.notifier).setItemPage(totalPages),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              '$totalPages',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }

  Widget _buildPageArrow({required IconData icon, VoidCallback? onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 15,
          color: onTap != null
              ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))
              : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // RIGHT SIDE PANEL: Recent Activities (Live Audit Feed)
  // -------------------------------------------------------------
  Widget _buildRightSidePanel(BuildContext context, InventoryState state, bool isDark) {
    return _buildRecentActivitiesCard(context, state, isDark);
  }

  Widget _buildRecentActivitiesCard(BuildContext context, InventoryState state, bool isDark) {
    final activities = state.overview?.recentActivities ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activities',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Live stock movement feed',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: widget.onViewAllActivities,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent activity recorded yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            )
          else
            _buildActivityTimeline(context, state, activities, isDark),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline(
    BuildContext context,
    InventoryState state,
    List<InventoryActivityItem> activities,
    bool isDark,
  ) {
    return Column(
      children: List.generate(activities.length, (index) {
        final act = activities[index];
        final isLast = index == activities.length - 1;

        Color dotColor;
        try {
          final hex = act.dotColor.replaceAll('#', '');
          dotColor = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
        } catch (_) {
          dotColor = const Color(0xFF2563EB);
        }

        return _buildActivityItem(
          context: context,
          state: state,
          activity: act,
          dotColor: dotColor,
          isLast: isLast,
          isDark: isDark,
        );
      }),
    );
  }

  Widget _buildActivityItem({
    required BuildContext context,
    required InventoryState state,
    required InventoryActivityItem activity,
    required Color dotColor,
    required bool isLast,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onViewActivity != null) {
            widget.onViewActivity!(activity.id);
          } else {
            final itemName = activity.subtitle.split('(').first.trim();
            if (itemName.isNotEmpty) {
              ref.read(inventoryProvider.notifier).setTxSearch(itemName);
            }
            widget.onViewAllActivities?.call();
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 48,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              fontFamily: 'Inter',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          activity.timeStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'Inter',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteItem(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inventory Item'),
        content: Text('Are you sure you want to deactivate or delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(inventoryProvider.notifier).deleteItem(item.itemId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF475569),
  fontFamily: 'Inter',
);
