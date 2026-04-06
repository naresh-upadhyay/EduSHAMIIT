import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';
import 'dart:async';

/// Represents a chat message in the AI conversation
class ChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final String? aiSuggestion; // Optional suggestion from AI

  ChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.aiSuggestion,
  });

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> toJson() => {
    'isUser': isUser,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'aiSuggestion': aiSuggestion,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    isUser: json['isUser'] ?? false,
    text: json['text'] ?? '',
    timestamp: DateTime.parse(json['timestamp']),
    aiSuggestion: json['aiSuggestion'],
  );
}

/// State for AI Chat
class AiChatState {
  final List<ChatMessage> messages;
  final List<String> suggestions;
  final bool isLoading;
  final bool isTyping;
  final String? error;
  final int responseIndex; // For cycling through responses

  AiChatState({
    required this.messages,
    required this.suggestions,
    required this.isLoading,
    required this.isTyping,
    this.error,
    required this.responseIndex,
  });

  factory AiChatState.initial() => AiChatState(
    messages: [
      ChatMessage(
        isUser: false,
        text: '👋 Hey! I\'m your EduVerse AI. I can help you with homework, explain concepts, track your exams, check your fees, or anything school-related!',
        timestamp: DateTime.now(),
      ),
    ],
    suggestions: [
      '📅 Show timetable',
      '📝 Pending homework',
      '🚌 Where\'s bus?',
      '📚 Exam schedule',
      '💰 Fee status',
    ],
    isLoading: false,
    isTyping: false,
    error: null,
    responseIndex: 0,
  );

  AiChatState copyWith({
    List<ChatMessage>? messages,
    List<String>? suggestions,
    bool? isLoading,
    bool? isTyping,
    String? error,
    int? responseIndex,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      isTyping: isTyping ?? this.isTyping,
      error: error ?? this.error,
      responseIndex: responseIndex ?? this.responseIndex,
    );
  }
}

/// Notifier for AI Chat
class AiChatNotifier extends StateNotifier<AiChatState> {
  final ApiService apiService;

  AiChatNotifier(this.apiService) : super(AiChatState.initial()) {
    loadChatHistory();
  }

  /// Load chat history from cache
  Future<void> loadChatHistory() async {
    try {
      state = state.copyWith(isLoading: true);
      
      // Try to load from API
      final response = await apiService.get('/api/v1/chat/history');
      if (response['messages'] != null) {
        final messages = (response['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
        state = state.copyWith(
          messages: messages,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      // Use initial state if loading fails
      state = state.copyWith(isLoading: false);
    }
  }

  /// Send a message to the AI
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isTyping: true,
      error: null,
    );

    try {
      // Send to AI API
      final response = await apiService.post('/api/v1/chat/message', {
        'message': text,
        'context': {
          'userId': 'current_user', // Would come from auth provider
          'conversationId': _generateConversationId(),
        },
      });

      if (response['response'] != null) {
        final aiMessage = ChatMessage(
          isUser: false,
          text: response['response'],
          timestamp: DateTime.now(),
          aiSuggestion: response['suggestion'],
        );

        state = state.copyWith(
          messages: [...state.messages, aiMessage],
          isTyping: false,
          responseIndex: state.responseIndex + 1,
        );
      } else {
        // Fallback response
        await _simulateAIResponse();
      }
    } catch (e) {
      // Simulate response on error
      await _simulateAIResponse();
    }
  }

  /// Simulate AI response (fallback when API is unavailable)
  Future<void> _simulateAIResponse() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (state.messages.isEmpty) return;

    final responses = [
      "I'll check that for you! Your timetable shows Physics Lab at 9 AM tomorrow. 📚",
      'You have 3 pending homework assignments. The Math one is due today! ⚠️',
      'Your bus (Route 7B) is currently 1.2 km away. ETA: 8 minutes. 🚌',
      'Great question! Integration by parts: ∫u dv = uv - ∫v du. Want me to solve a problem? 📐',
      'Your attendance is at 94%. You\'ve missed 10 days this term. Keep it up! 📋',
      'Next exam: Mathematics on March 28. Focus on Calculus & Probability chapters. 🎯',
      'Your current rank is 3rd in class with 2,450 XP points. Amazing progress! 🏆',
    ];

    final aiMessage = ChatMessage(
      isUser: false,
      text: responses[state.responseIndex % responses.length],
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isTyping: false,
      responseIndex: state.responseIndex + 1,
    );
  }

  /// Use a suggestion
  Future<void> useSuggestion(String suggestion) async {
    await sendMessage(suggestion);
  }

  /// Clear chat history
  Future<void> clearChat() async {
    try {
      await apiService.delete('/api/v1/chat/history');
    } catch (e) {
      debugPrint('Error clearing chat: $e');
    }
    
    state = AiChatState.initial();
  }

  /// Export chat history
  Future<String> exportChat() async {
    final buffer = StringBuffer();
    buffer.writeln('EduVerse AI Chat History');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---');
    
    for (final msg in state.messages) {
      final sender = msg.isUser ? 'You' : 'AI';
      buffer.writeln('[$sender] ${msg.formattedTime}: ${msg.text}');
    }
    
    return buffer.toString();
  }

  String _generateConversationId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

/// AI Chat Provider
final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AiChatNotifier(apiService);
});