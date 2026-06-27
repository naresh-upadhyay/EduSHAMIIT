import 'dart:async';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';
import 'package:edu_shamiit_ai/core/widgets/image_preview_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/teacher_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_ai/core/services/call_service.dart';
import 'package:edu_shamiit_ai/shared/screens/call_screen.dart';

class TeacherMessaging extends ConsumerStatefulWidget {
  final String? initialChatId;
  const TeacherMessaging({super.key, this.initialChatId});

  @override
  ConsumerState<TeacherMessaging> createState() => _TeacherMessagingState();
}

class _TeacherMessagingState extends ConsumerState<TeacherMessaging> {
  int _selectedCategory = 0; // 0=All, 1=Teachers, 2=Students, 3=Groups
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(messagingProvider.notifier).fetchMessages();
      if (widget.initialChatId != null && mounted) {
        final conversations = ref.read(messagingProvider).conversations;
        final match = conversations
            .where((c) => c.id == widget.initialChatId)
            .firstOrNull;
        if (match != null) {
          _openChat(match);
        } else {
          _openChatById(widget.initialChatId!);
        }
      }
    });

    _searchController.addListener(_onSearchChanged);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    final channelName = 'messages_list_teach_$currentUserId';
    _realtimeChannel = Supabase.instance.client.channel(channelName);

    _realtimeChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (!mounted) return;
        final newRecord = payload.newRecord;
        final msgGroupId = newRecord['group_id'] as String?;
        final msgSenderId = newRecord['sender_id'] as String?;
        final msgReceiverId = newRecord['receiver_id'] as String?;

        bool shouldUpdate = false;
        if (msgGroupId != null) {
          final conversations = ref.read(messagingProvider).conversations;
          shouldUpdate =
              conversations.any((c) => c.type == 'group' && c.id == msgGroupId);
        } else {
          shouldUpdate =
              msgSenderId == currentUserId || msgReceiverId == currentUserId;
        }

        if (shouldUpdate) {
          debugPrint('[Realtime List] Refreshing conversations list');
          ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
        }
      },
    )
        .subscribe((status, [error]) {
      debugPrint('[Realtime List] Channel status: $status, error: $error');
    });
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      setState(() => _isSearching = true);
      final results =
          await ref.read(messagingProvider.notifier).searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}';
  }

  Gradient _getGradientForSender(String senderId) {
    final hash = senderId.hashCode;
    final gradients = [
      const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)]),
      const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
      const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
      const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
      const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).userData?['id'] as String?;
    if (currentUserId != null && _realtimeChannel == null) {
      Future.microtask(() => _setupRealtimeSubscription());
    }
    final messagingState = ref.watch(messagingProvider);
    final conversations = messagingState.conversations;

    // Filter conversations by category
    final filteredConversations = conversations.where((c) {
      if (_selectedCategory == 0) return true;
      if (_selectedCategory == 1) {
        return c.type == 'direct' && c.role == 'teacher';
      }
      if (_selectedCategory == 2) {
        return c.type == 'direct' && c.role == 'student';
      }
      if (_selectedCategory == 3) return c.type == 'group';
      return true;
    }).toList();

    final isSearchingMode = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
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
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: isSearchingMode
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                hintText: '🔍 Search teachers, students...',
                hintStyle:
                    const TextStyle(fontSize: 12, color: TeacherColors.text3),
                filled: true,
                fillColor: TeacherColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: TeacherColors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          if (!isSearchingMode) ...[
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
          ],

          // List content
          Expanded(
            child: isSearchingMode
                ? _buildSearchResultsList()
                : messagingState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedCategory == 3
                        ? _buildGroupsView(filteredConversations)
                        : filteredConversations.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        size: 64, color: TeacherColors.text3),
                                    SizedBox(height: 16),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontFamily: AppFonts.heading,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: TeacherColors.text3,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: filteredConversations.length,
                                itemBuilder: (context, index) {
                                  return _buildChatTile(
                                      filteredConversations[index]);
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index) {
    final isActive = _selectedCategory == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? TeacherColors.primary : const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : TeacherColors.primary,
            fontFamily: AppFonts.heading,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsView(List<ChatConversation> filteredConversations) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: InkWell(
            onTap: _showBrowseGroupsSheet,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.explore, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore School Groups',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Discover and join active study revision squads',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredConversations.isEmpty
              ? const Center(
                  child: Text(
                    'No groups joined yet',
                    style: TextStyle(color: TeacherColors.text3, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filteredConversations.length,
                  itemBuilder: (context, index) {
                    return _buildChatTile(filteredConversations[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: TeacherColors.text3),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TeacherColors.text3,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final u = _searchResults[index];
        final name = u['full_name'] as String? ?? 'User';
        final role = u['role'] as String? ?? 'student';
        final id = u['id'] as String;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _ChatDetailScreen(
                  senderName: name,
                  senderId: id,
                  isGroup: false,
                  avatarUrl: u['avatar_url'] as String?,
                ),
              ),
            );
            if (mounted) {
              ref
                  .read(messagingProvider.notifier)
                  .fetchMessages(useCache: false);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TeacherColors.surface,
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
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: u['avatar_url'] != null &&
                          (u['avatar_url'] as String).isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            u['avatar_url'] as String,
                            fit: BoxFit.cover,
                            width: 42,
                            height: 42,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: TeacherColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: TeacherColors.text3,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTile(ChatConversation conversation) {
    final gradient = _getGradientForSender(conversation.id);
    final initial =
        conversation.name.isNotEmpty ? conversation.name[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: () => _openChat(conversation),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TeacherColors.surface,
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
                  child: conversation.avatarUrl != null &&
                          conversation.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            conversation.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 42,
                            height: 42,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
                if (conversation.unreadCount > 0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: TeacherColors.primary,
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
                  Row(
                    children: [
                      Text(
                        conversation.name,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (conversation.type == 'group') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GROUP',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: TeacherColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.lastMessage,
                    style: TextStyle(
                      fontSize: 10,
                      color: conversation.unreadCount > 0
                          ? TeacherColors.text
                          : TeacherColors.text3,
                      fontWeight: conversation.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
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
                  _formatTime(conversation.lastMessageTime),
                  style: const TextStyle(
                    fontSize: 9,
                    color: TeacherColors.text3,
                  ),
                ),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: TeacherColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Center(
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
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

  void _openChat(ChatConversation conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatDetailScreen(
          senderName: conversation.name,
          senderId: conversation.id,
          isGroup: conversation.type == 'group',
          avatarUrl: conversation.avatarUrl,
        ),
      ),
    );
    if (mounted) {
      ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
    }
  }

  void _openChatById(String id) async {
    try {
      final client = Supabase.instance.client;
      // 1. Check if it's a group
      final groupRes =
          await client.from('groups').select().eq('id', id).maybeSingle();
      if (groupRes != null) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ChatDetailScreen(
              senderName: groupRes['name'] as String? ?? 'Group',
              senderId: id,
              isGroup: true,
              avatarUrl: groupRes['avatar_url'] as String?,
            ),
          ),
        );
        if (mounted) {
          ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
        }
        return;
      }

      // 2. Otherwise check if it's a user profile
      final profileRes =
          await client.from('profiles').select().eq('id', id).maybeSingle();
      if (profileRes != null) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _ChatDetailScreen(
              senderName: profileRes['full_name'] as String? ?? 'User',
              senderId: id,
              isGroup: false,
              avatarUrl: profileRes['avatar_url'] as String?,
            ),
          ),
        );
        if (mounted) {
          ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
        }
      }
    } catch (e) {
      debugPrint('Error opening chat by ID: $e');
    }
  }

  void _showBrowseGroupsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: ref.read(messagingProvider.notifier).fetchGroups(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final groups = snapshot.data ?? [];
                if (groups.isEmpty) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: Text('No study groups available')),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Browse Study Groups',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final g = groups[index];
                            final name = g['name'] as String;
                            final desc =
                                g['description'] as String? ?? 'No description';
                            final id = g['id'] as String;
                            final isMember = g['is_member'] as bool? ?? false;

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              subtitle: Text(desc,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: TeacherColors.text3)),
                              trailing: isMember
                                  ? const Text('Joined',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))
                                  : ElevatedButton(
                                      onPressed: () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        Navigator.pop(context);
                                        final ok = await ref
                                            .read(messagingProvider.notifier)
                                            .joinGroup(id);
                                        if (ok && mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Joined squad "$name"!')),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TeacherColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                      ),
                                      child: const Text('Join',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateGroupBottomSheet(isTeacher: true),
    );
  }
}

// Chat Detail Screen
class _ChatDetailScreen extends ConsumerStatefulWidget {
  final String senderName;
  final String senderId;
  final bool isGroup;
  final String? avatarUrl;

  const _ChatDetailScreen({
    required this.senderName,
    required this.senderId,
    required this.isGroup,
    this.avatarUrl,
  });

  @override
  ConsumerState<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<_ChatDetailScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;
  String? _lastSeenMessageId;

  final SpeechToText _stt = SpeechToText();
  bool _isListening = false;
  bool _sttAvailable = false;
  final String _sttLocale = 'en_US';
  String _liveWords = '';
  late AnimationController _micPulseController;
  MessageItem? _replyingTo;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
    _micPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));

    Future.microtask(() async {
      if (!mounted) return;
      await ref
          .read(messagingProvider.notifier)
          .fetchChatHistory(widget.senderId);
      if (!mounted) return;
      _updateLastSeenMessageId();
    });

    _setupRealtimeSubscription();
    _startPollTimer();
  }

  void _updateLastSeenMessageId() {
    if (!mounted) return;
    final history = ref.read(messagingProvider).chatHistory;
    if (history.isNotEmpty) {
      _lastSeenMessageId = history.last.id;
    }
  }

  /// Polling fallback: every 3s silently check for new messages.
  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final history = ref.read(messagingProvider).chatHistory;
      final latestId = history.isNotEmpty ? history.last.id : null;
      if (latestId != _lastSeenMessageId) {
        _lastSeenMessageId = latestId;
        return;
      }
      await ref.read(messagingProvider.notifier).fetchChatHistory(
            widget.senderId,
            refreshConversations: false,
          );
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateLastSeenMessageId();
    });
  }

  void _setupRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    final channelName = 'messages_chat_teach_${widget.senderId}_$currentUserId';
    _realtimeChannel = Supabase.instance.client.channel(channelName);

    _realtimeChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (!mounted) return;
        final newRecord = payload.newRecord;
        final msgGroupId = newRecord['group_id'] as String?;
        final msgSenderId = newRecord['sender_id'] as String?;
        final msgReceiverId = newRecord['receiver_id'] as String?;

        debugPrint('[Realtime] Received insert payload: $newRecord');

        bool shouldUpdate = false;
        if (widget.isGroup) {
          shouldUpdate =
              msgGroupId?.toLowerCase() == widget.senderId.toLowerCase();
          debugPrint(
              '[Realtime] group_id: $msgGroupId, widget.senderId: ${widget.senderId}, shouldUpdate: $shouldUpdate');
        } else {
          final isFromPartner = msgSenderId?.toLowerCase() ==
                  widget.senderId.toLowerCase() &&
              (msgReceiverId == null ||
                  msgReceiverId.toLowerCase() == currentUserId.toLowerCase());
          final isFromMe = msgSenderId?.toLowerCase() ==
                  currentUserId.toLowerCase() &&
              (msgReceiverId == null ||
                  msgReceiverId.toLowerCase() == widget.senderId.toLowerCase());
          final noReceiver = msgReceiverId == null || msgReceiverId.isEmpty;
          final involvesMe =
              msgSenderId?.toLowerCase() == currentUserId.toLowerCase() ||
                  msgSenderId?.toLowerCase() == widget.senderId.toLowerCase();
          shouldUpdate =
              isFromPartner || isFromMe || (noReceiver && involvesMe);
          debugPrint(
              '[Realtime] isFromPartner: $isFromPartner, isFromMe: $isFromMe, noReceiver: $noReceiver, shouldUpdate: $shouldUpdate');
        }

        if (shouldUpdate) {
          ref
              .read(messagingProvider.notifier)
              .appendNewMessage(newRecord, currentUserId);
          _lastSeenMessageId = newRecord['id'] as String? ?? _lastSeenMessageId;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              ref.read(messagingProvider.notifier).fetchChatHistory(
                    widget.senderId,
                    refreshConversations: msgSenderId?.toLowerCase() !=
                        currentUserId.toLowerCase(),
                  );
            }
          });
        }
      },
    )
        .subscribe((status, [error]) {
      debugPrint('[Realtime] Channel status: $status, error: $error');
    });
  }

  void _onMessageTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _micPulseController.dispose();
    try {
      _stt.stop();
    } catch (_) {}
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _startVoice() async {
    if (!_sttAvailable) {
      try {
        _sttAvailable = await _stt.initialize(
          onError: (e) {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          },
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') &&
                mounted &&
                _isListening) {
              _onSttDone();
            }
          },
        );
      } catch (e) {
        _sttAvailable = false;
      }
    }

    if (!mounted) return;
    if (!_sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Speech recognition is not available on this device.')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _liveWords = '';
    });
    _micPulseController.repeat(reverse: true);

    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted) return;
          if (!_isListening) return;
          setState(() {
            _liveWords = result.recognizedWords;
            _messageController.text = _liveWords;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _liveWords.length),
            );
          });
          if (result.finalResult && _liveWords.trim().isNotEmpty) {
            _stopAndSendVoice();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: _sttLocale,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _micPulseController.stop();
      }
    }
  }

  void _onSttDone() {
    if (_isListening) {
      _stopAndSendVoice();
    }
  }

  Future<void> _stopAndSendVoice() async {
    if (!_isListening) return;
    final text = _liveWords.trim();
    setState(() {
      _isListening = false;
      _liveWords = '';
    });
    _micPulseController.stop();
    try {
      _stt.stop();
    } catch (_) {}

    if (text.isEmpty) return;
    _sendMessage(text);
  }

  Widget _buildVoiceListeningBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _micPulseController,
            builder: (_, __) => Icon(
              Icons.mic_rounded,
              color: Colors.red
                  .withValues(alpha: 0.5 + 0.5 * _micPulseController.value),
              size: 20 + 4 * _micPulseController.value,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _liveWords.isEmpty ? 'Listening... speak now' : _liveWords,
              style: TextStyle(
                fontSize: 13,
                color: _liveWords.isEmpty ? Colors.grey : Colors.black87,
                fontStyle:
                    _liveWords.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Attach',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(
                    label: 'Gallery',
                    icon: Icons.photo_library,
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery);
                    },
                  ),
                  _buildAttachOption(
                    label: 'Camera',
                    icon: Icons.camera_alt,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera);
                    },
                  ),
                  _buildAttachOption(
                    label: 'Document',
                    icon: Icons.insert_drive_file,
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final filename = pickedFile.name;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('📸 Uploading image...'),
            duration: Duration(seconds: 2)),
      );
    }

    try {
      final response = await ref.read(apiServiceProvider).multipartPostBytes(
            '/teacher/messages/upload',
            bytes,
            filename,
            'file',
          );
      final data = response.containsKey('data') ? response['data'] : response;
      final url = data['url'] as String;

      _sendMessage('[IMAGE]$url');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final filename = file.name;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('📄 Uploading document...'),
            duration: Duration(seconds: 2)),
      );
    }

    try {
      final response = await ref.read(apiServiceProvider).multipartPostBytes(
            '/teacher/messages/upload',
            bytes,
            filename,
            'file',
          );
      final data = response.containsKey('data') ? response['data'] : response;
      final url = data['url'] as String;

      _sendMessage('[DOCUMENT]$url|$filename');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _clearChat() async {
    final ok =
        await ref.read(messagingProvider.notifier).clearChat(widget.senderId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared successfully!')),
      );
    }
  }

  Future<void> _exportChatHistory() async {
    final history = ref.read(messagingProvider).chatHistory;
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history to export')),
      );
      return;
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('========================================');
    sb.writeln('EduSHAMIIT Chat Export with: ${widget.senderName}');
    sb.writeln('Exported on: ${DateTime.now().toLocal()}');
    sb.writeln('========================================\n');

    final currentUserId = ref.read(authProvider).userData?['id'] as String?;

    for (final msg in history) {
      final timeStr = msg.createdAt.toLocal().toString();
      final senderName =
          msg.senderId == currentUserId ? 'You' : (msg.senderName ?? 'Contact');
      sb.writeln('[$timeStr] $senderName: ${msg.content}');
    }

    try {
      final content = sb.toString();
      final dataUri =
          'data:text/plain;charset=utf-8,${Uri.encodeComponent(content)}';
      final filename =
          "chat_export_${widget.senderName.replaceAll(' ', '_')}.txt";
      await getDownloadHelper().downloadFile(dataUri, filename);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat exported successfully as $filename')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export chat: $e')),
      );
    }
  }

  void _showMessageContextMenu(Offset position, MessageItem msg, bool isMe) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx,
        MediaQuery.of(context).size.height - position.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E293B),
      items: [
        const PopupMenuItem(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Reply',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Copy', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (isMe)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'reply') {
        setState(() {
          _replyingTo = msg;
        });
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: msg.content)).then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message copied to clipboard!')),
            );
          }
        });
      } else if (value == 'delete') {
        _deleteMessage(msg.id);
      }
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    final ok = await ref
        .read(messagingProvider.notifier)
        .deleteMessage(messageId, widget.senderId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted successfully!')),
      );
    }
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: TeacherColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${msgName(_replyingTo!)}',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TeacherColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  String msgName(MessageItem msg) {
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (msg.senderId == currentUserId) return 'You';
    return msg.senderName ?? 'User';
  }

  void _startCall({required bool isVideo}) {
    if (widget.isGroup) return; // Group calls not supported (P2P only)

    final authState = ref.read(authProvider);
    final currentUserId = authState.userData?['id'] as String?;
    if (currentUserId == null) return;

    final callService = CallService.instance;

    if (callService.activeCall.value != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already in a call.')),
      );
      return;
    }

    callService.initiateCall(
      calleeId: widget.senderId,
      calleeName: widget.senderName,
      calleeAvatarUrl: widget.avatarUrl,
      callType: isVideo ? CallType.video : CallType.audio,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );
  }

  void _showDetailsView() async {
    List<Map<String, dynamic>> groupMembers = [];
    bool isLoadingMembers = false;

    if (widget.isGroup) {
      setState(() => isLoadingMembers = true);
      groupMembers = await ref
          .read(messagingProvider.notifier)
          .fetchGroupMembers(widget.senderId);
      if (!mounted) return;
      setState(() => isLoadingMembers = false);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentUserId =
                ref.read(authProvider).userData?['id'] as String?;
            final currentUserMember = groupMembers.firstWhere(
              (m) => m['id'] == currentUserId,
              orElse: () => <String, dynamic>{},
            );
            final isCurrentUserAdmin =
                currentUserMember['group_role'] == 'admin';

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF06B6D4)
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.lightBlue.shade100, width: 3),
                              ),
                              child: widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        widget.avatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 80,
                                        height: 80,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Text(
                                            widget.senderName.isNotEmpty
                                                ? widget.senderName[0]
                                                    .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                                fontSize: 32,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        widget.senderName.isNotEmpty
                                            ? widget.senderName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            fontSize: 32,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.senderName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFamily: AppFonts.heading,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isGroup ? "Study Group" : "School Member",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      if (widget.isGroup) ...[
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: TeacherColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Description",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Active collaboration, notes sharing, and revision queries squad.",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[800]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Group Members (${groupMembers.length})",
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_add_alt_1_rounded,
                                  color: TeacherColors.primary, size: 20),
                              onPressed: () => _showAddMemberDialog(
                                  setSheetState, groupMembers),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isLoadingMembers)
                          const Center(child: CircularProgressIndicator())
                        else if (groupMembers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: Text("No members in this group",
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey))),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: groupMembers.length,
                            itemBuilder: (context, index) {
                              final member = groupMembers[index];
                              final mName =
                                  member['full_name'] as String? ?? 'Member';
                              final mRole =
                                  member['role'] as String? ?? 'student';
                              final gRole =
                                  member['group_role'] as String? ?? 'member';
                              final isCreator = gRole == 'admin';
                              final mId = member['id'] as String;
                              final isSelf = mId == currentUserId;

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                onTap: (isCurrentUserAdmin && !isSelf)
                                    ? () => _showMemberActionsDialog(
                                          context,
                                          member,
                                          setSheetState,
                                          groupMembers,
                                        )
                                    : null,
                                leading: member['avatar_url'] != null &&
                                        (member['avatar_url'] as String)
                                            .isNotEmpty
                                    ? SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: ClipOval(
                                          child: Image.network(
                                            member['avatar_url'] as String,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              color: TeacherColors.primary
                                                  .withValues(alpha: 0.1),
                                              alignment: Alignment.center,
                                              child: Text(
                                                  mName.isNotEmpty
                                                      ? mName[0].toUpperCase()
                                                      : 'M',
                                                  style: const TextStyle(
                                                      color:
                                                          TeacherColors.primary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: TeacherColors.primary
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                            mName.isNotEmpty
                                                ? mName[0].toUpperCase()
                                                : 'M',
                                            style: const TextStyle(
                                                color: TeacherColors.primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                title: Text(mName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                subtitle: Text(mRole.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                trailing: isCreator
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text('Admin',
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold)),
                                      )
                                    : null,
                              );
                            },
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _leaveGroupAction(context),
                            icon: const Icon(Icons.exit_to_app,
                                color: Colors.white, size: 16),
                            label: const Text("Leave Group",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (isCurrentUserAdmin) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteGroupAction(context),
                              icon: const Icon(Icons.delete_forever,
                                  color: Colors.red, size: 16),
                              label: const Text("Delete Group",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.email_outlined,
                              color: TeacherColors.primary),
                          title: const Text("Email Address",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "${widget.senderName.toLowerCase().replaceAll(' ', '.')}@edushamiit.edu",
                              style: const TextStyle(fontSize: 13)),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_user_outlined,
                              color: TeacherColors.primary),
                          title: const Text("Role & Identity",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              widget.senderName.contains('Sharma') ||
                                      widget.senderName.contains('Verma')
                                  ? "Teacher (Faculty)"
                                  : "Student classmate (Class X-A)",
                              style: const TextStyle(fontSize: 13)),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.school_outlined,
                              color: TeacherColors.primary),
                          title: Text("Institution",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text("EduSHAMIIT Public School",
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showMemberActionsDialog(
    BuildContext context,
    Map<String, dynamic> member,
    void Function(void Function()) setSheetState,
    List<Map<String, dynamic>> groupMembers,
  ) {
    final mName = member['full_name'] as String? ?? 'Member';
    final mId = member['id'] as String;
    final gRole = member['group_role'] as String? ?? 'member';
    final isAdmin = gRole == 'admin';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            mName,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.admin_panel_settings,
                  color: TeacherColors.primary,
                ),
                title: Text(isAdmin ? 'Dismiss as Admin' : 'Make Group Admin'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);

                  final newRole = isAdmin ? 'member' : 'admin';
                  final ok = await ref
                      .read(messagingProvider.notifier)
                      .changeMemberRole(
                        widget.senderId,
                        mId,
                        newRole,
                      );

                  if (ok) {
                    final updated = await ref
                        .read(messagingProvider.notifier)
                        .fetchGroupMembers(widget.senderId);
                    setSheetState(() {
                      groupMembers.clear();
                      groupMembers.addAll(updated);
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text('Updated $mName to $newRole')),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Failed to update role. A group must have at least one admin.')),
                    );
                  }
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.person_remove_outlined, color: Colors.red),
                title: const Text('Remove from Group',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(dialogContext);

                  final ok = await ref
                      .read(messagingProvider.notifier)
                      .removeGroupMember(
                        widget.senderId,
                        mId,
                      );

                  if (ok) {
                    final updated = await ref
                        .read(messagingProvider.notifier)
                        .fetchGroupMembers(widget.senderId);
                    setSheetState(() {
                      groupMembers.clear();
                      groupMembers.addAll(updated);
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text('Removed $mName from group')),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Failed to remove member')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteGroupAction(BuildContext sheetContext) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Delete Group",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: const Text(
              "Are you sure you want to permanently delete this group? All messages and members will be removed."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                Navigator.pop(dialogContext); // close dialog
                Navigator.pop(sheetContext); // close sheet

                final ok = await ref
                    .read(messagingProvider.notifier)
                    .deleteGroup(widget.senderId);
                if (ok) {
                  navigator
                      .pop(); // return from ChatDetailScreen to Conversation list
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Group deleted successfully.')),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to delete group.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddMemberDialog(void Function(void Function()) setSheetState,
      List<Map<String, dynamic>> currentMembers) {
    final searchMemberController = TextEditingController();
    List<Map<String, dynamic>> searchMemberResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Group Member',
                  style: TextStyle(fontFamily: AppFonts.heading)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchMemberController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by name...',
                    ),
                    onChanged: (val) async {
                      if (val.trim().isNotEmpty) {
                        setDialogState(() => isSearching = true);
                        final res = await ref
                            .read(messagingProvider.notifier)
                            .searchUsers(val.trim());
                        setDialogState(() {
                          searchMemberResults = res;
                          isSearching = false;
                        });
                      } else {
                        setDialogState(() {
                          searchMemberResults = [];
                          isSearching = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (searchMemberResults.isEmpty &&
                      searchMemberController.text.trim().isNotEmpty)
                    const Center(
                        child: Text('No results found',
                            style: TextStyle(fontSize: 12, color: Colors.grey)))
                  else
                    SizedBox(
                      height: 150,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: searchMemberResults.length,
                        itemBuilder: (context, index) {
                          final u = searchMemberResults[index];
                          final uName = u['full_name'] as String? ?? 'User';
                          final uId = u['id'] as String;
                          final uRole = u['role'] as String? ?? 'student';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(uName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(uRole.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: TeacherColors.primary),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                try {
                                  final client = ref.read(apiServiceProvider);
                                  // First add member in group_members table
                                  await client.post(
                                      '/groups/${widget.senderId}/members', {
                                    'member_id': uId,
                                  });

                                  // Then send direct system announcement
                                  await client.post('/student/messages/send', {
                                    'group_id': widget.senderId,
                                    'content':
                                        '📢 $uName joined the squad revision!'
                                  });

                                  final updatedMembers = await ref
                                      .read(messagingProvider.notifier)
                                      .fetchGroupMembers(widget.senderId);
                                  if (!mounted) return;
                                  setSheetState(() {
                                    currentMembers.clear();
                                    currentMembers.addAll(updatedMembers);
                                  });

                                  messenger.showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Added $uName to group!')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Added member to group!')),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _leaveGroupAction(BuildContext sheetContext) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Leave Group?',
              style: TextStyle(fontFamily: AppFonts.heading)),
          content: Text(
              'Are you sure you want to leave the study group "${widget.senderName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                Navigator.pop(dialogContext);
                Navigator.pop(sheetContext);

                final ok = await ref
                    .read(messagingProvider.notifier)
                    .leaveGroup(widget.senderId);
                if (ok) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content: Text('You left group "${widget.senderName}"')),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content:
                            Text('Failed to leave group. Please try again.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagingState = ref.watch(messagingProvider);
    final history = messagingState.chatHistory;
    final currentUserId = ref.watch(authProvider).userData?['id'] as String?;
    if (currentUserId != null && _realtimeChannel == null) {
      Future.microtask(() => _setupRealtimeSubscription());
    }

    // Auto-scroll to bottom once list loads or updates
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        backgroundColor: TeacherColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _showDetailsView,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          widget.avatarUrl!,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              widget.senderName.isNotEmpty
                                  ? widget.senderName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.senderName.isNotEmpty
                              ? widget.senderName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
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
                    Text(
                      widget.isGroup ? 'Study Group' : 'Online',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () => _startCall(isVideo: true),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'clear') {
                _clearChat();
              } else if (val == 'export') {
                _exportChatHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Chat', style: TextStyle(fontSize: 13)),
              ),
              const PopupMenuItem(
                value: 'export',
                child:
                    Text('Export Chat (.txt)', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Say hello! 👋',
                      style:
                          TextStyle(color: TeacherColors.text3, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final msg = history[index];
                      final isMe = msg.senderId == currentUserId;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          if (_isListening) _buildVoiceListeningBar(),
          if (_replyingTo != null) _buildReplyPreview(),
          _buildComposeBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageItem msg, bool isMe) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPressStart: (details) =>
                _showMessageContextMenu(details.globalPosition, msg, isMe),
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? TeacherColors.primary : TeacherColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isGroup && !isMe) ...[
                    Text(
                      msg.senderName ?? 'Anonymous',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: TeacherColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (msg.content.startsWith('[IMAGE]')) ...[
                    GestureDetector(
                      onTap: () {
                        final rawUrl = msg.content.substring('[IMAGE]'.length);
                        final imageUrl = rawUrl.replaceAll(
                            'http://kong:8000', 'http://127.0.0.1:8000');
                        ImagePreviewDialog.show(context, imageUrl,
                            title: 'Image View');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            msg.content.substring('[IMAGE]'.length).replaceAll(
                                'http://kong:8000', 'http://127.0.0.1:8000'),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.black12,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image,
                                      color: Colors.grey, size: 16),
                                  SizedBox(width: 8),
                                  Text('Failed to load image',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else if (msg.content.startsWith('[DOCUMENT]')) ...[
                    Builder(builder: (context) {
                      final parts =
                          msg.content.substring('[DOCUMENT]'.length).split('|');
                      final url = parts[0];
                      final name = parts.length > 1 ? parts[1] : 'Attachment';
                      final resolvedUrl = url.replaceAll(
                          'http://kong:8000', 'http://127.0.0.1:8000');
                      return InkWell(
                        onTap: () async {
                          try {
                            await getDownloadHelper()
                                .downloadFile(resolvedUrl, name);
                          } catch (_) {
                            try {
                              final uri = Uri.parse(resolvedUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            } catch (_) {}
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.15)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file,
                                  color: isMe
                                      ? Colors.white
                                      : TeacherColors.primary,
                                  size: 24),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to view / download',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white : TeacherColors.text,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 8,
                          color: isMe ? Colors.white70 : TeacherColors.text3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeBar() {
    final text = _messageController.text.trim();
    final isEmpty = text.isEmpty;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: TeacherColors.surface,
          border: Border(top: BorderSide(color: TeacherColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: TeacherColors.primary, size: 26),
              onPressed: _showAttachMenu,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: TeacherColors.text3),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (value) => _sendMessage(value),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopAndSendVoice();
                } else if (isEmpty) {
                  _startVoice();
                } else {
                  _sendMessage(_messageController.text);
                }
              },
              child: AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (_, __) {
                    final pulsing = _isListening;
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: pulsing ? Colors.red : TeacherColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: pulsing
                            ? [
                                BoxShadow(
                                  color: Colors.red.withValues(
                                      alpha: 0.35 +
                                          0.35 * _micPulseController.value),
                                  blurRadius: 8 + 6 * _micPulseController.value,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        pulsing
                            ? Icons.stop_rounded
                            : (isEmpty ? Icons.mic : Icons.send),
                        size: 16,
                        color: Colors.white,
                      ),
                    );
                  }),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => context.push('/teacher/ai-chat'),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    String content = text.trim();
    if (_replyingTo != null) {
      final senderName = msgName(_replyingTo!);
      content = '↳ "$senderName: ${_replyingTo!.content}"\n\n$content';
    }

    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });

    if (widget.isGroup) {
      await ref
          .read(messagingProvider.notifier)
          .sendMessage(content, groupId: widget.senderId);
    } else {
      await ref
          .read(messagingProvider.notifier)
          .sendMessage(content, receiverId: widget.senderId);
    }

    _scrollToBottom();
  }
}

// Stateful Call Overlay Screen Widget
class _CallOverlayScreen extends StatefulWidget {
  final String callerName;
  final bool isVideo;

  const _CallOverlayScreen({
    required this.callerName,
    required this.isVideo,
  });

  @override
  State<_CallOverlayScreen> createState() => _CallOverlayScreenState();
}

class _CallOverlayScreenState extends State<_CallOverlayScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Ringing...';
  int _duration = 0;
  Timer? _ringTimer;
  Timer? _durationTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCamOff = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ringTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _status = 'Connected';
        });
        _startDurationTimer();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration++;
        });
      }
    });
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final initials =
        widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : 'U';
    final isRinging = _status == 'Ringing...';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            if (widget.isVideo && !_isCamOff)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Icon(Icons.videocam,
                          size: 200, color: Colors.lightBlue.shade200),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  if (!widget.isVideo || _isCamOff) ...[
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                        CurvedAnimation(
                            parent: _pulseController, curve: Curves.easeInOut),
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Colors.lightBlue.shade900.withValues(alpha: 0.5),
                          border: Border.all(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.5),
                              width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRinging ? 'Ringing...' : _formatDuration(_duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: isRinging
                          ? Colors.lightBlue.shade300
                          : Colors.green.shade400,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.mic_off : Icons.mic,
                            color: _isMuted ? Colors.red : Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            color: _isSpeakerOn
                                ? const Color(0xFF06B6D4)
                                : Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSpeakerOn = !_isSpeakerOn;
                            });
                          },
                        ),
                        if (widget.isVideo) ...[
                          IconButton(
                            icon: Icon(
                              _isCamOff ? Icons.videocam_off : Icons.videocam,
                              color: _isCamOff ? Colors.red : Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              setState(() {
                                _isCamOff = !_isCamOff;
                              });
                            },
                          ),
                        ],
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Call with ${widget.callerName} ended'),
                              ),
                            );
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (widget.isVideo && !_isCamOff)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 8)
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Text(
                          'You',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupBottomSheet extends ConsumerStatefulWidget {
  final bool isTeacher;
  const _CreateGroupBottomSheet({required this.isTeacher});

  @override
  ConsumerState<_CreateGroupBottomSheet> createState() =>
      _CreateGroupBottomSheetState();
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashCount = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final rect =
        Rect.fromCircle(center: Offset(radius, radius), radius: radius);

    final sweepAngle = (2 * 3.141592653589793) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * sweepAngle * 2;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashCount != dashCount;
  }
}

class _CreateGroupBottomSheetState
    extends ConsumerState<_CreateGroupBottomSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _filteredCandidates = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoadingCandidates = false;

  Uint8List? _groupAvatarBytes;
  String? _groupAvatarName;
  Timer? _searchDebounceTimer;

  int _activeTab = 0;
  String _groupLevel = 'class';

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupAvatar() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1000, imageQuality: 90);
    if (picked == null) return;

    final croppedBytes = await _cropImage(picked.path);
    if (croppedBytes == null) return;

    String filename = picked.name;
    if (!filename.contains('.')) {
      filename += '.jpg';
    }

    setState(() {
      _groupAvatarBytes = croppedBytes;
      _groupAvatarName = filename;
    });
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 300, height: 300),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return null;
  }

  void _loadCandidates() async {
    setState(() => _isLoadingCandidates = true);
    final res = await ref.read(messagingProvider.notifier).searchUsers("");
    setState(() {
      _filteredCandidates = res;
      _isLoadingCandidates = false;
    });
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      if (!mounted) return;

      setState(() => _isLoadingCandidates = true);
      final res = await ref.read(messagingProvider.notifier).searchUsers(query);
      if (!mounted) return;

      setState(() {
        _filteredCandidates = res;
        _isLoadingCandidates = false;
      });
    });
  }

  List<Map<String, dynamic>> _getFilteredByRole(int tabIndex) {
    if (tabIndex == 0) return _filteredCandidates;
    if (tabIndex == 1) {
      return _filteredCandidates.where((u) => u['role'] == 'student').toList();
    }
    if (tabIndex == 2) {
      return _filteredCandidates.where((u) => u['role'] == 'teacher').toList();
    }
    if (tabIndex == 3) {
      return _filteredCandidates.where((u) {
        final role = (u['role'] as String? ?? '').toLowerCase();
        return role == 'hod' || role == 'principal' || role == 'admin';
      }).toList();
    }
    if (tabIndex == 4) {
      return _filteredCandidates.where((u) => u['role'] == 'parent').toList();
    }
    return _filteredCandidates;
  }

  Widget _buildRoleTab(String label, int index) {
    final isActive = _activeTab == index;
    final primaryColor =
        widget.isTeacher ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : primaryColor,
            fontFamily: AppFonts.heading,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        widget.isTeacher ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);
    final accentColor =
        widget.isTeacher ? const Color(0xFF0369A1) : const Color(0xFF7C3AED);
    final bottomOffset = MediaQuery.of(context).viewInsets.bottom;

    final userData = ref.watch(authProvider).userData ?? {};
    final userRole = userData['role'] as String? ?? 'student';
    final userClass = userData['class'] as String? ?? '';
    final isStudent = userRole == 'student';

    final activeList = _getFilteredByRole(_activeTab);
    final allSelected = activeList.isNotEmpty &&
        activeList.every((u) => _selectedUserIds.contains(u['id']));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor, accentColor]),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isTeacher
                          ? 'Create Class Group'
                          : 'Create Study Group',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + bottomOffset),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickGroupAvatar,
                            child: CustomPaint(
                              painter: DashedCirclePainter(
                                color: const Color(0xFF818CF8),
                                strokeWidth: 2,
                                dashCount: 16,
                              ),
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: _groupAvatarBytes != null
                                    ? ClipOval(
                                        child: Image.memory(
                                          _groupAvatarBytes!,
                                          fit: BoxFit.cover,
                                          width: 70,
                                          height: 70,
                                        ),
                                      )
                                    : const Center(
                                        child: Text(
                                          '📷',
                                          style: TextStyle(fontSize: 30),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Add Group Icon',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Group Name',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: widget.isTeacher
                            ? 'e.g. Class X-A Updates'
                            : 'e.g. Physics Revision Squad',
                        hintStyle:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Description (Optional)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _descController,
                      decoration: InputDecoration(
                        hintText: 'What is this group for?',
                        hintStyle:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Group Privacy Type Selection
                    const Text(
                      'GROUP PRIVACY',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _groupLevel = 'class'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _groupLevel == 'class'
                                    ? primaryColor.withValues(alpha: 0.1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _groupLevel == 'class'
                                      ? primaryColor
                                      : const Color(0xFFCBD5E1),
                                  width: _groupLevel == 'class' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.lock_outline_rounded,
                                          color: _groupLevel == 'class'
                                              ? primaryColor
                                              : Colors.grey,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        '🔒 Private',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _groupLevel == 'class'
                                              ? primaryColor
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Only selected members\ncan see and join',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _groupLevel == 'class'
                                          ? primaryColor.withValues(alpha: 0.8)
                                          : Colors.grey,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _groupLevel = 'school'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _groupLevel == 'school'
                                    ? primaryColor.withValues(alpha: 0.1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _groupLevel == 'school'
                                      ? primaryColor
                                      : const Color(0xFFCBD5E1),
                                  width: _groupLevel == 'school' ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.public_rounded,
                                          color: _groupLevel == 'school'
                                              ? primaryColor
                                              : Colors.grey,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        '🌐 Public (School)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _groupLevel == 'school'
                                              ? primaryColor
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Visible to school\nAnyone in school can join',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _groupLevel == 'school'
                                          ? primaryColor.withValues(alpha: 0.8)
                                          : Colors.grey,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (!isStudent || _groupLevel != 'class') ...[
                      const Text(
                        'ADD PARTICIPANTS',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: '🔍 Search by name or role...',
                          hintStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildRoleTab('All', 0),
                            const SizedBox(width: 6),
                            _buildRoleTab('Students', 1),
                            const SizedBox(width: 6),
                            _buildRoleTab('Teachers', 2),
                            const SizedBox(width: 6),
                            _buildRoleTab('HOD/Seniors', 3),
                            const SizedBox(width: 6),
                            _buildRoleTab('Parents', 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (activeList.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: allSelected,
                                  activeColor: primaryColor,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        for (final u in activeList) {
                                          _selectedUserIds.add(u['id']);
                                        }
                                      } else {
                                        for (final u in activeList) {
                                          _selectedUserIds.remove(u['id']);
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Select All Shown',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: _isLoadingCandidates
                            ? const Center(child: CircularProgressIndicator())
                            : activeList.isEmpty
                                ? const Center(
                                    child: Text('No school members found',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)))
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    itemCount: activeList.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                            height: 1,
                                            color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final u = activeList[index];
                                      final id = u['id'] as String;
                                      final name =
                                          u['full_name'] as String? ?? 'User';
                                      final role =
                                          u['role'] as String? ?? 'student';
                                      final isSelected =
                                          _selectedUserIds.contains(id);
                                      final avatarUrl =
                                          u['avatar_url'] as String?;

                                      final initial = name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U';
                                      final isTeacher = role == 'teacher';
                                      final bg = isTeacher
                                          ? const Color(0xFFEEF2FF)
                                          : const Color(0xFFFFF1F2);
                                      final fg = isTeacher
                                          ? const Color(0xFF4F46E5)
                                          : const Color(0xFFE11D48);

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedUserIds.remove(id);
                                            } else {
                                              _selectedUserIds.add(id);
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Row(
                                            children: [
                                              avatarUrl != null &&
                                                      avatarUrl.isNotEmpty
                                                  ? SizedBox(
                                                      width: 32,
                                                      height: 32,
                                                      child: ClipOval(
                                                        child: Image.network(
                                                          avatarUrl,
                                                          fit: BoxFit.cover,
                                                          width: 32,
                                                          height: 32,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              Container(
                                                            color: bg,
                                                            alignment: Alignment
                                                                .center,
                                                            child: Text(
                                                              isTeacher
                                                                  ? '👨‍🏫'
                                                                  : initial,
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: fg,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: bg,
                                                      child: Text(
                                                        isTeacher
                                                            ? '👨‍🏫'
                                                            : initial,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: fg,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                    ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 12),
                                                    ),
                                                    Text(
                                                      role.toUpperCase(),
                                                      style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.grey),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Checkbox(
                                                value: isSelected,
                                                activeColor: primaryColor,
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      _selectedUserIds.add(id);
                                                    } else {
                                                      _selectedUserIds
                                                          .remove(id);
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  final desc = _descController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a group name')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);

                  final level = isStudent ? 'class' : 'school';
                  final className = isStudent ? userClass : null;
                  final isPrivate = _groupLevel == 'class';

                  final ok =
                      await ref.read(messagingProvider.notifier).createGroup(
                            name,
                            desc,
                            memberIds: _selectedUserIds.toList(),
                            avatarBytes: _groupAvatarBytes,
                            avatarFilename: _groupAvatarName,
                            groupLevel: level,
                            className: className,
                            isPrivate: isPrivate,
                          );
                  if (ok) {
                    messenger.showSnackBar(
                      SnackBar(
                          content:
                              Text('🎉 Group "$name" Created successfully!')),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Failed to create group. Please try again.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: Text(
                  _groupLevel == 'class'
                      ? 'Create Private Group (${_selectedUserIds.length})'
                      : 'Create Public Group (${_selectedUserIds.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
