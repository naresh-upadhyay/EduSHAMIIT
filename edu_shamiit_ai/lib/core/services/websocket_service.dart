import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service for real-time WebSocket communication
/// Handles live classes, messaging, notifications, and other real-time features
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _serverUrl;
  String? _authToken;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of incoming messages
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of connection status changes
  Stream<bool> get connectionStatus => _connectionController.stream;

  /// Stream of error messages
  Stream<String> get errors => _errorController.stream;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect({
    required String serverUrl,
    required String authToken,
    bool autoReconnect = true,
    Duration reconnectInterval = const Duration(seconds: 5),
  }) async {
    try {
      _serverUrl = serverUrl;
      _authToken = authToken;

      // Build WebSocket URI with auth token
      final uri = Uri.parse(serverUrl).replace(
        queryParameters: {
          'token': authToken,
          'platform': 'flutter',
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      _channel = WebSocketChannel.connect(uri);

      // Listen for incoming messages
      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
          debugPrint('WebSocket connection closed');
          
          if (autoReconnect) {
            _reconnect(reconnectInterval);
          }
        },
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
          _errorController.add(error.toString());
          debugPrint('WebSocket error: $error');
        },
        cancelOnError: false,
      );

      _isConnected = true;
      _connectionController.add(true);
      debugPrint('WebSocket connected to $serverUrl');

    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _errorController.add(e.toString());
      debugPrint('WebSocket connection error: $e');
      
      if (autoReconnect) {
        _reconnect(reconnectInterval);
      }
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
      _channel = null;
      _isConnected = false;
      _connectionController.add(false);
      debugPrint('WebSocket disconnected');
    } catch (e) {
      debugPrint('Error disconnecting WebSocket: $e');
    }
  }

  /// Send a message to the server
  Future<void> send(Map<String, dynamic> message) async {
    if (!_isConnected || _channel == null) {
      throw WebSocketException('Not connected to WebSocket server');
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      _errorController.add('Failed to send message: $e');
      rethrow;
    }
  }

  /// Send a message with acknowledgment
  Future<Map<String, dynamic>?> sendWithAck({
    required String type,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<Map<String, dynamic>?>();
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create subscription for acknowledgment
    late StreamSubscription subscription;
    subscription = messages.listen((message) {
      if (message['ack_id'] == messageId) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(message);
        }
      }
    });

    // Send message with ack_id
    await send({
      'type': type,
      'data': data,
      'ack_id': messageId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Timeout handling
    return completer.future.timeout(timeout, onTimeout: () {
      subscription.cancel();
      return null;
    });
  }

  /// Reconnect to WebSocket server
  Future<void> _reconnect(Duration interval) async {
    debugPrint('Attempting to reconnect in ${interval.inSeconds} seconds...');
    await Future.delayed(interval);
    
    if (_serverUrl != null && _authToken != null) {
      await connect(
        serverUrl: _serverUrl!,
        authToken: _authToken!,
      );
    }
  }

  /// Handle incoming messages
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    switch (type) {
      case 'ping':
        // Respond to ping with pong
        send({'type': 'pong', 'timestamp': DateTime.now().toIso8601String()});
        break;
      
      case 'notification':
        // Handle real-time notification
        _messageController.add(message);
        break;
      
      case 'message':
        // Handle real-time message
        _messageController.add(message);
        break;
      
      case 'live_class_update':
        // Handle live class updates
        _messageController.add(message);
        break;
      
      case 'attendance_update':
        // Handle attendance updates
        _messageController.add(message);
        break;
      
      default:
        _messageController.add(message);
        break;
    }
  }

  // ====== Live Class Features ======

  /// Join a live class
  Future<void> joinLiveClass({
    required String classId,
    required String studentId,
  }) async {
    await send({
      'type': 'join_live_class',
      'data': {
        'class_id': classId,
        'student_id': studentId,
        'joined_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Leave a live class
  Future<void> leaveLiveClass({
    required String classId,
    required String studentId,
  }) async {
    await send({
      'type': 'leave_live_class',
      'data': {
        'class_id': classId,
        'student_id': studentId,
        'left_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Send a message in live class chat
  Future<void> sendLiveClassMessage({
    required String classId,
    required String message,
    required String studentId,
  }) async {
    await send({
      'type': 'live_class_chat',
      'data': {
        'class_id': classId,
        'student_id': studentId,
        'message': message,
        'sent_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// React to live class (emoji, raise hand, etc.)
  Future<void> sendLiveClassReaction({
    required String classId,
    required String reaction,
    required String studentId,
  }) async {
    await send({
      'type': 'live_class_reaction',
      'data': {
        'class_id': classId,
        'student_id': studentId,
        'reaction': reaction,
        'sent_at': DateTime.now().toIso8601String(),
      },
    });
  }

  // ====== Messaging Features ======

  /// Send a direct message
  Future<void> sendMessage({
    required String recipientId,
    required String content,
    required String senderId,
  }) async {
    await send({
      'type': 'direct_message',
      'data': {
        'sender_id': senderId,
        'recipient_id': recipientId,
        'content': content,
        'sent_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Mark message as read
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    await send({
      'type': 'mark_read',
      'data': {
        'message_id': messageId,
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Subscribe to typing indicators
  Future<void> sendTypingIndicator({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    await send({
      'type': 'typing_indicator',
      'data': {
        'conversation_id': conversationId,
        'user_id': userId,
        'is_typing': isTyping,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  // ====== Notification Features ======

  /// Subscribe to real-time notifications
  Future<void> subscribeToNotifications({required String userId}) async {
    await send({
      'type': 'subscribe_notifications',
      'data': {
        'user_id': userId,
        'subscribed_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications({required String userId}) async {
    await send({
      'type': 'unsubscribe_notifications',
      'data': {
        'user_id': userId,
        'unsubscribed_at': DateTime.now().toIso8601String(),
      },
    });
  }

  // ====== Presence Features ======

  /// Update user presence (online/offline)
  Future<void> updatePresence({
    required String userId,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    await send({
      'type': 'presence_update',
      'data': {
        'user_id': userId,
        'status': status, // 'online', 'offline', 'away', 'busy'
        'metadata': metadata ?? {},
        'updated_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Subscribe to user presence updates
  Future<void> subscribeToPresence({required List<String> userIds}) async {
    await send({
      'type': 'subscribe_presence',
      'data': {
        'user_ids': userIds,
        'subscribed_at': DateTime.now().toIso8601String(),
      },
    });
  }

  // ====== Exam Features ======

  /// Start an online exam
  Future<void> startExam({
    required String examId,
    required String studentId,
  }) async {
    await send({
      'type': 'start_exam',
      'data': {
        'exam_id': examId,
        'student_id': studentId,
        'started_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Submit exam answer
  Future<void> submitExamAnswer({
    required String examId,
    required String questionId,
    required String answer,
    required String studentId,
  }) async {
    await send({
      'type': 'submit_answer',
      'data': {
        'exam_id': examId,
        'question_id': questionId,
        'answer': answer,
        'student_id': studentId,
        'submitted_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Submit exam
  Future<void> submitExam({
    required String examId,
    required String studentId,
  }) async {
    await send({
      'type': 'submit_exam',
      'data': {
        'exam_id': examId,
        'student_id': studentId,
        'submitted_at': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Dispose resources
  void dispose() {
    _messageController.close();
    _connectionController.close();
    _errorController.close();
    disconnect();
  }
}

/// Custom exception for WebSocket errors
class WebSocketException implements Exception {
  final String message;
  WebSocketException(this.message);
  @override
  String toString() => 'WebSocketException: $message';
}

/// WebSocket message types
class WebSocketMessageTypes {
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String notification = 'notification';
  static const String message = 'message';
  static const String liveClassUpdate = 'live_class_update';
  static const String attendanceUpdate = 'attendance_update';
  static const String joinLiveClass = 'join_live_class';
  static const String leaveLiveClass = 'leave_live_class';
  static const String liveClassChat = 'live_class_chat';
  static const String liveClassReaction = 'live_class_reaction';
  static const String directMessage = 'direct_message';
  static const String markRead = 'mark_read';
  static const String typingIndicator = 'typing_indicator';
  static const String subscribeNotifications = 'subscribe_notifications';
  static const String unsubscribeNotifications = 'unsubscribe_notifications';
  static const String presenceUpdate = 'presence_update';
  static const String subscribePresence = 'subscribe_presence';
  static const String startExam = 'start_exam';
  static const String submitAnswer = 'submit_answer';
  static const String submitExam = 'submit_exam';
}
