import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';

class PurchaseOrdersTab extends ConsumerStatefulWidget {
  final Function(PurchaseOrder po)? onViewOrder;
  final Function(PurchaseOrder po)? onReceiveGoods;
  final Function(PurchaseOrder po)? onDownloadOrder;
  final Function(PurchaseOrder po)? onEditOrder;
  final VoidCallback? onCreateOrder;
  final VoidCallback? onExportReport;
  final VoidCallback? onPrintReport;

  const PurchaseOrdersTab({
    super.key,
    this.onViewOrder,
    this.onReceiveGoods,
    this.onDownloadOrder,
    this.onEditOrder,
    this.onCreateOrder,
    this.onExportReport,
    this.onPrintReport,
  });

  @override
  ConsumerState<PurchaseOrdersTab> createState() => _PurchaseOrdersTabState();
}

class _PurchaseOrdersTabState extends ConsumerState<PurchaseOrdersTab> {
  int? _getPoSortColumnIndex(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'po_number': return 1;
      case 'order_date':
      case 'date': return 2;
      case 'supplier':
      case 'supplier_name': return 3;
      case 'items':
      case 'total_items': return 4;
      case 'total_amount':
      case 'amount': return 5;
      case 'status': return 6;
      case 'delivery_date':
      case 'expected_delivery': return 7;
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
                  child: _buildOrdersWorkspace(context, state, isDark),
                ),
                const SizedBox(width: 24),
                // Right 26% - Summary + Trend + Quick Actions
                Expanded(
                  flex: 26,
                  child: _buildRightSidePanel(context, state, isDark),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrdersWorkspace(context, state, isDark),
                const SizedBox(height: 24),
                _buildRightSidePanel(context, state, isDark),
              ],
            ),
    );
  }

  Widget _buildOrdersWorkspace(BuildContext context, InventoryState state, bool isDark) {
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

          if (state.isLoadingPo)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.purchaseOrders.isEmpty)
            _buildEmptyState(isDark)
          else
            _isChartView
                ? _buildLargeChartView(context, state, isDark)
                : _buildOrdersTable(context, state, isDark),

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
          // Search box
          Container(
            width: 240,
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
                ref.read(inventoryProvider.notifier).setPoSearch(val);
              },
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                hintText: 'Search purchase orders...',
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

          // Status Dropdown (dynamic lookups)
          _buildDropdownFilter(
            label: 'All Status',
            value: state.selectedPoStatus,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Status')),
              ...?metadata?.purchaseStatuses.map(
                (s) {
                  final text = s.lookupValue.isNotEmpty ? s.lookupValue : s.lookupCode;
                  return DropdownMenuItem<String?>(
                    value: text,
                    child: Text(text),
                  );
                },
              ),
            ],
            onChanged: (val) => ref.read(inventoryProvider.notifier).setPoStatus(val),
            isDark: isDark,
          ),

          // All Suppliers Dropdown
          _buildDropdownFilter(
            label: 'All Suppliers',
            value: state.selectedPoSupplierId,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Suppliers')),
              ...?metadata?.suppliers.map(
                (sup) => DropdownMenuItem<String?>(
                  value: sup.supplierId,
                  child: Text(sup.supplierName),
                ),
              ),
            ],
            onChanged: (val) => ref.read(inventoryProvider.notifier).setPoSupplier(val),
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
                ref.read(inventoryProvider.notifier).setPoDateRange(
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
              ref.read(inventoryProvider.notifier).loadPurchaseOrders();
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

          // Toggle List / Chart
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

  Widget _buildOrdersTable(BuildContext context, InventoryState state, bool isDark) {
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
              dataRowMaxHeight: 56,
              horizontalMargin: 16,
              columnSpacing: 18,
              sortColumnIndex: _getPoSortColumnIndex(state.poSortBy),
              sortAscending: state.poSortAscending,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              ),
              columns: [
                const DataColumn(label: Text('#', style: _headerStyle)),
                DataColumn(
                  label: const Text('PO Number', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('po_number'),
                ),
                DataColumn(
                  label: const Text('Date', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('order_date'),
                ),
                DataColumn(
                  label: const Text('Supplier', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('supplier'),
                ),
                DataColumn(
                  label: const Text('Items', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('items'),
                ),
                DataColumn(
                  label: const Text('Total Amount (₹)', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('total_amount'),
                ),
                DataColumn(
                  label: const Text('Status', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('status'),
                ),
                DataColumn(
                  label: const Text('Delivery Date', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortPurchaseOrders('delivery_date'),
                ),
                const DataColumn(label: Text('Actions', style: _headerStyle)),
              ],
              rows: state.purchaseOrders.asMap().entries.map((entry) {
                final index = (state.poPage - 1) * state.poPageSize + entry.key + 1;
                final po = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('$index', style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(
                      Text(
                        po.poNumber,
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
                        po.formattedOrderDate,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        po.supplierName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${po.itemsCount} Items',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFmt.format(po.totalAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                    DataCell(_buildStatusBadge(po.status)),
                    DataCell(
                      Text(
                        po.formattedDeliveryDate,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 17, color: Color(0xFF2563EB)),
                            onPressed: () => widget.onViewOrder?.call(po),
                            tooltip: 'View Order',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined, size: 17, color: Color(0xFF64748B)),
                            onPressed: () => widget.onDownloadOrder?.call(po),
                            tooltip: 'Download PDF/Invoice',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx) {
                              final statusUpper = po.status.trim().toUpperCase();
                              final isAlreadyReceived = statusUpper == 'DELIVERED' || statusUpper == 'COMPLETED' || statusUpper == 'RECEIVED' || statusUpper.contains('DELIVER') || statusUpper.contains('RECEIV');
                              final canReceive = !isAlreadyReceived && statusUpper != 'CANCELLED' && (statusUpper == 'PENDING' || statusUpper == 'PARTIAL' || statusUpper == 'CONFIRMED' || statusUpper == 'PROCESSING' || statusUpper == 'DRAFT');
                              final canCancel = !isAlreadyReceived && (statusUpper == 'PENDING' || statusUpper == 'DRAFT');
                              return [
                                if (canReceive)
                                  const PopupMenuItem(
                                    value: 'grn',
                                    child: Row(
                                      children: [
                                        Icon(Icons.archive_outlined, size: 16, color: Color(0xFF10B981)),
                                        SizedBox(width: 8),
                                        Text('Receive Goods (GRN)'),
                                      ],
                                    ),
                                  ),
                                if (canCancel)
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Cancel Order'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                      SizedBox(width: 8),
                                      Text('Edit Order Details'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'pdf',
                                  child: Row(
                                    children: [
                                      Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFFEF4444)),
                                      SizedBox(width: 8),
                                      Text('Download Invoice PDF'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                                      SizedBox(width: 8),
                                      Text('View PO Details'),
                                    ],
                                  ),
                                ),
                              ];
                            },
                            onSelected: (val) async {
                              if (val == 'edit') widget.onEditOrder?.call(po);
                              if (val == 'pdf') widget.onDownloadOrder?.call(po);
                              if (val == 'grn') widget.onReceiveGoods?.call(po);
                              if (val == 'view') widget.onViewOrder?.call(po);
                              if (val == 'cancel') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Purchase Order'),
                                    content: Text('Are you sure you want to cancel purchase order ${po.poNumber}? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('No, Keep Order'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  final success = await ref.read(inventoryProvider.notifier).cancelPurchaseOrder(po.id, reason: 'Cancelled by user');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Purchase Order ${po.poNumber} cancelled successfully' : 'Failed to cancel purchase order'),
                                        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status.toUpperCase()) {
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        text = 'Delivered';
        break;
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        text = 'Pending';
        break;
      case 'PARTIAL':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        text = 'Partial';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        text = 'Cancelled';
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
        borderRadius: BorderRadius.circular(6),
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

  Widget _buildLargeChartView(BuildContext context, InventoryState state, bool isDark) {
    final trends = state.poMonthlyTrend;
    final statuses = state.poStatusDistribution;
    final topSupp = state.poTopSuppliers;

    // Monthly bars calculations
    List<String> months = [];
    List<BarChartGroupData> barGroups = [];
    double maxVal = 0.0;
    double scale = 100000.0;
    String unit = 'L';

    if (trends.isNotEmpty) {
      for (final t in trends) {
        final v = (t['value'] as num?)?.toDouble() ?? 0.0;
        if (v > maxVal) maxVal = v;
      }
      if (maxVal > 50000) {
        scale = 100000.0;
        unit = 'L';
      } else {
        scale = 1000.0;
        unit = 'k';
      }

      for (int i = 0; i < trends.length; i++) {
        final t = trends[i];
        final m = t['month']?.toString() ?? 'M${i+1}';
        final val = ((t['value'] as num?)?.toDouble() ?? 0.0) / scale;
        months.add(m);
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: const Color(0xFF2563EB),
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }
    } else {
      months = ['Jan', 'Feb', 'Mar', 'Apr'];
      barGroups = [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1.8, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 16.9, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 7.0, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
      ];
      maxVal = 2000000;
    }

    final maxY = maxVal > 0 ? (maxVal / scale) * 1.3 : 25.0;

    // Status Pie chart calculations
    final List<PieChartSectionData> pieSections = [];
    int totalStatusCount = 0;
    for (final s in statuses) {
      totalStatusCount += (s['count'] as num?)?.toInt() ?? 0;
    }
    if (statuses.isNotEmpty && totalStatusCount > 0) {
      for (final s in statuses) {
        final stName = s['status']?.toString().toLowerCase() ?? '';
        final cnt = (s['count'] as num?)?.toDouble() ?? 1.0;
        Color col = const Color(0xFF0284C7);
        if (stName.contains('deliv') || stName.contains('receiv')) {
          col = const Color(0xFF10B981);
        } else if (stName.contains('part')) {
          col = const Color(0xFFF59E0B);
        } else if (stName.contains('pend')) {
          col = const Color(0xFF38BDF8);
        } else if (stName.contains('canc')) {
          col = const Color(0xFFEF4444);
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
        PieChartSectionData(value: 30, color: const Color(0xFF10B981), radius: 24, showTitle: false),
        PieChartSectionData(value: 8, color: const Color(0xFF38BDF8), radius: 24, showTitle: false),
        PieChartSectionData(value: 8, color: const Color(0xFFEF4444), radius: 24, showTitle: false),
        PieChartSectionData(value: 2, color: const Color(0xFFF59E0B), radius: 24, showTitle: false),
      ]);
    }

    final totalSpend = (state.poKPIs['total_spend'] as num?)?.toDouble() ?? 3285570.0;
    final completedPos = (state.poKPIs['completed_pos'] as num?)?.toInt() ?? 30;
    final totalPos = state.poTotal > 0 ? state.poTotal : 48;
    final completionPct = totalPos > 0 ? ((completedPos / totalPos) * 100).toStringAsFixed(0) : '0';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Metric Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsMetricCard(
                  title: 'Total Purchase Orders',
                  value: '$totalPos',
                  badgeText: 'All Time',
                  badgeColor: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetricCard(
                  title: 'Procurement Spend',
                  value: '₹${NumberFormat('#,##,###').format(totalSpend.round())}',
                  badgeText: 'Live Aggregate',
                  badgeColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetricCard(
                  title: 'Receipt / Fulfillment',
                  value: '$completionPct%',
                  badgeText: '$completedPos Completed',
                  badgeColor: const Color(0xFF059669),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Trend Bar Chart
              Expanded(
                flex: 60,
                child: Container(
                  height: 320,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Procurement Spend Trend',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            'Values in ₹ $unit',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontFamily: 'Inter',
                            ),
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
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final m = groupIndex < months.length ? months[groupIndex] : '';
                                  final valStr = (rod.toY * scale).toStringAsFixed(0);
                                  return BarTooltipItem(
                                    '$m: ₹$valStr',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                                        child: Text(months[idx], style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: maxY > 5 ? (maxY / 4).roundToDouble() : 1.0,
                                  getTitlesWidget: (val, meta) => Text('${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}$unit', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),

              // Status Distribution Donut Chart
              Expanded(
                flex: 40,
                child: Container(
                  height: 320,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders by Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 3,
                                      centerSpaceRadius: 36,
                                      sections: pieSections,
                                    ),
                                  ),
                                  Text(
                                    '$completionPct%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: (statuses.isNotEmpty ? statuses : [
                                  {'status': 'Delivered', 'count': 30},
                                  {'status': 'Pending', 'count': 8},
                                  {'status': 'Cancelled', 'count': 8},
                                  {'status': 'Partial', 'count': 2},
                                ]).map((s) {
                                  final st = s['status']?.toString() ?? '';
                                  final cnt = s['count']?.toString() ?? '0';
                                  Color col = const Color(0xFF0284C7);
                                  if (st.toLowerCase().contains('deliv') || st.toLowerCase().contains('receiv')) {
                                    col = const Color(0xFF10B981);
                                  } else if (st.toLowerCase().contains('part')) {
                                    col = const Color(0xFFF59E0B);
                                  } else if (st.toLowerCase().contains('pend')) {
                                    col = const Color(0xFF38BDF8);
                                  } else if (st.toLowerCase().contains('canc')) {
                                    col = const Color(0xFFEF4444);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(st, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B), fontFamily: 'Inter'), overflow: TextOverflow.ellipsis)),
                                        Text(cnt, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: col, fontFamily: 'Inter')),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Top Suppliers Leaderboard
          if (topSupp.isNotEmpty) ...[
            Text(
              'Top Suppliers by Procurement Volume',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: topSupp.map((s) {
                final name = s['name']?.toString() ?? 'Supplier';
                final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
                final oCount = s['order_count']?.toString() ?? '1';
                return Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A), fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${NumberFormat('#,##,###').format(amt.round())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontFamily: 'Inter')),
                          Text('$oCount POs', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetricCard({
    required String title,
    required String value,
    required String badgeText,
    required Color badgeColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(badgeText, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: badgeColor, fontFamily: 'Inter')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A), fontFamily: 'Inter')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No purchase orders found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a new purchase order or adjust your status/supplier filters.',
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
    final start = (state.poPage - 1) * state.poPageSize + 1;
    final end = (state.poPage * state.poPageSize).clamp(0, state.totalPoCount);
    final totalPages = (state.totalPoCount / state.poPageSize).ceil().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            'Showing $start - $end of ${state.totalPoCount} Purchase Orders',
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
                onTap: state.poPage > 1 ? () => ref.read(inventoryProvider.notifier).setPoPage(state.poPage - 1) : null,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._buildPageNumbers(state.poPage, totalPages, isDark),
              const SizedBox(width: 6),
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_right,
                onTap: state.poPage < totalPages ? () => ref.read(inventoryProvider.notifier).setPoPage(state.poPage + 1) : null,
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
                  child: DropdownButton<int>(
                    value: state.poPageSize,
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
                        ref.read(inventoryProvider.notifier).setPoPageSize(val);
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
          onTap: () => ref.read(inventoryProvider.notifier).setPoPage(p),
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
  // RIGHT SIDE PANEL: Summary + Trend + Quick Actions
  // -------------------------------------------------------------
  Widget _buildRightSidePanel(BuildContext context, InventoryState state, bool isDark) {
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Dynamic calculations from real status distribution and KPIs
    int poDelivered = (state.poKPIs['completed_pos'] as num?)?.toInt() ?? 0;
    int poPending = (state.poKPIs['pending_pos'] as num?)?.toInt() ?? 0;
    int poCancelled = (state.poKPIs['cancelled_pos'] as num?)?.toInt() ?? 0;
    int poPartial = 0;
    double poTotalSpend = (state.poKPIs['total_spend'] as num?)?.toDouble() ?? 0.0;
    int poTotalStatic = (state.poKPIs['total_pos'] as num?)?.toInt() ?? 0;

    for (final it in state.poStatusDistribution) {
      final st = (it['status'] as String? ?? '').toLowerCase();
      final cnt = (it['count'] as num?)?.toInt() ?? 0;
      final amt = (it['total_amount'] as num?)?.toDouble() ?? 0.0;
      if (poTotalSpend == 0.0) poTotalSpend += amt;
      if (st.contains('deliv') || st.contains('receiv') || st.contains('complet')) {
        if (poDelivered == 0) poDelivered += cnt;
      } else if (st.contains('pend')) {
        if (poPending == 0) poPending += cnt;
      } else if (st.contains('cancel')) {
        if (poCancelled == 0) poCancelled += cnt;
      } else if (st.contains('part')) {
        poPartial += cnt;
      }
    }
    if (poTotalSpend == 0.0) poTotalSpend = (state.poKPIs['total_spend'] as num?)?.toDouble() ?? (state.overview?.totalPurchaseValue ?? 0.0);
    if (poTotalStatic == 0) poTotalStatic = (state.poKPIs['total_pos'] as num?)?.toInt() ?? (state.overview?.totalPurchaseOrders ?? state.poTotal);

    // Dynamic Monthly Trend max value
    double maxTrend = 0.0;
    for (final t in state.poMonthlyTrend) {
      final val = ((t['value'] as num?)?.toDouble() ?? 0.0) / 100000.0;
      if (val > maxTrend) maxTrend = val;
    }
    final trendMaxY = maxTrend > 0 ? (maxTrend * 1.25) : 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Purchase Order Summary Card
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
                    'Purchase Order Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (state.selectedPoStatus != null)
                    InkWell(
                      onTap: () => ref.read(inventoryProvider.notifier).setPoStatus(null),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSummaryRow(
                icon: Icons.shopping_cart_outlined,
                iconColor: const Color(0xFF2563EB),
                label: "Total PO's",
                value: '$poTotalStatic',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setPoStatus(null),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Total Value',
                value: currencyFmt.format(poTotalSpend),
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setPoStatus(null),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Delivered',
                value: '$poDelivered',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setPoStatus('Delivered'),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Pending',
                value: '$poPending',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setPoStatus('Pending'),
              ),
              if (poPartial > 0) ...[
                const SizedBox(height: 10),
                _buildSummaryRow(
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: const Color(0xFF0284C7),
                  label: 'Partial',
                  value: '$poPartial',
                  isDark: isDark,
                  onTap: () => ref.read(inventoryProvider.notifier).setPoStatus('Partial'),
                ),
              ],
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFEF4444),
                label: 'Cancelled',
                value: '$poCancelled',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setPoStatus('Cancelled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Monthly Purchase Trend
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
                    'Monthly Purchase Trend',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isChartView = !_isChartView),
                    child: Row(
                      children: [
                        Text(
                          _isChartView ? 'View Table' : 'View Report',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(_isChartView ? Icons.table_chart_outlined : Icons.arrow_forward_rounded, size: 13, color: const Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: trendMaxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = state.poMonthlyTrend.isNotEmpty && group.x < state.poMonthlyTrend.length
                              ? state.poMonthlyTrend[group.x]
                              : null;
                          final month = item?['month'] ?? 'Month ${group.x + 1}';
                          final val = (rod.toY * 100000).toInt();
                          return BarTooltipItem(
                            '$month\n${currencyFmt.format(val)}',
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
                            if (state.poMonthlyTrend.isNotEmpty && idx >= 0 && idx < state.poMonthlyTrend.length) {
                              final m = state.poMonthlyTrend[idx]['month']?.toString() ?? '';
                              return Text(
                                m,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                ),
                              );
                            }
                            final months = ['Jan', 'Feb', 'Mar', 'Apr'];
                            if (idx >= 0 && idx < months.length) {
                              return Text(
                                months[idx],
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
                          reservedSize: 28,
                          interval: trendMaxY > 4 ? 2.0 : 1.0,
                          getTitlesWidget: (val, meta) {
                            String t = '${val.toInt()}L';
                            if (val == 0) t = '0L';
                            return Text(
                              t,
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
                      horizontalInterval: trendMaxY > 4 ? 2.0 : 1.0,
                      getDrawingHorizontalLine: (val) => FlLine(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: state.poMonthlyTrend.isNotEmpty
                        ? state.poMonthlyTrend.take(6).toList().asMap().entries.map((entry) {
                            final val = ((entry.value['value'] as num?)?.toDouble() ?? 0.0) / 100000.0;
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: val > 0 ? val : 0.2,
                                  color: const Color(0xFF38BDF8),
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList()
                        : [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 0, color: const Color(0xFF38BDF8), width: 14, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 0, color: const Color(0xFF38BDF8), width: 14, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 0, color: const Color(0xFF38BDF8), width: 14, borderRadius: BorderRadius.circular(4))]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 0, color: const Color(0xFF38BDF8), width: 14, borderRadius: BorderRadius.circular(4))]),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    Widget row = Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              fontFamily: 'Inter',
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: row,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: row,
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Color(0xFF475569),
  fontFamily: 'Inter',
);
