import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_academic/core/utils/sse_client_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_academic/core/utils/sse_client_web.dart'
    if (dart.library.io) 'package:edu_shamiit_academic/core/utils/sse_client_mobile.dart';

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
  final bool isLoadingMore;
  final bool isTyping;
  final bool isRecording;
  final String? error;
  final String sessionId;
  final bool hasMoreHistory;
  final int historyOffset;

  const AiChatState({
    required this.messages,
    required this.suggestions,
    required this.sessions,
    required this.isLoading,
    this.isLoadingMore = false,
    required this.isTyping,
    required this.isRecording,
    required this.sessionId,
    this.hasMoreHistory = true,
    this.historyOffset = 0,
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
        isLoadingMore: false,
        isTyping: false,
        isRecording: false,
        hasMoreHistory: true,
        historyOffset: 0,
      );

  AiChatState copyWith({
    List<ChatMessage>? messages,
    List<String>? suggestions,
    List<Map<String, dynamic>>? sessions,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isTyping,
    bool? isRecording,
    String? error,
    String? sessionId,
    bool? hasMoreHistory,
    int? historyOffset,
  }) =>
      AiChatState(
        messages: messages ?? this.messages,
        suggestions: suggestions ?? this.suggestions,
        sessions: sessions ?? this.sessions,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isTyping: isTyping ?? this.isTyping,
        isRecording: isRecording ?? this.isRecording,
        sessionId: sessionId ?? this.sessionId,
        hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
        historyOffset: historyOffset ?? this.historyOffset,
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
    await loadChatHistory(clearExisting: true);
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
  Future<void> loadChatHistory({bool clearExisting = false}) async {
    if (clearExisting) {
      state = state.copyWith(
        isLoading: true,
        historyOffset: 0,
        hasMoreHistory: true,
        messages: [state.messages.first],
      );
    } else {
      if (!state.hasMoreHistory || state.isLoadingMore) return;
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final token = await _token();
      if (token == null) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
        return;
      }

      const int limit = 20;
      final int offset = state.historyOffset;

      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/chat/history/${state.sessionId}?limit=$limit&offset=$offset');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] as Map<String, dynamic>?)?['messages'] as List? ?? [];
        final loaded = data.map((m) => ChatMessage(
              isUser: m['role'] == 'user',
              text: (m['content'] as String?) ?? '',
              timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
            )).toList();

        final bool hasMore = loaded.length >= limit;
        final int newOffset = offset + loaded.length;

        if (clearExisting) {
          state = state.copyWith(
            messages: [state.messages.first, ...loaded],
            historyOffset: newOffset,
            hasMoreHistory: hasMore,
            isLoading: false,
          );
        } else {
          final existing = state.messages.length > 1
              ? state.messages.sublist(1)
              : <ChatMessage>[];
          state = state.copyWith(
            messages: [state.messages.first, ...loaded, ...existing],
            historyOffset: newOffset,
            hasMoreHistory: hasMore,
            isLoadingMore: false,
          );
        }
      } else {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      state = state.copyWith(isLoading: false, isLoadingMore: false);
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
      isLoadingMore: false,
      historyOffset: 0,
      hasMoreHistory: true,
      error: null,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shami_chat_session_id', sessionId);

    await loadChatHistory(clearExisting: true);
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
  Future<void> sendMessage(String text, {bool appendUserBubble = true, String? launchedFrom}) async {
    if (text.trim().isEmpty) return;

    if (appendUserBubble) {
      // 1. Append user bubble
      final userMsg = ChatMessage(isUser: true, text: text.trim());
      // 2. Append empty AI bubble that will fill in via SSE
      final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

      state = state.copyWith(
        messages: [...state.messages, userMsg, aiMsg],
        isTyping: true,
        error: null,
        historyOffset: state.historyOffset + 2,
      );
    } else {
      // Just append empty AI bubble (since user voice bubble already exists)
      final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isTyping: true,
        error: null,
        historyOffset: state.historyOffset + 1,
      );
    }

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/message');
      final client = getSseClient();

      String accumulated = '';
      final completer = Completer<void>();

      await client.sendRequest(
        uri: uri,
        headers: _authHeaders(token),
        body: {
          'message': text.trim(),
          'session_id': state.sessionId,
          if (launchedFrom != null) 'context': launchedFrom,
        },
        onChunk: (chunk) {
          if (!chunk.startsWith('data:')) return;
          final raw = chunk.substring(5).trim();
          if (raw.isEmpty) return;

          try {
            final parsed = jsonDecode(raw) as Map<String, dynamic>;
            final type = parsed['type'] as String? ?? '';
            final content = parsed['content'] as String? ?? '';

            if (type == 'text') {
              accumulated += content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'done') {
              _updateLastAiMessage(accumulated, isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateLastAiMessage(
                  '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                  isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            }
          } catch (_) {
            // Silently skip unparseable SSE frames
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (err) {
          _updateLastAiMessage(
              '⚠️ Connection error: $err',
              isStreaming: false);
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Safety: stop typing indicator even if 'done' was missed
      if (state.isTyping) {
        final hasNoResponse = accumulated.isEmpty;
        _updateLastAiMessage(
            !hasNoResponse ? accumulated : '🤔 No response received.',
            isStreaming: false);
        if (hasNoResponse) {
          _runHistoryPollingFallback(state.sessionId);
        }
      }
    } catch (e) {
      _updateLastAiMessage(
          '⚠️ Connection error. Please check your internet and try again.',
          isStreaming: false);
      debugPrint('AiChat SSE error: $e');
      _runHistoryPollingFallback(state.sessionId);
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
  Future<void> sendImage(XFile imageFile, {String question = 'Describe this image'}) async {
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
      historyOffset: state.historyOffset + 2,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/image');
      final imageBytes = await imageFile.readAsBytes();
      String filename = imageFile.name;
      if (filename.isEmpty || filename == 'image') {
        filename = 'image.png';
      }
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

  // ── Send text and image together via SSE stream ───────────
  Future<void> sendMessageWithImage(String text, XFile imageFile, {String? launchedFrom}) async {
    final displayUserText = text.trim().isNotEmpty ? text.trim() : '📷 Image sent';
    final userMsg = ChatMessage(
      isUser: true,
      text: displayUserText,
      type: MessageType.image,
      imagePath: imageFile.path,
    );
    final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isTyping: true,
      error: null,
      historyOffset: state.historyOffset + 2,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/message');
      final client = getSseClient();

      final imageBytes = await imageFile.readAsBytes();
      final imageB64 = base64Encode(imageBytes);

      String accumulated = '';
      final completer = Completer<void>();

      await client.sendRequest(
        uri: uri,
        headers: _authHeaders(token),
        body: {
          'message': text.trim().isNotEmpty ? text.trim() : 'Describe this image',
          'session_id': state.sessionId,
          'image_b64': imageB64,
          if (launchedFrom != null) 'context': launchedFrom,
        },
        onChunk: (chunk) {
          if (!chunk.startsWith('data:')) return;
          final raw = chunk.substring(5).trim();
          if (raw.isEmpty) return;

          try {
            final parsed = jsonDecode(raw) as Map<String, dynamic>;
            final type = parsed['type'] as String? ?? '';
            final content = parsed['content'] as String? ?? '';

            if (type == 'text') {
              accumulated += content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'done') {
              _updateLastAiMessage(accumulated, isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateLastAiMessage(
                  '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                  isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            }
          } catch (_) {
            // Silently skip unparseable SSE frames
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (err) {
          _updateLastAiMessage(
              '⚠️ Connection error: $err',
              isStreaming: false);
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Safety: stop typing indicator even if 'done' was missed
      if (state.isTyping) {
        final hasNoResponse = accumulated.isEmpty;
        _updateLastAiMessage(
            !hasNoResponse ? accumulated : '🤔 No response received.',
            isStreaming: false);
        if (hasNoResponse) {
          _runHistoryPollingFallback(state.sessionId);
        }
      }
    } catch (e) {
      _updateLastAiMessage(
          '⚠️ Connection error. Please check your internet and try again.',
          isStreaming: false);
      debugPrint('AiChat SSE with image error: $e');
      _runHistoryPollingFallback(state.sessionId);
    } finally {
      await loadSessions();
    }
  }

  // ── Send voice recording ──────────────────────────────────
  // Flow: record audio → POST /chat/voice/transcribe → get text
  //       → sendMessage(text) [exact same flow as typing]
  Future<void> sendVoice(XFile audioFile, {String? locale, String? launchedFrom}) async {
    // Show a "transcribing..." placeholder in the user bubble
    final placeholderMsg = ChatMessage(
      isUser: true,
      text: '🎤 Transcribing...',
      type: MessageType.voice,
    );
    state = state.copyWith(
      messages: [...state.messages, placeholderMsg],
      isTyping: true,
      historyOffset: state.historyOffset + 1,
    );

    try {
      // ── Step 1: Read audio bytes & detect MIME type ────────
      final Uint8List audioBytes;
      String mimeType;
      String filename;

      if (kIsWeb && audioFile.path.startsWith('blob:')) {
        final resp = await http.get(Uri.parse(audioFile.path));
        audioBytes = resp.bodyBytes;
        final rawMime = resp.headers['content-type'] ?? 'audio/webm';
        mimeType = rawMime.split(';').first.trim();
      } else {
        audioBytes = await audioFile.readAsBytes();
        final ext = audioFile.path.split('.').last.toLowerCase();
        const extToMime = {
          'wav': 'audio/wav', 'mp3': 'audio/mpeg',
          'webm': 'audio/webm', 'ogg': 'audio/ogg',
          'm4a': 'audio/m4a', 'mp4': 'audio/mp4',
        };
        mimeType = extToMime[ext] ?? 'audio/m4a';
      }

      // Detect WAV by magic bytes RIFF....WAVE
      if (audioBytes.length >= 12 &&
          audioBytes[0] == 0x52 && audioBytes[1] == 0x49 &&
          audioBytes[2] == 0x46 && audioBytes[3] == 0x46 &&
          audioBytes[8] == 0x57 && audioBytes[9] == 0x41 &&
          audioBytes[10] == 0x56 && audioBytes[11] == 0x45) {
        mimeType = 'audio/wav';
      }

      // Pick filename from mime type
      const mimeToFilename = {
        'audio/wav': 'audio.wav', 'audio/x-wav': 'audio.wav',
        'audio/mpeg': 'audio.mp3', 'audio/mp3': 'audio.mp3',
        'audio/webm': 'audio.webm', 'audio/ogg': 'audio.ogg',
        'audio/mp4': 'audio.m4a', 'audio/m4a': 'audio.m4a',
      };
      filename = mimeToFilename[mimeType] ?? 'audio.m4a';

      // ── Step 2: POST to /chat/voice/transcribe ─────────────
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/voice/transcribe');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ));

      if (locale != null) {
        request.fields['locale'] = locale;
      }

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        // Transcription failed — update bubble and stop
        _replaceLastUserVoiceBubble('🎤 Could not transcribe audio. Please type instead.');
        _updateLastAiMessage(
          '⚠️ Sorry, I could not understand the audio.\n\n'
          'Please try again or just type your message!',
          isStreaming: false,
        );
        return;
      }

      // ── Step 3: Extract transcript ─────────────────────────
      final json = jsonDecode(body) as Map<String, dynamic>;
      final transcript = ((json['data'] as Map?)??{})['transcript'] as String? ?? '';

      if (transcript.trim().isEmpty) {
        _replaceLastUserVoiceBubble('🎤 No speech detected.');
        _updateLastAiMessage(
          "I couldn't hear anything. Please try again!",
          isStreaming: false,
        );
        return;
      }

      // ── Step 4: Show transcript as user bubble ─────────────
      _replaceLastUserVoiceBubble('🎤 "$transcript"');

      // Remove the AI typing placeholder we added above — sendMessage adds its own
      final msgs = List<ChatMessage>.from(state.messages);
      state = state.copyWith(messages: msgs, isTyping: false);

      // ── Step 5: Send transcript as normal text message ─────
      // This reuses the exact same SSE flow as typing
      await sendMessage(transcript, appendUserBubble: false, launchedFrom: launchedFrom);

    } catch (e) {
      _replaceLastUserVoiceBubble('🎤 Voice error');
      _updateLastAiMessage('⚠️ Voice error: $e', isStreaming: false);
      debugPrint('sendVoice error: $e');
    }
  }

  /// Replace the most recent user voice bubble text.
  void _replaceLastUserVoiceBubble(String text) {
    final msgs = List<ChatMessage>.from(state.messages);
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].isUser && msgs[i].type == MessageType.voice) {
        msgs[i] = msgs[i].copyWith(text: text);
        state = state.copyWith(messages: msgs);
        return;
      }
    }
  }

  // ── Suggestion chip shortcut ──────────────────────────────
  Future<void> useSuggestion(String suggestion) => sendMessage(suggestion);

  // ── Clear local + server history ─────────────────────────
  Future<void> clearChat() async {
    state = AiChatState.initial();
  }

  // ── Regenerate AI message ───────────────────────────────
  Future<void> regenerateMessage(ChatMessage aiMsg, {String? launchedFrom}) async {
    final aiIndex = state.messages.indexOf(aiMsg);
    if (aiIndex == -1) return;
    
    // Find the nearest preceding user message
    ChatMessage? userMsg;
    for (int i = aiIndex - 1; i >= 0; i--) {
      if (state.messages[i].isUser) {
        userMsg = state.messages[i];
        break;
      }
    }
    
    if (userMsg == null) return;
    
    String userPrompt = userMsg.text;
    // Clean voice formatting if any (e.g. 🎤 "Hello")
    if (userMsg.type == MessageType.voice && userPrompt.startsWith('🎤 "') && userPrompt.endsWith('"')) {
      userPrompt = userPrompt.substring(4, userPrompt.length - 1);
    }
    
    // Truncate list up to the user message
    final userIndex = state.messages.indexOf(userMsg);
    final keptMessages = state.messages.sublist(0, userIndex + 1);
    
    state = state.copyWith(
      messages: keptMessages,
      isTyping: true,
      error: null,
      historyOffset: keptMessages.length,
    );
    
    // Stream new response
    if (userMsg.imagePath != null) {
      final imageFile = XFile(userMsg.imagePath!);
      final cleanPrompt = userPrompt == '📷 Image sent' ? 'Describe this image' : userPrompt;
      await sendMessageWithImage(cleanPrompt, imageFile, launchedFrom: launchedFrom);
    } else {
      await sendMessage(userPrompt, appendUserBubble: false, launchedFrom: launchedFrom);
    }
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

  // ── Send text and document together via SSE stream ────────
  Future<void> sendMessageWithDocument(String text, PlatformFile docFile, {String? launchedFrom}) async {
    final displayUserText = '📄 [Document: ${docFile.name}]${text.trim().isNotEmpty ? '\n\n${text.trim()}' : ''}';
    final userMsg = ChatMessage(
      isUser: true,
      text: displayUserText,
      type: MessageType.text,
    );
    final aiMsg = ChatMessage(isUser: false, text: '', isStreaming: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiMsg],
      isTyping: true,
      error: null,
      historyOffset: state.historyOffset + 2,
    );

    try {
      final token = await _token();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/message');
      final client = getSseClient();

      final Uint8List docBytes;
      if (kIsWeb) {
        docBytes = docFile.bytes!;
      } else {
        docBytes = await File(docFile.path!).readAsBytes();
      }
      final docB64 = base64Encode(docBytes);

      String accumulated = '';
      final completer = Completer<void>();

      await client.sendRequest(
        uri: uri,
        headers: _authHeaders(token),
        body: {
          'message': text.trim().isNotEmpty ? text.trim() : 'Process this document',
          'session_id': state.sessionId,
          'doc_b64': docB64,
          'doc_name': docFile.name,
          if (launchedFrom != null) 'context': launchedFrom,
        },
        onChunk: (chunk) {
          if (!chunk.startsWith('data:')) return;
          final raw = chunk.substring(5).trim();
          if (raw.isEmpty) return;

          try {
            final parsed = jsonDecode(raw) as Map<String, dynamic>;
            final type = parsed['type'] as String? ?? '';
            final content = parsed['content'] as String? ?? '';

            if (type == 'text') {
              accumulated += content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateLastAiMessage(accumulated, isStreaming: true);
            } else if (type == 'done') {
              _updateLastAiMessage(accumulated, isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateLastAiMessage(
                  '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                  isStreaming: false);
              if (!completer.isCompleted) completer.complete();
            }
          } catch (_) {
            // Silently skip unparseable SSE frames
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (err) {
          _updateLastAiMessage(
              '⚠️ Connection error: $err',
              isStreaming: false);
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Safety: stop typing indicator even if 'done' was missed
      if (state.isTyping) {
        final hasNoResponse = accumulated.isEmpty;
        _updateLastAiMessage(
            !hasNoResponse ? accumulated : '🤔 No response received.',
            isStreaming: false);
        if (hasNoResponse) {
          _runHistoryPollingFallback(state.sessionId);
        }
      }
    } catch (e) {
      _updateLastAiMessage(
          '⚠️ Connection error. Please check your internet and try again.',
          isStreaming: false);
      debugPrint('AiChat SSE with document error: $e');
      _runHistoryPollingFallback(state.sessionId);
    } finally {
      await loadSessions();
    }
  }

  void _runHistoryPollingFallback(String targetSessionId, {int attemptsLeft = 3}) {
    if (attemptsLeft <= 0) return;
    
    Future.delayed(const Duration(seconds: 3), () async {
      // Check if we are still on the same session
      if (state.sessionId != targetSessionId) return;
      
      try {
        final token = await _token();
        if (token == null) return;
        
        final int limit = state.historyOffset > 20 ? state.historyOffset : 20;
        final uri = Uri.parse(
            '${AppConfig.apiBaseUrl}/chat/history/$targetSessionId?limit=$limit&offset=0');
        final resp = await http.get(uri, headers: _authHeaders(token))
            .timeout(const Duration(seconds: 10));
            
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          if (body['success'] == true) {
            final data = (body['data'] as Map<String, dynamic>?)?['messages'] as List? ?? [];
            if (data.isNotEmpty) {
              final loaded = data.map((m) => ChatMessage(
                    isUser: m['role'] == 'user',
                    text: (m['content'] as String?) ?? '',
                    timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
                  )).toList();
              
              if (loaded.isNotEmpty) {
                state = state.copyWith(
                  messages: [state.messages.first, ...loaded],
                  historyOffset: loaded.length,
                  isTyping: false,
                );
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Fallback polling error: $e');
      }
      
      _runHistoryPollingFallback(targetSessionId, attemptsLeft: attemptsLeft - 1);
    });
  }
}

// ═══════════════════════════════════════════════════════════
//  Provider
// ═══════════════════════════════════════════════════════════

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) => AiChatNotifier());
