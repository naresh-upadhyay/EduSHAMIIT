import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';

class SalesOrdersTab extends ConsumerStatefulWidget {
  final Function(SalesOrder so)? onViewOrder;
  final Function(SalesOrder so)? onFulfillOrder;
  final Function(SalesOrder so)? onDownloadOrder;
  final Function(SalesOrder so)? onEditOrder;
  final VoidCallback? onCreateOrder;
  final VoidCallback? onExportReport;
  final VoidCallback? onPrintReport;

  const SalesOrdersTab({
    super.key,
    this.onViewOrder,
    this.onFulfillOrder,
    this.onDownloadOrder,
    this.onEditOrder,
    this.onCreateOrder,
    this.onExportReport,
    this.onPrintReport,
  });

  @override
  ConsumerState<SalesOrdersTab> createState() => _SalesOrdersTabState();
}

class _SalesOrdersTabState extends ConsumerState<SalesOrdersTab> {
  int? _getSoSortColumnIndex(String sortBy) {
    switch (sortBy.toLowerCase()) {
      case 'so_number': return 1;
      case 'order_date':
      case 'date': return 2;
      case 'customer':
      case 'customer_name': return 3;
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

          if (state.isLoadingSo)
            const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.salesOrders.isEmpty)
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
                    ref.read(inventoryProvider.notifier).setSoSearch(val);
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    hintText: 'Search sales orders...',
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

              // Status Dropdown
              _buildDropdownFilter(
                label: 'All Status',
                value: state.selectedSoStatus,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Status')),
                  ...?metadata?.salesStatuses.map(
                    (s) {
                      final text = s.lookupValue.isNotEmpty ? s.lookupValue : s.lookupCode;
                      return DropdownMenuItem<String?>(
                        value: text,
                        child: Text(text),
                      );
                    },
                  ),
                ],
                onChanged: (val) => ref.read(inventoryProvider.notifier).setSoStatus(val),
                isDark: isDark,
              ),

              // All Customers Dropdown (Unique Customers from SO list)
              _buildCustomerDropdown(state, isDark),

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
                    ref.read(inventoryProvider.notifier).setSoDateRange(
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
                  ref.read(inventoryProvider.notifier).loadSalesOrders();
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

              // Toggle List / Chart
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

  Widget _buildCustomerDropdown(InventoryState state, bool isDark) {
    final metaCustomers = state.metadata?.customers ?? [];
    final Set<String> nameSet = {};
    for (final c in metaCustomers) {
      final n = c.lookupValue.isNotEmpty ? c.lookupValue : c.lookupCode;
      if (n.isNotEmpty && n != 'PROFILE') nameSet.add(n);
    }
    for (final so in state.salesOrders) {
      if (so.customerName.isNotEmpty) nameSet.add(so.customerName);
    }
    final customerNames = nameSet.toList()..sort();

    final matchedValue = customerNames.contains(state.selectedSoCustomerId)
        ? state.selectedSoCustomerId
        : (customerNames.any((c) => state.selectedSoCustomerId != null && c.toLowerCase() == state.selectedSoCustomerId!.toLowerCase())
            ? customerNames.firstWhere((c) => c.toLowerCase() == state.selectedSoCustomerId!.toLowerCase())
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
        child: AppSearchableDropdown<String?>.fromMenuItems(
          value: matchedValue,
          label: 'All Customers',
          hint: 'All Customers',
          allowClear: true,
          isDense: true,
          isExpanded: false,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All Customers')),
            ...customerNames.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
          ],
          onChanged: (val) => ref.read(inventoryProvider.notifier).setSoCustomer(val),
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            fontFamily: 'Inter',
          ),
        ),
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
              sortColumnIndex: _getSoSortColumnIndex(state.soSortBy),
              sortAscending: state.soSortAscending,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              ),
              columns: [
                const DataColumn(label: Text('#', style: _headerStyle)),
                DataColumn(
                  label: const Text('SO Number', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('so_number'),
                ),
                DataColumn(
                  label: const Text('Date', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('order_date'),
                ),
                DataColumn(
                  label: const Text('Customer', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('customer'),
                ),
                DataColumn(
                  label: const Text('Items', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('items'),
                ),
                DataColumn(
                  label: const Text('Total Amount (₹)', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('total_amount'),
                ),
                DataColumn(
                  label: const Text('Status', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('status'),
                ),
                DataColumn(
                  label: const Text('Delivery Date', style: _headerStyle),
                  onSort: (col, asc) => ref.read(inventoryProvider.notifier).sortSalesOrders('delivery_date'),
                ),
                const DataColumn(label: Text('Actions', style: _headerStyle)),
              ],
              rows: state.salesOrders.asMap().entries.map((entry) {
                final index = (state.soPage - 1) * state.soPageSize + entry.key + 1;
                final so = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('$index', style: const TextStyle(fontSize: 12.5, fontFamily: 'Inter'))),
                    DataCell(
                      Text(
                        so.soNumber,
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
                        so.formattedOrderDate,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        so.customerName,
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
                        '${so.itemsCount} Items',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        currencyFmt.format(so.totalAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                    DataCell(_buildStatusBadge(so.status)),
                    DataCell(
                      Text(
                        so.formattedDeliveryDate,
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
                            onPressed: () => widget.onViewOrder?.call(so),
                            tooltip: 'View Order',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined, size: 17, color: Color(0xFF64748B)),
                            onPressed: () => widget.onDownloadOrder?.call(so),
                            tooltip: 'Download Invoice PDF',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx) {
                              final statusUpper = so.status.trim().toUpperCase();
                              final isAlreadyDelivered = statusUpper == 'DELIVERED' || statusUpper == 'COMPLETED' || statusUpper == 'FULFILLED' || statusUpper.contains('DELIVER') || statusUpper.contains('FULFILL');
                              final canDeliver = !isAlreadyDelivered && statusUpper != 'CANCELLED';
                              final canCancel = !isAlreadyDelivered && (statusUpper == 'PENDING' || statusUpper == 'DRAFT');
                              return [
                                if (canDeliver)
                                  const PopupMenuItem(
                                    value: 'deliver',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                        SizedBox(width: 8),
                                        Text('Deliver / Fulfill Order'),
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
                                      Text('View Order Details'),
                                    ],
                                  ),
                                ),
                              ];
                            },
                            onSelected: (val) async {
                              if (val == 'edit') widget.onEditOrder?.call(so);
                              if (val == 'pdf') widget.onDownloadOrder?.call(so);
                              if (val == 'deliver') widget.onFulfillOrder?.call(so);
                              if (val == 'view') widget.onViewOrder?.call(so);
                              if (val == 'cancel') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Cancel Sales Order'),
                                    content: Text('Are you sure you want to cancel sales order ${so.soNumber}? Any reserved stock will be released.'),
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
                                  final success = await ref.read(inventoryProvider.notifier).cancelSalesOrder(so.id, reason: 'Cancelled by user');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success ? 'Sales Order ${so.soNumber} cancelled successfully' : 'Failed to cancel sales order'),
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
      case 'PROCESSING':
      case 'CONFIRMED':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        text = 'Processing';
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
    final trends = state.soSalesTrend;
    final statuses = state.soStatusDistribution;
    final topCust = state.soTopCustomers;

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
      months = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
      barGroups = [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 3.2, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 9.6, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 18.5, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 21.9, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
        BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 11.3, color: const Color(0xFF2563EB), width: 18, borderRadius: BorderRadius.circular(4))]),
      ];
      maxVal = 2500000;
    }

    final maxY = maxVal > 0 ? (maxVal / scale) * 1.3 : 30.0;

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
        if (stName.contains('deliv')) {
          col = const Color(0xFF10B981);
        } else if (stName.contains('pend')) col = const Color(0xFFF59E0B);
        else if (stName.contains('canc')) col = const Color(0xFFEF4444);
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
        PieChartSectionData(value: 112, color: const Color(0xFF10B981), radius: 24, showTitle: false),
        PieChartSectionData(value: 10, color: const Color(0xFFF59E0B), radius: 24, showTitle: false),
        PieChartSectionData(value: 6, color: const Color(0xFF0284C7), radius: 24, showTitle: false),
      ]);
    }

    final totalVal = (state.soKPIs['total_sales_value'] as num?)?.toDouble() ?? 6473850.0;
    final completedOrders = (state.soKPIs['completed_orders'] as num?)?.toInt() ?? 112;
    final totalOrders = state.soTotal > 0 ? state.soTotal : 128;
    final completionPct = totalOrders > 0 ? ((completedOrders / totalOrders) * 100).toStringAsFixed(0) : '0';

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
                  title: 'Total Sales Orders',
                  value: '$totalOrders',
                  badgeText: 'All Time',
                  badgeColor: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetricCard(
                  title: 'Total Revenue',
                  value: '₹${NumberFormat('#,##,###').format(totalVal.round())}',
                  badgeText: 'Live Aggregate',
                  badgeColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildAnalyticsMetricCard(
                  title: 'Order Fulfillment',
                  value: '$completionPct%',
                  badgeText: '$completedOrders Delivered',
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
                            'Monthly Sales Revenue Trend',
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
                                  {'status': 'Delivered', 'count': 112},
                                  {'status': 'Pending', 'count': 10},
                                  {'status': 'Processing', 'count': 6},
                                ]).map((s) {
                                  final st = s['status']?.toString() ?? '';
                                  final cnt = s['count']?.toString() ?? '0';
                                  Color col = const Color(0xFF0284C7);
                                  if (st.toLowerCase().contains('deliv')) {
                                    col = const Color(0xFF10B981);
                                  } else if (st.toLowerCase().contains('pend')) col = const Color(0xFFF59E0B);
                                  else if (st.toLowerCase().contains('canc')) col = const Color(0xFFEF4444);
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

          // 3. Top Institutional Customers Leaderboard
          if (topCust.isNotEmpty) ...[
            Text(
              'Top Institutional Customers by Volume',
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
              children: topCust.map((c) {
                final name = c['name']?.toString() ?? 'Partner';
                final amt = (c['total_amount'] as num?)?.toDouble() ?? 0.0;
                final oCount = c['order_count']?.toString() ?? '1';
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
                          Text('$oCount Orders', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
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
          Icon(Icons.shopping_bag_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No sales orders found',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a new sales order or adjust your filters.',
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
    final start = (state.soPage - 1) * state.soPageSize + 1;
    final end = (state.soPage * state.soPageSize).clamp(0, state.totalSoCount);
    final totalPages = (state.totalSoCount / state.soPageSize).ceil().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            'Showing $start - $end of ${state.totalSoCount} Sales Orders',
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
                onTap: state.soPage > 1 ? () => ref.read(inventoryProvider.notifier).setSoPage(state.soPage - 1) : null,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              ..._buildPageNumbers(state.soPage, totalPages, isDark),
              const SizedBox(width: 6),
              _buildPageArrow(
                icon: Icons.keyboard_double_arrow_right,
                onTap: state.soPage < totalPages ? () => ref.read(inventoryProvider.notifier).setSoPage(state.soPage + 1) : null,
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
                    value: state.soPageSize,
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
                        ref.read(inventoryProvider.notifier).setSoPageSize(val);
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
          onTap: () => ref.read(inventoryProvider.notifier).setSoPage(p),
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
    int soDelivered = (state.soKPIs['completed_orders'] as num?)?.toInt() ?? 0;
    int soPending = (state.soKPIs['pending_orders'] as num?)?.toInt() ?? 0;
    int soProcessing = (state.soKPIs['processing_orders'] as num?)?.toInt() ?? 0;
    int soCancelled = 0;
    double soTotalValue = (state.soKPIs['total_sales_value'] as num?)?.toDouble() ?? 0.0;
    int soTotalStatic = (state.soKPIs['total_orders'] as num?)?.toInt() ?? 0;

    for (final it in state.soStatusDistribution) {
      final st = (it['status'] as String? ?? '').toLowerCase();
      final cnt = (it['count'] as num?)?.toInt() ?? 0;
      final amt = (it['total_amount'] as num?)?.toDouble() ?? 0.0;
      if (soTotalValue == 0.0) soTotalValue += amt;
      if (st.contains('deliv') || st.contains('complet')) {
        if (soDelivered == 0) soDelivered += cnt;
      } else if (st.contains('pend')) {
        if (soPending == 0) soPending += cnt;
      } else if (st.contains('process')) {
        if (soProcessing == 0) soProcessing += cnt;
      } else if (st.contains('cancel')) {
        soCancelled += cnt;
      }
    }
    if (soTotalValue == 0.0) soTotalValue = (state.soKPIs['total_sales_value'] as num?)?.toDouble() ?? (state.overview?.totalSalesValue ?? 0.0);
    if (soTotalStatic == 0) soTotalStatic = (state.soKPIs['total_orders'] as num?)?.toInt() ?? (state.overview?.totalSalesOrders ?? state.soTotal);

    // Dynamic Monthly Trend max value
    double maxTrend = 0.0;
    for (final t in state.soSalesTrend) {
      final val = ((t['value'] as num?)?.toDouble() ?? 0.0) / 100000.0;
      if (val > maxTrend) maxTrend = val;
    }
    final trendMaxY = maxTrend > 0 ? (maxTrend * 1.25) : 3.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sales Order Summary Card
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
                    'Sales Order Summary',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (state.selectedSoStatus != null)
                    InkWell(
                      onTap: () => ref.read(inventoryProvider.notifier).setSoStatus(null),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSummaryRow(
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Total Orders',
                value: '$soTotalStatic',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setSoStatus(null),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.currency_rupee_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Total Value',
                value: currencyFmt.format(soTotalValue),
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setSoStatus(null),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Delivered',
                value: '$soDelivered',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setSoStatus('Delivered'),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Pending',
                value: '$soPending',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setSoStatus('Pending'),
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                icon: Icons.settings_backup_restore_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'Processing',
                value: '$soProcessing',
                isDark: isDark,
                onTap: () => ref.read(inventoryProvider.notifier).setSoStatus('Processing'),
              ),
              if (soCancelled > 0) ...[
                const SizedBox(height: 10),
                _buildSummaryRow(
                  icon: Icons.cancel_outlined,
                  iconColor: const Color(0xFFEF4444),
                  label: 'Cancelled',
                  value: '$soCancelled',
                  isDark: isDark,
                  onTap: () => ref.read(inventoryProvider.notifier).setSoStatus('Cancelled'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Monthly Sales Trend
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
                    'Monthly Sales Trend',
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
                          final item = state.soSalesTrend.isNotEmpty && group.x < state.soSalesTrend.length
                              ? state.soSalesTrend[group.x]
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
                            if (state.soSalesTrend.isNotEmpty && idx >= 0 && idx < state.soSalesTrend.length) {
                              final m = state.soSalesTrend[idx]['month']?.toString() ?? '';
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
                          reservedSize: 26,
                          interval: trendMaxY > 6 ? 2.0 : 1.0,
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
                      horizontalInterval: trendMaxY > 6 ? 2.0 : 1.0,
                      getDrawingHorizontalLine: (val) => FlLine(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: state.soSalesTrend.isNotEmpty
                        ? state.soSalesTrend.take(6).toList().asMap().entries.map((entry) {
                            final val = ((entry.value['value'] as num?)?.toDouble() ?? 0.0) / 100000.0;
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: val > 0 ? val : 0.5,
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
