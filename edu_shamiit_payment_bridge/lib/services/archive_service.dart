import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArchiveService {
  static final ArchiveService _instance = ArchiveService._internal();
  factory ArchiveService() => _instance;
  ArchiveService._internal();

  static const String _archivedAlertsKey = 'archived_alert_ids_v1';
  static const String _archivedTransactionsKey = 'archived_transaction_ids_v1';

  final Set<String> _archivedAlertIds = {};
  final Set<String> _archivedTransactionIds = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertList = prefs.getStringList(_archivedAlertsKey) ?? [];
      final txList = prefs.getStringList(_archivedTransactionsKey) ?? [];
      _archivedAlertIds.clear();
      _archivedAlertIds.addAll(alertList);
      _archivedTransactionIds.clear();
      _archivedTransactionIds.addAll(txList);
      _initialized = true;
    } catch (e) {
      debugPrint('[ArchiveService] init error: $e');
    }
  }

  // --- ALERTS ARCHIVE ---

  bool isAlertArchived(String id) {
    return _archivedAlertIds.contains(id);
  }

  Set<String> get archivedAlertIds => Set.unmodifiable(_archivedAlertIds);

  Future<void> archiveAlert(String id) async {
    if (id.isEmpty) return;
    await init();
    _archivedAlertIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedAlertsKey, _archivedAlertIds.toList());
  }

  Future<void> unarchiveAlert(String id) async {
    if (id.isEmpty) return;
    await init();
    _archivedAlertIds.remove(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedAlertsKey, _archivedAlertIds.toList());
  }

  // --- TRANSACTIONS ARCHIVE ---

  bool isTransactionArchived(String id) {
    return _archivedTransactionIds.contains(id);
  }

  Set<String> get archivedTransactionIds => Set.unmodifiable(_archivedTransactionIds);

  Future<void> archiveTransaction(String id) async {
    if (id.isEmpty) return;
    await init();
    _archivedTransactionIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedTransactionsKey, _archivedTransactionIds.toList());
  }

  Future<void> unarchiveTransaction(String id) async {
    if (id.isEmpty) return;
    await init();
    _archivedTransactionIds.remove(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_archivedTransactionsKey, _archivedTransactionIds.toList());
  }
}
