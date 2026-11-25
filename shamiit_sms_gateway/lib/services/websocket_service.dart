import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/platform_bridge.dart';
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _nativeSub;
  int _reconnectAttempts = 0;
  bool isConnected = false;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _eventController.stream;

  void connect() {
    disconnect();
    _nativeSub ??= PlatformBridge.nativeEvents.listen((event) {
      _eventController.add(event);
    });

    try {
      final base = ApiService()
          .baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$base/sms-gateway/ws?school_id=${ApiService().schoolId}');
      _channel = WebSocketChannel.connect(uri);
      isConnected = true;
      _reconnectAttempts = 0;

      _channel?.stream.listen(
        (data) {
          try {
            final parsed = json.decode(data.toString());
            if (parsed is Map) {
              _eventController.add(Map<String, dynamic>.from(parsed));
            }
          } catch (e) {
            debugPrint('[SMS WS] parse error: $e');
          }
        },
        onError: (_) {
          isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add(json.encode({'type': 'PING'}));
        } catch (_) {}
      });
    } catch (_) {
      isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    var delay = 1 << _reconnectAttempts;
    if (delay > 60) delay = 60;
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    isConnected = false;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
