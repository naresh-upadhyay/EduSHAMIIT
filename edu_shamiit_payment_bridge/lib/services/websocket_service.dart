import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _eventController.stream;
  Stream<Map<String, dynamic>> get notificationStream => _eventController.stream;

  void connect() {
    disconnect();
    try {
      final base = ApiService().baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$base/ws?school_id=${ApiService().schoolId}');
      _channel = WebSocketChannel.connect(uri);
      _reconnectAttempts = 0; // Reset backoff on connection attempt

      _channel?.stream.listen(
        (data) {
          try {
            final parsed = json.decode(data.toString());
            _eventController.add(parsed);
          } catch (e) {
            debugPrint('[WS] parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[WS] stream error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] disconnected');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add(json.encode({'type': 'PING'}));
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[WS] Connection exception: $e');
      _scheduleReconnect();
    }
  }

  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 60; // Max 60 seconds

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    // Exponential backoff: 2, 4, 8, 16, 32... capped at 60s
    int delaySeconds = 1 << _reconnectAttempts;
    if (delaySeconds > _maxReconnectDelay) {
      delaySeconds = _maxReconnectDelay;
    }
    
    // Add jitter to prevent thundering herd
    final jitter = (delaySeconds * 0.2 * (DateTime.now().millisecond / 1000)).toInt();
    delaySeconds += jitter;
    
    _reconnectAttempts++;
    debugPrint('[WS] Scheduling reconnect in $delaySeconds seconds (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
