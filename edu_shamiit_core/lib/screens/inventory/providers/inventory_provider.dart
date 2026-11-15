import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/lookup_event_bus.dart';
import '../models/inventory_models.dart';
import '../services/inventory_api_service.dart';

class InventoryState {
  final int activeTab; // 0: Stock Items, 1: Recent Transactions, 2: Purchase Orders, 3: Sales Orders
  final bool isLoading;
  final bool isLoadingItems;
  final bool isLoadingTx;
  final bool isLoadingPo;
  final bool isLoadingSo;
  final bool isRefreshing;
  final String? errorMessage;

  final InventoryOverviewData? overview;
  final String overviewInterval;
  final InventoryMetadata? metadata;
  final List<InventoryItem> catalogItems;

  // Tab 1: Stock Items
  final List<InventoryItem> items;
  final int itemsTotal;
  final int itemsPage;
  final int itemsPageSize;
  final String? selectedCategory;
  final String? selectedStoreId;
  final String? selectedStatus;
  final String itemSearchQuery;
  final bool isGridView;
  final String itemsSortBy;
  final bool itemsSortAscending;

  // Tab 2: Recent Transactions
  final List<InventoryMovement> transactions;
  final int transactionsTotal;
  final int transactionsPage;
  final int transactionsPageSize;
  final String? selectedTxType;
  final String? selectedTxItemId;
  final String? selectedTxStoreId;
  final String txSearchQuery;
  final bool isTxChartView;
  final List<dynamic> txChartSummary;
  final List<dynamic> txRecentActivity;
  final List<dynamic> txTypeDistribution;
  final List<dynamic> txTopItems;
  final String txSortBy;
  final bool txSortAscending;

  // Tab 3: Purchase Orders
  final List<InventoryPurchaseOrder> purchaseOrders;
  final int poTotal;
  final int poPage;
  final int poPageSize;
  final String? selectedPoStatus;
  final String? selectedPoSupplierId;
  final String? poStartDate;
  final String? poEndDate;
  final String poSearchQuery;
  final bool isPoChartView;
  final Map<String, dynamic> poKPIs;
  final List<dynamic> poMonthlyTrend;
  final List<dynamic> poStatusDistribution;
  final List<dynamic> poTopSuppliers;
  final String poSortBy;
  final bool poSortAscending;

  // Tab 4: Sales Orders
  final List<InventorySalesOrder> salesOrders;
  final int soTotal;
  final int soPage;
  final int soPageSize;
  final String? selectedSoStatus;
  final String? selectedSoCustomerId;
  final String? soStartDate;
  final String? soEndDate;
  final String soSearchQuery;
  final bool isSoChartView;
  final Map<String, dynamic> soKPIs;
  final List<dynamic> soSalesTrend;
  final List<dynamic> soStatusDistribution;
  final List<dynamic> soTopCustomers;
  final String soSortBy;
  final bool soSortAscending;

  // Drawer / Inspection 360 State
  final InventoryItem? selectedItem;
  final InventoryMovement? selectedMovement;
  final InventoryPurchaseOrder? selectedPO;
  final InventorySalesOrder? selectedSO;
  final bool isDrawerOpen;

  const InventoryState({
    this.activeTab = 0,
    this.isLoading = false,
    this.isLoadingItems = false,
    this.isLoadingTx = false,
    this.isLoadingPo = false,
    this.isLoadingSo = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.overview,
    this.overviewInterval = '6m',
    this.metadata,
    this.catalogItems = const [],
    // Tab 1
    this.items = const [],
    this.itemsTotal = 0,
    this.itemsPage = 1,
    this.itemsPageSize = 5,
    this.selectedCategory,
    this.selectedStoreId,
    this.selectedStatus,
    this.itemSearchQuery = '',
    this.isGridView = false,
    this.itemsSortBy = 'created_at',
    this.itemsSortAscending = false,
    // Tab 2
    this.transactions = const [],
    this.transactionsTotal = 0,
    this.transactionsPage = 1,
    this.transactionsPageSize = 10,
    this.selectedTxType,
    this.selectedTxItemId,
    this.selectedTxStoreId,
    this.txSearchQuery = '',
    this.isTxChartView = false,
    this.txChartSummary = const [],
    this.txRecentActivity = const [],
    this.txTypeDistribution = const [],
    this.txTopItems = const [],
    this.txSortBy = 'created_at',
    this.txSortAscending = false,
    // Tab 3
    this.purchaseOrders = const [],
    this.poTotal = 0,
    this.poPage = 1,
    this.poPageSize = 10,
    this.selectedPoStatus,
    this.selectedPoSupplierId,
    this.poStartDate,
    this.poEndDate,
    this.poSearchQuery = '',
    this.isPoChartView = false,
    this.poKPIs = const {},
    this.poMonthlyTrend = const [],
    this.poStatusDistribution = const [],
    this.poTopSuppliers = const [],
    this.poSortBy = 'order_date',
    this.poSortAscending = false,
    // Tab 4
    this.salesOrders = const [],
    this.soTotal = 0,
    this.soPage = 1,
    this.soPageSize = 10,
    this.selectedSoStatus,
    this.selectedSoCustomerId,
    this.soStartDate,
    this.soEndDate,
    this.soSearchQuery = '',
    this.isSoChartView = false,
    this.soKPIs = const {},
    this.soSalesTrend = const [],
    this.soStatusDistribution = const [],
    this.soTopCustomers = const [],
    this.soSortBy = 'order_date',
    this.soSortAscending = false,
    // Drawer
    this.selectedItem,
    this.selectedMovement,
    this.selectedPO,
    this.selectedSO,
    this.isDrawerOpen = false,
  });

  int get itemPage => itemsPage;
  int get itemPageSize => itemsPageSize;
  int get totalItemsCount => itemsTotal;
  List<InventoryMovement> get movements => transactions;
  int get txPage => transactionsPage;
  int get txPageSize => transactionsPageSize;
  int get totalTxCount => transactionsTotal;
  int get totalPoCount => poTotal;
  int get totalSoCount => soTotal;

  InventoryState copyWith({
    int? activeTab,
    bool? isLoading,
    bool? isLoadingItems,
    bool? isLoadingTx,
    bool? isLoadingPo,
    bool? isLoadingSo,
    bool? isRefreshing,
    String? errorMessage,
    InventoryOverviewData? overview,
    String? overviewInterval,
    InventoryMetadata? metadata,
    List<InventoryItem>? catalogItems,
    // Tab 1
    List<InventoryItem>? items,
    int? itemsTotal,
    int? itemsPage,
    int? itemsPageSize,
    String? selectedCategory,
    bool clearCategory = false,
    String? selectedStoreId,
    bool clearStoreId = false,
    String? selectedStatus,
    bool clearStatus = false,
    String? itemSearchQuery,
    bool? isGridView,
    String? itemsSortBy,
    bool? itemsSortAscending,
    // Tab 2
    List<InventoryMovement>? transactions,
    int? transactionsTotal,
    int? transactionsPage,
    int? transactionsPageSize,
    String? selectedTxType,
    bool clearTxType = false,
    String? selectedTxItemId,
    bool clearTxItemId = false,
    String? selectedTxStoreId,
    bool clearTxStoreId = false,
    String? txSearchQuery,
    bool? isTxChartView,
    List<dynamic>? txChartSummary,
    List<dynamic>? txRecentActivity,
    List<dynamic>? txTypeDistribution,
    List<dynamic>? txTopItems,
    String? txSortBy,
    bool? txSortAscending,
    // Tab 3
    List<InventoryPurchaseOrder>? purchaseOrders,
    int? poTotal,
    int? poPage,
    int? poPageSize,
    String? selectedPoStatus,
    bool clearPoStatus = false,
    String? selectedPoSupplierId,
    bool clearPoSupplierId = false,
    String? poStartDate,
    bool clearPoStartDate = false,
    String? poEndDate,
    bool clearPoEndDate = false,
    String? poSearchQuery,
    bool? isPoChartView,
    Map<String, dynamic>? poKPIs,
    List<dynamic>? poMonthlyTrend,
    List<dynamic>? poStatusDistribution,
    List<dynamic>? poTopSuppliers,
    String? poSortBy,
    bool? poSortAscending,
    // Tab 4
    List<InventorySalesOrder>? salesOrders,
    int? soTotal,
    int? soPage,
    int? soPageSize,
    String? selectedSoStatus,
    bool clearSoStatus = false,
    String? selectedSoCustomerId,
    bool clearSoCustomerId = false,
    String? soStartDate,
    bool clearSoStartDate = false,
    String? soEndDate,
    bool clearSoEndDate = false,
    String? soSearchQuery,
    bool? isSoChartView,
    Map<String, dynamic>? soKPIs,
    List<dynamic>? soSalesTrend,
    List<dynamic>? soStatusDistribution,
    List<dynamic>? soTopCustomers,
    String? soSortBy,
    bool? soSortAscending,
    // Drawer
    InventoryItem? selectedItem,
    InventoryMovement? selectedMovement,
    InventoryPurchaseOrder? selectedPO,
    InventorySalesOrder? selectedSO,
    bool? isDrawerOpen,
    bool clearSelectedItem = false,
    bool clearSelectedMovement = false,
    bool clearSelectedPO = false,
    bool clearSelectedSO = false,
  }) {
    return InventoryState(
      activeTab: activeTab ?? this.activeTab,
      isLoading: isLoading ?? this.isLoading,
      isLoadingItems: isLoadingItems ?? this.isLoadingItems,
      isLoadingTx: isLoadingTx ?? this.isLoadingTx,
      isLoadingPo: isLoadingPo ?? this.isLoadingPo,
      isLoadingSo: isLoadingSo ?? this.isLoadingSo,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      overview: overview ?? this.overview,
      overviewInterval: overviewInterval ?? this.overviewInterval,
      metadata: metadata ?? this.metadata,
      catalogItems: catalogItems ?? this.catalogItems,
      // Tab 1
      items: items ?? this.items,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      itemsPage: itemsPage ?? this.itemsPage,
      itemsPageSize: itemsPageSize ?? this.itemsPageSize,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedStoreId: clearStoreId ? null : (selectedStoreId ?? this.selectedStoreId),
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      itemSearchQuery: itemSearchQuery ?? this.itemSearchQuery,
      isGridView: isGridView ?? this.isGridView,
      itemsSortBy: itemsSortBy ?? this.itemsSortBy,
      itemsSortAscending: itemsSortAscending ?? this.itemsSortAscending,
      // Tab 2
      transactions: transactions ?? this.transactions,
      transactionsTotal: transactionsTotal ?? this.transactionsTotal,
      transactionsPage: transactionsPage ?? this.transactionsPage,
      transactionsPageSize: transactionsPageSize ?? this.transactionsPageSize,
      selectedTxType: clearTxType ? null : (selectedTxType ?? this.selectedTxType),
      selectedTxItemId: clearTxItemId ? null : (selectedTxItemId ?? this.selectedTxItemId),
      selectedTxStoreId: clearTxStoreId ? null : (selectedTxStoreId ?? this.selectedTxStoreId),
      txSearchQuery: txSearchQuery ?? this.txSearchQuery,
      isTxChartView: isTxChartView ?? this.isTxChartView,
      txChartSummary: txChartSummary ?? this.txChartSummary,
      txRecentActivity: txRecentActivity ?? this.txRecentActivity,
      txTypeDistribution: txTypeDistribution ?? this.txTypeDistribution,
      txTopItems: txTopItems ?? this.txTopItems,
      txSortBy: txSortBy ?? this.txSortBy,
      txSortAscending: txSortAscending ?? this.txSortAscending,
      // Tab 3
      purchaseOrders: purchaseOrders ?? this.purchaseOrders,
      poTotal: poTotal ?? this.poTotal,
      poPage: poPage ?? this.poPage,
      poPageSize: poPageSize ?? this.poPageSize,
      selectedPoStatus: clearPoStatus ? null : (selectedPoStatus ?? this.selectedPoStatus),
      selectedPoSupplierId: clearPoSupplierId ? null : (selectedPoSupplierId ?? this.selectedPoSupplierId),
      poStartDate: clearPoStartDate ? null : (poStartDate ?? this.poStartDate),
      poEndDate: clearPoEndDate ? null : (poEndDate ?? this.poEndDate),
      poSearchQuery: poSearchQuery ?? this.poSearchQuery,
      isPoChartView: isPoChartView ?? this.isPoChartView,
      poKPIs: poKPIs ?? this.poKPIs,
      poMonthlyTrend: poMonthlyTrend ?? this.poMonthlyTrend,
      poStatusDistribution: poStatusDistribution ?? this.poStatusDistribution,
      poTopSuppliers: poTopSuppliers ?? this.poTopSuppliers,
      poSortBy: poSortBy ?? this.poSortBy,
      poSortAscending: poSortAscending ?? this.poSortAscending,
      // Tab 4
      salesOrders: salesOrders ?? this.salesOrders,
      soTotal: soTotal ?? this.soTotal,
      soPage: soPage ?? this.soPage,
      soPageSize: soPageSize ?? this.soPageSize,
      selectedSoStatus: clearSoStatus ? null : (selectedSoStatus ?? this.selectedSoStatus),
      selectedSoCustomerId: clearSoCustomerId ? null : (selectedSoCustomerId ?? this.selectedSoCustomerId),
      soStartDate: clearSoStartDate ? null : (soStartDate ?? this.soStartDate),
      soEndDate: clearSoEndDate ? null : (soEndDate ?? this.soEndDate),
      soSearchQuery: soSearchQuery ?? this.soSearchQuery,
      isSoChartView: isSoChartView ?? this.isSoChartView,
      soKPIs: soKPIs ?? this.soKPIs,
      soSalesTrend: soSalesTrend ?? this.soSalesTrend,
      soStatusDistribution: soStatusDistribution ?? this.soStatusDistribution,
      soTopCustomers: soTopCustomers ?? this.soTopCustomers,
      soSortBy: soSortBy ?? this.soSortBy,
      soSortAscending: soSortAscending ?? this.soSortAscending,
      // Drawer
      selectedItem: clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      selectedMovement: clearSelectedMovement ? null : (selectedMovement ?? this.selectedMovement),
      selectedPO: clearSelectedPO ? null : (selectedPO ?? this.selectedPO),
      selectedSO: clearSelectedSO ? null : (selectedSO ?? this.selectedSO),
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(const InventoryState()) {
    init();
    LookupEventBus.instance.addListener(_onLookupEvent);
  }

  void _onLookupEvent() {
    loadMetadata();
    loadCatalogItems();
  }

  @override
  void dispose() {
    LookupEventBus.instance.removeListener(_onLookupEvent);
    super.dispose();
  }

  final InventoryApiService _api = InventoryApiService.instance;
  bool _isInitializing = false;

  Future<void> init([int initialTab = 0]) async {
    if (_isInitializing) return;
    _isInitializing = true;
    state = state.copyWith(activeTab: initialTab);
    try {
      if (initialTab == 0) {
        loadItems();
        loadOverview();
        loadMetadata();
        loadCatalogItems();
        loadTransactions();
        loadPurchaseOrders();
        loadSalesOrders();
      } else if (initialTab == 1) {
        loadTransactions();
        loadMetadata();
        loadCatalogItems();
        loadOverview();
        loadItems();
        loadPurchaseOrders();
        loadSalesOrders();
      } else if (initialTab == 2) {
        loadPurchaseOrders();
        loadMetadata();
        loadCatalogItems();
        loadOverview();
        loadItems();
        loadTransactions();
        loadSalesOrders();
      } else {
        loadSalesOrders();
        loadMetadata();
        loadCatalogItems();
        loadOverview();
        loadItems();
        loadTransactions();
        loadPurchaseOrders();
      }
    } catch (_) {
    } finally {
      state = state.copyWith(isLoading: false);
      _isInitializing = false;
    }
  }

  Future<void> loadAll() async {
    _isInitializing = false;
    await init(state.activeTab);
  }

  void setActiveTab(int tabIndex) {
    state = state.copyWith(activeTab: tabIndex);
    switch (tabIndex) {
      case 0:
        loadItems();
        loadOverview();
        break;
      case 1:
        loadTransactions();
        break;
      case 2:
        loadPurchaseOrders();
        break;
      case 3:
        loadSalesOrders();
        break;
    }
  }

  Future<void> loadOverview({String? interval}) async {
    final effectiveInterval = interval ?? state.overviewInterval;
    final ov = await _api.getOverview(interval: effectiveInterval);
    state = state.copyWith(overview: ov, overviewInterval: effectiveInterval);
  }

  void setOverviewInterval(String interval) {
    loadOverview(interval: interval);
  }

  Future<void> loadMetadata() async {
    final meta = await _api.getMetadata();
    state = state.copyWith(metadata: meta);
    if (state.catalogItems.isEmpty && meta.items.isNotEmpty) {
      final fallbackItems = meta.items.map((m) => InventoryItem(
        id: (m.id != null && m.id!.isNotEmpty) ? m.id! : (m.code.isNotEmpty ? m.code : 'ITEM-${m.name}'),
        sku: m.code.isNotEmpty ? m.code : 'SKU-${m.name}',
        itemName: m.name,
        category: m.category ?? 'Stationery',
        unit: m.unit ?? 'Pcs',
        currentStock: 0,
        minStock: 5,
        purchasePrice: m.purchasePrice ?? 50.0,
        sellingPrice: m.sellingPrice ?? 65.0,
        status: 'IN_STOCK',
      )).toList();
      state = state.copyWith(catalogItems: fallbackItems);
    }
  }

  Future<void> loadCatalogItems({String? search}) async {
    try {
      final items = await _api.getCatalogItems(search: search);
      state = state.copyWith(catalogItems: items);
    } catch (_) {}
  }

  Future<InventoryDropdownItem?> quickAddLookup({
    required String keyCode,
    required String valueName,
    String? description,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final res = await _api.quickAddLookup(
        keyCode: keyCode,
        valueName: valueName,
        description: description,
        extraData: extraData,
      );
      if (res['success'] == true) {
        await loadMetadata();
        LookupEventBus.instance.notifyLookupChanged(keyCode, 'quick_add');
        return InventoryDropdownItem(
          code: res['code']?.toString() ?? '',
          name: res['name']?.toString() ?? valueName,
          id: res['id']?.toString(),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<InventoryItem?> quickAddItem({
    required String itemName,
    String? category,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    String? storeId,
  }) async {
    try {
      final res = await _api.quickAddItem(
        itemName: itemName,
        category: category,
        unit: unit,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        storeId: storeId,
      );
      if (res['success'] == true) {
        await Future.wait([
          loadCatalogItems(),
          loadItems(),
          loadMetadata(),
        ]);
        LookupEventBus.instance.notifyLookupChanged('INVENTORY_ITEMS', 'quick_add_item');
        if (res['item'] is Map) {
          return InventoryItem.fromJson(Map<String, dynamic>.from(res['item'] as Map));
        }
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // TAB 1: ITEMS
  // =========================================================================
  Future<void> loadItems() async {
    state = state.copyWith(isLoadingItems: true);
    try {
      final res = await _api.getItems(
        search: state.itemSearchQuery,
        category: state.selectedCategory,
        storeId: state.selectedStoreId,
        status: state.selectedStatus,
        page: state.itemsPage,
        pageSize: state.itemsPageSize,
        sortBy: state.itemsSortBy,
        sortOrder: state.itemsSortAscending ? 'asc' : 'desc',
      );
      final items = res['items'] as List<InventoryItem>? ?? <InventoryItem>[];
      final total = res['total'] as int? ?? items.length;
      state = state.copyWith(
        items: items,
        itemsTotal: total > 0 ? total : state.itemsTotal,
        isLoadingItems: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingItems: false, isLoading: false);
    }
  }

  void setItemSearch(String query) {
    state = state.copyWith(itemSearchQuery: query, itemsPage: 1);
    loadItems();
  }

  void setItemCategory(String? cat) {
    state = state.copyWith(selectedCategory: cat, clearCategory: cat == null, itemsPage: 1);
    loadItems();
  }

  void setItemStore(String? storeId) {
    state = state.copyWith(selectedStoreId: storeId, clearStoreId: storeId == null, itemsPage: 1);
    loadItems();
  }

  void setItemStatus(String? status) {
    state = state.copyWith(selectedStatus: status, clearStatus: status == null, itemsPage: 1);
    loadItems();
  }

  void setItemPage(int page) {
    state = state.copyWith(itemsPage: page);
    loadItems();
  }

  void setItemPageSize(int size) {
    state = state.copyWith(itemsPageSize: size, itemsPage: 1);
    loadItems();
  }

  void toggleGridView() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  void sortItems(String column) {
    if (state.itemsSortBy == column) {
      state = state.copyWith(itemsSortAscending: !state.itemsSortAscending);
    } else {
      state = state.copyWith(itemsSortBy: column, itemsSortAscending: true);
    }
    loadItems();
  }

  // =========================================================================
  // TAB 2: TRANSACTIONS
  // =========================================================================
  Future<void> loadTransactions() async {
    state = state.copyWith(isLoadingTx: true);
    try {
      final res = await _api.getTransactions(
        search: state.txSearchQuery,
        type: state.selectedTxType,
        itemId: state.selectedTxItemId,
        storeId: state.selectedTxStoreId,
        page: state.transactionsPage,
        pageSize: state.transactionsPageSize,
        sortBy: state.txSortBy,
        sortOrder: state.txSortAscending ? 'asc' : 'desc',
      );
      final txs = res['transactions'] as List<InventoryMovement>? ?? <InventoryMovement>[];
      state = state.copyWith(
        transactions: txs,
        transactionsTotal: res['total'] as int? ?? state.transactionsTotal,
        txChartSummary: res['monthly_summary'] as List? ?? res['chart_summary'] as List? ?? [],
        txRecentActivity: res['recent_activity'] as List? ?? [],
        txTypeDistribution: res['type_distribution'] as List? ?? [],
        txTopItems: res['top_items'] as List? ?? [],
        isLoadingTx: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingTx: false);
    }
  }

  Future<void> loadMovements() => loadTransactions();

  void setTxSearch(String query) {
    state = state.copyWith(txSearchQuery: query, transactionsPage: 1);
    loadTransactions();
  }

  void setTxType(String? type) {
    state = state.copyWith(selectedTxType: type, clearTxType: type == null, transactionsPage: 1);
    loadTransactions();
  }

  void setTxItemId(String? itemId) {
    state = state.copyWith(selectedTxItemId: itemId, clearTxItemId: itemId == null, transactionsPage: 1);
    loadTransactions();
  }

  void setTxStore(String? storeId) {
    state = state.copyWith(selectedTxStoreId: storeId, clearTxStoreId: storeId == null, transactionsPage: 1);
    loadTransactions();
  }

  void setTxDateRange(String? start, String? end) {
    loadTransactions();
  }

  void setTxPage(int page) {
    state = state.copyWith(transactionsPage: page);
    loadTransactions();
  }

  void setTxPageSize(int size) {
    state = state.copyWith(transactionsPageSize: size, transactionsPage: 1);
    loadTransactions();
  }

  void setTxChartView(bool isChart) {
    state = state.copyWith(isTxChartView: isChart);
  }

  void sortTransactions(String column) {
    if (state.txSortBy == column) {
      state = state.copyWith(txSortAscending: !state.txSortAscending);
    } else {
      state = state.copyWith(txSortBy: column, txSortAscending: true);
    }
    loadTransactions();
  }

  // =========================================================================
  // TAB 3: PURCHASE ORDERS
  // =========================================================================
  Future<void> loadPurchaseOrders() async {
    state = state.copyWith(isLoadingPo: true);
    try {
      final res = await _api.getPurchaseOrders(
        search: state.poSearchQuery,
        status: state.selectedPoStatus,
        supplierId: state.selectedPoSupplierId,
        startDate: state.poStartDate,
        endDate: state.poEndDate,
        page: state.poPage,
        pageSize: state.poPageSize,
        sortBy: state.poSortBy,
        sortOrder: state.poSortAscending ? 'asc' : 'desc',
      );
      final pos = res['purchase_orders'] as List<InventoryPurchaseOrder>? ?? <InventoryPurchaseOrder>[];
      state = state.copyWith(
        purchaseOrders: pos,
        poTotal: res['total'] as int? ?? state.poTotal,
        poKPIs: res['kpis'] as Map<String, dynamic>? ?? {},
        poMonthlyTrend: res['purchase_trend'] as List? ?? res['monthly_trend'] as List? ?? [],
        poStatusDistribution: res['status_distribution'] as List? ?? [],
        poTopSuppliers: res['top_suppliers'] as List? ?? [],
        isLoadingPo: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingPo: false);
    }
  }

  void setPoSearch(String query) {
    state = state.copyWith(poSearchQuery: query, poPage: 1);
    loadPurchaseOrders();
  }

  void setPoStatus(String? status) {
    state = state.copyWith(selectedPoStatus: status, clearPoStatus: status == null, poPage: 1);
    loadPurchaseOrders();
  }

  void setPoSupplier(String? supplierId) {
    state = state.copyWith(selectedPoSupplierId: supplierId, clearPoSupplierId: supplierId == null, poPage: 1);
    loadPurchaseOrders();
  }

  void setPoDateRange(String? start, String? end) {
    state = state.copyWith(
      poStartDate: start,
      clearPoStartDate: start == null,
      poEndDate: end,
      clearPoEndDate: end == null,
      poPage: 1,
    );
    loadPurchaseOrders();
  }

  void setPoPage(int page) {
    state = state.copyWith(poPage: page);
    loadPurchaseOrders();
  }

  void setPoPageSize(int size) {
    state = state.copyWith(poPageSize: size, poPage: 1);
    loadPurchaseOrders();
  }

  void setPoChartView(bool isChart) {
    state = state.copyWith(isPoChartView: isChart);
  }

  void sortPurchaseOrders(String column) {
    if (state.poSortBy == column) {
      state = state.copyWith(poSortAscending: !state.poSortAscending);
    } else {
      state = state.copyWith(poSortBy: column, poSortAscending: true);
    }
    loadPurchaseOrders();
  }

  // =========================================================================
  // TAB 4: SALES ORDERS
  // =========================================================================
  Future<void> loadSalesOrders() async {
    state = state.copyWith(isLoadingSo: true);
    try {
      final res = await _api.getSalesOrders(
        search: state.soSearchQuery,
        status: state.selectedSoStatus,
        customer: state.selectedSoCustomerId,
        startDate: state.soStartDate,
        endDate: state.soEndDate,
        page: state.soPage,
        pageSize: state.soPageSize,
        sortBy: state.soSortBy,
        sortOrder: state.soSortAscending ? 'asc' : 'desc',
      );
      final sos = res['sales_orders'] as List<InventorySalesOrder>? ?? <InventorySalesOrder>[];
      state = state.copyWith(
        salesOrders: sos,
        soTotal: res['total'] as int? ?? state.soTotal,
        soKPIs: res['kpis'] as Map<String, dynamic>? ?? {},
        soSalesTrend: res['sales_trend'] as List? ?? [],
        soStatusDistribution: res['status_distribution'] as List? ?? [],
        soTopCustomers: res['top_customers'] as List? ?? [],
        isLoadingSo: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingSo: false);
    }
  }

  void setSoSearch(String query) {
    state = state.copyWith(soSearchQuery: query, soPage: 1);
    loadSalesOrders();
  }

  void setSoStatus(String? status) {
    state = state.copyWith(selectedSoStatus: status, clearSoStatus: status == null, soPage: 1);
    loadSalesOrders();
  }

  void setSoCustomer(String? customer) {
    state = state.copyWith(selectedSoCustomerId: customer, clearSoCustomerId: customer == null, soPage: 1);
    loadSalesOrders();
  }

  void setSoDateRange(String? start, String? end) {
    state = state.copyWith(
      soStartDate: start,
      clearSoStartDate: start == null,
      soEndDate: end,
      clearSoEndDate: end == null,
      soPage: 1,
    );
    loadSalesOrders();
  }

  void setSoPage(int page) {
    state = state.copyWith(soPage: page);
    loadSalesOrders();
  }

  void setSoPageSize(int size) {
    state = state.copyWith(soPageSize: size, soPage: 1);
    loadSalesOrders();
  }

  void setSoChartView(bool isChart) {
    state = state.copyWith(isSoChartView: isChart);
  }

  void sortSalesOrders(String column) {
    if (state.soSortBy == column) {
      state = state.copyWith(soSortAscending: !state.soSortAscending);
    } else {
      state = state.copyWith(soSortBy: column, soSortAscending: true);
    }
    loadSalesOrders();
  }

  // =========================================================================
  // MUTATIONS (CRUD & WORKFLOWS)
  // =========================================================================
  String? lastActionError;

  Future<Map<String, dynamic>> saveItem(Map<String, dynamic> itemData) async {
    final res = await _api.saveItem(itemData);
    if (res['success'] == true) {
      lastActionError = null;
      await loadItems();
      await loadOverview();
      return {'success': true, 'item_id': res['item_id']};
    }
    final err = (res['error'] ?? res['detail'] ?? 'Failed to save item').toString();
    lastActionError = err;
    return {'success': false, 'error': err};
  }

  Future<Map<String, dynamic>> upsertItem(Map<String, dynamic> data) => saveItem(data);

  Future<bool> deleteItem(String itemId) async {
    final res = await _api.deleteItem(itemId);
    if (res['success'] == true) {
      await loadItems();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> receiveStock(Map<String, dynamic> data) async {
    final res = await _api.receiveStock(data);
    if (res['success'] == true) {
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> issueStock(Map<String, dynamic> data) async {
    final res = await _api.issueStock(data);
    if (res['success'] == true) {
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> adjustStock(Map<String, dynamic> data) async {
    final res = await _api.adjustStock(data);
    if (res['success'] == true) {
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> transferStock(Map<String, dynamic> data) async {
    final res = await _api.transferStock(data);
    if (res['success'] == true) {
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> reverseTransaction(String movementId, String reason) async {
    final res = await _api.reverseTransaction(movementId, reason);
    if (res['success'] == true) {
      await loadTransactions();
      await loadItems();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> createPurchaseOrder(Map<String, dynamic> data) async {
    final res = await _api.createPurchaseOrder(data);
    if (res['success'] == true) {
      await loadPurchaseOrders();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> receiveGRN(Map<String, dynamic> data) async {
    final res = await _api.receiveGRN(data);
    if (res['success'] == true) {
      await loadPurchaseOrders();
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> createSalesOrder(Map<String, dynamic> data) async {
    final res = await _api.createSalesOrder(data);
    if (res['success'] == true) {
      await loadSalesOrders();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> fulfillSalesOrder(String soId, [String action = 'deliver']) async {
    final res = await _api.fulfillSalesOrder(soId, action);
    if (res['success'] == true) {
      await loadSalesOrders();
      await loadItems();
      await loadOverview();
      await loadTransactions();
      return true;
    }
    return false;
  }

  Future<bool> cancelPurchaseOrder(String poId, {String? reason}) async {
    final res = await _api.cancelPurchaseOrder(poId, reason: reason);
    if (res['success'] == true) {
      await loadPurchaseOrders();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> cancelSalesOrder(String soId, {String? reason}) async {
    final res = await _api.cancelSalesOrder(soId, reason: reason);
    if (res['success'] == true) {
      await loadSalesOrders();
      await loadItems();
      await loadOverview();
      return true;
    }
    return false;
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});
