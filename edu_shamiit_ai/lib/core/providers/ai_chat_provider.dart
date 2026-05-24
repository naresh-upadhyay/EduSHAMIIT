import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

// ═══════════════════════════════════════════════════════════
//  Chat Message Model
// ═══════════════════════════════════════════════════════════

enum MessageType { text, image, voice }

class ChatMessage {
  final String id;
  final bool isUser;
  String text;                    // mutable so SSE chunks can append
  final DateTime timestamp;
  final MessageType type;
  final String? imagePath;       // local image path for preview
  final bool isStreaming;        // true while SSE is active

  ChatMessage({
    String? id,
    required this.isUser,
    required this.text,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.imagePath,
    this.isStreaming = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
        id: id,
        isUser: isUser,
        text: text ?? this.text,
        timestamp: timestamp,
        type: type,
        imagePath: imagePath,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ═══════════════════════════════════════════════════════════
//  AI Chat State
// ═══════════════════════════════════════════════════════════

class AiChatState {
  final List<ChatMessage> messages;
  final List<String> suggestions;
  final List<Map<String, dynamic>> sessions;
  final bool isLoading;
  final bool isTyping;
  final bool isRecording;
  final String? error;
  final String sessionId;

  const AiChatState({
    required this.messages,
    required this.suggestions,
    required this.sessions,
    required this.isLoading,
    required this.isTyping,
    required this.isRecording,
    required this.sessionId,
    this.error,
  });

  factory AiChatState.initial() => AiChatState(
        sessionId: const Uuid().v4(),
        messages: [
          ChatMessage(
            isUser: false,
            text: '👋 Hey! I\'m **Shami**, your EduSHAMIIT AI companion.\n\n'
                'I can help you with:\n'
                '• 📅 Your timetable & schedule\n'
                '• 📝 Homework & exam updates\n'
                '• 💰 Fee & payment status\n'
                '• 🚌 Bus tracking\n'
                '• 📚 Academic concepts & questions\n\n'
                'Ask me anything in Hindi or English! 🇮🇳',
          ),
        ],
        suggestions: const [
          '📅 Show my timetable',
          '📝 Pending homework',
          '🚌 Where is my bus?',
          '📚 Exam schedule',
          '💰 Fee status',
        ],
        sessions: const [],
        isLoading: false,
        isTyping: false,
        isRecording: false,
      );

  AiChatState copyWith({
    List<ChatMessage>? messages,
    List<String>? suggestions,
    List<Map<String, dynamic>>? sessions,
    bool? isLoading,
    bool? isTyping,
    bool? isRecording,
    String? error,
    String? sessionId,
  }) =>
      AiChatState(
        messages: messages ?? this.messages,
        suggestions: suggestions ?? this.suggestions,
        sessions: sessions ?? this.sessions,
        isLoading: isLoading ?? this.isLoading,
        isTyping: isTyping ?? this.isTyping,
        isRecording: isRecording ?? this.isRecording,
        sessionId: sessionId ?? this.sessionId,
        error: error,
      );
}

// ═══════════════════════════════════════════════════════════
//  AI Chat Notifier
// ═══════════════════════════════════════════════════════════

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier() : super(AiChatState.initial()) {
    _initChat();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSessionId = prefs.getString('shami_chat_session_id');
    if (savedSessionId != null && savedSessionId.isNotEmpty) {
      state = state.copyWith(sessionId: savedSessionId);
    } else {
      await prefs.setString('shami_chat_session_id', state.sessionId);
    }
    await loadChatHistory();
    await loadSessions();
  }

  // ── Auth helper ────────────────────────────────────────────
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.tokenStorageKey);
  }

  Map<String, String> _authHeaders(String? token, {String contentType = 'application/json'}) => {
        'Content-Type': contentType,
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Load history from server ───────────────────────────────
  Future<void> loadChatHistory() async {
    try {
      state = state.copyWith(isLoading: true);
      final token = await _token();
      if (token == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/chat/history/${state.sessionId}');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] as Map<String, dynamic>?)?['messages'] as List? ?? [];
        if (data.isNotEmpty) {
          final loaded = data.map((m) => ChatMessage(
                isUser: m['role'] == 'user',
                text: (m['content'] as String?) ?? '',
                timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
              )).toList();
          // Prepend the greeting to history
          state = state.copyWith(
            messages: [state.messages.first, ...loaded],
            isLoading: false,
          );
          return;
        } else {
          // If no messages on server, reset list to only contain initial greeting
          state = state.copyWith(
            messages: [state.messages.first],
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Load session list from server ──────────────────────────
  Future<void> loadSessions() async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/sessions');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final list = (body['data']?['sessions'] as List?)
                  ?.map((s) => s as Map<String, dynamic>)
                  .toList() ?? [];
          state = state.copyWith(sessions: list);
        }
      }
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }
  }

  // ── Select and switch to an older session ──────────────────
  Future<void> selectSession(String sessionId) async {
    if (sessionId.isEmpty) return;

    state = state.copyWith(
      sessionId: sessionId,
      messages: [state.messages.first], // Keep initial greeting only
      isLoading: true,
      error: null,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shami_chat_session_id', sessionId);

    await loadChatHistory();
  }

  // ── Start a brand new chat session ─────────────────────────
  Future<void> startNewChat() async {
    final newSessionId = const Uuid().v4();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shami_chat_session_id', newSessionId);

    state = AiChatState.initial().copyWith(
      sessionId: newSessionId,
      sessions: state.sessions,
    );
  }

  // ── Delete a session on the server ─────────────────────────
  Future<void> deleteSession(String sessionId) async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/session/$sessionId');
      final resp = await http.delete(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        if (state.sessionId == sessionId) {
          await startNewChat();
        }
        await loadSessions();
      }
    } catch (e) {
      debugPrint('Error deleting chat session: $e');
    }
  }

  // ── Send text message via SSE stream ──────────────────────
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Append user bubble
    final userMsg = ChatMessage(isUser: true, text: text.trim());
    // 2. Append empty AI bubble that will fill in via SSE
    final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isTyping: true,
      error: null,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/message');

      final request = http.Request('POST', uri)
        ..headers.addAll(_authHeaders(token))
        ..body = jsonEncode({
          'message': text.trim(),
          'session_id': state.sessionId,
        });

      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );

      String accumulated = '';

      await for (final chunk in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!chunk.startsWith('data:')) continue;
        final raw = chunk.substring(5).trim();
        if (raw.isEmpty) continue;

        try {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          final type = parsed['type'] as String? ?? '';
          final content = parsed['content'] as String? ?? '';

          if (type == 'text') {
            accumulated += content;
            _updateLastAiMessage(accumulated, isStreaming: true);
          } else if (type == 'done') {
            _updateLastAiMessage(accumulated, isStreaming: false);
            break;
          } else if (type == 'error') {
            _updateLastAiMessage(
                '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                isStreaming: false);
            break;
          }
        } catch (_) {
          // Silently skip unparseable SSE frames
        }
      }

      // Safety: stop typing indicator even if 'done' was missed
      if (state.isTyping) {
        _updateLastAiMessage(
            accumulated.isNotEmpty ? accumulated : '🤔 No response received.',
            isStreaming: false);
      }
    } catch (e) {
      _updateLastAiMessage(
          '⚠️ Connection error. Please check your internet and try again.',
          isStreaming: false);
      debugPrint('AiChat SSE error: $e');
    } finally {
      await loadSessions();
    }
  }

  void _updateLastAiMessage(String text, {required bool isStreaming}) {
    final msgs = List<ChatMessage>.from(state.messages);
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (!msgs[i].isUser) {
        msgs[i] = msgs[i].copyWith(text: text, isStreaming: isStreaming);
        break;
      }
    }
    state = state.copyWith(messages: msgs, isTyping: isStreaming);
  }

  // ── Send image via multipart upload ───────────────────────
  Future<void> sendImage(File imageFile, {String question = 'Describe this image'}) async {
    final userMsg = ChatMessage(
      isUser: true,
      text: '📷 Image sent',
      type: MessageType.image,
      imagePath: imageFile.path,
    );
    final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isTyping: true,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/image');
      final imageBytes = await imageFile.readAsBytes();
      final filename = imageFile.path.split('/').last.split('\\').last;
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..fields['question'] = question
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ));

      final streamed = await request.send().timeout(AppConfig.apiTimeout);
      final body = await streamed.stream.bytesToString();

      String result = '⚠️ Image analysis failed.';
      try {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        if (parsed['success'] == true) {
          result = (parsed['data']?['analysis'] as String?) ?? result;
        }
      } catch (_) {}

      _updateLastAiMessage(result, isStreaming: false);
    } catch (e) {
      _updateLastAiMessage('⚠️ Could not analyse image: $e', isStreaming: false);
    } finally {
      await loadSessions();
    }
  }

  // ── Send voice recording via multipart upload ─────────────
  Future<void> sendVoice(File audioFile) async {
    final userMsg = ChatMessage(
      isUser: true,
      text: '🎤 Voice message',
      type: MessageType.voice,
    );
    final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isTyping: true,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/voice');
      final audioBytes = await audioFile.readAsBytes();
      final filename = audioFile.path.split('/').last.split('\\').last;
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..fields['session_id'] = state.sessionId
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
        ));

      final streamed = await request.send();
      String accumulated = '';

      await for (final chunk in streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!chunk.startsWith('data:')) continue;
        final raw = chunk.substring(5).trim();
        if (raw.isEmpty) continue;
        try {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          final type = parsed['type'] as String? ?? '';
          final content = parsed['content'] as String? ?? '';
          if (type == 'transcript') {
            // Update the user voice bubble with transcript text
            final msgs = List<ChatMessage>.from(state.messages);
            for (int i = msgs.length - 1; i >= 0; i--) {
              if (msgs[i].isUser && msgs[i].type == MessageType.voice) {
                msgs[i] = msgs[i].copyWith(text: '🎤 "$content"');
                break;
              }
            }
            state = state.copyWith(messages: msgs);
          } else if (type == 'text') {
            accumulated += content;
            _updateLastAiMessage(accumulated, isStreaming: true);
          } else if (type == 'done') {
            _updateLastAiMessage(accumulated, isStreaming: false);
            break;
          }
        } catch (_) {}
      }

      if (state.isTyping) {
        _updateLastAiMessage(
          accumulated.isNotEmpty ? accumulated : '🎤 Could not process audio.',
          isStreaming: false,
        );
      }
    } catch (e) {
      _updateLastAiMessage('⚠️ Voice error: $e', isStreaming: false);
    } finally {
      await loadSessions();
    }
  }

  // ── Suggestion chip shortcut ──────────────────────────────
  Future<void> useSuggestion(String suggestion) => sendMessage(suggestion);

  // ── Clear local + server history ─────────────────────────
  Future<void> clearChat() async {
    state = AiChatState.initial();
  }

  // ── Export ───────────────────────────────────────────────
  String exportChat() {
    final buf = StringBuffer()
      ..writeln('EduSHAMIIT — Shami AI Chat Export')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Session: ${state.sessionId}')
      ..writeln('─' * 40);
    for (final msg in state.messages) {
      final who = msg.isUser ? 'You' : 'Shami';
      buf.writeln('[${msg.formattedTime}] $who: ${msg.text}');
    }
    return buf.toString();
  }
}

// ═══════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) => AiChatNotifier());