import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'api_provider.dart';

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return DateTime.now();
  return DateTime.tryParse(str) ?? DateTime.now();
}

bool _parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase().trim();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return defaultValue;
}

int _parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? defaultValue;
}

// ============================================================================
// MESSAGING MODELS
// ============================================================================

class MessageItem {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? senderRole;
  final String? senderPhone;
  final String? senderEmail;
  final String content;
  final String? attachmentUrl;
  final String? fileName;
  final int? fileSize;
  final String messageType; // 'text', 'file', 'image', 'voice', 'poll', 'announcement'
  final String? replyToId;
  final Map<String, dynamic> reactions;
  final bool isPinned;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  MessageItem({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.senderRole,
    this.senderPhone,
    this.senderEmail,
    required this.content,
    this.attachmentUrl,
    this.fileName,
    this.fileSize,
    this.messageType = 'text',
    this.replyToId,
    this.reactions = const {},
    this.isPinned = false,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return MessageItem(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: profile['full_name'] as String?,
      senderAvatar: profile['avatar_url'] as String?,
      senderRole: profile['role'] as String?,
      senderPhone: profile['phone'] as String?,
      senderEmail: profile['email'] as String?,
      content: json['content'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      messageType: json['message_type'] as String? ?? (json['attachment_url'] != null ? 'file' : 'text'),
      replyToId: json['reply_to_id'] as String?,
      reactions: (json['reactions'] as Map<String, dynamic>?) ?? const {},
      isPinned: _parseBool(json['is_pinned']),
      createdAt: _parseDateTime(json['created_at']),
      isRead: _parseBool(json['is_read']),
      readAt: json['read_at'] != null ? _parseDateTime(json['read_at']) : null,
    );
  }
}

class ChatConversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final String type; // 'direct' or 'group'
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? role; // 'student', 'parent', 'teacher', 'staff', 'admin'
  final String? phone;
  final String? email;
  final bool isVerified;
  final bool isOnline;
  final String? description;
  final String? studentName;
  final String? studentClass;
  final String? studentAvatar;
  final bool isPinned;

  ChatConversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.type,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.role,
    this.phone,
    this.email,
    this.isVerified = false,
    this.isOnline = false,
    this.description,
    this.studentName,
    this.studentClass,
    this.studentAvatar,
    this.isPinned = false,
  });

  ChatConversation copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? type,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? role,
    String? phone,
    String? email,
    bool? isVerified,
    bool? isOnline,
    String? description,
    String? studentName,
    String? studentClass,
    String? studentAvatar,
    bool? isPinned,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      description: description ?? this.description,
      studentName: studentName ?? this.studentName,
      studentClass: studentClass ?? this.studentClass,
      studentAvatar: studentAvatar ?? this.studentAvatar,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      type: json['type'] as String? ?? 'direct',
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: _parseDateTime(json['last_message_time']),
      unreadCount: _parseInt(json['unread_count']),
      role: json['role'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      isVerified: _parseBool(json['is_verified']),
      isOnline: _parseBool(json['is_online']),
      description: json['description'] as String?,
      studentName: json['student_name'] as String?,
      studentClass: json['student_class'] as String?,
      studentAvatar: json['student_avatar'] as String?,
      isPinned: _parseBool(json['is_pinned']),
    );
  }
}

// ============================================================================
// MESSAGING STATE & NOTIFIER
// ============================================================================

class MessagingState {
  final bool isLoading;
  final String? error;
  final List<ChatConversation> conversations;
  final List<MessageItem> chatHistory;
  final int unreadCount;
  final List<String> blockedUserIds;
  final Set<String> pinnedConversationIds;
  final Set<String> mutedConversationIds;

  MessagingState({
    this.isLoading = false,
    this.error,
    this.conversations = const [],
    this.chatHistory = const [],
    this.unreadCount = 0,
    this.blockedUserIds = const [],
    this.pinnedConversationIds = const {},
    this.mutedConversationIds = const {},
  });

  MessagingState copyWith({
    bool? isLoading,
    String? error,
    List<ChatConversation>? conversations,
    List<MessageItem>? chatHistory,
    int? unreadCount,
    List<String>? blockedUserIds,
    Set<String>? pinnedConversationIds,
    Set<String>? mutedConversationIds,
  }) {
    return MessagingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      conversations: conversations ?? this.conversations,
      chatHistory: chatHistory ?? this.chatHistory,
      unreadCount: unreadCount ?? this.unreadCount,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      pinnedConversationIds: pinnedConversationIds ?? this.pinnedConversationIds,
      mutedConversationIds: mutedConversationIds ?? this.mutedConversationIds,
    );
  }
}

class MessagingNotifier extends StateNotifier<MessagingState> {
  final ApiService _apiService;
  Set<String> _pinnedConversationIds = {};
  Set<String> _mutedConversationIds = {};

  MessagingNotifier(this._apiService) : super(MessagingState());

  Future<void> fetchMessages({bool useCache = true}) async {
    if (state.conversations.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      try {
        await fetchBlockedUsers();
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        final savedPinned = prefs.getStringList('pinned_conversations') ?? [];
        _pinnedConversationIds = savedPinned.toSet();
        final savedMuted = prefs.getStringList('muted_conversations') ?? [];
        _mutedConversationIds = savedMuted.toSet();
      } catch (_) {}

      final response =
          await _apiService.get('/messages', useCache: useCache);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawConvs = data['conversations'] as List? ?? [];
      final conversationsList = rawConvs.map((c) {
        final conv = ChatConversation.fromJson(c as Map<String, dynamic>);
        return conv.copyWith(
          isPinned: _pinnedConversationIds.contains(conv.id) || conv.isPinned,
        );
      }).toList();

      conversationsList.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

      final totalUnread =
          conversationsList.fold<int>(0, (sum, c) => sum + c.unreadCount);

      state = state.copyWith(
        isLoading: false,
        conversations: conversationsList,
        unreadCount: totalUnread,
        pinnedConversationIds: Set<String>.from(_pinnedConversationIds),
        mutedConversationIds: Set<String>.from(_mutedConversationIds),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleMuteConversation(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_mutedConversationIds.contains(conversationId)) {
        _mutedConversationIds.remove(conversationId);
      } else {
        _mutedConversationIds.add(conversationId);
      }
      await prefs.setStringList('muted_conversations', _mutedConversationIds.toList());
      state = state.copyWith(
        mutedConversationIds: Set<String>.from(_mutedConversationIds),
      );
    } catch (_) {}
  }

  Future<void> togglePinConversation(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pinnedConversationIds.contains(conversationId)) {
        _pinnedConversationIds.remove(conversationId);
      } else {
        _pinnedConversationIds.add(conversationId);
      }
      await prefs.setStringList('pinned_conversations', _pinnedConversationIds.toList());

      final updatedList = state.conversations.map((c) {
        if (c.id == conversationId) {
          return c.copyWith(isPinned: _pinnedConversationIds.contains(conversationId));
        }
        return c;
      }).toList();

      updatedList.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });

      state = state.copyWith(
        conversations: updatedList,
        pinnedConversationIds: Set<String>.from(_pinnedConversationIds),
      );
    } catch (_) {}
  }

  Future<void> fetchChatHistory(String chatId,
      {bool refreshConversations = true}) async {
    if (state.chatHistory.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService
          .get('/messages/chat?chat_id=$chatId', useCache: false);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawMsgs = data['messages'] as List? ?? [];
      final history = rawMsgs
          .map((m) => MessageItem.fromJson(m as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        isLoading: false,
        chatHistory: history,
      );
      // Refresh conversations to clear unread counts locally
      if (refreshConversations) {
        fetchMessages(useCache: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Directly append a new message from realtime payload to avoid an extra API call.
  /// Falls back to a full fetchChatHistory if the payload is incomplete.
  void appendNewMessage(Map<String, dynamic> rawPayload, String currentUserId) {
    try {
      final id = rawPayload['id'] as String?;
      final senderId = rawPayload['sender_id'] as String?;
      final content = rawPayload['content'] as String?;
      final createdAtStr = rawPayload['created_at'] as String?;
      if (id == null ||
          senderId == null ||
          content == null ||
          createdAtStr == null) {
        return;
      }

      // Avoid duplicates (our own send already optimistically refreshes)
      if (state.chatHistory.any((m) => m.id == id)) return;

      final newMsg = MessageItem(
        id: id,
        senderId: senderId,
        senderName: null, // will be filled when full history is fetched next time
        senderAvatar: null,
        senderRole: null,
        content: content,
        createdAt: _parseDateTime(createdAtStr),
        isRead: senderId == currentUserId,
      );

      state = state.copyWith(chatHistory: [...state.chatHistory, newMsg]);
    } catch (_) {
      // ignore parse errors
    }
  }

  Future<bool> sendMessage(
    String content, {
    String? receiverId,
    String? groupId,
    String? attachmentUrl,
    String? fileName,
    int? fileSize,
    String? messageType,
    String? replyToId,
  }) async {
    try {
      final body = <String, dynamic>{
        'content': content,
      };
      if (groupId != null) {
        body['group_id'] = groupId;
      } else {
        body['receiver_id'] = receiverId ?? '';
      }
      if (attachmentUrl != null) body['attachment_url'] = attachmentUrl;
      if (fileName != null) body['file_name'] = fileName;
      if (fileSize != null) body['file_size'] = fileSize;
      if (messageType != null) body['message_type'] = messageType;
      if (replyToId != null) body['reply_to_id'] = replyToId;

      await _apiService.post('/messages/send', body);

      // If we are currently viewing this chat, refresh its history
      final activeChatId = groupId ?? receiverId;
      if (activeChatId != null) {
        await fetchChatHistory(activeChatId);
      } else {
        await fetchMessages(useCache: false);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadMessageFile(Uint8List bytes, String filename) async {
    try {
      final res = await _apiService.multipartPostBytes(
        '/messages/upload',
        bytes,
        filename,
        'file',
      );
      final data = res.containsKey('data') ? res['data'] : res;
      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> reactToMessage(String messageId, String emoji, String chatId) async {
    try {
      await _apiService.post('/messages/react', {
        'message_id': messageId,
        'emoji': emoji,
      });
      await fetchChatHistory(chatId, refreshConversations: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pinMessage(String messageId, bool isPinned, String chatId) async {
    try {
      await _apiService.post('/messages/pin', {
        'message_id': messageId,
        'is_pinned': isPinned,
      });
      await fetchChatHistory(chatId, refreshConversations: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchContactDetails(String contactId) async {
    try {
      final res = await _apiService.get('/messages/contact-details/$contactId');
      final data = res.containsKey('data') ? res['data'] : res;
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _apiService.get('/users/search?q=$query');
      final data = response.containsKey('data') ? response['data'] : response;
      final users = data['users'] as List? ?? [];
      return List<Map<String, dynamic>>.from(users);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    try {
      final response = await _apiService.get('/groups');
      final data = response.containsKey('data') ? response['data'] : response;
      final groups = data['groups'] as List? ?? [];
      return List<Map<String, dynamic>>.from(groups);
    } catch (e) {
      return [];
    }
  }

  Future<String?> createGroup(
    String name,
    String description, {
    List<String> memberIds = const [],
    Uint8List? avatarBytes,
    String? avatarFilename,
    String groupLevel = 'school',
    String? className,
    bool isPrivate = false,
  }) async {
    try {
      final response = await _apiService.post('/groups/create', {
        'name': name,
        'description': description,
        'group_level': groupLevel,
        'class_name': className,
        'is_private': isPrivate,
      });
      final data = response.containsKey('data') ? response['data'] : response;
      final group = data['group'] as Map<String, dynamic>?;
      final groupId = group?['id'] as String?;

      if (groupId != null) {
        if (avatarBytes != null && avatarFilename != null) {
          try {
            await _apiService.multipartPostBytes(
              '/groups/$groupId/avatar',
              avatarBytes,
              avatarFilename,
              'avatar',
            );
          } catch (_) {}
        }

        if (memberIds.isNotEmpty) {
          for (final mid in memberIds) {
            try {
              await _apiService.post('/groups/$groupId/members', {
                'member_id': mid,
              });
            } catch (_) {}
          }

          try {
            await _apiService.post('/messages/send', {
              'group_id': groupId,
              'content':
                  '📢 Group squad formed with ${memberIds.length + 1} members!'
            });
          } catch (_) {}
        }
      }

      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return groupId ?? '';
    } catch (e) {
      return null;
    }
  }

  Future<bool> addMemberToGroup(String groupId, String memberId) async {
    try {
      await _apiService.post('/groups/$groupId/members', {
        'member_id': memberId,
      });
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateGroupDetails(String groupId, {String? name, String? description, String? avatarUrl}) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null && name.trim().isNotEmpty) payload['name'] = name.trim();
      if (description != null) payload['description'] = description.trim();
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) payload['avatar_url'] = avatarUrl.trim();
      
      await _apiService.put('/groups/$groupId', payload);
      _apiService.clearCache();
      
      final updatedList = state.conversations.map((c) {
        if (c.id == groupId) {
          return c.copyWith(
            name: name ?? c.name,
            description: description ?? c.description,
            avatarUrl: avatarUrl ?? c.avatarUrl,
          );
        }
        return c;
      }).toList();
      
      state = state.copyWith(conversations: updatedList);
      await fetchMessages(useCache: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> joinGroup(String groupId) async {
    try {
      await _apiService.post('/groups/$groupId/join', {});
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      await _apiService.post('/groups/$groupId/leave', {});
      _apiService.clearCache();
      final updatedList = state.conversations.where((c) => c.id != groupId).toList();
      state = state.copyWith(conversations: updatedList);
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    try {
      final response = await _apiService.get('/groups/$groupId/members', useCache: false);
      final data = response.containsKey('data') ? response['data'] : response;
      final members = data['members'] as List? ?? [];
      return List<Map<String, dynamic>>.from(members);
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteMessage(String messageId, String chatId) async {
    try {
      await _apiService.delete('/messages/$messageId');
      await fetchChatHistory(chatId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearChat(String chatId) async {
    try {
      await _apiService.post('/messages/clear', {'chat_id': chatId});
      await fetchChatHistory(chatId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchBlockedUsers() async {
    try {
      final response = await _apiService.get('/users/blocked');
      final data = response.containsKey('data') ? response['data'] : response;
      final blocked = data['blocked_ids'] as List? ?? [];
      state = state.copyWith(blockedUserIds: List<String>.from(blocked));
    } catch (_) {}
  }

  Future<bool> blockUser(String userId) async {
    try {
      await _apiService.post('/users/$userId/block', {});
      await fetchBlockedUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await _apiService.post('/users/$userId/unblock', {});
      await fetchBlockedUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await _apiService.delete('/groups/$groupId');
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeGroupMember(String groupId, String memberId) async {
    try {
      await _apiService.delete('/groups/$groupId/members/$memberId');
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeMemberRole(
      String groupId, String memberId, String role) async {
    try {
      await _apiService.post('/groups/$groupId/members/$memberId/role', {
        'role': role,
      });
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> updateGroupAvatar(
      String groupId, Uint8List bytes, String filename) async {
    try {
      final res = await _apiService.multipartPostBytes(
        '/groups/$groupId/avatar',
        bytes,
        filename,
        'avatar',
      );
      final newUrl = (res['data'] as Map<String, dynamic>?)?['avatar_url'] as String?;
      if (newUrl != null && newUrl.isNotEmpty) {
        final updatedList = state.conversations.map((c) {
          if (c.id == groupId) {
            return c.copyWith(avatarUrl: newUrl);
          }
          return c;
        }).toList();
        state = state.copyWith(conversations: updatedList);
      }
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return newUrl;
    } catch (e) {
      return null;
    }
  }
}

final messagingProvider =
    StateNotifierProvider<MessagingNotifier, MessagingState>((ref) {
  return MessagingNotifier(ref.watch(apiServiceProvider));
});

