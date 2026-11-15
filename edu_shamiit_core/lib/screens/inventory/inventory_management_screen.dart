import 'dart:convert';
import 'services/inventory_api_service.dart';
import '../../utils/tab_url_sync.dart';
import '../../utils/download_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/inventory_models.dart';
import 'providers/inventory_provider.dart';
import 'widgets/inventory_header_bar.dart';
import 'widgets/inventory_kpi_cards.dart';
import 'widgets/inventory_tabs_bar.dart';
import 'widgets/tabs/stock_overview_tab.dart';
import 'widgets/tabs/recent_transactions_tab.dart';
import 'widgets/tabs/purchase_orders_tab.dart';
import 'widgets/tabs/sales_orders_tab.dart';
import 'widgets/dialogs/create_edit_item_dialog.dart';
import 'widgets/dialogs/receive_stock_dialog.dart';
import 'widgets/dialogs/issue_stock_dialog.dart';
import 'widgets/dialogs/adjust_stock_dialog.dart';
import 'widgets/dialogs/transfer_stock_dialog.dart';
import 'widgets/dialogs/create_purchase_order_dialog.dart';
import 'widgets/dialogs/edit_purchase_order_dialog.dart';
import 'widgets/dialogs/receive_grn_dialog.dart';
import 'widgets/dialogs/create_sales_order_dialog.dart';
import 'widgets/dialogs/edit_sales_order_dialog.dart';
import 'widgets/dialogs/reverse_transaction_dialog.dart';
import 'widgets/dialogs/inventory_detail_drawer.dart';

class InventoryManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const InventoryManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends ConsumerState<InventoryManagementScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  InventoryItem? _inspectItem;
  InventoryMovement? _inspectMovement;
  PurchaseOrder? _inspectPo;
  SalesOrder? _inspectSo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialTab != 0) {
          ref.read(inventoryProvider.notifier).setActiveTab(widget.initialTab);
          updateTabUrl('/admin/inventory', widget.initialTab);
          dispatchTabChanged();
        }
        ref.read(inventoryProvider.notifier).loadAll();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InventoryManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(inventoryProvider.notifier).setActiveTab(widget.initialTab);
        }
      });
    }
  }

  bool get _isDrawerOpen =>
      _inspectItem != null || _inspectMovement != null || _inspectPo != null || _inspectSo != null;

  void _closeDrawer() {
    if (_isDrawerOpen) {
      setState(() {
        _inspectItem = null;
        _inspectMovement = null;
        _inspectPo = null;
        _inspectSo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isDrawerOpen = _isDrawerOpen;
            final isWideDrawer = _inspectPo != null || _inspectSo != null;
            final drawerWidth = isWideDrawer
                ? (screenWidth > 1100 ? 760.0 : (screenWidth > 720 ? 660.0 : screenWidth * 0.96))
                : (screenWidth > 540 ? 460.0 : screenWidth * 0.95);

            return Stack(
              children: [
                // 1. Module Header Bar & Scrollable Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    InventoryHeaderBar(
                      onNewPurchase: _openCreatePoDialog,
                      onCreatePO: _openCreatePoDialog,
                      onCreateSO: _openCreateSoDialog,
                      onReceiveStock: _openReceiveStockDialog,
                      onIssueStock: _openIssueStockDialog,
                      onAdjustStock: _openAdjustStockDialog,
                      onTransferStock: _openTransferStockDialog,
                    ),

                    // Scrollable Area
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(inventoryProvider.notifier).loadAll(),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                              child: InventoryKpiCards(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: InventoryTabsBar(
                                onTabChanged: (tabIndex) {
                                  ref.read(inventoryProvider.notifier).setActiveTab(tabIndex);
                                  updateTabUrl('/admin/inventory', tabIndex);
                                  dispatchTabChanged();
                                },
                              ),
                            ),
                            _buildActiveTabContent(state),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Instant Responsive Right Drawer Slide-Over (Hostel pattern)
                if (isDrawerOpen) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _closeDrawer,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Material(
                      elevation: 16,
                      color: Colors.transparent,
                      child: Container(
                        width: drawerWidth,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(-4, 0),
                            ),
                          ],
                        ),
                        child: _buildDrawerContent(),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(InventoryState state) {
    switch (state.activeTab) {
      case 0:
        return StockOverviewTab(
          onEditItem: (item) => _openCreateEditItemDialog(item: item),
          onViewItem: (item) => _inspectItemDetails(item),
          onNewPurchase: _openCreatePoDialog,
          onAddStock: _openReceiveStockDialog,
          onIssueStock: _openIssueStockDialog,
          onAdjustStock: _openAdjustStockDialog,
          onTransferStock: _openTransferStockDialog,
          onViewAllActivities: () {
            ref.read(inventoryProvider.notifier).setActiveTab(1);
            updateTabUrl('/admin/inventory', 1);
            dispatchTabChanged();
          },
          onViewAllLowStock: () {
            ref.read(inventoryProvider.notifier).setItemStatus('LOW_STOCK');
          },
          onViewActivity: (activityId) {
            ref.read(inventoryProvider.notifier).setActiveTab(1);
            updateTabUrl('/admin/inventory', 1);
            dispatchTabChanged();
          },
        );

      case 1:
        return RecentTransactionsTab(
          onViewTransaction: (tx) => _inspectMovementDetails(tx),
          onReverseTransaction: (tx) => _openReverseTransactionDialog(tx),
          onExportReport: () => _exportCsv('movements'),
          onPrintReport: () => _printReport('Transactions'),
          onViewAllTransactions: () {
            ref.read(inventoryProvider.notifier).setTxType(null);
            ref.read(inventoryProvider.notifier).setTxSearch('');
          },
        );

      case 2:
        return PurchaseOrdersTab(
          onViewOrder: (po) => _inspectPoDetails(po),
          onReceiveGoods: (po) => _openReceiveGrnDialog(po),
          onDownloadOrder: (po) => _downloadPurchaseOrderInvoice(po),
          onEditOrder: (po) => _openEditPoDialog(po),
          onCreateOrder: _openCreatePoDialog,
          onExportReport: () => _exportCsv('purchase-orders'),
          onPrintReport: () => _printReport('Purchase Orders'),
        );

      case 3:
        return SalesOrdersTab(
          onViewOrder: (so) => _inspectSoDetails(so),
          onFulfillOrder: (so) => _fulfillSalesOrder(so),
          onDownloadOrder: (so) => _downloadSalesOrderInvoice(so),
          onEditOrder: (so) => _openEditSoDialog(so),
          onCreateOrder: _openCreateSoDialog,
          onExportReport: () => _exportCsv('sales-orders'),
          onPrintReport: () => _printReport('Sales Orders'),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDrawerContent() {
    if (_inspectItem != null) {
      return InventoryDetailDrawer(
        item: _inspectItem,
        onClose: _closeDrawer,
        onEdit: () {
          final it = _inspectItem;
          _closeDrawer();
          _openCreateEditItemDialog(item: it);
        },
      );
    }
    if (_inspectMovement != null) {
      return InventoryDetailDrawer(
        movement: _inspectMovement,
        onClose: _closeDrawer,
      );
    }
    if (_inspectPo != null) {
      return InventoryDetailDrawer(
        purchaseOrder: _inspectPo,
        onClose: _closeDrawer,
        onEdit: () => _openEditPoDialog(_inspectPo!),
        onDownloadPdf: () => _downloadPurchaseOrderInvoice(_inspectPo!),
      );
    }
    if (_inspectSo != null) {
      return InventoryDetailDrawer(
        salesOrder: _inspectSo,
        onClose: _closeDrawer,
        onEdit: () => _openEditSoDialog(_inspectSo!),
        onDownloadPdf: () => _downloadSalesOrderInvoice(_inspectSo!),
      );
    }
    return const SizedBox.shrink();
  }

  void _inspectItemDetails(InventoryItem item) {
    setState(() {
      _inspectItem = item;
      _inspectMovement = null;
      _inspectPo = null;
      _inspectSo = null;
    });
  }

  void _inspectMovementDetails(InventoryMovement tx) {
    setState(() {
      _inspectMovement = tx;
      _inspectItem = null;
      _inspectPo = null;
      _inspectSo = null;
    });
  }

  void _inspectPoDetails(PurchaseOrder po) {
    setState(() {
      _inspectPo = po;
      _inspectItem = null;
      _inspectMovement = null;
      _inspectSo = null;
    });
  }

  void _inspectSoDetails(SalesOrder so) {
    setState(() {
      _inspectSo = so;
      _inspectItem = null;
      _inspectMovement = null;
      _inspectPo = null;
    });
  }

  void _openCreateEditItemDialog({InventoryItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEditItemDialog(item: item),
    );
  }

  void _openReceiveStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReceiveStockDialog(),
    );
  }

  void _openIssueStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const IssueStockDialog(),
    );
  }

  void _openAdjustStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AdjustStockDialog(),
    );
  }

  void _openTransferStockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TransferStockDialog(),
    );
  }

  void _openCreatePoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreatePurchaseOrderDialog(),
    );
  }

  void _openEditPoDialog(PurchaseOrder po) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditPurchaseOrderDialog(
        purchaseOrder: po,
        onSaved: (updated) {
          setState(() {
            _inspectPo = updated;
          });
        },
      ),
    );
  }

  void _openReceiveGrnDialog(PurchaseOrder po) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiveGrnDialog(po: po),
    );
  }

  void _openCreateSoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateSalesOrderDialog(),
    );
  }

  void _openEditSoDialog(SalesOrder so) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSalesOrderDialog(
        salesOrder: so,
        onSaved: (updated) {
          setState(() {
            _inspectSo = updated;
          });
        },
      ),
    );
  }

  void _openReverseTransactionDialog(InventoryMovement tx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReverseTransactionDialog(movement: tx),
    );
  }

  Future<void> _fulfillSalesOrder(SalesOrder so) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fulfill Sales Order ${so.soNumber}'),
        content: Text('Deliver items to ${so.customerName} and deduct from inventory stock balances?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Delivery', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ref.read(inventoryApiServiceProvider).fulfillSalesOrder(so.soId, 'deliver');
        if (res['success'] == true) {
          ref.read(inventoryProvider.notifier).loadSalesOrders();
          ref.read(inventoryProvider.notifier).loadItems();
          ref.read(inventoryProvider.notifier).loadMovements();
          ref.read(inventoryProvider.notifier).loadOverview();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sales order delivered and stock deducted!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['error'] ?? 'Failed to fulfill order')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _downloadPurchaseOrderInvoice(InventoryPurchaseOrder po) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading Invoice PDF for ${po.poNumber}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      await ref.read(inventoryApiServiceProvider).downloadPurchaseOrderPdf(po.id, po.poNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${po.poNumber}.pdf downloaded successfully.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadSalesOrderInvoice(InventorySalesOrder so) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading Invoice PDF for ${so.soNumber}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      await ref.read(inventoryApiServiceProvider).downloadSalesOrderPdf(so.id, so.soNumber);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${so.soNumber}.pdf downloaded successfully.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCsv(String entity) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preparing $entity report CSV...')),
      );
      final csv = await ref.read(inventoryApiServiceProvider).exportCsv(entity);
      if (csv.isNotEmpty) {
        final filename = 'inventory_${entity}_report.csv';
        await getDownloadHelper().downloadBytes(utf8.encode(csv), filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$filename downloaded successfully.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _printReport(String reportName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing $reportName for print spooler...')),
    );
  }
}
