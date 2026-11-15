import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../../config/app_config.dart';

class WhiteboardWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _whiteboardId;
  bool _manualDisconnect = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  DateTime _lastCursorSent = DateTime.fromMillisecondsSinceEpoch(0);

  void Function(Map<String, dynamic> event)? onEvent;
  void Function(bool connected)? onConnectionChanged;

  bool get isConnected => _isConnected && _channel != null;

  Future<void> connect(String whiteboardId) async {
    _manualDisconnect = false;
    _whiteboardId = whiteboardId;
    await _closeChannelOnly();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        _isConnected = false;
        onConnectionChanged?.call(false);
        return;
      }

      final wsBase = AppConfig.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final uri = Uri.parse('$wsBase/ws/whiteboards/$whiteboardId?token=${Uri.encodeQueryComponent(token)}');

      _channel = WebSocketChannel.connect(uri);

      // Listen safely with error and disconnect handling
      _sub = _channel!.stream.listen(
        (raw) {
          if (!_isConnected) {
            _isConnected = true;
            onConnectionChanged?.call(true);
            _reconnectAttempts = 0;
          }
          try {
            final decoded = jsonDecode(raw.toString());
            if (decoded is Map<String, dynamic>) {
              onEvent?.call(decoded);
            }
          } catch (e) {
            debugPrint('[WhiteboardWS] Decode error: $e');
          }
        },
        onDone: _handleDisconnect,
        onError: (err) {
          debugPrint('[WhiteboardWS] Stream error: $err');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Wait for socket to become ready, but do not crash if it fails
      try {
        await _channel!.ready.timeout(const Duration(seconds: 4));
        _isConnected = true;
        onConnectionChanged?.call(true);
        _reconnectAttempts = 0;
      } catch (readyErr) {
        debugPrint('[WhiteboardWS] Socket ready timeout/fail: $readyErr');
        // Do not throw; listen onError/onDone will handle or next message will promote
      }

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        sendRaw({'event_type': 'ping'});
      });
    } catch (e) {
      debugPrint('[WhiteboardWS] Connect failed: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    final oldChannel = _channel;
    _channel = null;
    try {
      oldChannel?.sink.close();
    } catch (_) {}
    _closeChannelOnly();
    onConnectionChanged?.call(false);

    if (_manualDisconnect || _whiteboardId == null) return;
    if (_reconnectAttempts >= 5) {
      debugPrint('[WhiteboardWS] Max reconnect attempts (5) reached. Stopping.');
      return;
    }
    _reconnectAttempts++;
    final delaySec = (_reconnectAttempts * 2).clamp(2, 20);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_manualDisconnect && _whiteboardId != null) {
        connect(_whiteboardId!);
      }
    });
  }

  void sendRaw(Map<String, dynamic> msg) {
    if (!_isConnected || _channel == null) return;
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('[WhiteboardWS] Send error: $e');
    }
  }

  void sendCursorMoved({
    required String pageId,
    required double x,
    required double y,
    required String tool,
    bool isLaser = false,
  }) {
    final now = DateTime.now();
    if (now.difference(_lastCursorSent).inMilliseconds < 45) return;
    _lastCursorSent = now;
    sendRaw({
      'event_type': isLaser ? 'laser.moved' : 'cursor.moved',
      'page_id': pageId,
      'x': x,
      'y': y,
      'tool': tool,
    });
  }

  void sendPageChanged(String pageId, int pageOrder) {
    sendRaw({
      'event_type': 'page.changed',
      'page_id': pageId,
      'page_order': pageOrder,
    });
  }

  void sendStrokePreview({
    required String pageId,
    required String eventType,
    required String tempId,
    required List<List<double>> points,
    required String colorHex,
    required double strokeWidth,
    required bool isHighlighter,
  }) {
    sendRaw({
      'event_type': eventType,
      'page_id': pageId,
      'payload': {
        'id': tempId,
        'points': points,
        'color': colorHex,
        'strokeWidth': strokeWidth,
        'type': isHighlighter ? 'highlighter' : 'stroke',
      },
    });
  }

  void sendOperation({
    required String pageId,
    required String operationId,
    required String operationType,
    String? objectId,
    String? objectType,
    required Map<String, dynamic> payload,
  }) {
    sendRaw({
      'event_type': 'operation',
      'page_id': pageId,
      'operation_id': operationId,
      'operation_type': operationType,
      if (objectId != null) 'object_id': objectId,
      if (objectType != null) 'object_type': objectType,
      'payload': payload,
    });
  }

  Future<void> _closeChannelOnly() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> dispose() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeChannelOnly();
  }
}
