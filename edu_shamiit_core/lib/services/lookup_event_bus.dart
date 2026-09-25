import 'package:flutter/foundation.dart';

/// Event model representing a lookup key or value mutation.
class LookupChangeEvent {
  final String? keyCode;
  final String? action; // 'create', 'update', 'delete', 'reorder', 'import', etc.
  final DateTime timestamp;

  LookupChangeEvent({this.keyCode, this.action}) : timestamp = DateTime.now();

  @override
  String toString() => 'LookupChangeEvent(keyCode: $keyCode, action: $action, timestamp: $timestamp)';
}

/// Global reactive event bus for cross-module lookup cache invalidation and UI updates.
class LookupEventBus extends ChangeNotifier {
  static final LookupEventBus instance = LookupEventBus._internal();
  LookupEventBus._internal();

  LookupChangeEvent? _lastEvent;
  LookupChangeEvent? get lastEvent => _lastEvent;

  /// Notify all registered modules (Academics, HR, Admissions, etc.) that lookup data has changed.
  void notifyLookupChanged([String? keyCode, String? action]) {
    _lastEvent = LookupChangeEvent(keyCode: keyCode, action: action);
    notifyListeners();
  }
}
