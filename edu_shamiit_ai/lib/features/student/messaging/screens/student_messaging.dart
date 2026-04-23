import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';

class StudentMessaging extends ConsumerStatefulWidget {
  const StudentMessaging({super.key});

  @override
  ConsumerState<StudentMessaging> createState() => _StudentMessagingState();
}

class _StudentMessagingState extends ConsumerState<StudentMessaging> {
  final int _selectedCategory = 0; // 0=All, 1=Teachers, 2=Students, 3=Groups

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(messagingProvider.notifier).fetchMessages();
    });
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}';
  }

  Gradient _getGradientForSender(String senderId) {
    // Generate consistent gradient based on sender ID
    final hash = senderId.hashCode;
    final gradients = [
      const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
      const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFDB2777)]),
      const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
      const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
      const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final messagingState = ref.watch(messagingProvider);
    final messages = messagingState.messages;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: () => _showCreateGroupDialog(),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: '🔍 Search teachers, students, groups...',
                hintStyle: const TextStyle(fontSize: 12, color: StudentColors.text3),
                filled: true,
                fillColor: StudentColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StudentColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildCategoryChip('All', 0),
                const SizedBox(width: 6),
                _buildCategoryChip('👨‍🏫 Teachers', 1),
                const SizedBox(width: 6),
                _buildCategoryChip('👤 Students', 2),
                const SizedBox(width: 6),
                _buildCategoryChip('👥 Groups', 3),
              ],
            ),
          ),

          // Chat list
          Expanded(
            child: messagingState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: StudentColors.text3),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: StudentColors.text3,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return _buildChatTile(messages[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index) {
    final isActive = _selectedCategory == index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? StudentColors.primary : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.white : StudentColors.primary,
          fontFamily: AppFonts.heading,
        ),
      ),
    );
  }

  Widget _buildChatTile(MessageItem message) {
    final gradient = _getGradientForSender(message.senderId);
    final initial = message.senderName?.isNotEmpty == true 
        ? message.senderName![0].toUpperCase() 
        : 'U';
    
    return GestureDetector(
      onTap: () => _openChat(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(child: Text(initial, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold))),
                ),
                if (!message.isRead)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: StudentColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName ?? 'Unknown User',
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StudentColors.text3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 9,
                    color: StudentColors.text3,
                  ),
                ),
                if (!message.isRead) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: StudentColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.circle, size: 8, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(MessageItem message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatDetailScreen(
          senderName: message.senderName ?? 'Unknown',
          senderId: message.senderId,
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Study Group'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Physics Revision Squad',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What is this group for?',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🎉 Group Created!')),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// Chat Detail Screen
class _ChatDetailScreen extends StatefulWidget {
  final String senderName;
  final String senderId;

  const _ChatDetailScreen({required this.senderName, required this.senderId});

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  
  // Sample messages for demo (would be fetched from API in real app)
  final List<Map<String, dynamic>> _sampleMessages = [
    {
      'text': 'Hello! How can I assist you with your studies today?',
      'isMe': false,
      'time': '9:00 AM',
    },
    {
      'text': 'Can you explain integration by parts one more time?',
      'isMe': true,
      'time': '3:20 PM',
    },
    {
      'text': 'Sure! The formula is ∫u·dv = uv - ∫v·du. Pick u as the function that simplifies when differentiated.',
      'isMe': false,
      'time': '3:25 PM',
    },
    {
      'text': 'Thank you! 🙏',
      'isMe': true,
      'time': '3:26 PM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: StudentColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(widget.senderName[0], style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.senderName,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _sampleMessages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_sampleMessages[index]);
              },
            ),
          ),
          _buildComposeBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: msg['isMe'] ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: msg['isMe'] ? StudentColors.primary : StudentColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg['isMe'] ? 18 : 0),
                bottomRight: Radius.circular(msg['isMe'] ? 0 : 18),
              ),
              boxShadow: [
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
                  msg['text']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: msg['isMe'] ? Colors.white : StudentColors.text,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg['time']!,
                  style: TextStyle(
                    fontSize: 9,
                    color: msg['isMe'] ? Colors.white60 : StudentColors.text3,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: StudentColors.surface,
        border: Border(top: BorderSide(color: StudentColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: StudentColors.text3),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(fontSize: 12, color: StudentColors.text3),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
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
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: StudentColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _sampleMessages.add({
        'text': text,
        'isMe': true,
        'time': 'Just now',
      });
      _messageController.clear();
    });
    
    // In real app, would call:
    // ref.read(messagingProvider.notifier).sendMessage(text, widget.senderId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}