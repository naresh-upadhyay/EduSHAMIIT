import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/ai_chat_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load chat history on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).loadChatHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0C29), Color(0xFF302B63)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('🤖', style: TextStyle(fontSize: 14))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EduSHAMIIT AI',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            chatState.isTyping ? 'Typing...'.tr(ref) : 'Always Online'.tr(ref),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Menu button for export/clear
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'export') {
                      _exportChat();
                    } else if (value == 'clear') {
                      _clearChat();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'export', child: Text('Export Chat'.tr(ref))),
                    PopupMenuItem(value: 'clear', child: Text('Clear Chat'.tr(ref))),
                  ],
                ),
              ],
            ),
          ),

          // Loading indicator
          if (chatState.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: chatState.messages.length + (chatState.isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (chatState.isTyping && index == chatState.messages.length) {
                  return _buildTypingIndicator();
                }

                final msg = chatState.messages[index];
                return _buildMessage(msg);
              },
            ),
          ),

          // Suggestion Chips
          if (chatState.messages.length <= 3 && chatState.suggestions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: chatState.suggestions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: ActionChip(
                        label: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: StudentColors.primary,
                          ),
                        ),
                        backgroundColor: StudentColors.primaryLight,
                        onPressed: () => _sendSuggestion(s),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: StudentColors.surface,
              border: Border(top: BorderSide(color: StudentColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask anything about school...'.tr(ref),
                      filled: true,
                      fillColor: StudentColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 12))),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: msg.isUser ? StudentColors.primary : StudentColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: msg.isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: msg.isUser ? Colors.white : StudentColors.text,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.formattedTime,
                    style: TextStyle(
                      fontSize: 9,
                      color: msg.isUser ? Colors.white60 : StudentColors.text3,
                    ),
                    textAlign: msg.isUser ? TextAlign.end : TextAlign.start,
                  ),
                  // Show AI suggestion if available
                  if (!msg.isUser && msg.aiSuggestion != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ActionChip(
                        label: Text(
                          msg.aiSuggestion!,
                          style: const TextStyle(fontSize: 10, color: StudentColors.primary),
                        ),
                        backgroundColor: StudentColors.primaryLight,
                        onPressed: () => _sendMessage(msg.aiSuggestion!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 12))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: StudentColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.zero,
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                _buildTypingDot(1),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: StudentColors.text3,
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 600 + index * 200),
        tween: Tween(begin: 0, end: -6),
        onEnd: () {
          // Reset animation
        },
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, sin(value) * -6),
            child: child,
          );
        },
        child: const SizedBox.shrink(),
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _sendSuggestion(String suggestion) {
    ref.read(aiChatProvider.notifier).useSuggestion(suggestion);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _exportChat() async {
    final chatHistory = await ref.read(aiChatProvider.notifier).exportChat();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat exported!'.tr(ref))),
      );
      // In a real app, you would share or save the chatHistory string
      debugPrint(chatHistory);
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Chat'.tr(ref)),
        content: Text('Are you sure you want to clear all chat history?'.tr(ref)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr(ref)),
          ),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearChat();
              Navigator.pop(context);
            },
            child: Text('Clear'.tr(ref), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}