import '../../../services/api_service.dart';
import '../../../services/lookup_event_bus.dart';
import '../models/inventory_models.dart';

class InventoryLookupHelper {
  static final InventoryLookupHelper instance = InventoryLookupHelper._internal();
  InventoryLookupHelper._internal() {
    LookupEventBus.instance.addListener(() {
      clearCache();
    });
  }

  final ApiService _api = ApiService();
  final Map<String, List<InventoryDropdownItem>> _cache = {};

  Future<List<InventoryDropdownItem>> getLookupItems(
    String keyCode, {
    List<InventoryDropdownItem>? fallbacks,
    bool forceRefresh = false,
  }) async {
    final upperKey = keyCode.toUpperCase().trim();
    if (!forceRefresh && _cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!;
    }

    try {
      final res = await _api.get(
        '/lookups/code/$upperKey',
        query: {'include_inactive': false},
        useCache: false,
      );

      if (res['success'] == true && res['values'] is List) {
        final list = (res['values'] as List)
            .map((e) => InventoryDropdownItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    if (fallbacks != null && fallbacks.isNotEmpty) {
      _cache[upperKey] = fallbacks;
      return fallbacks;
    }

    return [];
  }

  void clearCache([String? keyCode]) {
    if (keyCode != null) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }
}
