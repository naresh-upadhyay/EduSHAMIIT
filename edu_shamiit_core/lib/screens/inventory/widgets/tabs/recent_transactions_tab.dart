import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';

class RecentTransactionsTab extends ConsumerStatefulWidget {
  final Function(InventoryMovement tx)? onViewTransaction;
  final Function(InventoryMovement tx)? onReverseTransaction;
  final VoidCallback? onExportReport;
  final VoidCallback? onPrintReport;
  final VoidCallback? onViewAllTransactions;

  const RecentTransactionsTab({
    super.key,
    this.onViewTransaction,
    this.onReverseTransaction,
    this.onExportReport,
    this.onPrintReport,
    this.onViewAllTransactions,
  });

  @override
  ConsumerState<RecentTransactionsTab> createState() => _RecentTransactionsTabState();
}

class _RecentTransactionsTabState extends ConsumerState<RecentTransactionsTab> {
  int? _getTxSortColumnIndex(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'created_at':
      case 'date': return 1;
      case 'transaction_type':
      case 'type': return 2;
      case 'item_name': return 3;
      case 'quantity': return 4;
      case 'rate':
      case 'unit_cost': return 5;
      case 'total':
      case 'amount': return 6;
      case 'location': return 7;
      default: return null;
    }
  }

  bool _isChartView = false;
  String _dateRangeText = '01 Apr ${DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1} - 31 Mar ${DateTime.now().month >= 4 ? DateTime.now().year + 1 : DateTime.now().year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: screenWidth >= 1200
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 74% - Workspace (Toolbar + Table + Pagination)
                Expanded(
                  flex: 74,
                  child: _buildTransactionsWorkspace(context, state, isDark),
                ),
                const SizedBox(width: 24),
                // Right 26% - Summary Chart + Quick Actions + Recent Activity
                Expanded(
                  flex: 26,
                  child: _buildRightSidePanel(context, state, isDark),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTransactionsWorkspace(context, state, isDark),
                const SizedBox(height: 24),
                _buildRightSidePanel(context, state, isDark),
              ],
            ),
    );
  }

  Widget _buildTransactionsWorkspace(BuildContext context, InventoryState state, bool isDark) {
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
          _buildFilterToolbar(context, state, isDark),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          if (state.isLoadingTx)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.movements.isEmpty)
            _buildEmptyState(isDark)
          else
            _isChartView
                ? _buildLargeChartView(context, state, isDark)
                : _buildTransactionsTable(context, state, isDark),

          _buildPaginationBar(context, state, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(BuildContext context, InventoryState state, bool isDark) {
    final metadata = state.metadata;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search box
              Container(
                width: isNarrow ? constraints.maxWidth : 230,
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
                    ref.read(inventoryProvider.notifier).setTxSearch(val);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    hintText: 'Search transactions...',
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

              // All Types (dynamic lookups)
              _buildDropdownFilter(
                label: 'All Types',
                value: state.selectedTxType,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Types')),
                  ...?metadata?.movementTypes.map(
                    (t) {
                      final text = t.lookupValue.isNotEmpty ? t.lookupValue : t.lookupCode;
                      return DropdownMenuItem<String?>(
                        value: text,
                        child: Text(text),
                      );
                    },
                  ),
                ],
                onChanged: (val) => ref.read(inventoryProvider.notifier).setTxType(val),
                isDark: isDark,
              ),

              // All Items
              _buildDropdownFilter(
                label: 'All Items',
                value: state.selectedTxItemId,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Items')),
                  ...(state.catalogItems.isNotEmpty ? state.catalogItems : state.items).map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.itemId,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (val) => ref.read(inventoryProvider.notifier).setTxItemId(val),
                isDark: isDark,
              ),

              // All Locations / Stores
              _buildDropdownFilter(
                label: 'All Locations',
                value: state.selectedTxStoreId,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Locations')),
                  ...?metadata?.stores.map(
                    (s) => DropdownMenuItem<String?>(
                      value: s.storeId,
                      child: Text(s.storeName),
                    ),
                  ),
                ],
                onChanged: (val) => ref.read(inventoryProvider.notifier).setTxStore(val),
                isDark: isDark,
              ),

              // Date Range picker chip
              InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2027),
                  );
                  if (range != null) {
                    final fmt = DateFormat('dd MMM yyyy');
                    setState(() {
                      _dateRangeText = '${fmt.format(range.start)} - ${fmt.format(range.end)}';
                    });
                    ref.read(inventoryProvider.notifier).setTxDateRange(
                          range.start.toIso8601String().split('T')[0],
                          range.end.toIso8601String().split('T')[0],
                        );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        _dateRangeText,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),

              // Filter Button
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(inventoryProvider.notifier).loadMovements();
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
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // List / Chart Toggle
              Container(
                height: 38,
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
                _buildViewToggleButton(
                  icon: Icons.format_list_bulleted_rounded,
                  label: 'List',
                  isSelected: !_isChartView,
                  onTap: () => setState(() => _isChartView = false),
                  isDark: isDark,
                ),
                _buildViewToggleButton(
                  icon: Icons.bar_chart_rounded,
                  label: 'Chart',
                  isSelected: _isChartView,
                  onTap: () => setState(() => _isChartView = true),
                  isDark: isDark,
                ),
              ],
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
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
      constraints: const BoxConstraints(maxWidth: 195),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<T?>.fromMenuItems(
          value: matchedValue,
          label: label,
          hint: label,
          allowClear: true,
          isDense: true,
          isExpanded: false,
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

  Widget _buildTransactionsTable(BuildContext context, InventoryState state, bool isDark) {
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 58,
              horizontalMargin: 16,
              columnSpacing: 18,
              sortColumnIndex: _getTxSortColumnIndex(state.txSortBy),
              sortAscending: state.txSortAscending,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              ),
              columns: [
                const DataColumn(label: Text('#', style: _headerStyle)),
                DataColumn(
                  label: const Text('Date & Time', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('created_at'),
                ),
                DataColumn(
                  label: const Text('Transaction Type', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('transaction_type'),
                ),
                DataColumn(
                  label: const Text('Item Name', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('item_name'),
                ),
                DataColumn(
                  label: const Text('Quantity', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('quantity'),
                ),
                DataColumn(
                  label: const Text('Rate (₹)', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('rate'),
                ),
                DataColumn(
                  label: const Text('Total (₹)', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('total'),
                ),
                DataColumn(
                  label: const Text('Location', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortTransactions('location'),
                ),
                const DataColumn(label: Text('Remarks', style: _headerStyle)),
                const DataColumn(label: Text('Action', style: _headerStyle)),
              ],
              rows: state.movements.asMap().entries.map((entry) {
                final index = (state.txPage - 1) * state.txPageSize + entry.key + 1;
                final tx = entry.value;

                final isPositive = tx.isStockIn;
                final qtyPrefix = isPositive ? '+' : '-';
                final qtyColor = isPositive ? const Color(0xFF16A34A) : const Color(0xFF1E293B);

                return DataRow(
                  cells: [
                    DataCell(Text('$index', style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(
                      Text(
                        tx.formattedDateTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontFamily: 'Inter',
                          height: 1.25,
                        ),
                      ),
                    ),
                    DataCell(_buildTransactionTypeBadge(tx.movementType)),
                    DataCell(
                      Text(
                        tx.itemName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '$qtyPrefix${tx.quantity.abs().toInt()}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: qtyColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFmt.format(tx.unitCost),
                        style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFmt.format(tx.totalCost),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                    DataCell(
                      Text(
                        tx.storeName,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          tx.notes ?? tx.referenceNumber ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                            onPressed: () => widget.onViewTransaction?.call(tx),
                            tooltip: 'View Details',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'reverse',
                                child: Row(
                                  children: [
                                    Icon(Icons.undo_rounded, size: 16, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Reverse Movement'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'reverse') widget.onReverseTransaction?.call(tx);
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

  Widget _buildTransactionTypeBadge(String type) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (type.toUpperCase()) {
      case 'PURCHASE':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        icon = Icons.shopping_cart_outlined;
        label = 'Purchase';
        break;
      case 'SALE':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        icon = Icons.shopping_bag_outlined;
        label = 'Sale';
        break;
      case 'STOCK_IN':
      case 'STOCK IN':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        icon = Icons.inventory_2_outlined;
        label = 'Stock In';
        break;
      case 'STOCK_OUT':
      case 'STOCK OUT':
      case 'ISSUE':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        icon = Icons.unarchive_outlined;
        label = 'Stock Out';
        break;
      case 'ADJUSTMENT':
      case 'STOCK ADJUSTMENT':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        icon = Icons.tune_rounded;
        label = 'Stock Adjustment';
        break;
      case 'TRANSFER':
        bg = const Color(0xFFFAF5FF);
        fg = const Color(0xFF8B5CF6);
        icon = Icons.swap_horiz_rounded;
        label = 'Transfer';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        icon = Icons.sync_alt_rounded;
        label = type;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeChartView(BuildContext context, InventoryState state, bool isDark) {
    final summaries = state.txChartSummary;
    final distributions = state.txTypeDistribution;
    final topItems = state.txTopItems;

    // Monthly bars calculations
    List<String> months = [];
    List<BarChartGroupData> barGroups = [];
    double maxVal = 0.0;
    double scale = 1.0;
    String unit = '';

    if (summaries.isNotEmpty) {
      for (final s in summaries) {
        final p = (s['purchase'] as num?)?.toDouble() ?? 0.0;
        final sl = (s['sale'] as num?)?.toDouble() ?? 0.0;
        final si = (s['stock_in'] as num?)?.toDouble() ?? 0.0;
        final so = (s['stock_out'] as num?)?.toDouble() ?? 0.0;
        if (p > maxVal) maxVal = p;
        if (sl > maxVal) maxVal = sl;
        if (si > maxVal) maxVal = si;
        if (so > maxVal) maxVal = so;
      }
      if (maxVal > 1000) {
        scale = 1000.0;
        unit = 'k';
      } else {
        scale = 1.0;
        unit = '';
      }

      for (int i = 0; i < summaries.length; i++) {
        final s = summaries[i];
        final m = s['month']?.toString() ?? 'M${i + 1}';
        final p = ((s['purchase'] as num?)?.toDouble() ?? 0.0) / scale;
        final sl = ((s['sale'] as num?)?.toDouble() ?? 0.0) / scale;
        final si = ((s['stock_in'] as num?)?.toDouble() ?? 0.0) / scale;
        final so = ((s['stock_out'] as num?)?.toDouble() ?? 0.0) / scale;
        months.add(m);
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: p, color: const Color(0xFF10B981), width: 9, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: sl, color: const Color(0xFF2563EB), width: 9, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: si, color: const Color(0xFF8B5CF6), width: 9, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: so, color: const Color(0xFFEA580C), width: 9, borderRadius: BorderRadius.circular(3)),
            ],
          ),
        );
      }
    } else {
      months = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
      barGroups = [
        _buildBarGroup(0, 14, 8, 5, 3),
        _buildBarGroup(1, 12, 10, 6, 4),
        _buildBarGroup(2, 16, 9, 7, 5),
        _buildBarGroup(3, 15, 11, 8, 4),
      ];
      maxVal = 20;
    }

    final maxY = maxVal > 0 ? (maxVal / scale) * 1.35 : 20.0;

    // Movement Type Pie chart calculations
    final List<PieChartSectionData> pieSections = [];
    int totalTypeEvents = 0;
    String topTypeName = 'Movements';
    double topTypePct = 0.0;

    if (distributions.isNotEmpty) {
      for (final d in distributions) {
        totalTypeEvents += (d['count'] as num?)?.toInt() ?? 0;
      }
      for (int i = 0; i < distributions.length; i++) {
        final d = distributions[i];
        final type = d['type']?.toString() ?? 'Other';
        final cnt = (d['count'] as num?)?.toDouble() ?? 1.0;
        Color col = const Color(0xFF64748B);
        final lower = type.toLowerCase();
        if (lower.contains('purch')) {
          col = const Color(0xFF10B981);
        } else if (lower.contains('sale')) {
          col = const Color(0xFF2563EB);
        } else if (lower.contains('in')) {
          col = const Color(0xFF8B5CF6);
        } else if (lower.contains('out')) {
          col = const Color(0xFFEA580C);
        } else if (lower.contains('adjust')) {
          col = const Color(0xFFF59E0B);
        } else if (lower.contains('trans')) {
          col = const Color(0xFF06B6D4);
        }

        if (i == 0 && totalTypeEvents > 0) {
          topTypeName = type;
          topTypePct = (cnt / totalTypeEvents) * 100;
        }

        pieSections.add(
          PieChartSectionData(
            value: cnt,
            color: col,
            radius: 24,
            showTitle: false,
          ),
        );
      }
    } else {
      pieSections.addAll([
        PieChartSectionData(value: 40, color: const Color(0xFF10B981), radius: 24, showTitle: false),
        PieChartSectionData(value: 30, color: const Color(0xFF2563EB), radius: 24, showTitle: false),
        PieChartSectionData(value: 20, color: const Color(0xFF8B5CF6), radius: 24, showTitle: false),
        PieChartSectionData(value: 10, color: const Color(0xFFEA580C), radius: 24, showTitle: false),
      ]);
    }

    // Dynamic KPI summaries
    int totalTx = state.totalTxCount;
    int inwardMoves = 0;
    int outwardMoves = 0;
    for (final d in distributions) {
      final t = d['type']?.toString().toLowerCase() ?? '';
      final c = (d['count'] as num?)?.toInt() ?? 0;
      if (t.contains('purch') || t.contains('in')) {
        inwardMoves += c;
      } else if (t.contains('sale') || t.contains('out')) {
        outwardMoves += c;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Top 3 Analytics Cards
          Row(
            children: [
              Expanded(
                child: _buildTxAnalyticsKpi(
                  title: 'Total Movements Logged',
                  value: totalTx > 0 ? '$totalTx' : '0',
                  subtitle: 'Permanent Audit Trail',
                  icon: Icons.history_edu_rounded,
                  iconColor: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTxAnalyticsKpi(
                  title: 'Inward Inflow Events',
                  value: inwardMoves > 0 ? '$inwardMoves' : '0',
                  subtitle: 'Procurement & Stock In',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTxAnalyticsKpi(
                  title: 'Outward Outflow Events',
                  value: outwardMoves > 0 ? '$outwardMoves' : '0',
                  subtitle: 'Sales & Consumptions',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFFEA580C),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: Charts (60% Trend, 40% Type Breakdown)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Trend Bar Chart
              Expanded(
                flex: 6,
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
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
                                'Monthly Stock Movement Trends',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Inward vs outward volume across logged cycles',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 10,
                            children: [
                              _buildLegendItem(const Color(0xFF10B981), 'Purchase', isDark),
                              _buildLegendItem(const Color(0xFF2563EB), 'Sale', isDark),
                              _buildLegendItem(const Color(0xFF8B5CF6), 'Stock In', isDark),
                              _buildLegendItem(const Color(0xFFEA580C), 'Stock Out', isDark),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final m = (group.x.toInt() < months.length) ? months[group.x.toInt()] : '';
                                  String label = 'Item';
                                  if (rodIndex == 0) label = 'Purchase';
                                  if (rodIndex == 1) label = 'Sale';
                                  if (rodIndex == 2) label = 'Stock In';
                                  if (rodIndex == 3) label = 'Stock Out';
                                  final val = (rod.toY * scale).toStringAsFixed(scale == 1.0 ? 0 : 1);
                                  return BarTooltipItem(
                                    '$m - $label\n$val units',
                                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < months.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          months[idx],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 34,
                                  getTitlesWidget: (val, meta) {
                                    final v = val.toInt();
                                    return Text(
                                      '$v$unit',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontFamily: 'Inter',
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (val) => FlLine(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Movement Type Breakdown Donut Chart
              Expanded(
                flex: 4,
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movement Type Breakdown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Activity distribution across lifecycle',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: SizedBox(
                          height: 140,
                          width: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sections: pieSections,
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 44,
                                  startDegreeOffset: -90,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    totalTypeEvents > 0 ? '${topTypePct.toStringAsFixed(0)}%' : '100%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    topTypeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: distributions.map<Widget>((d) {
                          final name = d['type']?.toString() ?? 'Other';
                          final count = d['count']?.toString() ?? '0';
                          Color col = const Color(0xFF64748B);
                          final lower = name.toLowerCase();
                          if (lower.contains('purch')) {
                            col = const Color(0xFF10B981);
                          } else if (lower.contains('sale')) {
                            col = const Color(0xFF2563EB);
                          } else if (lower.contains('in')) {
                            col = const Color(0xFF8B5CF6);
                          } else if (lower.contains('out')) {
                            col = const Color(0xFFEA580C);
                          } else if (lower.contains('adjust')) {
                            col = const Color(0xFFF59E0B);
                          } else if (lower.contains('trans')) {
                            col = const Color(0xFF06B6D4);
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: col.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                                const SizedBox(width: 5),
                                Text(
                                  '$name: $count',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 3: Top 5 Active Items Leaderboard
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
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
                          'Most Active Inventory Items',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fastest moving catalog items by movement frequency & total volume',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Top 5 Velocity',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (topItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No movement history recorded yet',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: topItems.map<Widget>((item) {
                      final name = item['item_name']?.toString() ?? 'Item';
                      final sku = item['sku']?.toString() ?? 'SKU';
                      final count = item['count']?.toString() ?? '0';
                      final qty = item['total_qty']?.toString() ?? '0';

                      return Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFF2563EB)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SKU: $sku',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$count Events',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Text(
                                  '$qty Pcs Moved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxAnalyticsKpi({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No transactions recorded yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stock movements from purchases, issues and adjustments will show here.',
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
    final start = (state.txPage - 1) * state.txPageSize + 1;
    final end = (state.txPage * state.txPageSize).clamp(0, state.totalTxCount);
    final totalPages = (state.totalTxCount / state.txPageSize).ceil().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            'Showing $start - $end of ${state.totalTxCount} transactions',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Inter',
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_left,
                onTap: state.txPage > 1 ? () => ref.read(inventoryProvider.notifier).setTxPage(state.txPage - 1) : null,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._buildPageNumbers(state.txPage, totalPages, isDark),
              const SizedBox(width: 6),
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_right,
                onTap: state.txPage < totalPages ? () => ref.read(inventoryProvider.notifier).setTxPage(state.txPage + 1) : null,
                isDark: isDark,
              ),
            ],
          ),
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
                  child: AppSearchableDropdown<int>.fromMenuItems(
                    value: state.txPageSize,
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
                        ref.read(inventoryProvider.notifier).setTxPageSize(val);
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
          onTap: () => ref.read(inventoryProvider.notifier).setTxPage(p),
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
  // RIGHT SIDE PANEL: Summary Bar Chart + Quick Actions + Recent Activity
  // -------------------------------------------------------------
  Widget _buildRightSidePanel(BuildContext context, InventoryState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Transaction Summary Grouped Bar Chart
        Container(
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
          child: Builder(
            builder: (context) {
              final summaries = state.txChartSummary;
              List<String> sbMonths = [];
              List<BarChartGroupData> sbGroups = [];
              double sbMaxVal = 0.0;
              double sbScale = 1.0;
              String sbUnit = '';

              if (summaries.isNotEmpty) {
                for (final s in summaries) {
                  final p = (s['purchase'] as num?)?.toDouble() ?? 0.0;
                  final sl = (s['sale'] as num?)?.toDouble() ?? 0.0;
                  final si = (s['stock_in'] as num?)?.toDouble() ?? 0.0;
                  final so = (s['stock_out'] as num?)?.toDouble() ?? 0.0;
                  if (p > sbMaxVal) sbMaxVal = p;
                  if (sl > sbMaxVal) sbMaxVal = sl;
                  if (si > sbMaxVal) sbMaxVal = si;
                  if (so > sbMaxVal) sbMaxVal = so;
                }
                if (sbMaxVal > 1000) {
                  sbScale = 1000.0;
                  sbUnit = 'k';
                }

                for (int i = 0; i < summaries.length.clamp(0, 4); i++) {
                  final s = summaries[i];
                  final m = s['month']?.toString() ?? 'M${i + 1}';
                  final p = ((s['purchase'] as num?)?.toDouble() ?? 0.0) / sbScale;
                  final sl = ((s['sale'] as num?)?.toDouble() ?? 0.0) / sbScale;
                  final si = ((s['stock_in'] as num?)?.toDouble() ?? 0.0) / sbScale;
                  final so = ((s['stock_out'] as num?)?.toDouble() ?? 0.0) / sbScale;
                  sbMonths.add(m);
                  sbGroups.add(_buildBarGroup(i, p, sl, si, so));
                }
              } else {
                sbMonths = ['M1', 'M2', 'M3', 'M4'];
                sbGroups = [
                  _buildBarGroup(0, 0, 0, 0, 0),
                  _buildBarGroup(1, 0, 0, 0, 0),
                  _buildBarGroup(2, 0, 0, 0, 0),
                  _buildBarGroup(3, 0, 0, 0, 0),
                ];
                sbMaxVal = 5;
              }

              final sbMaxY = sbMaxVal > 0 ? (sbMaxVal / sbScale) * 1.3 : 16.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legend
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _buildLegendItem(const Color(0xFF10B981), 'Purchase', isDark),
                      _buildLegendItem(const Color(0xFF2563EB), 'Sale', isDark),
                      _buildLegendItem(const Color(0xFF8B5CF6), 'Stock In', isDark),
                      _buildLegendItem(const Color(0xFFEA580C), 'Stock Out', isDark),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Grouped Bar Chart
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceBetween,
                        maxY: sbMaxY,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < sbMonths.length) {
                                  return Text(
                                    sbMonths[idx],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontFamily: 'Inter',
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: sbMaxY / 3,
                              getTitlesWidget: (val, meta) {
                                final v = val.toInt();
                                return Text(
                                  '$v$sbUnit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    fontFamily: 'Inter',
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: sbMaxY / 3,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: sbGroups,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // Recent Activity Card
        Container(
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
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  InkWell(
                    onTap: widget.onViewAllTransactions,
                    child: const Row(
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
                ],
              ),
              const SizedBox(height: 14),
              if (state.movements.isNotEmpty)
                ...state.movements.take(3).map((m) {
                  IconData icon = Icons.inventory_2_outlined;
                  Color color = const Color(0xFF2563EB);
                  Color bg = const Color(0xFFEFF6FF);
                  if (m.transactionType == 'Purchase' || m.transactionType == 'Stock In') {
                    icon = Icons.shopping_cart_outlined;
                    color = const Color(0xFF10B981);
                    bg = const Color(0xFFECFDF5);
                  } else if (m.transactionType == 'Sale' || m.transactionType == 'Stock Out') {
                    icon = Icons.shopping_bag_outlined;
                    color = const Color(0xFFEF4444);
                    bg = const Color(0xFFFEF2F2);
                  } else if (m.transactionType == 'Stock Adjustment') {
                    icon = Icons.tune_outlined;
                    color = const Color(0xFFEA580C);
                    bg = const Color(0xFFFFF7ED);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSideActivityRow(
                      icon: icon,
                      color: color,
                      bg: bg,
                      title: '${m.transactionType}: ${m.quantityFormatted} ${m.itemName}',
                      time: m.formattedDateTime.replaceAll('\n', ' - '),
                      isDark: isDark,
                    ),
                  );
                })
              else ...[
                _buildSideActivityRow(
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                  title: 'No recent movements recorded',
                  time: 'Live Ledger Active',
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y1, double y2, double y3, double y4) {
    const width = 5.0;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: const Color(0xFF10B981), width: width, borderRadius: BorderRadius.circular(2)),
        BarChartRodData(toY: y2, color: const Color(0xFF2563EB), width: width, borderRadius: BorderRadius.circular(2)),
        BarChartRodData(toY: y3, color: const Color(0xFF8B5CF6), width: width, borderRadius: BorderRadius.circular(2)),
        BarChartRodData(toY: y4, color: const Color(0xFFEA580C), width: width, borderRadius: BorderRadius.circular(2)),
      ],
    );
  }

  Widget _buildSideActivityRow({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String time,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                  fontFamily: 'Inter',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF475569),
  fontFamily: 'Inter',
);
