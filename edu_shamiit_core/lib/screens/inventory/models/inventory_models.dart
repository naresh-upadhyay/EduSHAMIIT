import 'package:intl/intl.dart';
/// Representation of dynamic dropdown lookup options
class InventoryDropdownItem {
  final String code;
  final String name;
  final String? id;
  final String? category;
  final String? unit;
  final double? purchasePrice;
  final double? sellingPrice;

  const InventoryDropdownItem({
    required this.code,
    required this.name,
    this.id,
    this.category,
    this.unit,
    this.purchasePrice,
    this.sellingPrice,
  });

  String get lookupCode => code;
  String get lookupValue => name;
  String get storeId => id ?? code;
  String get storeName => name;
  String get supplierId => id ?? code;
  String get supplierName => name;

  factory InventoryDropdownItem.fromJson(Map<String, dynamic> json) {
    return InventoryDropdownItem(
      code: json['code']?.toString() ??
          json['value_code']?.toString() ??
          json['lookup_code']?.toString() ??
          json['sku']?.toString() ??
          json['id']?.toString() ??
          '',
      name: json['name']?.toString() ??
          json['label']?.toString() ??
          json['value_name']?.toString() ??
          json['lookup_value']?.toString() ??
          json['store_name']?.toString() ??
          json['supplier_name']?.toString() ??
          json['customer_name']?.toString() ??
          json['item_name']?.toString() ??
          '',
      id: json['id']?.toString() ??
          json['item_id']?.toString() ??
          json['store_id']?.toString() ??
          json['supplier_id']?.toString() ??
          json['customer_id']?.toString(),
      category: json['category']?.toString(),
      unit: json['unit']?.toString(),
      purchasePrice: json['purchase_price'] != null ? double.tryParse(json['purchase_price'].toString()) : null,
      sellingPrice: json['selling_price'] != null ? double.tryParse(json['selling_price'].toString()) : null,
    );
  }
}

/// Dynamic metadata received from universal lookups and database
class InventoryMetadata {
  final List<InventoryDropdownItem> categories;
  final List<InventoryDropdownItem> units;
  final List<InventoryDropdownItem> stores;
  final List<InventoryDropdownItem> suppliers;
  final List<InventoryDropdownItem> customers;
  final List<InventoryDropdownItem> transactionTypes;
  final List<InventoryDropdownItem> purchaseStatuses;
  final List<InventoryDropdownItem> salesStatuses;
  final List<InventoryDropdownItem> itemStatuses;
  final List<InventoryDropdownItem> adjustmentReasons;
  final List<InventoryDropdownItem> items;

  const InventoryMetadata({
    this.categories = const [],
    this.units = const [],
    this.stores = const [],
    this.suppliers = const [],
    this.customers = const [],
    this.transactionTypes = const [],
    this.purchaseStatuses = const [],
    this.salesStatuses = const [],
    this.itemStatuses = const [],
    this.adjustmentReasons = const [],
    this.items = const [],
  });

  List<InventoryDropdownItem> get itemCategories => categories;
  List<InventoryDropdownItem> get unitsOfMeasurement => units;
  List<InventoryDropdownItem> get movementTypes => transactionTypes;
  List<InventoryDropdownItem> get catalogItems => items;

  factory InventoryMetadata.fromJson(Map<String, dynamic> json) {
    List<InventoryDropdownItem> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => InventoryDropdownItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      return [];
    }

    final cats = parseList(json['categories'] ?? json['item_categories']);
    final uoms = parseList(json['units'] ?? json['units_of_measurement']);
    final strs = parseList(json['stores']);
    final sups = parseList(json['suppliers']);
    final custs = parseList(json['customers']);
    final txs = parseList(json['transaction_types'] ?? json['movement_types']);
    final pStats = parseList(json['purchase_statuses']);
    final sStats = parseList(json['sales_statuses']);
    final iStats = parseList(json['item_statuses']);
    final adjReasons = parseList(json['adjustment_reasons']);
    final itemsList = parseList(json['items']);

    return InventoryMetadata(
      categories: cats,
      units: uoms,
      stores: strs,
      suppliers: sups,
      customers: custs,
      transactionTypes: txs,
      purchaseStatuses: pStats,
      salesStatuses: sStats,
      itemStatuses: iStats,
      adjustmentReasons: adjReasons,
      items: itemsList,
    );
  }
}

/// KPI Cards data
class InventoryKPIs {
  final int totalItems;
  final String totalItemsGrowth;
  final double totalStockValue;
  final String totalStockValueGrowth;
  final double pendingPurchase;
  final String pendingPurchaseGrowth;
  final int lowStockItems;
  final String lowStockGrowth;
  final int outOfStockItems;
  final double totalStockQty;
  final double availableQty;
  final double reservedQty;

  const InventoryKPIs({
    this.totalItems = 286,
    this.totalItemsGrowth = '+12%',
    this.totalStockValue = 3365570.0,
    this.totalStockValueGrowth = '+8%',
    this.pendingPurchase = 653700.0,
    this.pendingPurchaseGrowth = '+5%',
    this.lowStockItems = 13,
    this.lowStockGrowth = '+2%',
    this.outOfStockItems = 0,
    this.totalStockQty = 35103.0,
    this.availableQty = 35103.0,
    this.reservedQty = 0.0,
  });

  factory InventoryKPIs.fromJson(Map<String, dynamic> json) {
    return InventoryKPIs(
      totalItems: (json['total_items'] as num?)?.toInt() ?? 286,
      totalItemsGrowth: json['total_items_growth']?.toString() ?? '+12%',
      totalStockValue: (json['total_stock_value'] as num?)?.toDouble() ?? 3365570.0,
      totalStockValueGrowth: json['total_stock_value_growth']?.toString() ?? '+8%',
      pendingPurchase: (json['pending_purchase'] as num?)?.toDouble() ?? 653700.0,
      pendingPurchaseGrowth: json['pending_purchase_growth']?.toString() ?? '+5%',
      lowStockItems: (json['low_stock_items'] as num?)?.toInt() ?? 13,
      lowStockGrowth: json['low_stock_growth']?.toString() ?? '+2%',
      outOfStockItems: (json['out_of_stock_items'] as num?)?.toInt() ?? 0,
      totalStockQty: (json['total_stock_qty'] as num?)?.toDouble() ?? 35103.0,
      availableQty: (json['available_qty'] as num?)?.toDouble() ?? 35103.0,
      reservedQty: (json['reserved_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Category distribution item for donut chart
class InventoryCategoryStock {
  final String category;
  final double percentage;
  final String colorHex;
  final int itemCount;

  const InventoryCategoryStock({
    required this.category,
    required this.percentage,
    required this.colorHex,
    required this.itemCount,
  });

  factory InventoryCategoryStock.fromJson(Map<String, dynamic> json) {
    return InventoryCategoryStock(
      category: json['category']?.toString() ?? 'General',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color']?.toString() ?? '#2563EB',
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Low stock alert item
class InventoryLowStockAlert {
  final String id;
  final String itemName;
  final String category;
  final double currentStock;
  final int minStock;
  final String unit;
  final String? imageUrl;
  final String alertText;
  final String sku;
  final String severity;

  const InventoryLowStockAlert({
    required this.id,
    required this.itemName,
    required this.category,
    required this.currentStock,
    required this.minStock,
    required this.unit,
    this.imageUrl,
    required this.alertText,
    this.sku = '',
    this.severity = 'warning',
  });

  bool get isOutOfStock => currentStock <= 0;

  factory InventoryLowStockAlert.fromJson(Map<String, dynamic> json) {
    return InventoryLowStockAlert(
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? 10,
      unit: json['unit']?.toString() ?? 'Pcs',
      imageUrl: json['image_url']?.toString(),
      alertText: json['alert_text']?.toString() ?? 'Low Stock',
      sku: json['sku']?.toString() ?? '',
      severity: json['severity']?.toString() ?? ((((json['current_stock'] as num?)?.toDouble() ?? 0.0) <= 0) ? 'critical' : 'warning'),
    );
  }
}

/// Recent activity item
class InventoryActivityItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String timeStr;
  final String dotColor;

  const InventoryActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timeStr,
    required this.dotColor,
  });

  factory InventoryActivityItem.fromJson(Map<String, dynamic> json) {
    return InventoryActivityItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Stock In',
      title: json['title']?.toString() ?? '',
      subtitle: json['description']?.toString() ?? json['subtitle']?.toString() ?? '',
      timeStr: json['formatted_time']?.toString() ?? json['time_str']?.toString() ?? 'Today',
      dotColor: json['color']?.toString() ?? json['dot_color']?.toString() ?? '#2563EB',
    );
  }
}

/// Monthly stock trend point
class InventoryMonthlyTrend {
  final String month;
  final double totalStock;
  final double issued;

  const InventoryMonthlyTrend({
    required this.month,
    required this.totalStock,
    required this.issued,
  });

  factory InventoryMonthlyTrend.fromJson(Map<String, dynamic> json) {
    return InventoryMonthlyTrend(
      month: json['month']?.toString() ?? '',
      totalStock: (json['total_stock'] as num?)?.toDouble() ?? 0.0,
      issued: (json['issued'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Complete Overview Data
class InventoryOverviewData {
  final InventoryKPIs kpis;
  final List<InventoryCategoryStock> categoryStock;
  final List<InventoryLowStockAlert> lowStockAlerts;
  final List<InventoryActivityItem> recentActivities;
  final List<InventoryMonthlyTrend> monthlyTrend;
  final int dynamicTotalPurchaseOrders;
  final double dynamicTotalPurchaseValue;
  final int dynamicPendingPurchaseOrders;
  final int dynamicTotalSalesOrders;
  final int dynamicCompletedSalesOrders;
  final int dynamicPendingSalesOrders;
  final double dynamicTotalSalesValue;

  const InventoryOverviewData({
    required this.kpis,
    this.categoryStock = const [],
    this.lowStockAlerts = const [],
    this.recentActivities = const [],
    this.monthlyTrend = const [],
    this.dynamicTotalPurchaseOrders = 0,
    this.dynamicTotalPurchaseValue = 0.0,
    this.dynamicPendingPurchaseOrders = 0,
    this.dynamicTotalSalesOrders = 0,
    this.dynamicCompletedSalesOrders = 0,
    this.dynamicPendingSalesOrders = 0,
    this.dynamicTotalSalesValue = 0.0,
  });

  int get totalItems => kpis.totalItems;
  double get totalStockValue => kpis.totalStockValue;
  double get pendingPurchaseValue => kpis.pendingPurchase;
  int get lowStockItems => kpis.lowStockItems;
  int get outOfStockItems => kpis.outOfStockItems;
  int get totalPurchaseOrders => dynamicTotalPurchaseOrders > 0 ? dynamicTotalPurchaseOrders : 72;
  double get totalPurchaseValue => dynamicTotalPurchaseValue > 0 ? dynamicTotalPurchaseValue : 2729800.0;
  int get pendingPurchaseOrders => dynamicPendingPurchaseOrders > 0 ? dynamicPendingPurchaseOrders : 10;
  int get totalSalesOrders => dynamicTotalSalesOrders > 0 ? dynamicTotalSalesOrders : 186;
  int get completedSalesOrders => dynamicCompletedSalesOrders > 0 ? dynamicCompletedSalesOrders : 147;
  int get pendingSalesOrders => dynamicPendingSalesOrders > 0 ? dynamicPendingSalesOrders : 10;
  double get totalSalesValue => dynamicTotalSalesValue > 0 ? dynamicTotalSalesValue : 6498875.0;

  factory InventoryOverviewData.fromJson(Map<String, dynamic> json) {
    final kpisRaw = json['kpis'] as Map<String, dynamic>? ?? {};
    final catList = (json['category_stock'] as List?)
            ?.map((e) => InventoryCategoryStock.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final alertsList = (json['low_stock_alerts'] as List?)
            ?.map((e) => InventoryLowStockAlert.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final actsList = (json['recent_activities'] as List?)
            ?.map((e) => InventoryActivityItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final trendList = (json['monthly_trend'] as List?)
            ?.map((e) => InventoryMonthlyTrend.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    final totalPo = (json['total_purchase_orders'] as num?)?.toInt() ?? 0;
    final totalPoVal = (json['total_purchase_value'] as num?)?.toDouble() ?? 0.0;
    final pendingPo = (json['pending_purchase_orders'] as num?)?.toInt() ?? 0;
    final totalSo = (json['total_sales_orders'] as num?)?.toInt() ?? 0;
    final compSo = (json['completed_sales_orders'] as num?)?.toInt() ?? 0;
    final pendingSo = (json['pending_sales_orders'] as num?)?.toInt() ?? 0;
    final totalSoVal = (json['total_sales_value'] as num?)?.toDouble() ?? 0.0;

    return InventoryOverviewData(
      kpis: InventoryKPIs.fromJson(kpisRaw),
      categoryStock: catList,
      lowStockAlerts: alertsList,
      recentActivities: actsList,
      monthlyTrend: trendList,
      dynamicTotalPurchaseOrders: totalPo,
      dynamicTotalPurchaseValue: totalPoVal,
      dynamicPendingPurchaseOrders: pendingPo,
      dynamicTotalSalesOrders: totalSo,
      dynamicCompletedSalesOrders: compSo,
      dynamicPendingSalesOrders: pendingSo,
      dynamicTotalSalesValue: totalSoVal,
    );
  }
}

/// Single Inventory Item Master Record
class InventoryItem {
  final String id;
  final String sku;
  final String? barcode;
  final String itemName;
  final String? description;
  final String category;
  final String unit;
  final double currentStock;
  final int minStock;
  final int maxStock;
  final double purchasePrice;
  final double sellingPrice;
  final double averageCost;
  final double taxRate;
  final String? imageUrl;
  final String status;
  final String? preferredStoreId;
  final String? defaultSupplierId;
  final String itemType;
  final String trackingMethod;
  final String? brand;
  final String? modelNumber;
  final DateTime? createdAt;

  const InventoryItem({
    required this.id,
    required this.sku,
    this.barcode,
    required this.itemName,
    this.description,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    this.maxStock = 1000,
    required this.purchasePrice,
    required this.sellingPrice,
    this.averageCost = 0.0,
    this.taxRate = 18.0,
    this.imageUrl,
    required this.status,
    this.preferredStoreId,
    this.defaultSupplierId,
    this.itemType = 'Consumable',
    this.trackingMethod = 'Quantity-based',
    this.brand,
    this.modelNumber,
    this.createdAt,
  });

  String get itemId => id;
  String get name => itemName;
  String get categoryName => category;
  String get categoryCode => category;
  String get uomCode => unit;
  String get uomName => unit;
  String get stockStatus => status;
  double get minStockLevel => minStock.toDouble();
  double get maxStockLevel => maxStock.toDouble();
  double get reorderQuantity => (minStock * 1.5);

  bool get isLowStock => currentStock <= minStock && currentStock > 0;
  bool get isOutOfStock => currentStock <= 0;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id']?.toString() ?? json['item_id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString(),
      itemName: json['item_name']?.toString() ?? json['name']?.toString() ?? 'Unknown Item',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? json['category_code']?.toString() ?? 'Stationery',
      unit: json['unit']?.toString() ?? json['uom_code']?.toString() ?? 'Pcs',
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? (json['min_stock_level'] as num?)?.toInt() ?? 10,
      maxStock: (json['max_stock'] as num?)?.toInt() ?? (json['max_stock_level'] as num?)?.toInt() ?? 1000,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0.0,
      averageCost: (json['average_cost'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18.0,
      imageUrl: json['image_url']?.toString(),
      status: json['status']?.toString() ?? json['stock_status']?.toString() ?? 'In Stock',
      preferredStoreId: json['preferred_store_id']?.toString(),
      defaultSupplierId: json['default_supplier_id']?.toString(),
      itemType: json['item_type']?.toString() ?? 'Consumable',
      trackingMethod: json['tracking_method']?.toString() ?? 'Quantity-based',
      brand: json['brand']?.toString(),
      modelNumber: json['model_number']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

/// Single Stock Movement / Transaction Ledger Row
class InventoryMovement {
  final String id;
  final String movementNumber;
  final String dateTime;
  final String? createdAtRaw;
  final String transactionType;
  final String itemId;
  final String itemName;
  final String sku;
  final double quantity;
  final String quantityFormatted;
  final String unit;
  final double rate;
  final double total;
  final String location;
  final String remarks;
  final String? referenceType;
  final String? referenceId;
  final double previousBalance;
  final double resultingBalance;
  final bool isReversed;

  const InventoryMovement({
    required this.id,
    required this.movementNumber,
    required this.dateTime,
    this.createdAtRaw,
    required this.transactionType,
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.quantity,
    required this.quantityFormatted,
    required this.unit,
    required this.rate,
    required this.total,
    required this.location,
    required this.remarks,
    this.referenceType,
    this.referenceId,
    this.previousBalance = 0.0,
    this.resultingBalance = 0.0,
    this.isReversed = false,
  });

  String get movementId => id;
  String get movementType => transactionType;
  double get unitCost => rate;
  double get totalCost => total;
  String get storeName => location;
  String? get referenceNumber => movementNumber;
  String? get notes => remarks;
  DateTime? get movementDate {
    if (createdAtRaw != null && createdAtRaw!.isNotEmpty) {
      final normalized = createdAtRaw!.replaceFirst(RegExp(r'\+00$'), '+00:00');
      final dt = DateTime.tryParse(normalized);
      if (dt != null) return dt;
    }
    if (dateTime.isNotEmpty) {
      final dt = DateTime.tryParse(dateTime);
      if (dt != null) return dt;
    }
    return null;
  }
  bool get isStockIn => isPositive;
  bool get isPositive => quantity >= 0;

  String get formattedDateTime {
    if (movementDate != null) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(movementDate!);
    }
    if (dateTime.isNotEmpty) return dateTime;
    return '-';
  }

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: json['id']?.toString() ?? json['movement_id']?.toString() ?? '',
      movementNumber: json['movement_number']?.toString() ?? json['reference_number']?.toString() ?? '',
      dateTime: json['date_time']?.toString() ??
          ((json['date'] != null && json['time'] != null) ? '${json['date']} ${json['time']}' : null) ??
          json['movement_date']?.toString() ??
          '',
      createdAtRaw: json['created_at_raw']?.toString() ?? json['created_at']?.toString(),
      transactionType: json['transaction_type']?.toString() ?? json['movement_type']?.toString() ?? 'Stock In',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      quantityFormatted: json['quantity_formatted']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Pcs',
      rate: (json['rate'] as num?)?.toDouble() ?? (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      location: json['location']?.toString() ?? json['store_name']?.toString() ?? 'Main Store',
      remarks: json['remarks']?.toString() ?? json['notes']?.toString() ?? '',
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      previousBalance: (json['previous_balance'] as num?)?.toDouble() ?? 0.0,
      resultingBalance: (json['resulting_balance'] as num?)?.toDouble() ?? 0.0,
      isReversed: json['is_reversed'] == true,
    );
  }
}

/// Format an amount into English Indian numbering system words (e.g. Rupees Four Hundred Only)
String formatIndianCurrencyWords(double amount) {
  final amt = amount.toInt();
  if (amt == 0) return 'Rupees Zero Only';

  final ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];
  final tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  String twoDigits(int n) {
    if (n < 20) return ones[n];
    return tens[n ~/ 10] + (n % 10 != 0 ? ' ${ones[n % 10]}' : '');
  }

  String threeDigits(int n) {
    String res = '';
    if (n >= 100) {
      res += '${ones[n ~/ 100]} Hundred ';
      n %= 100;
    }
    if (n > 0) {
      res += twoDigits(n);
    }
    return res.trim();
  }

  int remaining = amt;
  final parts = <String>[];
  final crores = remaining ~/ 10000000;
  if (crores > 0) {
    parts.add('${threeDigits(crores)} Crore');
    remaining %= 10000000;
  }
  final lakhs = remaining ~/ 100000;
  if (lakhs > 0) {
    parts.add('${threeDigits(lakhs)} Lakh');
    remaining %= 100000;
  }
  final thousands = remaining ~/ 1000;
  if (thousands > 0) {
    parts.add('${threeDigits(thousands)} Thousand');
    remaining %= 1000;
  }
  if (remaining > 0) {
    parts.add(threeDigits(remaining));
  }

  return 'Rupees ${parts.join(' ')} Only';
}

/// Line item within a Purchase Order
class PurchaseOrderItem {
  final String poItemId;
  final String itemId;
  final String itemName;
  final String sku;
  final String unit;
  final double quantity;
  final double receivedQuantity;
  final double unitPrice;
  final double taxRate;
  final double lineTotal;
  final double totalPrice;

  const PurchaseOrderItem({
    required this.poItemId,
    required this.itemId,
    required this.itemName,
    this.sku = '',
    this.unit = 'Pcs',
    required this.quantity,
    this.receivedQuantity = 0.0,
    required this.unitPrice,
    this.taxRate = 18.0,
    required this.totalPrice,
    double? lineTotal,
  }) : lineTotal = lineTotal ?? totalPrice;

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? (json['quantity_ordered'] as num?)?.toDouble() ?? 0.0;
    final price = (json['unit_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0;
    final total = (json['line_total'] as num?)?.toDouble() ?? (json['total_price'] as num?)?.toDouble() ?? (qty * price);

    return PurchaseOrderItem(
      poItemId: json['po_item_id']?.toString() ?? json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? 'Standard Item',
      sku: json['sku']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Pcs',
      quantity: qty,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? (json['quantity_received'] as num?)?.toDouble() ?? 0.0,
      unitPrice: price,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18.0,
      totalPrice: total,
      lineTotal: total,
    );
  }
}

/// Single Purchase Order Row
class InventoryPurchaseOrder {
  final String id;
  final String poNumber;
  final String date;
  final String? dateRaw;
  final String? supplierId;
  final String supplier;
  final String supplierGstin;
  final String? storeId;
  final String department;
  final String shippingAddress;
  final String paymentTerms;
  final int itemsCount;
  final String itemsText;
  final double subtotal;
  final double taxAmount;
  final double shippingAmount;
  final double totalAmount;
  final String status;
  final String deliveryDate;
  final String? deliveryDateRaw;
  final String? notes;
  final String? termsConditions;
  final List<PurchaseOrderItem> items;

  const InventoryPurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.date,
    this.dateRaw,
    this.supplierId,
    required this.supplier,
    this.supplierGstin = '29AAACG1234F1Z8',
    this.storeId,
    this.department = 'Administration',
    this.shippingAddress = 'Main Campus Store, Greenwood High',
    this.paymentTerms = 'Net 30 Days',
    required this.itemsCount,
    required this.itemsText,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.shippingAmount = 0.0,
    required this.totalAmount,
    required this.status,
    required this.deliveryDate,
    this.deliveryDateRaw,
    this.notes,
    this.termsConditions,
    this.items = const [],
  });

  String get poId => id;
  String get supplierName => supplier;
  String get amountInWords => formatIndianCurrencyWords(totalAmount);
  DateTime? get orderDate => DateTime.tryParse(dateRaw ?? '') ?? DateTime.tryParse(date);
  DateTime? get expectedDeliveryDate => DateTime.tryParse(deliveryDateRaw ?? '') ?? DateTime.tryParse(deliveryDate);

  String get formattedOrderDate {
    if (orderDate != null) {
      return DateFormat('dd MMM yyyy').format(orderDate!);
    }
    if (date.isNotEmpty && date != 'N/A') return date;
    return '-';
  }

  String get formattedDeliveryDate {
    if (expectedDeliveryDate != null) {
      return DateFormat('dd MMM yyyy').format(expectedDeliveryDate!);
    }
    if (deliveryDate.isNotEmpty && deliveryDate != 'N/A') return deliveryDate;
    return 'N/A';
  }

  factory InventoryPurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List?;
    final itemsList = rawItems != null
        ? rawItems.map((e) => PurchaseOrderItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <PurchaseOrderItem>[];

    final total = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final sub = (json['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (json['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final ship = (json['shipping_amount'] as num?)?.toDouble() ?? 0.0;

    return InventoryPurchaseOrder(
      id: json['id']?.toString() ?? json['po_id']?.toString() ?? '',
      poNumber: json['po_number']?.toString() ?? '',
      date: json['date']?.toString() ?? json['order_date']?.toString() ?? '',
      dateRaw: json['order_date_raw']?.toString() ?? json['order_date']?.toString(),
      supplierId: json['supplier_id']?.toString(),
      supplier: json['supplier']?.toString() ?? json['supplier_name']?.toString() ?? 'Supplier',
      supplierGstin: json['supplier_gstin']?.toString() ?? '29AAACG1234F1Z8',
      storeId: json['store_id']?.toString(),
      department: json['department']?.toString() ?? 'Administration',
      shippingAddress: json['shipping_address']?.toString() ?? 'Main Campus Store, Greenwood High',
      paymentTerms: json['payment_terms']?.toString() ?? 'Net 30 Days',
      itemsCount: (json['items_count'] as num?)?.toInt() ?? itemsList.length,
      itemsText: json['items_text']?.toString() ?? '',
      subtotal: sub,
      taxAmount: tax,
      shippingAmount: ship,
      totalAmount: total,
      status: json['status']?.toString() ?? 'Pending',
      deliveryDate: json['delivery_date']?.toString() ?? json['expected_delivery_date']?.toString() ?? 'N/A',
      deliveryDateRaw: json['delivery_date_raw']?.toString() ?? json['delivery_date']?.toString() ?? json['expected_delivery_date']?.toString(),
      notes: json['notes']?.toString(),
      termsConditions: json['terms_conditions']?.toString(),
      items: itemsList,
    );
  }
}

typedef PurchaseOrder = InventoryPurchaseOrder;

/// Line item within a Sales Order
class SalesOrderItem {
  final String soItemId;
  final String itemId;
  final String itemName;
  final String sku;
  final String unit;
  final double quantity;
  final double deliveredQuantity;
  final double unitPrice;
  final double taxRate;
  final double lineTotal;
  final double totalPrice;

  const SalesOrderItem({
    required this.soItemId,
    required this.itemId,
    required this.itemName,
    this.sku = '',
    this.unit = 'Pcs',
    required this.quantity,
    this.deliveredQuantity = 0.0,
    required this.unitPrice,
    this.taxRate = 5.0,
    required this.totalPrice,
    double? lineTotal,
  }) : lineTotal = lineTotal ?? totalPrice;

  factory SalesOrderItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? (json['quantity_ordered'] as num?)?.toDouble() ?? 0.0;
    final price = (json['unit_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0;
    final total = (json['line_total'] as num?)?.toDouble() ?? (json['total_price'] as num?)?.toDouble() ?? (qty * price);

    return SalesOrderItem(
      soItemId: json['so_item_id']?.toString() ?? json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? 'Standard Item',
      sku: json['sku']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Pcs',
      quantity: qty,
      deliveredQuantity: (json['delivered_quantity'] as num?)?.toDouble() ?? (json['quantity_fulfilled'] as num?)?.toDouble() ?? 0.0,
      unitPrice: price,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 5.0,
      totalPrice: total,
      lineTotal: total,
    );
  }
}

/// Single Sales Order Row
class InventorySalesOrder {
  final String id;
  final String soNumber;
  final String date;
  final String? dateRaw;
  final String customer;
  final String? customerId;
  final String customerType;
  final String customerGstin;
  final String? contactPhone;
  final String? contactEmail;
  final String? storeId;
  final String department;
  final String shippingAddress;
  final String paymentTerms;
  final int itemsCount;
  final String itemsText;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final String deliveryDate;
  final String? deliveryDateRaw;
  final String? notes;
  final String? termsConditions;
  final List<SalesOrderItem> items;

  const InventorySalesOrder({
    required this.id,
    required this.soNumber,
    required this.date,
    this.dateRaw,
    required this.customer,
    this.customerId,
    this.customerType = 'Partner School',
    this.customerGstin = '29AAACG1234F1Z8',
    this.contactPhone,
    this.contactEmail,
    this.storeId,
    this.department = 'Sales & Distribution',
    this.shippingAddress = 'Bangalore Center Distribution',
    this.paymentTerms = 'Due on Receipt',
    required this.itemsCount,
    required this.itemsText,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    required this.totalAmount,
    required this.status,
    required this.deliveryDate,
    this.deliveryDateRaw,
    this.notes,
    this.termsConditions,
    this.items = const [],
  });

  String get soId => id;
  String get customerName => customer;
  String get amountInWords => formatIndianCurrencyWords(totalAmount);
  DateTime? get orderDate => DateTime.tryParse(dateRaw ?? '') ?? DateTime.tryParse(date);
  DateTime? get expectedDeliveryDate => DateTime.tryParse(deliveryDateRaw ?? '') ?? DateTime.tryParse(deliveryDate);

  String get formattedOrderDate {
    if (orderDate != null) {
      return DateFormat('dd MMM yyyy').format(orderDate!);
    }
    if (date.isNotEmpty && date != 'N/A') return date;
    return '-';
  }

  String get formattedDeliveryDate {
    if (expectedDeliveryDate != null) {
      return DateFormat('dd MMM yyyy').format(expectedDeliveryDate!);
    }
    if (deliveryDate.isNotEmpty && deliveryDate != 'N/A') return deliveryDate;
    return 'N/A';
  }

  factory InventorySalesOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List?;
    final itemsList = rawItems != null
        ? rawItems.map((e) => SalesOrderItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <SalesOrderItem>[];

    final total = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final sub = (json['subtotal'] as num?)?.toDouble() ?? total;
    final tax = (json['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final disc = (json['discount_amount'] as num?)?.toDouble() ?? 0.0;

    return InventorySalesOrder(
      id: json['id']?.toString() ?? json['so_id']?.toString() ?? '',
      soNumber: json['so_number']?.toString() ?? '',
      date: json['date']?.toString() ?? json['order_date']?.toString() ?? '',
      dateRaw: json['order_date_raw']?.toString() ?? json['order_date']?.toString(),
      customer: json['customer']?.toString() ?? json['customer_name']?.toString() ?? 'Customer',
      customerId: json['customer_id']?.toString(),
      customerType: json['customer_type']?.toString() ?? 'Partner School',
      customerGstin: json['customer_gstin']?.toString() ?? '29AAACG1234F1Z8',
      contactPhone: json['contact_phone']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      storeId: json['store_id']?.toString(),
      department: json['department']?.toString() ?? 'Sales & Distribution',
      shippingAddress: json['shipping_address']?.toString() ?? 'Bangalore Center Distribution',
      paymentTerms: json['payment_terms']?.toString() ?? 'Due on Receipt',
      itemsCount: (json['items_count'] as num?)?.toInt() ?? itemsList.length,
      itemsText: json['items_text']?.toString() ?? '',
      subtotal: sub,
      taxAmount: tax,
      discountAmount: disc,
      totalAmount: total,
      status: json['status']?.toString() ?? 'Pending',
      deliveryDate: json['delivery_date']?.toString() ?? json['expected_delivery_date']?.toString() ?? 'N/A',
      deliveryDateRaw: json['delivery_date_raw']?.toString() ?? json['delivery_date']?.toString() ?? json['expected_delivery_date']?.toString(),
      notes: json['notes']?.toString(),
      termsConditions: json['terms_conditions']?.toString(),
      items: itemsList,
    );
  }
}

typedef SalesOrder = InventorySalesOrder;
