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
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _eventController.stream;

  void connect() {
    disconnect();
    try {
      final base = ApiService().baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
      final uri = Uri.parse('$base/ws?school_id=${ApiService().schoolId}');
      _channel = WebSocketChannel.connect(uri);

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
          debugPrint('[WS] error: $e');
        },
        onDone: () {
          debugPrint('[WS] disconnected');
        },
      );

      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add(json.encode({'type': 'PING'}));
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[WS] Connection exception: $e');
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
