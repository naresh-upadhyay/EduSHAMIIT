import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../utils/download_helper.dart';
import '../models/inventory_models.dart';

class InventoryApiService {
  static final InventoryApiService instance = InventoryApiService._internal();
  InventoryApiService._internal();

  final ApiService _api = ApiService();

  // 1. Overview & Dashboard
  Future<InventoryOverviewData> getOverview({String interval = '6m'}) async {
    try {
      final res = await _api.get('/v1/inventory/overview', query: {'interval': interval}, useCache: false);
      if (res['success'] == true) {
        return InventoryOverviewData.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return const InventoryOverviewData(kpis: InventoryKPIs());
  }

  // 2. Metadata & Dropdowns
  Future<InventoryMetadata> getMetadata() async {
    try {
      final res = await _api.get('/v1/inventory/metadata', useCache: false);
      if (res['success'] == true) {
        return InventoryMetadata.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return const InventoryMetadata();
  }

  // 3b. Catalog Items (Full Unpaginated List for Dropdowns)
  Future<List<InventoryItem>> getCatalogItems({String? search}) async {
    try {
      final query = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      final res = await _api.get('/v1/inventory/catalog-items', query: query, useCache: false);
      if (res['success'] == true && res['items'] is List) {
        return (res['items'] as List)
            .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return <InventoryItem>[];
  }

  // 3c. Quick Add Lookup Value (Suppliers, Stores, Customers, Categories, Units)
  Future<Map<String, dynamic>> quickAddLookup({
    required String keyCode,
    required String valueName,
    String? description,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final payload = {
        'key_code': keyCode,
        'value_name': valueName,
        if (description != null) 'description': description,
        if (extraData != null) 'extra_data': extraData,
      };
      return await _api.post('/v1/inventory/lookups/quick-add', payload);
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
      return {'success': false, 'error': msg};
    }
  }

  // 3d. Quick Add Item on the fly
  Future<Map<String, dynamic>> quickAddItem({
    required String itemName,
    String? category,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    String? storeId,
  }) async {
    try {
      final payload = {
        'item_name': itemName,
        if (category != null) 'category': category,
        if (unit != null) 'unit': unit,
        if (purchasePrice != null) 'purchase_price': purchasePrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        if (storeId != null) 'store_id': storeId,
      };
      return await _api.post('/v1/inventory/items/quick-add', payload);
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
      return {'success': false, 'error': msg};
    }
  }

  // 3. Inventory Items (List, Search, Filter, Pagination)
  Future<Map<String, dynamic>> getItems({
    String? search,
    String? category,
    String? storeId,
    String? status,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (category != null && category != 'All Categories' && category != 'All') {
        query['category'] = category;
      }
      if (storeId != null && storeId != 'All Stores' && storeId != 'All') {
        query['store_id'] = storeId;
      }
      if (status != null && status != 'All Status' && status != 'All') {
        query['status'] = status;
      }

      final res = await _api.get('/v1/inventory/items', query: query, useCache: false);
      if (res['success'] == true && res['items'] is List) {
        final items = (res['items'] as List)
            .map((e) => InventoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'items': items,
          'total': (res['total'] as num?)?.toInt() ?? items.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
        };
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[InventoryApiService] getItems error: $e\n$st');
    }
    return {'items': <InventoryItem>[], 'total': 0, 'total_pages': 1};
  }

  // Create or Update Item
  Future<Map<String, dynamic>> saveItem(Map<String, dynamic> itemData) async {
    try {
      if (itemData['item_id'] != null || (itemData['id'] != null && itemData['id'].toString().isNotEmpty)) {
        final itemId = (itemData['item_id'] ?? itemData['id']).toString();
        return await _api.put('/v1/inventory/items/$itemId', itemData);
      } else {
        return await _api.post('/v1/inventory/items', itemData);
      }
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
      return {'success': false, 'error': msg};
    }
  }

  // Delete / Deactivate Item
  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    try {
      return await _api.delete('/v1/inventory/items/$itemId');
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stock Operations: Receive, Issue, Adjust, Transfer
  Future<Map<String, dynamic>> receiveStock(Map<String, dynamic> data) async {
    try {
      return await _api.post('/v1/inventory/receive', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> issueStock(Map<String, dynamic> data) async {
    try {
      return await _api.post('/v1/inventory/issue', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adjustStock(Map<String, dynamic> data) async {
    try {
      return await _api.post('/v1/inventory/adjust', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> transferStock(Map<String, dynamic> data) async {
    try {
      return await _api.post('/v1/inventory/transfer', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 4. Recent Transactions / Stock Ledger
  Future<Map<String, dynamic>> getTransactions({
    String? search,
    String? type,
    String? itemId,
    String? storeId,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (type != null && type != 'All Types' && type != 'All') {
        query['type'] = type;
      }
      if (itemId != null && itemId != 'All Items' && itemId != 'All') {
        query['item_id'] = itemId;
      }
      if (storeId != null && storeId != 'All Locations' && storeId != 'All') {
        query['store_id'] = storeId;
      }
      if (startDate != null && startDate.isNotEmpty) {
        query['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        query['end_date'] = endDate;
      }

      final res = await _api.get('/v1/inventory/transactions', query: query, useCache: false);
      if (res['success'] == true && res['transactions'] is List) {
        final txs = (res['transactions'] as List)
            .map((e) => InventoryMovement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'transactions': txs,
          'total': (res['total'] as num?)?.toInt() ?? txs.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'chart_summary': res['monthly_summary'] ?? res['chart_summary'] ?? [],
          'monthly_summary': res['monthly_summary'] ?? res['chart_summary'] ?? [],
          'type_distribution': res['type_distribution'] ?? [],
          'top_items': res['top_items'] ?? [],
          'recent_activity': res['recent_activity'] ?? [],
        };
      }
    } catch (_) {}
    return {
      'transactions': <InventoryMovement>[],
      'total': 0,
      'total_pages': 1,
      'chart_summary': [],
      'recent_activity': [],
    };
  }

  Future<Map<String, dynamic>> reverseTransaction(String movementId, String reason) async {
    try {
      return await _api.post('/v1/inventory/transactions/$movementId/reverse', {'reason': reason});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 5. Purchase Orders
  Future<Map<String, dynamic>> getPurchaseOrders({
    String? search,
    String? status,
    String? supplierId,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (status != null && status != 'All Status' && status != 'All') {
        query['status'] = status;
      }
      if (supplierId != null && supplierId != 'All Suppliers' && supplierId != 'All') {
        query['supplier_id'] = supplierId;
      }
      if (startDate != null && startDate.isNotEmpty) {
        query['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        query['end_date'] = endDate;
      }

      final res = await _api.get('/v1/inventory/purchase-orders', query: query, useCache: false);
      if (res['success'] == true && res['purchase_orders'] is List) {
        final pos = (res['purchase_orders'] as List)
            .map((e) => InventoryPurchaseOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'purchase_orders': pos,
          'total': (res['total'] as num?)?.toInt() ?? pos.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'kpis': res['kpis'] ?? {},
          'monthly_trend': res['purchase_trend'] ?? res['monthly_trend'] ?? [],
          'purchase_trend': res['purchase_trend'] ?? res['monthly_trend'] ?? [],
          'status_distribution': res['status_distribution'] ?? [],
          'top_suppliers': res['top_suppliers'] ?? [],
        };
      }
    } catch (_) {}
    return {
      'purchase_orders': <InventoryPurchaseOrder>[],
      'total': 0,
      'total_pages': 1,
      'kpis': {},
      'monthly_trend': [],
    };
  }

  Future<Map<String, dynamic>> createPurchaseOrder(
    Map<String, dynamic> orderData, [
    List<Map<String, dynamic>>? items,
  ]) async {
    try {
      final payload = Map<String, dynamic>.from(orderData);
      if (items != null) payload['items'] = items;
      return await _api.post('/v1/inventory/purchase-orders', payload);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPurchaseOrder(String poId) async {
    try {
      return await _api.get('/v1/inventory/purchase-orders/$poId', useCache: false);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePurchaseOrder(String poId, Map<String, dynamic> data) async {
    try {
      return await _api.put('/v1/inventory/purchase-orders/$poId', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> receiveGoodsReceipt(
    String poId,
    Map<String, dynamic> grnData, [
    List<Map<String, dynamic>>? items,
  ]) async {
    try {
      final payload = Map<String, dynamic>.from(grnData);
      payload['items'] = items ?? [];
      return await _api.post('/v1/inventory/purchase-orders/$poId/receive', payload);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> receiveGRN(Map<String, dynamic> data) async {
    final poId = data['po_id']?.toString() ?? '';
    return receiveGoodsReceipt(poId, data);
  }

  Future<Map<String, dynamic>> cancelPurchaseOrder(String poId, {String? reason}) async {
    try {
      return await _api.post(
        '/v1/inventory/purchase-orders/$poId/cancel',
        {'reason': reason ?? 'Cancelled by authority'},
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 6. Sales Orders
  Future<Map<String, dynamic>> getSalesOrders({
    String? search,
    String? status,
    String? customer,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (sortBy != null && sortBy.isNotEmpty) {
        query['sort_by'] = sortBy;
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        query['sort_order'] = sortOrder;
      }
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (status != null && status != 'All Status' && status != 'All') {
        query['status'] = status;
      }
      if (customer != null && customer != 'All Customers' && customer != 'All') {
        query['customer'] = customer;
      }
      if (startDate != null && startDate.isNotEmpty) {
        query['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        query['end_date'] = endDate;
      }

      final res = await _api.get('/v1/inventory/sales-orders', query: query, useCache: false);
      if (res['success'] == true && res['sales_orders'] is List) {
        final sos = (res['sales_orders'] as List)
            .map((e) => InventorySalesOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return {
          'sales_orders': sos,
          'total': (res['total'] as num?)?.toInt() ?? sos.length,
          'total_pages': (res['total_pages'] as num?)?.toInt() ?? 1,
          'kpis': res['kpis'] ?? {},
          'sales_trend': res['sales_trend'] ?? [],
          'status_distribution': res['status_distribution'] ?? [],
          'top_customers': res['top_customers'] ?? [],
        };
      }
    } catch (_) {}
    return {
      'sales_orders': <InventorySalesOrder>[],
      'total': 0,
      'total_pages': 1,
      'kpis': {},
      'sales_trend': [],
    };
  }

  Future<Map<String, dynamic>> createSalesOrder(
    Map<String, dynamic> orderData, [
    List<Map<String, dynamic>>? items,
  ]) async {
    try {
      final payload = Map<String, dynamic>.from(orderData);
      if (items != null) payload['items'] = items;
      return await _api.post('/v1/inventory/sales-orders', payload);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getSalesOrder(String soId) async {
    try {
      return await _api.get('/v1/inventory/sales-orders/$soId', useCache: false);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateSalesOrder(String soId, Map<String, dynamic> data) async {
    try {
      return await _api.put('/v1/inventory/sales-orders/$soId', data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fulfillSalesOrder(String soId, [String action = 'deliver']) async {
    try {
      return await _api.post('/v1/inventory/sales-orders/$soId/fulfill', {'action': action});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelSalesOrder(String soId, {String? reason}) async {
    try {
      return await _api.post(
        '/v1/inventory/sales-orders/$soId/cancel',
        {'reason': reason ?? 'Cancelled by authority'},
      );
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 6. PDF Invoice Downloads
  Future<void> downloadPurchaseOrderPdf(String poId, String poNumber) async {
    final bytes = await _api.getBytes('/v1/inventory/purchase-orders/$poId/pdf');
    final filename = 'Invoice-${poNumber.isNotEmpty ? poNumber : poId}.pdf';
    await getDownloadHelper().downloadBytes(bytes, filename);
  }

  Future<void> downloadSalesOrderPdf(String soId, String soNumber) async {
    final bytes = await _api.getBytes('/v1/inventory/sales-orders/$soId/pdf');
    final filename = 'Invoice-${soNumber.isNotEmpty ? soNumber : soId}.pdf';
    await getDownloadHelper().downloadBytes(bytes, filename);
  }

  // 7. CSV Export
  Future<String> exportCsv(String entity, {List<String>? selectedIds}) async {
    final query = <String, dynamic>{};
    if (selectedIds != null && selectedIds.isNotEmpty) {
      query['ids'] = selectedIds.join(',');
    }
    return await _api.getString('/v1/inventory/export/$entity', query: query.isNotEmpty ? query : null);
  }
}

final inventoryApiServiceProvider = Provider<InventoryApiService>((ref) {
  return InventoryApiService.instance;
});
