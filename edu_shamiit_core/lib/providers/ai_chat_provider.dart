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
import '../utils/sse_client.dart';

// ═══════════════════════════════════════════════════════════
//  Chat Message Model
// ═══════════════════════════════════════════════════════════

enum MessageType { text, image, voice }

class ScratchpadStep {
  final String title;
  final String detail;
  final String stage; // 'thinking', 'planning', 'tool_running', 'tool_done', 'synthesizing', 'fallback', 'done'
  final DateTime timestamp;

  ScratchpadStep({
    required this.title,
    this.detail = '',
    this.stage = 'thinking',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    'stage': stage,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ScratchpadStep.fromJson(Map<String, dynamic> json) => ScratchpadStep(
    title: json['title'] as String? ?? 'Thinking',
    detail: json['detail'] as String? ?? '',
    stage: json['stage'] as String? ?? 'thinking',
    timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
  );
}

class ChatMessage {
  final String id;
  final bool isUser;
  String text;                    // mutable so SSE chunks can append
  final DateTime timestamp;
  final MessageType type;
  final String? imagePath;       // local image path for preview
  final bool isStreaming;        // true while SSE is active
  int feedbackRating;            // 0 = none, 1 = like, -1 = dislike
  final String? sessionId;
  final List<ScratchpadStep> scratchpadSteps;
  final bool isThinking;

  ChatMessage({
    String? id,
    required this.isUser,
    required this.text,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.imagePath,
    this.isStreaming = false,
    this.feedbackRating = 0,
    this.sessionId,
    List<ScratchpadStep>? scratchpadSteps,
    this.isThinking = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        scratchpadSteps = scratchpadSteps ?? [];

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    int? feedbackRating,
    String? sessionId,
    List<ScratchpadStep>? scratchpadSteps,
    bool? isThinking,
  }) => ChatMessage(
        id: id,
        isUser: isUser,
        text: text ?? this.text,
        timestamp: timestamp,
        type: type,
        imagePath: imagePath,
        isStreaming: isStreaming ?? this.isStreaming,
        feedbackRating: feedbackRating ?? this.feedbackRating,
        sessionId: sessionId ?? this.sessionId,
        scratchpadSteps: scratchpadSteps ?? this.scratchpadSteps,
        isThinking: isThinking ?? this.isThinking,
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
  final String activeTitle;
  final String activeSubtitle;
  final List<Map<String, dynamic>> quickActions;
  final List<String> suggestedQuestions;
  final List<Map<String, dynamic>> connectedModules;
  final String searchQuery;
  final bool isArchivedView;

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
    this.activeTitle = 'New Conversation',
    this.activeSubtitle = 'Ask anything about your school, attendance, fees, timetable or reports...',
    this.quickActions = const [],
    this.suggestedQuestions = const [],
    this.connectedModules = const [],
    this.searchQuery = '',
    this.isArchivedView = false,
    this.error,
  });

  static ChatMessage createInitialGreeting([String? sessionId]) => ChatMessage(
        isUser: false,
        sessionId: sessionId,
        text: '👋 Hey! I\'m **Shami**, your EduSHAMIIT AI companion.\n\n'
            'I can help you with:\n'
            '• 📅 Your timetable & schedule\n'
            '• 📝 Homework & exam updates\n'
            '• 💰 Fee & payment status\n'
            '• 🚌 Bus tracking\n'
            '• 📚 Academic concepts & questions\n\n'
            'Ask me anything in Hindi or English! 🇮🇳',
      );

  factory AiChatState.initial([String? sid]) {
    final s = sid ?? const Uuid().v4();
    return AiChatState(
        sessionId: s,
        messages: [
          createInitialGreeting(s),
        ],
        suggestions: const [
          '📅 Show my timetable',
          '📝 Pending homework',
          '🚌 Where is my bus?',
          '📚 Exam schedule',
          '💰 Fee status',
        ],
        sessions: const [],
        quickActions: const [
          {'id': 'gen_report', 'label': 'Generate Report', 'icon': 'bar_chart', 'prompt': 'Generate a comprehensive fee and attendance report for this month.'},
          {'id': 'student_search', 'label': 'Student Search', 'icon': 'person_search', 'prompt': 'Search student details by name or roll number.'},
          {'id': 'att_query', 'label': 'Attendance Query', 'icon': 'event_available', 'prompt': 'Show me today\'s attendance summary for all classes.'},
          {'id': 'fee_report', 'label': 'Fee Report', 'icon': 'currency_rupee', 'prompt': 'Show me the fee collection report for April 2025 for all classes.'},
          {'id': 'timetable', 'label': 'Timetable', 'icon': 'schedule', 'prompt': 'Show me the timetable for Class 10.'},
          {'id': 'send_notice', 'label': 'Send Notice', 'icon': 'campaign', 'prompt': 'Draft a notice for parents regarding the upcoming school event.'},
        ],
        suggestedQuestions: const [
          'Show me today\'s attendance.',
          'Generate class 10 timetable.',
          'List all pending fees.',
          'How many students are in Class 9?',
          'Show recent notices.',
        ],
        isLoading: false,
        isLoadingMore: false,
        isTyping: false,
        isRecording: false,
        hasMoreHistory: true,
        historyOffset: 0,
        activeTitle: 'New Conversation',
        activeSubtitle: 'Ask anything about your school, attendance, fees, timetable or reports...',
      );
  }

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
    String? activeTitle,
    String? activeSubtitle,
    List<Map<String, dynamic>>? quickActions,
    List<String>? suggestedQuestions,
    List<Map<String, dynamic>>? connectedModules,
    String? searchQuery,
    bool? isArchivedView,
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
        activeTitle: activeTitle ?? this.activeTitle,
        activeSubtitle: activeSubtitle ?? this.activeSubtitle,
        quickActions: quickActions ?? this.quickActions,
        suggestedQuestions: suggestedQuestions ?? this.suggestedQuestions,
        connectedModules: connectedModules ?? this.connectedModules,
        searchQuery: searchQuery ?? this.searchQuery,
        isArchivedView: isArchivedView ?? this.isArchivedView,
        error: error,
      );
}

// ═══════════════════════════════════════════════════════════
//  AI Chat Notifier
// ═══════════════════════════════════════════════════════════

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Map<String, List<ChatMessage>> _sessionMessagesCache = {};
  final Map<String, bool> _activeStreamingSessions = {};
  final Map<String, String> _activeSessionTitles = {};

  AiChatNotifier() : super(AiChatState.initial()) {
    _initChat();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSessionId = prefs.getString('shami_chat_session_id');
    final activeId = (savedSessionId != null && savedSessionId.isNotEmpty)
        ? savedSessionId
        : state.sessionId;
    if (savedSessionId == null || savedSessionId.isEmpty) {
      await prefs.setString('shami_chat_session_id', activeId);
    }
    state = state.copyWith(
      sessionId: activeId,
      messages: [AiChatState.createInitialGreeting(activeId)],
    );
    await loadChatHistory(clearExisting: true, targetSessionId: activeId);
    await loadSessions();
    await loadSuggestions();
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
  Future<void> loadChatHistory({bool clearExisting = false, String? targetSessionId}) async {
    final reqSessionId = targetSessionId ?? state.sessionId;
    if (reqSessionId.isEmpty) return;

    if (clearExisting) {
      if (state.sessionId == reqSessionId) {
        state = state.copyWith(
          isLoading: true,
          historyOffset: 0,
          hasMoreHistory: true,
          messages: [AiChatState.createInitialGreeting(reqSessionId)],
        );
      }
    } else {
      if (!state.hasMoreHistory || state.isLoadingMore) return;
      if (state.sessionId == reqSessionId) {
        state = state.copyWith(isLoadingMore: true);
      }
    }

    try {
      final token = await _token();
      if (token == null) {
        if (state.sessionId == reqSessionId) {
          state = state.copyWith(isLoading: false, isLoadingMore: false);
        }
        return;
      }

      const int limit = 20;
      final int offset = (state.sessionId == reqSessionId && !clearExisting)
          ? state.historyOffset
          : 0;

      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/chat/history/$reqSessionId?limit=$limit&offset=$offset');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] as Map<String, dynamic>?)?['messages'] as List? ?? [];
        final loaded = data.map((m) => ChatMessage(
              id: m['id'] as String?,
              isUser: m['role'] == 'user',
              text: (m['content'] as String?) ?? '',
              sessionId: (m['session_id'] as String?) ?? reqSessionId,
              timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
            )).toList();

        final bool hasMore = loaded.length >= limit;
        final int newOffset = offset + loaded.length;

        final greeting = AiChatState.createInitialGreeting(reqSessionId);
        final List<ChatMessage> fullList;
        if (clearExisting) {
          fullList = [greeting, ...loaded];
        } else {
          final cached = _sessionMessagesCache[reqSessionId] ?? (state.sessionId == reqSessionId ? state.messages : [greeting]);
          final existing = cached.length > 1 ? cached.sublist(1) : <ChatMessage>[];
          fullList = [greeting, ...loaded, ...existing];
        }

        _sessionMessagesCache[reqSessionId] = fullList;

        if (state.sessionId == reqSessionId) {
          state = state.copyWith(
            messages: fullList,
            historyOffset: newOffset,
            hasMoreHistory: hasMore,
            isLoading: false,
            isLoadingMore: false,
          );
        }
      } else {
        if (state.sessionId == reqSessionId) {
          state = state.copyWith(isLoading: false, isLoadingMore: false);
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      if (state.sessionId == reqSessionId) {
        state = state.copyWith(isLoading: false, isLoadingMore: false);
      }
    }
  }

  // ── Load session list from server ──────────────────────────
  Future<void> loadSessions({String? search, bool? archived}) async {
    try {
      final token = await _token();
      if (token == null) return;

      final isArch = archived ?? state.isArchivedView;
      final q = search ?? state.searchQuery;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/sessions?search=${Uri.encodeComponent(q)}&archived=$isArch');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final list = (body['data']?['sessions'] as List?)
                  ?.map((s) => s as Map<String, dynamic>)
                  .toList() ?? [];
          String? currentTitle;
          String? currentSnippet;
          for (final s in list) {
            if (s['session_id'] == state.sessionId) {
              currentTitle = s['title'] as String?;
              currentSnippet = s['snippet'] as String?;
              break;
            }
          }
          state = state.copyWith(
            sessions: list,
            searchQuery: q,
            isArchivedView: isArch,
            activeTitle: currentTitle ?? state.activeTitle,
            activeSubtitle: (currentSnippet != null && currentSnippet.isNotEmpty)
                ? currentSnippet
                : state.activeSubtitle,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }
  }

  // ── Load smart suggestions & quick actions ────────────────
  Future<void> loadSuggestions() async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/suggestions');
      final resp = await http.get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.apiTimeout);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>? ?? {};
          final qa = (data['quick_actions'] as List?)?.map((x) => x as Map<String, dynamic>).toList() ?? state.quickActions;
          final sq = (data['suggested_questions'] as List?)?.map((x) => x.toString()).toList() ?? state.suggestedQuestions;
          final cm = (data['connected_modules'] as List?)?.map((x) => x as Map<String, dynamic>).toList() ?? state.connectedModules;
          state = state.copyWith(
            quickActions: qa,
            suggestedQuestions: sq,
            connectedModules: cm,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  // ── Select and switch to an older session ──────────────────
  Future<void> selectSession(String sessionId, {String? title, String? subtitle}) async {
    if (sessionId.isEmpty) return;

    // Cache current session messages before switching
    if (state.sessionId.isNotEmpty && state.messages.isNotEmpty) {
      _sessionMessagesCache[state.sessionId] = List<ChatMessage>.from(state.messages);
    }

    final cachedMessages = _sessionMessagesCache[sessionId];
    final isStreamingActive = _activeStreamingSessions[sessionId] == true;

    state = state.copyWith(
      sessionId: sessionId,
      activeTitle: title ?? _activeSessionTitles[sessionId] ?? state.activeTitle,
      activeSubtitle: subtitle ?? 'School management assistance and queries.',
      messages: cachedMessages != null && cachedMessages.isNotEmpty
          ? cachedMessages
          : [AiChatState.createInitialGreeting(sessionId)],
      isLoading: cachedMessages == null,
      isLoadingMore: false,
      isTyping: isStreamingActive,
      historyOffset: cachedMessages?.length ?? 0,
      hasMoreHistory: true,
      error: null,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shami_chat_session_id', sessionId);

    if (cachedMessages == null || cachedMessages.isEmpty) {
      await loadChatHistory(clearExisting: true, targetSessionId: sessionId);
    }
  }

  // ── Rename a session on the server ────────────────────────
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/conversations/$sessionId');
      final resp = await http.patch(
        uri,
        headers: _authHeaders(token),
        body: jsonEncode({'title': newTitle}),
      ).timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        if (state.sessionId == sessionId) {
          state = state.copyWith(activeTitle: newTitle);
        }
        await loadSessions();
      }
    } catch (e) {
      debugPrint('Error renaming session: $e');
    }
  }

  // ── Toggle Pin session on server ──────────────────────────
  Future<void> togglePinSession(String sessionId, bool isPinned) async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/conversations/$sessionId');
      final resp = await http.patch(
        uri,
        headers: _authHeaders(token),
        body: jsonEncode({'is_pinned': isPinned}),
      ).timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        await loadSessions(archived: state.isArchivedView);
      }
    } catch (e) {
      debugPrint('Error toggling pin session: $e');
    }
  }

  // ── Toggle Archive session on server ──────────────────────
  Future<void> toggleArchiveSession(String sessionId, bool isArchived) async {
    try {
      final token = await _token();
      if (token == null) return;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/conversations/$sessionId');
      final resp = await http.patch(
        uri,
        headers: _authHeaders(token),
        body: jsonEncode({'is_archived': isArchived}),
      ).timeout(AppConfig.apiTimeout);

      if (resp.statusCode == 200) {
        await loadSessions(archived: state.isArchivedView);
      }
    } catch (e) {
      debugPrint('Error toggling archive session: $e');
    }
  }

  // ── Submit Feedback (Like/Dislike) ────────────────────────
  Future<void> submitFeedback(ChatMessage msg, int rating, {String? comment}) async {
    try {
      final token = await _token();
      if (token == null) return;

      // Update message locally
      final msgs = state.messages.map((m) {
        if (m.id == msg.id) {
          return m.copyWith(feedbackRating: rating);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: msgs);

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/chat/messages/${msg.id}/feedback');
      await http.post(
        uri,
        headers: _authHeaders(token),
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ).timeout(AppConfig.apiTimeout);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
    }
  }



  // ── Start a brand new chat session ─────────────────────────
  Future<void> startNewChat() async {
    if (state.sessionId.isNotEmpty && state.messages.isNotEmpty) {
      _sessionMessagesCache[state.sessionId] = List<ChatMessage>.from(state.messages);
    }

    final newSessionId = const Uuid().v4();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shami_chat_session_id', newSessionId);

    state = AiChatState.initial(newSessionId).copyWith(
      sessionId: newSessionId,
      messages: [AiChatState.createInitialGreeting(newSessionId)],
      activeTitle: 'New Conversation',
      activeSubtitle: 'Ask anything about your school, attendance, fees, timetable or reports...',
      sessions: state.sessions,
    );
  }

  // ── Delete a session on the server ─────────────────────────
  Future<void> deleteSession(String sessionId) async {
    _sessionMessagesCache.remove(sessionId);
    _activeStreamingSessions.remove(sessionId);
    _activeSessionTitles.remove(sessionId);
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

  bool _isGreetingText(String text) {
    final clean = text.replaceAll(RegExp(r'[#*_`\n\r.,!?:;\-]'), ' ').trim().toLowerCase();
    const greetings = {
      'hi', 'hello', 'hey', 'hii', 'hiii', 'namaste', 'good morning',
      'good afternoon', 'good evening', 'greetings', 'yo', 'heya', 'help', 'test'
    };
    return greetings.contains(clean) || clean.length < 3;
  }

  String _generateSmartTitle(String prompt) {
    if (_isGreetingText(prompt)) {
      return 'General Consultation';
    }
    var clean = prompt.replaceAll(RegExp(r'[#*_`\n\r]'), ' ').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    final lower = clean.toLowerCase();
    const prefixes = [
      'can you please ', 'please ', 'show me the ', 'show me ', 'tell me about ', 'tell me ',
      'what is the ', 'what is ', 'generate a ', 'generate ', 'give me the ', 'give me ',
      'draft a ', 'draft ', 'create a ', 'create ', 'how many ', 'where is ', 'find ', 'list ',
      'compare ', 'summarize ', 'explain ', 'check ', 'display ', 'get ', 'view ', 'which '
    ];
    for (final p in prefixes) {
      if (lower.startsWith(p)) {
        clean = clean.substring(p.length).trim();
        break;
      }
    }
    final words = clean.split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'General Consultation';
    final sub = words.take(5).join(' ').replaceAll(RegExp(r'[.,!?:;\-]+$'), '');
    return sub[0].toUpperCase() + sub.substring(1);
  }

  // ── Session-aware message updater ─────────────────────────
  void _updateAiMessageForSession(
    String targetSessionId, {
    String? text,
    ScratchpadStep? newScratchpadStep,
    required bool isStreaming,
    bool? isThinking,
  }) {
    if (targetSessionId.isEmpty) return;

    List<ChatMessage> msgs;
    if (state.sessionId == targetSessionId) {
      msgs = List<ChatMessage>.from(state.messages);
    } else if (_sessionMessagesCache.containsKey(targetSessionId)) {
      msgs = List<ChatMessage>.from(_sessionMessagesCache[targetSessionId]!);
    } else {
      return;
    }

    int aiIndex = -1;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (!msgs[i].isUser && (msgs[i].sessionId == targetSessionId || msgs[i].sessionId == null)) {
        aiIndex = i;
        break;
      }
    }

    if (aiIndex != -1) {
      final oldMsg = msgs[aiIndex];
      List<ScratchpadStep> steps = List<ScratchpadStep>.from(oldMsg.scratchpadSteps);
      if (newScratchpadStep != null) {
        final existingIdx = steps.indexWhere((s) => s.title == newScratchpadStep.title);
        if (existingIdx != -1) {
          steps[existingIdx] = newScratchpadStep;
        } else {
          steps.add(newScratchpadStep);
        }
      }

      final updatedText = text ?? oldMsg.text;
      final updatedThinking = isThinking ?? (isStreaming && updatedText.isEmpty);

      msgs[aiIndex] = oldMsg.copyWith(
        text: updatedText,
        isStreaming: isStreaming,
        scratchpadSteps: steps,
        isThinking: updatedThinking,
        sessionId: targetSessionId,
      );
    }

    _sessionMessagesCache[targetSessionId] = msgs;
    _activeStreamingSessions[targetSessionId] = isStreaming;

    if (state.sessionId == targetSessionId) {
      state = state.copyWith(
        messages: msgs,
        isTyping: isStreaming,
      );
    }
  }

  void _updateLastAiMessage(String text, {required bool isStreaming}) {
    _updateAiMessageForSession(state.sessionId, text: text, isStreaming: isStreaming);
  }

  // ── Send text message via SSE stream ──────────────────────
  Future<void> sendMessage(String text, {bool appendUserBubble = true, String? launchedFrom}) async {
    if (text.trim().isEmpty) return;

    final originatingSessionId = state.sessionId;

    final currentTitle = state.activeTitle;
    const genericTitles = {
      'new conversation', 'new chat', 'fee collection report', 
      'general consultation', 'general inquiry', 'hi', 'hello', 'hey', 'conversation'
    };
    String? newTitle;
    final isGeneric = currentTitle.isEmpty || genericTitles.contains(currentTitle.toLowerCase()) || _isGreetingText(currentTitle);
    if (isGeneric && !_isGreetingText(text)) {
      newTitle = _generateSmartTitle(text);
    } else if (currentTitle == 'New Conversation' || currentTitle.isEmpty) {
      newTitle = _generateSmartTitle(text);
    }
    if (newTitle != null) {
      _activeSessionTitles[originatingSessionId] = newTitle;
    }

    final initialSteps = [
      ScratchpadStep(
        title: 'Brainstorming & Planning...',
        detail: 'Analyzing inquiry and identifying necessary academic tools',
        stage: 'thinking',
      )
    ];

    if (appendUserBubble) {
      final userMsg = ChatMessage(isUser: true, text: text.trim(), sessionId: originatingSessionId);
      final aiMsg = ChatMessage(
        isUser: false,
        text: '',
        isStreaming: true,
        sessionId: originatingSessionId,
        scratchpadSteps: initialSteps,
        isThinking: true,
      );

      final newMsgs = [...state.messages, userMsg, aiMsg];
      _sessionMessagesCache[originatingSessionId] = newMsgs;
      _activeStreamingSessions[originatingSessionId] = true;

      state = state.copyWith(
        messages: newMsgs,
        isTyping: true,
        error: null,
        historyOffset: state.historyOffset + 2,
        activeTitle: newTitle ?? state.activeTitle,
        activeSubtitle: newTitle != null ? 'Active consultation • AI Assistant' : state.activeSubtitle,
      );
    } else {
      final aiMsg = ChatMessage(
        isUser: false,
        text: '',
        isStreaming: true,
        sessionId: originatingSessionId,
        scratchpadSteps: initialSteps,
        isThinking: true,
      );

      final newMsgs = [...state.messages, aiMsg];
      _sessionMessagesCache[originatingSessionId] = newMsgs;
      _activeStreamingSessions[originatingSessionId] = true;

      state = state.copyWith(
        messages: newMsgs,
        isTyping: true,
        error: null,
        historyOffset: state.historyOffset + 1,
        activeTitle: newTitle ?? state.activeTitle,
        activeSubtitle: newTitle != null ? 'Active consultation • AI Assistant' : state.activeSubtitle,
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
          'session_id': originatingSessionId,
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
            final chunkSessionId = parsed['session_id'] as String? ?? originatingSessionId;

            if (type == 'scratchpad') {
              final stage = parsed['stage'] as String? ?? 'thinking';
              final title = parsed['title'] as String? ?? 'Thinking';
              final detail = parsed['detail'] as String? ?? '';
              final step = ScratchpadStep(title: title, detail: detail, stage: stage);
              _updateAiMessageForSession(
                chunkSessionId,
                newScratchpadStep: step,
                isStreaming: true,
                isThinking: true,
              );
            } else if (type == 'conversation_updated') {
              final sTitle = parsed['title'] as String?;
              if (sTitle != null && sTitle.trim().isNotEmpty) {
                _activeSessionTitles[chunkSessionId] = sTitle.trim();
                if (state.sessionId == chunkSessionId) {
                  state = state.copyWith(
                    activeTitle: sTitle.trim(),
                    activeSubtitle: 'Active consultation • AI Assistant',
                  );
                }
              }
            } else if (type == 'text') {
              accumulated += content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'done') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: false,
                isThinking: false,
              );
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                isStreaming: false,
                isThinking: false,
              );
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
          _updateAiMessageForSession(
            originatingSessionId,
            text: '⚠️ Connection error: $err',
            isStreaming: false,
            isThinking: false,
          );
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Refresh recent sessions list and suggestions based on new message
      loadSessions();
      loadSuggestions();

      // Safety check for originatingSessionId
      if (_activeStreamingSessions[originatingSessionId] == true) {
        final hasNoResponse = accumulated.isEmpty;
        _updateAiMessageForSession(
          originatingSessionId,
          text: !hasNoResponse ? accumulated : '🤔 No response received.',
          isStreaming: false,
          isThinking: false,
        );
        if (hasNoResponse) {
          _runHistoryPollingFallback(originatingSessionId);
        }
      }
    } catch (e) {
      _updateAiMessageForSession(
        originatingSessionId,
        text: '⚠️ Connection error. Please check your internet and try again.',
        isStreaming: false,
        isThinking: false,
      );
      debugPrint('AiChat SSE error: $e');
      _runHistoryPollingFallback(originatingSessionId);
    } finally {
      _activeStreamingSessions[originatingSessionId] = false;
      await loadSessions();
    }
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
    final originatingSessionId = state.sessionId;
    final displayUserText = text.trim().isNotEmpty ? text.trim() : '📷 Image sent';

    final initialSteps = [
      ScratchpadStep(
        title: 'Analyzing Visual & Query...',
        detail: 'Inspecting image inputs and reasoning about features',
        stage: 'thinking',
      )
    ];

    final userMsg = ChatMessage(
      isUser: true,
      text: displayUserText,
      type: MessageType.image,
      imagePath: imageFile.path,
      sessionId: originatingSessionId,
    );
    final aiMsg = ChatMessage(
      isUser: false,
      text: '',
      isStreaming: true,
      sessionId: originatingSessionId,
      scratchpadSteps: initialSteps,
      isThinking: true,
    );

    final newMsgs = [...state.messages, userMsg, aiMsg];
    _sessionMessagesCache[originatingSessionId] = newMsgs;
    _activeStreamingSessions[originatingSessionId] = true;

    state = state.copyWith(
      messages: newMsgs,
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
          'session_id': originatingSessionId,
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
            final chunkSessionId = parsed['session_id'] as String? ?? originatingSessionId;

            if (type == 'scratchpad') {
              final stage = parsed['stage'] as String? ?? 'thinking';
              final title = parsed['title'] as String? ?? 'Thinking';
              final detail = parsed['detail'] as String? ?? '';
              final step = ScratchpadStep(title: title, detail: detail, stage: stage);
              _updateAiMessageForSession(
                chunkSessionId,
                newScratchpadStep: step,
                isStreaming: true,
                isThinking: true,
              );
            } else if (type == 'conversation_updated') {
              final sTitle = parsed['title'] as String?;
              if (sTitle != null && sTitle.trim().isNotEmpty) {
                _activeSessionTitles[chunkSessionId] = sTitle.trim();
                if (state.sessionId == chunkSessionId) {
                  state = state.copyWith(
                    activeTitle: sTitle.trim(),
                    activeSubtitle: 'Active consultation • AI Assistant',
                  );
                }
              }
            } else if (type == 'text') {
              accumulated += content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'done') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: false,
                isThinking: false,
              );
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                isStreaming: false,
                isThinking: false,
              );
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
          _updateAiMessageForSession(
            originatingSessionId,
            text: '⚠️ Connection error: $err',
            isStreaming: false,
            isThinking: false,
          );
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Refresh recent sessions list and suggestions based on new message
      loadSessions();
      loadSuggestions();

      // Safety check for originatingSessionId
      if (_activeStreamingSessions[originatingSessionId] == true) {
        final hasNoResponse = accumulated.isEmpty;
        _updateAiMessageForSession(
          originatingSessionId,
          text: !hasNoResponse ? accumulated : '🤔 No response received.',
          isStreaming: false,
          isThinking: false,
        );
        if (hasNoResponse) {
          _runHistoryPollingFallback(originatingSessionId);
        }
      }
    } catch (e) {
      _updateAiMessageForSession(
        originatingSessionId,
        text: '⚠️ Connection error. Please check your internet and try again.',
        isStreaming: false,
        isThinking: false,
      );
      debugPrint('AiChat SSE with image error: $e');
      _runHistoryPollingFallback(originatingSessionId);
    } finally {
      _activeStreamingSessions[originatingSessionId] = false;
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

  // ── Stop Generation ───────────────────────────────────────
  void stopGeneration() {
    final sid = state.sessionId;
    _activeStreamingSessions[sid] = false;
    _updateAiMessageForSession(
      sid,
      isStreaming: false,
      isThinking: false,
    );
    state = state.copyWith(isTyping: false);
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
  Future<void> sendMessageWithDocument(
    String text,
    PlatformFile docFile, {
    XFile? imageFile,
    String? launchedFrom,
  }) async {
    final originatingSessionId = state.sessionId;
    String displayUserText = '📄 [Document: ${docFile.name}]';
    if (imageFile != null) displayUserText = '📷 [Image: ${imageFile.name}]\n$displayUserText';
    if (text.trim().isNotEmpty) displayUserText = '$displayUserText\n\n${text.trim()}';

    final initialSteps = [
      ScratchpadStep(
        title: 'Parsing Attachments & Query...',
        detail: 'Extracting content from ${docFile.name}${imageFile != null ? ' and ${imageFile.name}' : ''}',
        stage: 'thinking',
      )
    ];

    final userMsg = ChatMessage(
      isUser: true,
      text: displayUserText,
      type: MessageType.text,
      sessionId: originatingSessionId,
    );
    final aiMsg = ChatMessage(
      isUser: false,
      text: '',
      isStreaming: true,
      sessionId: originatingSessionId,
      scratchpadSteps: initialSteps,
      isThinking: true,
    );

    final newMsgs = [...state.messages, userMsg, aiMsg];
    _sessionMessagesCache[originatingSessionId] = newMsgs;
    _activeStreamingSessions[originatingSessionId] = true;

    state = state.copyWith(
      messages: newMsgs,
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

      String? imageB64;
      if (imageFile != null) {
        final imageBytes = await imageFile.readAsBytes();
        imageB64 = base64Encode(imageBytes);
      }

      String accumulated = '';
      final completer = Completer<void>();

      await client.sendRequest(
        uri: uri,
        headers: _authHeaders(token),
        body: {
          'message': text.trim().isNotEmpty ? text.trim() : 'Process this document and attachment',
          'session_id': originatingSessionId,
          'doc_b64': docB64,
          'doc_name': docFile.name,
          if (imageB64 != null) 'image_b64': imageB64,
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
            final chunkSessionId = parsed['session_id'] as String? ?? originatingSessionId;

            if (type == 'scratchpad') {
              final stage = parsed['stage'] as String? ?? 'thinking';
              final title = parsed['title'] as String? ?? 'Thinking';
              final detail = parsed['detail'] as String? ?? '';
              final step = ScratchpadStep(title: title, detail: detail, stage: stage);
              _updateAiMessageForSession(
                chunkSessionId,
                newScratchpadStep: step,
                isStreaming: true,
                isThinking: true,
              );
            } else if (type == 'conversation_updated') {
              final sTitle = parsed['title'] as String?;
              if (sTitle != null && sTitle.trim().isNotEmpty) {
                _activeSessionTitles[chunkSessionId] = sTitle.trim();
                if (state.sessionId == chunkSessionId) {
                  state = state.copyWith(
                    activeTitle: sTitle.trim(),
                    activeSubtitle: 'Active consultation • AI Assistant',
                  );
                }
              }
            } else if (type == 'text') {
              accumulated += content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'replace_text') {
              accumulated = content;
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: true,
                isThinking: false,
              );
            } else if (type == 'done') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: accumulated,
                isStreaming: false,
                isThinking: false,
              );
              if (!completer.isCompleted) completer.complete();
            } else if (type == 'error') {
              _updateAiMessageForSession(
                chunkSessionId,
                text: '⚠️ ${content.isNotEmpty ? content : 'Something went wrong. Please try again.'}',
                isStreaming: false,
                isThinking: false,
              );
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
          _updateAiMessageForSession(
            originatingSessionId,
            text: '⚠️ Connection error: $err',
            isStreaming: false,
            isThinking: false,
          );
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for stream to finish or timeout
      await completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      });

      // Refresh recent sessions list and suggestions based on new message
      loadSessions();
      loadSuggestions();

      // Safety check for originatingSessionId
      if (_activeStreamingSessions[originatingSessionId] == true) {
        final hasNoResponse = accumulated.isEmpty;
        _updateAiMessageForSession(
          originatingSessionId,
          text: !hasNoResponse ? accumulated : '🤔 No response received.',
          isStreaming: false,
          isThinking: false,
        );
        if (hasNoResponse) {
          _runHistoryPollingFallback(originatingSessionId);
        }
      }
    } catch (e) {
      _updateAiMessageForSession(
        originatingSessionId,
        text: '⚠️ Connection error. Please check your internet and try again.',
        isStreaming: false,
        isThinking: false,
      );
      debugPrint('AiChat SSE with document error: $e');
      _runHistoryPollingFallback(originatingSessionId);
    } finally {
      _activeStreamingSessions[originatingSessionId] = false;
      await loadSessions();
    }
  }

  void _runHistoryPollingFallback(String targetSessionId, {int attemptsLeft = 3}) {
    if (attemptsLeft <= 0 || targetSessionId.isEmpty) return;
    
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final token = await _token();
        if (token == null) return;
        
        const int limit = 20;
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
                    id: m['id'] as String?,
                    isUser: m['role'] == 'user',
                    text: (m['content'] as String?) ?? '',
                    sessionId: targetSessionId,
                    timestamp: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
                  )).toList();
              
              if (loaded.isNotEmpty) {
                final fullList = [AiChatState.createInitialGreeting(targetSessionId), ...loaded];
                _sessionMessagesCache[targetSessionId] = fullList;
                if (state.sessionId == targetSessionId) {
                  state = state.copyWith(
                    messages: fullList,
                    historyOffset: loaded.length,
                    isTyping: false,
                  );
                }
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
