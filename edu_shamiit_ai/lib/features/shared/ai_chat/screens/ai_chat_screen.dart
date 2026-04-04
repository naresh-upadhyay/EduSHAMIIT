import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        content: "Hello! I'm ${AppConfig.aiAssistantName}, your AI learning assistant. 🤖\n\nHow can I help you today? I can assist with:\n• Explaining concepts\n• Solving problems\n• Study tips\n• And much more!",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        content: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate AI response (replace with real API call)
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));

    final response = _generateResponse(text);

    setState(() {
      _messages.add(ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
    });

    _scrollToBottom();
  }

  String _generateResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('math') || lowerMessage.contains('algebra') || lowerMessage.contains('geometry')) {
      return "Great question about mathematics! 📐\n\nMathematics is all around us. For algebra, remember:\n• Isolate the variable\n• Perform the same operation on both sides\n• Check your answer\n\nWould you like me to explain a specific concept or solve a problem?";
    }

    if (lowerMessage.contains('physics') || lowerMessage.contains('newton') || lowerMessage.contains('force')) {
      return "Physics is fascinating! ⚛️\n\nNewton's Laws of Motion:\n1. An object at rest stays at rest\n2. F = ma (Force = mass × acceleration)\n3. For every action, there's an equal and opposite reaction\n\nWhat specific topic would you like to explore?";
    }

    if (lowerMessage.contains('chemistry') || lowerMessage.contains('element') || lowerMessage.contains('reaction')) {
      return "Chemistry is the central science! 🧪\n\nKey concepts:\n• Atoms are the building blocks\n• Chemical reactions rearrange atoms\n• The periodic table organizes elements\n\nWhat would you like to learn more about?";
    }

    if (lowerMessage.contains('study') || lowerMessage.contains('tip') || lowerMessage.contains('advice')) {
      return "Here are some effective study tips! 📚\n\n1. **Active Recall**: Test yourself instead of just re-reading\n2. **Spaced Repetition**: Review material at increasing intervals\n3. **Pomodoro Technique**: 25 min focus + 5 min break\n4. **Teach others**: Explaining concepts reinforces learning\n5. **Sleep well**: Memory consolidation happens during sleep\n\nWhich technique would you like to try?";
    }

    if (lowerMessage.contains('homework') || lowerMessage.contains('assignment')) {
      return "I'm here to help with your homework! 📝\n\nWhile I can guide you through problems and explain concepts, remember:\n• Try solving it yourself first\n• Show your work step by step\n• Ask specific questions\n• Learn from mistakes\n\nWhat subject is your homework in?";
    }

    if (lowerMessage.contains('exam') || lowerMessage.contains('test') || lowerMessage.contains('prepare')) {
      return "Let's prepare for your exam! 🎯\n\nExam preparation strategy:\n1. **Start early** - Don't cram\n2. **Create a study schedule**\n3. **Practice with past papers**\n4. **Focus on weak areas**\n5. **Get enough sleep before the exam**\n\nWhat subject are you preparing for?";
    }

    if (lowerMessage.contains('thank')) {
      return "You're welcome! 😊\n\nI'm always here to help you learn. Feel free to ask anything else!\n\nRemember: Every expert was once a beginner. Keep learning! 🌟";
    }

    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || lowerMessage.contains('hey')) {
      return "Hello! 👋\n\nI'm ${AppConfig.aiAssistantName}, your personal AI learning companion.\n\nWhat would you like to learn about today? I can help with math, science, study tips, and more!";
    }

    // Default response
    return "That's an interesting question! 🤔\n\nI'm here to help you learn. Could you tell me more about what you'd like to understand? I can assist with:\n\n• Mathematics (algebra, geometry, calculus)\n• Science (physics, chemistry, biology)\n• Study strategies\n• Problem-solving\n\nWhat topic would you like to explore?";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: StudentColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: StudentColors.text),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppGradients.studentPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConfig.aiAssistantName,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: StudentColors.text,
                  ),
                ),
                Text(
                  _isTyping ? 'Typing...' : 'Online',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 12,
                    color: _isTyping ? StudentColors.warning : StudentColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: StudentColors.text),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Clear Chat'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _messages.clear();
                            _addWelcomeMessage();
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About Shami AI'),
                        onTap: () {
                          Navigator.pop(context);
                          showAboutDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppGradients.studentPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudentColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
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

  Widget _buildTypingDot(int delay) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + delay * 200),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: StudentColors.text3.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppGradients.studentPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF4F46E5) : StudentColors.surface,
                borderRadius: message.isUser
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? const Color(0xFF4F46E5).withOpacity(0.2)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      color: message.isUser ? Colors.white : StudentColors.text,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser
                          ? Colors.white.withOpacity(0.7)
                          : StudentColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: StudentColors.primary,
              child: Text('👤', style: TextStyle(fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: StudentColors.border,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Ask Shami anything...',
                    hintStyle: TextStyle(
                      color: StudentColors.text3,
                      fontFamily: 'DM Sans',
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: AppGradients.studentPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Shami AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version: 1.0.0'),
            const SizedBox(height: 8),
            const Text(
              'Shami is an AI-powered learning assistant designed to help students with their academic journey. It can explain concepts, solve problems, and provide study tips.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Capabilities:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('• Mathematics (algebra, geometry, calculus)'),
            const Text('• Science (physics, chemistry, biology)'),
            const Text('• Study strategies and tips'),
            const Text('• Problem-solving guidance'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}