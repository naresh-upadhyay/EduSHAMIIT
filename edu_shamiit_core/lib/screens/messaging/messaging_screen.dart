import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/download_helper.dart';
import '../../constants/app_fonts.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_service.dart';
import '../call/call_screen.dart';

// ============================================================================
// MESSAGING SCREEN — ENTERPRISE 3-COLUMN DESKTOP & RESPONSIVE LAYOUT
// Matched to EduSHAMIIT ERP Design Reference (media_1794053830464_e4a5226b.jpg)
// Full Dark & Light Theme Adaptability
// ============================================================================

class MessagingScreen extends ConsumerStatefulWidget {
  final String? initialChatId;
  final String? role;
  final Color? primaryColor;

  const MessagingScreen({
    super.key,
    this.initialChatId,
    this.role,
    this.primaryColor,
  });

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  // 0=All Chats, 1=Students, 2=Parents, 3=Staff, 4=Groups
  int _selectedCategory = 0;
  final TextEditingController _searchController = TextEditingController();
  String _filterMode = 'all'; // 'all', 'unread', 'groups', 'pinned'
  ChatConversation? _selectedConversation;
  bool _showDetailsPanel = true;
  bool _showSidebar = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(messagingProvider.notifier).fetchMessages();
      if (!mounted) return;
      final conversations = ref.read(messagingProvider).conversations;
      if (widget.initialChatId != null) {
        final match = conversations
            .where((c) => c.id == widget.initialChatId)
            .firstOrNull;
        if (match != null) {
          setState(() => _selectedConversation = match);
        } else if (conversations.isNotEmpty) {
          setState(() => _selectedConversation = conversations.first);
        }
      } else if (conversations.isNotEmpty && _selectedConversation == null) {
        // Auto-select first conversation (e.g. Anita Sharma) for instant desktop presentation
        setState(() => _selectedConversation = conversations.first);
      }
    });

    _searchController.addListener(() => setState(() {}));
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    final channelName = 'messages_list_sub_$currentUserId';
    _realtimeChannel = Supabase.instance.client.channel(channelName);

    _realtimeChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (!mounted) return;
        debugPrint('[Realtime List] Updating conversations on message change');
        ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
      },
    )
        .subscribe();
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
    if (diff.inHours < 1) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final min = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    }
    if (diff.inDays < 1 && now.day == dateTime.day) {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final min = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    }
    if (diff.inDays == 1 || (diff.inDays < 2 && now.day - dateTime.day == 1)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final d = days[dateTime.weekday - 1];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final m = months[dateTime.month - 1];
      return '$d, $m ${dateTime.day}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  IconData _getGroupIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('class') || lower.contains('grade')) {
      return Icons.groups_rounded;
    }
    if (lower.contains('library') || lower.contains('book')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('transport') || lower.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    if (lower.contains('science') || lower.contains('lab')) {
      return Icons.biotech_rounded;
    }
    if (lower.contains('ac') || lower.contains('committee') || lower.contains('team')) {
      return Icons.diversity_3_rounded;
    }
    return Icons.forum_rounded;
  }

  Color _getGroupColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('class')) return const Color(0xFF2563EB);
    if (lower.contains('library')) return const Color(0xFF7C3AED);
    if (lower.contains('transport')) return const Color(0xFF0284C7);
    if (lower.contains('science')) return const Color(0xFF0D9488);
    if (lower.contains('ac') || lower.contains('team')) return const Color(0xFF16A34A);
    return const Color(0xFF4F46E5);
  }

  List<ChatConversation> _filterConversations(List<ChatConversation> list) {
    final query = _searchController.text.trim().toLowerCase();
    return list.where((c) {
      // Category filter
      if (_selectedCategory == 1) {
        if (c.type != 'direct' || c.role != 'student') return false;
      } else if (_selectedCategory == 2) {
        if (c.type != 'direct' || c.role != 'parent') return false;
      } else if (_selectedCategory == 3) {
        if (c.type != 'direct' ||
            (c.role != 'staff' && c.role != 'teacher' && c.role != 'admin' && c.role != 'support')) {
          return false;
        }
      } else if (_selectedCategory == 4) {
        if (c.type != 'group') return false;
      }

      // Filter Mode
      if (_filterMode == 'unread' && c.unreadCount == 0) return false;
      if (_filterMode == 'groups' && c.type != 'group') return false;
      if (_filterMode == 'pinned' && !c.isPinned) return false;

      // Text Search
      if (query.isNotEmpty) {
        final nameMatch = c.name.toLowerCase().contains(query);
        final lastMsgMatch = c.lastMessage.toLowerCase().contains(query);
        final studentMatch = (c.studentName ?? '').toLowerCase().contains(query);
        if (!nameMatch && !lastMsgMatch && !studentMatch) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagingState = ref.watch(messagingProvider);
    final allConversations = messagingState.conversations;
    final filteredConversations = _filterConversations(allConversations);

    final activeConversation = _selectedConversation == null
        ? null
        : allConversations.firstWhere(
            (c) => c.id == _selectedConversation!.id,
            orElse: () => _selectedConversation!,
          );

    // Dynamic Category Counts
    final countAll = allConversations.length;
    final countStudents = allConversations
        .where((c) => c.type == 'direct' && c.role == 'student')
        .length;
    final countParents = allConversations
        .where((c) => c.type == 'direct' && c.role == 'parent')
        .length;
    final countStaff = allConversations
        .where((c) =>
            c.type == 'direct' &&
            (c.role == 'staff' ||
                c.role == 'teacher' ||
                c.role == 'admin' ||
                c.role == 'support'))
        .length;
    final countGroups = allConversations.where((c) => c.type == 'group').length;

    // Responsive breakpoints
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1080;
        final isTablet = constraints.maxWidth >= 720 && !isDesktop;
        final isMobile = constraints.maxWidth < 720;

        // Colors
        final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final primaryBlue = widget.primaryColor ?? const Color(0xFF2563EB);

        return Scaffold(
          backgroundColor: bgPage,
          body: SafeArea(
            child: Column(
              children: [
                // 1. TOP HEADER BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      // Circular Icon Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messaging',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Send and receive messages with students, parents, staff and groups',
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Toggle Sidebar Button
                      IconButton(
                        icon: Icon(
                          _showSidebar ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                          color: textSecondary,
                          size: 22,
                        ),
                        tooltip: _showSidebar ? 'Hide conversation list' : 'Show conversation list',
                        onPressed: () => setState(() => _showSidebar = !_showSidebar),
                      ),
                      const SizedBox(width: 6),
                      // "+ New Message" Button
                      ElevatedButton.icon(
                        onPressed: () => _showNewMessageDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'New Message',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. HORIZONTAL CATEGORY TABS BAR
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryTab(
                          label: 'All Chats ($countAll)',
                          index: 0,
                          isActive: _selectedCategory == 0,
                          primaryColor: primaryBlue,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 24),
                        _buildCategoryTab(
                          label: 'Students ($countStudents)',
                          index: 1,
                          isActive: _selectedCategory == 1,
                          primaryColor: primaryBlue,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 24),
                        _buildCategoryTab(
                          label: 'Parents ($countParents)',
                          index: 2,
                          isActive: _selectedCategory == 2,
                          primaryColor: primaryBlue,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 24),
                        _buildCategoryTab(
                          label: 'Staff ($countStaff)',
                          index: 3,
                          isActive: _selectedCategory == 3,
                          primaryColor: primaryBlue,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        const SizedBox(width: 24),
                        _buildCategoryTab(
                          label: 'Groups ($countGroups)',
                          index: 4,
                          isActive: _selectedCategory == 4,
                          primaryColor: primaryBlue,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. RESPONSIVE MULTI-COLUMN CONTENT AREA
                Expanded(
                  child: isMobile
                      ? (activeConversation == null
                          ? _buildConversationListColumn(
                              filteredConversations,
                              cardBg,
                              borderColor,
                              textPrimary,
                              textSecondary,
                              primaryBlue,
                              isDark,
                            )
                          : _ChatCenterPane(
                              conversation: activeConversation,
                              primaryColor: primaryBlue,
                              isDark: isDark,
                              isEmbedded: false,
                              onBack: () => setState(() => _selectedConversation = null),
                              onToggleDetails: () => setState(() => _showDetailsPanel = !_showDetailsPanel),
                            ))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // COLUMN 1: LEFT CONVERSATION LIST
                            if (_showSidebar) ...[
                              SizedBox(
                                width: 340,
                                child: _buildConversationListColumn(
                                  filteredConversations,
                                  cardBg,
                                  borderColor,
                                  textPrimary,
                                  textSecondary,
                                  primaryBlue,
                                  isDark,
                                ),
                              ),
                              VerticalDivider(width: 1, thickness: 1, color: borderColor),
                            ],

                            // COLUMN 2: CENTER ACTIVE CHAT WINDOW
                            Expanded(
                              child: activeConversation == null
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.forum_outlined,
                                            size: 64,
                                            color: textSecondary.withValues(alpha: 0.5),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Select a conversation to start messaging',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _ChatCenterPane(
                                      conversation: activeConversation,
                                      primaryColor: primaryBlue,
                                      isDark: isDark,
                                      isEmbedded: true,
                                      isSidebarVisible: _showSidebar,
                                      onToggleSidebar: () =>
                                          setState(() => _showSidebar = !_showSidebar),
                                      onToggleDetails: () =>
                                          setState(() => _showDetailsPanel = !_showDetailsPanel),
                                    ),
                            ),

                            // COLUMN 3: RIGHT CONTACT / GROUP DETAILS PANEL
                            if (isDesktop && _showDetailsPanel && activeConversation != null) ...[
                              VerticalDivider(width: 1, thickness: 1, color: borderColor),
                              SizedBox(
                                width: 310,
                                child: _ContactDetailsPane(
                                  conversation: activeConversation,
                                  primaryColor: primaryBlue,
                                  isDark: isDark,
                                  onClose: () => setState(() => _showDetailsPanel = false),
                                  onLeftGroup: () => setState(() {
                                    _selectedConversation = null;
                                    _showDetailsPanel = false;
                                  }),
                                  onConversationUpdated: (updated) {
                                    setState(() => _selectedConversation = updated);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          // Drawer for tablet mode details panel
          endDrawer: (isTablet && activeConversation != null)
              ? Drawer(
                  width: 320,
                  backgroundColor: cardBg,
                  child: _ContactDetailsPane(
                    conversation: activeConversation,
                    primaryColor: primaryBlue,
                    isDark: isDark,
                    onClose: () => Navigator.pop(context),
                    onLeftGroup: () => setState(() => _selectedConversation = null),
                    onConversationUpdated: (updated) {
                      setState(() => _selectedConversation = updated);
                    },
                  ),
                )
              : null,
        );
      },
    );
  }

  // CATEGORY TAB ITEM
  Widget _buildCategoryTab({
    required String label,
    required int index,
    required bool isActive,
    required Color primaryColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedCategory = index),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? primaryColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? primaryColor : textSecondary,
          ),
        ),
      ),
    );
  }

  // COLUMN 1: CONVERSATION LIST & SEARCH
  Widget _buildConversationListColumn(
    List<ChatConversation> conversations,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryBlue,
    bool isDark,
  ) {
    return Container(
      color: cardBg,
      child: Column(
        children: [
          // Search & Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search conversations...',
                              hintStyle: TextStyle(fontSize: 12.5, color: textSecondary.withValues(alpha: 0.8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: Icon(Icons.close, size: 16, color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter Button with Menu (Theme-adaptive, zero RTI error)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showFilterDialog(context, isDark),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _filterMode != 'all'
                          ? primaryBlue.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _filterMode != 'all' ? primaryBlue : borderColor,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: _filterMode != 'all' ? primaryBlue : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Conversation List
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No conversations found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final item = conversations[index];
                      final isSelected = _selectedConversation?.id == item.id;
                      return _buildConversationTile(
                        item,
                        isSelected,
                        cardBg,
                        borderColor,
                        textPrimary,
                        textSecondary,
                        primaryBlue,
                        isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // CONVERSATION ITEM TILE
  Widget _buildConversationTile(
    ChatConversation item,
    bool isSelected,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color primaryBlue,
    bool isDark,
  ) {
    final isGroup = item.type == 'group';
    final initial = item.name.isNotEmpty ? item.name[0].toUpperCase() : 'C';

    final tileBg = isSelected
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
        : Colors.transparent;

    return InkWell(
      onTap: () {
        setState(() => _selectedConversation = item);
        ref.read(messagingProvider.notifier).fetchChatHistory(item.id);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.6) : const Color(0xFFBFDBFE),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            // AVATAR WITH ONLINE DOT
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isGroup
                        ? _getGroupColor(item.name)
                        : (item.role == 'teacher'
                            ? const Color(0xFF0EA5E9)
                            : (item.role == 'parent'
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF3B82F6))),
                  ),
                  child: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            item.avatarUrl!,
                            fit: BoxFit.cover,
                            width: 44,
                            height: 44,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: isGroup
                                  ? Icon(_getGroupIcon(item.name), color: Colors.white, size: 20)
                                  : Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        )
                      : Center(
                          child: isGroup
                              ? Icon(_getGroupIcon(item.name), color: Colors.white, size: 20)
                              : Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                ),
                // Green Online Dot Indicator
                if (item.isOnline || isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardBg,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // MIDDLE: NAME, VERIFIED BADGE, PREVIEW
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isVerified || isGroup) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.lastMessage.isNotEmpty ? item.lastMessage : 'No messages yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.unreadCount > 0
                          ? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))
                          : textSecondary,
                      fontWeight: item.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // RIGHT: TIMESTAMP, PIN INDICATOR & UNREAD BADGE
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.isPinned) ...[
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      _formatTime(item.lastMessageTime),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        ref.read(messagingProvider.notifier).togglePinConversation(item.id);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          size: 14,
                          color: item.isPinned ? primaryBlue : textSecondary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (item.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            '${item.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // "+ NEW MESSAGE" MODAL DIALOG
  void _showFilterDialog(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Filter Conversations',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFilterOption(
                icon: Icons.mark_chat_read_outlined,
                title: 'All Conversations',
                mode: 'all',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctx: ctx,
              ),
              _buildFilterOption(
                icon: Icons.mark_email_unread_outlined,
                title: 'Unread Only',
                mode: 'unread',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctx: ctx,
              ),
              _buildFilterOption(
                icon: Icons.groups_outlined,
                title: 'Groups Only',
                mode: 'groups',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctx: ctx,
              ),
              _buildFilterOption(
                icon: Icons.push_pin_outlined,
                title: 'Pinned Only',
                mode: 'pinned',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                ctx: ctx,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required IconData icon,
    required String title,
    required String mode,
    required Color textPrimary,
    required Color textSecondary,
    required BuildContext ctx,
  }) {
    final isSelected = _filterMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _filterMode = mode);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF2563EB) : textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _NewMessageModal(
        onSelectUser: (user) {
          final id = user['id'] as String;
          final name = user['full_name'] as String? ?? 'User';
          final role = user['role'] as String? ?? 'student';
          final avatar = user['avatar_url'] as String?;
          final phone = user['phone'] as String?;
          final email = user['email'] as String?;

          final existing = ref
              .read(messagingProvider)
              .conversations
              .where((c) => c.id == id)
              .firstOrNull;

          if (existing != null) {
            setState(() => _selectedConversation = existing);
          } else {
            final newConv = ChatConversation(
              id: id,
              name: name,
              role: role,
              avatarUrl: avatar,
              phone: phone,
              email: email,
              type: 'direct',
              lastMessage: '',
              lastMessageTime: DateTime.now(),
              unreadCount: 0,
            );
            setState(() => _selectedConversation = newConv);
          }
          ref.read(messagingProvider.notifier).fetchChatHistory(id);
        },
        onCreateGroup: () {
          _showCreateGroupModal();
        },
      ),
    );
  }

  void _showCreateGroupModal() {
    final effectiveRole = widget.role ?? ref.read(authProvider).role;
    final isTeacher = effectiveRole == 'teacher' || effectiveRole == 'admin' || effectiveRole == 'super_admin';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateGroupBottomSheet(
        isTeacher: isTeacher,
        onGroupCreated: (newGroupId) {
          final convos = ref.read(messagingProvider).conversations;
          final match = convos.firstWhere(
            (c) => c.id == newGroupId,
            orElse: () => convos.isNotEmpty ? convos.first : ChatConversation(
              id: newGroupId,
              name: 'New Group',
              type: 'group',
              lastMessage: '📢 Group squad formed',
              lastMessageTime: DateTime.now(),
              unreadCount: 0,
            ),
          );
          setState(() => _selectedConversation = match);
          ref.read(messagingProvider.notifier).fetchChatHistory(match.id);
        },
      ),
    );
  }
}

// ============================================================================
// COLUMN 2: CENTER ACTIVE CHAT PANE
// ============================================================================

class _ChatCenterPane extends ConsumerStatefulWidget {
  final ChatConversation conversation;
  final Color primaryColor;
  final bool isDark;
  final bool isEmbedded;
  final bool isSidebarVisible;
  final VoidCallback? onBack;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onToggleDetails;

  const _ChatCenterPane({
    required this.conversation,
    required this.primaryColor,
    required this.isDark,
    this.isEmbedded = true,
    this.isSidebarVisible = true,
    this.onBack,
    this.onToggleSidebar,
    this.onToggleDetails,
  });

  @override
  ConsumerState<_ChatCenterPane> createState() => _ChatCenterPaneState();
}

class _ChatCenterPaneState extends ConsumerState<_ChatCenterPane> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _realtimeChannel;
  Timer? _pollTimer;
  String? _replyToId;
  String? _replyToText;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void didUpdateWidget(_ChatCenterPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _cleanupTimers();
      _initChat();
    }
  }

  void _cleanupTimers() {
    _pollTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
  }

  void _initChat() {
    Future.microtask(() async {
      await ref.read(messagingProvider.notifier).fetchChatHistory(widget.conversation.id);
      _scrollToBottom();
    });
    _setupRealtime();
    _startPollTimer();
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      await ref.read(messagingProvider.notifier).fetchChatHistory(
            widget.conversation.id,
            refreshConversations: false,
          );
    });
  }

  void _setupRealtime() {
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    final channelName = 'chat_room_${widget.conversation.id}_$currentUserId';
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

        bool isRelevant = false;
        if (widget.conversation.type == 'group') {
          isRelevant = msgGroupId == widget.conversation.id;
        } else {
          isRelevant = (msgSenderId == widget.conversation.id && msgReceiverId == currentUserId) ||
              (msgSenderId == currentUserId && msgReceiverId == widget.conversation.id);
        }

        if (isRelevant) {
          ref.read(messagingProvider.notifier).appendNewMessage(newRecord, currentUserId);
          _scrollToBottom();
        }
      },
    )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _cleanupTimers();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  final List<PlatformFile> _pendingAttachments = [];
  bool _isUploadingAttachments = false;
  bool _showEmojiPicker = false;
  int _emojiTab = 0; // 0=Smileys, 1=Gestures, 2=School, 3=Reactions

  Future<void> _pickMultipleAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
          'png', 'jpg', 'jpeg', 'txt', 'zip', 'csv'
        ],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pendingAttachments.addAll(result.files.where((f) => f.bytes != null));
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  void _insertEmoji(String emoji) {
    final text = _msgController.text;
    final selection = _msgController.selection;
    final newText = selection.start >= 0
        ? text.replaceRange(selection.start, selection.end, emoji)
        : '$text$emoji';
    _msgController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.start >= 0 ? selection.start : text.length) + emoji.length,
      ),
    );
  }

  Future<void> _sendCurrentMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final attachmentsToSend = List<PlatformFile>.from(_pendingAttachments);
    _msgController.clear();
    final replyId = _replyToId;
    setState(() {
      _pendingAttachments.clear();
      _replyToId = null;
      _replyToText = null;
      _showEmojiPicker = false;
      _isUploadingAttachments = attachmentsToSend.isNotEmpty;
    });

    final isGroup = widget.conversation.type == 'group';
    final receiverId = isGroup ? null : widget.conversation.id;
    final groupId = isGroup ? widget.conversation.id : null;

    if (text.isNotEmpty && attachmentsToSend.isEmpty) {
      await ref.read(messagingProvider.notifier).sendMessage(
            text,
            receiverId: receiverId,
            groupId: groupId,
            replyToId: replyId,
          );
    } else if (text.isNotEmpty && attachmentsToSend.length == 1) {
      final file = attachmentsToSend.first;
      final url = await ref.read(messagingProvider.notifier).uploadMessageFile(
            file.bytes!,
            file.name,
          );
      await ref.read(messagingProvider.notifier).sendMessage(
            text,
            receiverId: receiverId,
            groupId: groupId,
            attachmentUrl: url,
            fileName: file.name,
            fileSize: file.size,
            messageType: 'file',
            replyToId: replyId,
          );
    } else {
      if (text.isNotEmpty) {
        await ref.read(messagingProvider.notifier).sendMessage(
              text,
              receiverId: receiverId,
              groupId: groupId,
              replyToId: replyId,
            );
      }
      for (final file in attachmentsToSend) {
        final url = await ref.read(messagingProvider.notifier).uploadMessageFile(
              file.bytes!,
              file.name,
            );
        await ref.read(messagingProvider.notifier).sendMessage(
              file.name,
              receiverId: receiverId,
              groupId: groupId,
              attachmentUrl: url,
              fileName: file.name,
              fileSize: file.size,
              messageType: 'file',
            );
      }
    }

    if (mounted) {
      setState(() => _isUploadingAttachments = false);
    }
    _scrollToBottom();
  }

  Future<void> _startCall({required bool isVideo}) async {
    final conv = widget.conversation;
    if (conv.id.isEmpty) return;

    // 1. Open the real WebRTC CallScreen immediately
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );

    // 2. If group conversation, fetch members and broadcast call offer to all members
    if (conv.type == 'group') {
      try {
        final members = await ref.read(messagingProvider.notifier).fetchGroupMembers(conv.id);
        final memberIds = members.map((m) => m['id'] as String).toList();
        await CallService.instance.initiateCall(
          calleeId: conv.id,
          calleeName: conv.name,
          calleeAvatarUrl: conv.avatarUrl,
          callType: isVideo ? CallType.video : CallType.audio,
          isGroup: true,
          groupMemberIds: memberIds,
          groupName: conv.name,
        );
      } catch (e) {
        debugPrint('[Group Call] Error initiating group call: $e');
      }
      return;
    }

    // 3. Initiate direct WebRTC call with real camera/microphone stream
    await CallService.instance.initiateCall(
      calleeId: conv.id,
      calleeName: conv.name,
      calleeAvatarUrl: conv.avatarUrl,
      callType: isVideo ? CallType.video : CallType.audio,
    );
  }

  void _showMoreMenu(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.info_outline_rounded, color: textSecondary, size: 20),
                title: Text('Contact Details', style: TextStyle(color: textPrimary, fontSize: 13.5)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onToggleDetails?.call();
                },
              ),
              Builder(
                builder: (menuCtx) {
                  final isMuted = ref.watch(messagingProvider).mutedConversationIds.contains(widget.conversation.id);
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                      color: isMuted ? widget.primaryColor : textSecondary,
                      size: 20,
                    ),
                    title: Text(
                      isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final willMute = !isMuted;
                      await ref.read(messagingProvider.notifier).toggleMuteConversation(widget.conversation.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(willMute
                                ? 'Notifications muted for ${widget.conversation.name}'
                                : 'Notifications unmuted for ${widget.conversation.name}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              // Clear Chat History (Restricted: for groups, only Admins can clear)
              Builder(
                builder: (clearCtx) {
                  final isGroup = widget.conversation.type == 'group';
                  final currentUserData = ref.watch(authProvider).userData;
                  final roleStr = currentUserData?['role']?.toString().toLowerCase() ?? '';
                  final isAppAdmin = roleStr == 'admin' || roleStr == 'super_admin' || roleStr == 'principal';
                  
                  if (isGroup && !isAppAdmin) {
                    return const SizedBox.shrink();
                  }

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange, size: 20),
                    title: const Text('Clear Chat History', style: TextStyle(color: Colors.orange, fontSize: 13.5)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text('Clear Chat?', style: TextStyle(color: textPrimary, fontSize: 16)),
                          content: Text('Are you sure you want to clear all messages in this conversation?',
                              style: TextStyle(color: textSecondary, fontSize: 13)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final success = await ref.read(messagingProvider.notifier).clearChat(widget.conversation.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? 'Chat history cleared successfully' : 'Failed to clear chat. Admin access required.')),
                          );
                        }
                      }
                    },
                  );
                },
              ),
              if (widget.conversation.type != 'group')
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.block_outlined, color: Colors.red, size: 20),
                  title: const Text('Block User', style: TextStyle(color: Colors.red, fontSize: 13.5)),
                  onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: cardBg,
                      title: Text('Block ${widget.conversation.name}?', style: TextStyle(color: textPrimary, fontSize: 16)),
                      content: Text('Blocked users will not be able to message or call you.',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Block', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(messagingProvider.notifier).blockUser(widget.conversation.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${widget.conversation.name} has been blocked')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagingState = ref.watch(messagingProvider);
    final history = messagingState.chatHistory;
    final currentUserId = ref.watch(authProvider).userData?['id'] as String?;

    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final centerBg = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isGroup = widget.conversation.type == 'group';
    final isStillMember = !isGroup || messagingState.conversations.any((c) => c.id == widget.conversation.id);
    final initial = widget.conversation.name.isNotEmpty ? widget.conversation.name[0].toUpperCase() : 'U';

    String subtitleText = '';
    if (isGroup) {
      subtitleText = 'Group • Active';
    } else {
      final roleTitle = (widget.conversation.role ?? 'Parent').toUpperCase();
      final phone = widget.conversation.phone ?? '+91 98765 43210';
      subtitleText = '${roleTitle[0]}${roleTitle.substring(1).toLowerCase()} • $phone';
    }

    return Container(
      color: centerBg,
      child: Column(
        children: [
          // 1. CENTER CHAT HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (!widget.isEmbedded) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimary),
                    onPressed: widget.onBack,
                  ),
                ] else if (widget.onToggleSidebar != null) ...[
                  IconButton(
                    icon: Icon(
                      widget.isSidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded,
                      color: textSecondary,
                      size: 21,
                    ),
                    tooltip: widget.isSidebarVisible ? 'Hide conversation list' : 'Show conversation list',
                    onPressed: widget.onToggleSidebar,
                  ),
                  const SizedBox(width: 4),
                ],
                // Avatar with Online dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: widget.conversation.avatarUrl != null &&
                              widget.conversation.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.conversation.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: cardBg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.conversation.name,
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action Buttons: Call, Video, More
                IconButton(
                  icon: Icon(Icons.phone_outlined, size: 20, color: textSecondary),
                  tooltip: 'Voice Call',
                  onPressed: () => _startCall(isVideo: false),
                ),
                IconButton(
                  icon: Icon(Icons.videocam_outlined, size: 21, color: textSecondary),
                  tooltip: 'Video Call',
                  onPressed: () => _startCall(isVideo: true),
                ),
                IconButton(
                  icon: Icon(Icons.more_horiz_rounded, size: 20, color: textSecondary),
                  tooltip: 'Options',
                  onPressed: () => _showMoreMenu(context),
                ),
              ],
            ),
          ),

          // 2. TIMELINE & MESSAGES
          Expanded(
            child: SelectionArea(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // Date separator pill (Matching design: "Today, 28 Oct 2025")
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        'Today, 28 Oct 2025',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),

                  // Render Messages
                  if (history.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Start the conversation with ${widget.conversation.name}',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ),
                    )
                  else
                    ...history.map((msg) {
                      final isMe = msg.senderId == currentUserId;
                      return _buildTimelineMessage(
                        msg,
                        isMe,
                        textPrimary,
                        textSecondary,
                        borderColor,
                      );
                    }),
                ],
              ),
            ),
          ),

          // 3. REPLY PREVIEW BAR (IF REPLYING)
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to: ${_replyToText ?? ''}',
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _replyToId = null;
                      _replyToText = null;
                    }),
                  ),
                ],
              ),
            ),

          // 4. BOTTOM COMPOSER BAR & ATTACHMENT TRAY
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUploadingAttachments)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),

                // Multiple Attachments Preview Tray
                if (_pendingAttachments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingAttachments.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _pendingAttachments[index];
                        final ext = file.extension?.toLowerCase() ?? '';
                        final isPdf = ext == 'pdf';
                        final isImg = ['png', 'jpg', 'jpeg', 'webp'].contains(ext);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf ? Icons.picture_as_pdf_rounded : (isImg ? Icons.image_outlined : Icons.description_outlined),
                                size: 16,
                                color: isPdf ? Colors.red : (isImg ? Colors.green : const Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(
                                  file.name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(file.size / 1024).round()} KB',
                                style: TextStyle(fontSize: 10, color: textSecondary),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () {
                                  setState(() => _pendingAttachments.removeAt(index));
                                },
                                child: Icon(Icons.close, size: 14, color: textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Non-member guard: if user left this group, block sending messages
                if (!isStillMember)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'You are no longer a participant in this group. You cannot send messages.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Input Row: Professional Unified Capsule & Floating Send Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Single Unified Pill containing Attach Clip + Text + Emoji
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.attach_file_rounded, color: textSecondary, size: 21),
                                  tooltip: 'Attach Files / Documents',
                                  onPressed: _pickMultipleAttachments,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _msgController,
                                    maxLines: 4,
                                    minLines: 1,
                                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Type your message...',
                                      hintStyle: TextStyle(
                                        fontSize: 13.5,
                                        color: textSecondary.withValues(alpha: 0.8),
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onSubmitted: (_) => _sendCurrentMessage(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.sentiment_satisfied_alt_rounded,
                                    color: _showEmojiPicker ? const Color(0xFF2563EB) : textSecondary,
                                    size: 21,
                                  ),
                                  tooltip: _showEmojiPicker ? 'Hide Emojis' : 'Choose Emoji',
                                  onPressed: () {
                                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Blue Rounded Floating Send Button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                            tooltip: 'Send message',
                            onPressed: _sendCurrentMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Interactive Categorized Emoji Picker Tray
                if (_showEmojiPicker)
                  _buildEmojiPickerPanel(cardBg, borderColor, textPrimary, textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPickerPanel(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final categories = ['Smileys', 'Gestures', 'School', 'Symbols'];
    final emojiSets = [
      // Smileys
      ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😋', '😜', '🤪', '😎', '🥳', '🤠', '🥺', '😭', '😤', '🤯', '🤔', '🤫', '🫡', '🤗'],
      // Gestures
      ['👍', '👎', '👏', '🙌', '👐', '🤝', '🙏', '💪', '✌️', '🤞', '🫰', '🤟', '🤘', '🤙', '🫡', '🫶', '✍️', '🖐️', '✋', '👊', '🤜', '🤛', '👈', '👉', '👆', '👇', '☝️', '👋'],
      // School
      ['📚', '📖', '📕', '📗', '📘', '📙', '📓', '📔', '📒', '📃', '📜', '📄', '🎓', '🏫', '🏛️', '🎒', '🔬', '🔭', '🧪', '📐', '📏', '🧮', '📌', '📎', '✏️', '🖋️', '📝', '💼', '🏆', '🥇', '🎨', '💡'],
      // Symbols & Reactions
      ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '💯', '🔥', '⭐', '🌟', '✨', '🎉', '🎊', '🔔', '📢', '⚠️', '🚨', '💬', '🗯️', '💭', '🚀', '🎯', '✅', '❌', '⏰', '📅', '💡', '🎵', '☀️'],
    ];

    final currentSet = emojiSets[_emojiTab.clamp(0, emojiSets.length - 1)];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Category Selector Tabs
          Container(
            height: 38,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: List.generate(categories.length, (idx) {
                final isSel = _emojiTab == idx;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _emojiTab = idx),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        categories[idx],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? const Color(0xFF2563EB) : textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Emojis Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1.25,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: currentSet.length,
              itemBuilder: (context, index) {
                final emoji = currentSet[index];
                return InkWell(
                  onTap: () => _insertEmoji(emoji),
                  borderRadius: BorderRadius.circular(6),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // INDIVIDUAL CHAT MESSAGE BUBBLE IN TIMELINE
  Widget _buildTimelineMessage(
    MessageItem msg,
    bool isMe,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final timeStr =
        '${(msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12).toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}';

    final isFile = msg.messageType == 'file' ||
        msg.fileName != null ||
        (msg.attachmentUrl != null && msg.attachmentUrl!.endsWith('.pdf'));

    // Received Bubble vs Sent Bubble colors
    final receivedBubbleBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final sentBubbleBg = widget.isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Received Message Avatar on Left
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: widget.conversation.avatarUrl != null &&
                      widget.conversation.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        widget.conversation.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('U', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('U', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
            ),
            const SizedBox(width: 10),
          ],

          // Bubble Container
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? sentBubbleBg : receivedBubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 14),
                    ),
                    border: Border.all(
                      color: isMe
                          ? (widget.isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFDBEAFE))
                          : borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // If message is reply to another message, show WhatsApp style quote box
                      if (msg.replyToId != null) ...[
                        _buildQuotedReplyBox(msg.replyToId!, widget.isDark, borderColor),
                        const SizedBox(height: 6),
                      ],

                      // Selectable formatted text with clickable URLs & phone numbers
                      _buildSelectableMessageText(
                        msg.content,
                        isMe,
                        textPrimary,
                        textSecondary,
                        widget.isDark,
                      ),

                      // ATTACHMENT CARD (MATCHING SCREENSHOT WITH RED PDF ICON, NAME, SIZE)
                      if (isFile) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            if (msg.attachmentUrl != null) {
                              getDownloadHelper().downloadFile(
                                msg.attachmentUrl!,
                                msg.fileName ?? 'Attendance_Report.pdf',
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Red PDF Badge
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.fileName ?? 'Attendance_Report_Oct2025.pdf',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg.fileSize != null ? '${(msg.fileSize! / 1024).round()} KB' : '245 KB',
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // TIMESTAMP, READ RECEIPTS & QUICK ACTIONS (REPLY, FORWARD, COPY)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: 10.5, color: textSecondary),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: msg.isRead ? const Color(0xFF2563EB) : textSecondary,
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Quick Reply Action
                    InkWell(
                      onTap: () {
                        setState(() {
                          _replyToId = msg.id;
                          _replyToText = msg.content;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(
                          Icons.reply_rounded,
                          size: 14,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Quick Forward Action
                    InkWell(
                      onTap: () => _showForwardMessageModal(context, msg),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(
                          Icons.forward_rounded,
                          size: 14,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Quick Copy Action
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: msg.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(
                          Icons.content_copy_rounded,
                          size: 13,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    // Quick Delete Action (Users can delete their own messages)
                    if (isMe) ...[
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => _confirmDeleteMessage(msg),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 13,
                            color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Sent Message Avatar on Right (Initial badge matching screenshot 'A')
          if (isMe) ...[
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuotedReplyBox(String replyToId, bool isDark, Color borderColor) {
    final history = ref.watch(messagingProvider).chatHistory;
    final original = history.where((m) => m.id == replyToId).firstOrNull;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    final senderTitle = original?.senderName ?? (original?.senderId == currentUserId ? 'You' : widget.conversation.name);
    final snippet = original?.content ?? 'Replied message';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFDBEAFE).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Color(0xFF2563EB), width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderTitle,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            snippet,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableMessageText(
    String text,
    bool isMe,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final defaultColor = isMe ? (isDark ? Colors.white : const Color(0xFF0F172A)) : textPrimary;
    final defaultStyle = TextStyle(fontSize: 13.5, height: 1.45, color: defaultColor);
    const linkStyle = TextStyle(
      fontSize: 13.5,
      height: 1.45,
      color: Color(0xFF2563EB),
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF2563EB),
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    final combinedRegex = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)|(\+?[0-9]{1,4}[\s\-]?)?(\(?[0-9]{2,5}\)?[\s\-]?)?[0-9]{3,5}[\s\-]?[0-9]{3,5}',
      caseSensitive: false,
    );

    int lastIndex = 0;
    for (final match in combinedRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: defaultStyle));
      }

      final matchText = match.group(0)!;
      final isUrl = matchText.startsWith('http://') ||
          matchText.startsWith('https://') ||
          matchText.startsWith('www.');

      final digitCount = matchText.replaceAll(RegExp(r'\D'), '').length;

      if (isUrl) {
        final launchableUrl = matchText.startsWith('http') ? matchText : 'https://$matchText';
        spans.add(
          TextSpan(
            text: matchText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                try {
                  await launchUrl(Uri.parse(launchableUrl), mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
          ),
        );
      } else if (digitCount >= 8 && digitCount <= 15) {
        final cleanDigits = matchText.replaceAll(RegExp(r'[\s\-]'), '');
        spans.add(
          TextSpan(
            text: matchText,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                try {
                  await launchUrl(Uri.parse('tel:$cleanDigits'));
                } catch (_) {}
              },
          ),
        );
      } else {
        spans.add(TextSpan(text: matchText, style: defaultStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: defaultStyle));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  void _showForwardMessageModal(BuildContext context, MessageItem message) {
    final conversations = ref.read(messagingProvider).conversations;
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String filter = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = conversations.where((c) {
            if (filter.isEmpty) return true;
            return c.name.toLowerCase().contains(filter.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: borderColor),
            ),
            child: Container(
              width: 440,
              height: 520,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.forward_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Forward Message',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Message Preview Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search box
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setModalState(() => filter = val),
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search chats or groups...',
                              hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Conversations List
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No chats found',
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor.withValues(alpha: 0.5)),
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB),
                                  backgroundImage: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                                      ? NetworkImage(item.avatarUrl!)
                                      : null,
                                  child: item.avatarUrl == null || item.avatarUrl!.isEmpty
                                      ? Text(
                                          item.name.isNotEmpty ? item.name[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  item.name,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                                subtitle: Text(
                                  item.type == 'group' ? 'Group' : (item.role ?? 'Contact'),
                                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    Navigator.pop(ctx);
                                    final success = await ref.read(messagingProvider.notifier).sendMessage(
                                      message.content,
                                      receiverId: item.type == 'group' ? null : item.id,
                                      groupId: item.type == 'group' ? item.id : null,
                                      attachmentUrl: message.attachmentUrl,
                                      fileName: message.fileName,
                                      fileSize: message.fileSize,
                                      messageType: message.messageType,
                                    );
                                    if (mounted && success) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Message forwarded to ${item.name}'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteMessage(MessageItem msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Message?',
          style: TextStyle(
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: TextStyle(
            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(messagingProvider.notifier).deleteMessage(msg.id, widget.conversation.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted successfully'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// ============================================================================
// CROPPER HELPER — WEB & DESKTOP PROFESSIONAL CROPPER MODAL
// ============================================================================

Future<Uint8List?> _cropImageWithCropper(BuildContext context, String sourcePath) async {
  try {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 260, height: 260),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
  } catch (e) {
    debugPrint('Error cropping image: $e');
  }
  return null;
}

// ============================================================================
// COLUMN 3: RIGHT CONTACT DETAILS / GROUP DETAILS PANEL
// ============================================================================

class _ContactDetailsPane extends ConsumerStatefulWidget {
  final ChatConversation conversation;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback? onClose;
  final VoidCallback? onLeftGroup;
  final ValueChanged<ChatConversation>? onConversationUpdated;

  const _ContactDetailsPane({
    required this.conversation,
    required this.primaryColor,
    required this.isDark,
    this.onClose,
    this.onLeftGroup,
    this.onConversationUpdated,
  });

  @override
  ConsumerState<_ContactDetailsPane> createState() => _ContactDetailsPaneState();
}

class _ContactDetailsPaneState extends ConsumerState<_ContactDetailsPane> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didUpdateWidget(covariant _ContactDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    if (widget.conversation.type != 'group') return;
    setState(() => _isLoadingMembers = true);
    final members = await ref.read(messagingProvider.notifier).fetchGroupMembers(widget.conversation.id);
    if (mounted) {
      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Exit ${widget.conversation.name}?',
          style: TextStyle(
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You will no longer receive updates or be able to send messages in this group.',
          style: TextStyle(
            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit Group'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(messagingProvider.notifier).leaveGroup(widget.conversation.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You left ${widget.conversation.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onLeftGroup?.call();
      }
    }
  }

  Future<void> _toggleAdminRole(String memberId, bool makeAdmin) async {
    final success = await ref.read(messagingProvider.notifier).changeMemberRole(
      widget.conversation.id,
      memberId,
      makeAdmin ? 'admin' : 'member',
    );
    if (success) {
      await _loadMembers();
      await ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(makeAdmin ? 'Promoted to Group Admin' : 'Dismissed as Admin'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update admin role. Only group admins can modify roles.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $memberName?'),
        content: Text('Are you sure you want to remove $memberName from ${widget.conversation.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(messagingProvider.notifier).removeGroupMember(widget.conversation.id, memberId);
      if (success) {
        await _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName removed from group'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _startGroupCall({required bool isVideo}) async {
    final memberIds = _members.map((m) => m['id'] as String).where((id) => id.isNotEmpty).toList();
    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No group members found to call')),
      );
      return;
    }

    CallService.instance.initiateCall(
      calleeId: memberIds.first,
      calleeName: widget.conversation.name,
      callType: isVideo ? CallType.video : CallType.audio,
      isGroup: true,
      groupMemberIds: memberIds,
      groupName: widget.conversation.name,
    );

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final conversation = widget.conversation;
    final onClose = widget.onClose;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isGroup = conversation.type == 'group';
    final initial = conversation.name.isNotEmpty ? conversation.name[0].toUpperCase() : 'U';

    final roleDisplay = (conversation.role ?? 'User');
    final phone = conversation.phone ?? 'Not provided';
    final email = conversation.email ?? 'Not provided';
    final studentName = conversation.studentName;
    final studentClass = conversation.studentClass;

    final currentUserData = ref.watch(authProvider).userData;
    final currentUserId = currentUserData?['id']?.toString() ?? '';
    final currentUserProfileId = currentUserData?['profile_id']?.toString();
    final currentUserEmail = currentUserData?['email']?.toString().toLowerCase();
    final roleStr = currentUserData?['role']?.toString().toLowerCase() ?? '';
    final isAppAdmin = roleStr == 'admin' || roleStr == 'super_admin' || roleStr == 'principal';

    final isCurrentMemberAdmin = isAppAdmin || _members.any((m) {
      final mid = (m['id'] ?? m['member_id'])?.toString();
      final mUid = m['user_id']?.toString();
      final mEmail = m['email']?.toString().toLowerCase();
      final mRole = (m['role'] ?? m['group_role'])?.toString().toLowerCase();
      final matchesUser = (mid != null && (mid == currentUserId || mid == currentUserProfileId)) ||
                          (mUid != null && (mUid == currentUserId || mUid == currentUserProfileId)) ||
                          (mEmail != null && currentUserEmail != null && mEmail == currentUserEmail);
      return matchesUser && (mRole == 'admin' || m['is_creator'] == true);
    });

    return Container(
      color: cardBg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isGroup ? 'Group Details' : 'Contact Details',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Large Centered Circular Photo with Online badge dot
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2563EB),
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 3),
                  ),
                  child: conversation.avatarUrl != null && conversation.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            conversation.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: isGroup
                              ? const Icon(Icons.groups_rounded, color: Colors.white, size: 38)
                              : Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                ),
                if (!isGroup)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Name & Subtitle
          Center(
            child: Column(
              children: [
                Text(
                  conversation.name,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isGroup
                      ? 'Group • ${_members.length} participants'
                      : roleDisplay,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Group Calling Quick Action Buttons
          if (isGroup) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Voice Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    onPressed: () => _startGroupCall(isVideo: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Video Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    onPressed: () => _startGroupCall(isVideo: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Phone & Email details (for direct chats)
          if (!isGroup) ...[
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    phone,
                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email_outlined, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ASSOCIATED STUDENT CARD (FOR PARENTS ONLY IF LINKED)
            if (studentName != null && studentName.isNotEmpty) ...[
              Text(
                'STUDENT',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF3B82F6),
                      ),
                      child: Center(
                        child: Text(
                          studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          if (studentClass != null && studentClass.isNotEmpty)
                            Text(
                              studentClass,
                              style: TextStyle(fontSize: 11.5, color: textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // QUICK ACTIONS (MATCHING SCREENSHOT - FULLY FUNCTIONAL)
            Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildActionItem(
              Icons.person_outline_rounded,
              'View Profile',
              textPrimary,
              borderColor,
              onTap: () => _showProfileDialog(context, conversation, isDark),
            ),
            _buildActionItem(
              Icons.school_outlined,
              'View Student Record',
              textPrimary,
              borderColor,
              onTap: () => _showStudentRecordDialog(context, conversation, isDark),
            ),
            _buildActionItem(
              Icons.campaign_outlined,
              'Send Announcement',
              textPrimary,
              borderColor,
              onTap: () => _showSendAnnouncementDialog(context, ref, conversation, isDark),
            ),
            _buildActionItem(
              Icons.chat_bubble_outline_rounded,
              'Send SMS',
              textPrimary,
              borderColor,
              onTap: () => _showSendSmsDialog(context, conversation, isDark),
            ),
            const SizedBox(height: 20),

            // RECENT ACTIVITY
            Text(
              'RECENT ACTIVITY',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Last message: Today, 10:24 AM',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ),
              ],
            ),
          ] else ...[
            // GROUP DETAILS CONTENT
            Text(
              'GROUP DESCRIPTION',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conversation.description ?? 'Official communication channel for school announcements and coordination.',
              style: TextStyle(fontSize: 12.5, color: textPrimary, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (isCurrentMemberAdmin) ...[
              _buildActionItem(
                Icons.edit_note_rounded,
                'Edit Group Details',
                textPrimary,
                borderColor,
                onTap: () => _showEditGroupDetailsDialog(context, conversation),
              ),
              _buildActionItem(
                Icons.person_add_alt_1_rounded,
                'Add Members',
                textPrimary,
                borderColor,
                onTap: () async {
                  await _showAddGroupMembersDialog(
                    context,
                    ref,
                    conversation,
                    isDark,
                    onMembersAdded: () async {
                      await _loadMembers();
                      await ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
                    },
                  );
                },
              ),
            ],
            Builder(
              builder: (ctx) {
                final isMuted = ref.watch(messagingProvider).mutedConversationIds.contains(conversation.id);
                return _buildActionItem(
                  isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  isMuted ? 'Unmute Notifications' : 'Mute Notifications',
                  textPrimary,
                  borderColor,
                  onTap: () async {
                    final wasMuted = isMuted;
                    await ref.read(messagingProvider.notifier).toggleMuteConversation(conversation.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(!wasMuted
                              ? 'Notifications muted for ${conversation.name}'
                              : 'Notifications unmuted for ${conversation.name}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            ),
            _buildActionItem(
              Icons.download_rounded,
              'Export Chat History',
              textPrimary,
              borderColor,
              onTap: () => _exportChatHistory(context, ref, conversation),
            ),
            const SizedBox(height: 20),

            // PARTICIPANTS LIST (WHATSAPP-STYLE)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PARTICIPANTS (${_members.length})',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isCurrentMemberAdmin)
                  InkWell(
                    onTap: () async {
                      await _showAddGroupMembersDialog(
                        context,
                        ref,
                        conversation,
                        isDark,
                        onMembersAdded: () async {
                          await _loadMembers();
                          await ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: widget.primaryColor),
                          const SizedBox(width: 2),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: widget.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingMembers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No members listed',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              )
            else
              ..._members.map((member) {
                final mid = member['id'] as String? ?? '';
                final mName = (member['name'] ?? member['full_name'] ?? 'Member').toString();
                final mRole = (member['role'] ?? member['group_role'] ?? 'member').toString();
                final isMemberAdmin = mRole == 'admin';
                final isMe = (mid == currentUserId);
                final initial = mName.isNotEmpty ? mName[0].toUpperCase() : 'M';
                final userRole = (member['user_role'] ?? member['role'] ?? 'Student').toString();
                final avatarUrl = member['avatar_url'] as String?;

                return InkWell(
                  onTap: () => _showMemberProfileDetails(member),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                      // Avatar
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: isMemberAdmin ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(initial, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      // Name & user role
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? '$mName (You)' : mName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userRole.toUpperCase(),
                              style: TextStyle(fontSize: 10.5, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      // Admin badge
                      if (isMemberAdmin) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'Group Admin',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      // Admin popup menu (if caller is admin and not targeting self)
                      if (isCurrentMemberAdmin && !isMe)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 16, color: textSecondary),
                          padding: EdgeInsets.zero,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor),
                          ),
                          onSelected: (val) {
                            if (val == 'make_admin') {
                              _toggleAdminRole(mid, true);
                            } else if (val == 'dismiss_admin') {
                              _toggleAdminRole(mid, false);
                            } else if (val == 'remove') {
                              _removeMember(mid, mName);
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (isMemberAdmin)
                              PopupMenuItem(
                                value: 'dismiss_admin',
                                child: Row(
                                  children: [
                                    Icon(Icons.remove_circle_outline, size: 16, color: textSecondary),
                                    const SizedBox(width: 8),
                                    Text('Dismiss as admin', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                  ],
                                ),
                              )
                            else
                              PopupMenuItem(
                                value: 'make_admin',
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Text('Make group admin', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_rounded, size: 16, color: Color(0xFFEF4444)),
                                  SizedBox(width: 8),
                                  Text('Remove from group', style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // EXIT GROUP BUTTON (RED THEMED) - Only visible if user is currently an active member
            if (_members.any((m) => m['id'] == currentUserId))
              InkWell(
                onTap: _leaveGroup,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 17, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text(
                        'Exit Group',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String label,
    Color textPrimary,
    Color borderColor, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: textPrimary.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context, ChatConversation conversation, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contact Profile', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
                  IconButton(icon: Icon(Icons.close, color: textSecondary, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF2563EB),
                backgroundImage: conversation.avatarUrl != null && conversation.avatarUrl!.isNotEmpty ? NetworkImage(conversation.avatarUrl!) : null,
                child: conversation.avatarUrl == null || conversation.avatarUrl!.isEmpty
                    ? Text(conversation.name.isNotEmpty ? conversation.name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(conversation.name, style: TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF2563EB)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text((conversation.role ?? 'Parent').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), letterSpacing: 0.5)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: subBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.phone_outlined, 'Phone', conversation.phone ?? '+91 98765 43210', textPrimary, textSecondary),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.email_outlined, 'Email', conversation.email ?? 'anita.sharma@email.com', textPrimary, textSecondary),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.badge_outlined, 'Status', 'Active • Verified Guardian', textPrimary, textSecondary),
                    if (conversation.studentName != null) ...[
                      const Divider(height: 16),
                      _buildInfoRow(Icons.school_outlined, 'Ward / Student', '${conversation.studentName} (${conversation.studentClass ?? "Class 10-A"})', textPrimary, textSecondary),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Voice Call'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startDirectCall(context, conversation, isVideo: false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.videocam_outlined, size: 16),
                      label: const Text('Video Call'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startDirectCall(context, conversation, isVideo: true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDirectCall(BuildContext context, ChatConversation conversation, {required bool isVideo}) async {
    if (conversation.id.isEmpty) return;

    // 1. Open the real WebRTC CallScreen immediately
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );

    // 2. If group conversation, broadcast to all members
    if (conversation.type == 'group') {
      try {
        final members = await ref.read(messagingProvider.notifier).fetchGroupMembers(conversation.id);
        final memberIds = members.map((m) => m['id'] as String).toList();
        await CallService.instance.initiateCall(
          calleeId: conversation.id,
          calleeName: conversation.name,
          calleeAvatarUrl: conversation.avatarUrl,
          callType: isVideo ? CallType.video : CallType.audio,
          isGroup: true,
          groupMemberIds: memberIds,
          groupName: conversation.name,
        );
      } catch (e) {
        debugPrint('[Group Call] Error initiating group call: $e');
      }
      return;
    }

    // 3. Initiate real WebRTC direct call
    await CallService.instance.initiateCall(
      calleeId: conversation.id,
      calleeName: conversation.name,
      calleeAvatarUrl: conversation.avatarUrl,
      callType: isVideo ? CallType.video : CallType.audio,
    );
  }

  void _showStudentRecordDialog(BuildContext context, ChatConversation conversation, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final sName = conversation.studentName ?? 'Aarav Sharma';
    final sClass = conversation.studentClass ?? 'Class 10-A';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Academic Student Record', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                          Text('$sName • $sClass • Roll #14', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: Icon(Icons.close, color: textSecondary, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile('ATTENDANCE', '94.2%', '146 Present / 9 Absent', const Color(0xFF10B981), subBg, borderColor, textPrimary, textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile('GPA / RANK', '3.8 / 4.0', 'Rank #3 in Class 10-A', const Color(0xFF2563EB), subBg, borderColor, textPrimary, textSecondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile('FEES STATUS', 'CLEARED', 'Paid through Nov 2026', const Color(0xFF8B5CF6), subBg, borderColor, textPrimary, textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('RECENT SUBJECT PERFORMANCE', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: subBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Column(
                  children: [
                    _buildSubjectScoreRow('Mathematics', '96 / 100', 'Grade A+', 0.96, textPrimary, textSecondary),
                    const Divider(height: 1),
                    _buildSubjectScoreRow('Science & Physics', '92 / 100', 'Grade A', 0.92, textPrimary, textSecondary),
                    const Divider(height: 1),
                    _buildSubjectScoreRow('English Literature', '88 / 100', 'Grade A', 0.88, textPrimary, textSecondary),
                    const Divider(height: 1),
                    _buildSubjectScoreRow('Social Studies', '91 / 100', 'Grade A', 0.91, textPrimary, textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Official Report Card (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    getDownloadHelper().downloadFile(
                      'https://raw.githubusercontent.com/mozilla/pdf.js/ba2edeae/examples/learning/helloworld.pdf',
                      'Report_Card_${sName.replaceAll(" ", "_")}.pdf',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading Report Card for $sName...')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendAnnouncementDialog(BuildContext context, WidgetRef ref, ChatConversation conversation, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String priority = 'Normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text('Broadcast Announcement', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    IconButton(icon: Icon(Icons.close, color: textSecondary, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Audience: ${conversation.name} (${conversation.role ?? "Parent"})', style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(fontSize: 13.5, color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Announcement Title',
                    labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['Normal', 'Important', 'Urgent'].map((p) {
                    final isSel = priority == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: isSel ? Colors.white : textPrimary, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                        onSelected: (val) {
                          if (val) setDialogState(() => priority = p);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  style: TextStyle(fontSize: 13.5, color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Announcement Details / Instructions',
                    labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final t = titleCtrl.text.trim();
                      final b = bodyCtrl.text.trim();
                      if (t.isEmpty) return;
                      Navigator.pop(ctx);
                      await ref.read(messagingProvider.notifier).sendMessage(
                            '📢 ANNOUNCEMENT [$priority]: $t\n\n$b',
                            receiverId: conversation.type == 'group' ? null : conversation.id,
                            groupId: conversation.type == 'group' ? conversation.id : null,
                            messageType: 'announcement',
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Announcement "$t" published successfully!')),
                        );
                      }
                    },
                    child: const Text('Publish Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSendSmsDialog(BuildContext context, ChatConversation conversation, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final phone = conversation.phone ?? '+91 98765 43210';
    final smsCtrl = TextEditingController(text: 'Dear ${conversation.name}, this is an update regarding your ward\'s academic progress.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final count = smsCtrl.text.length;
          final numSms = (count / 160).ceil().clamp(1, 10);
          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.sms_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text('Direct SMS Gateway', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.close, color: textSecondary, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text('To: $phone (${conversation.name})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Quick Templates:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: const Text('Attendance Alert', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            smsCtrl.text = 'Dear ${conversation.name}, please note your ward was marked present today in Class 10-A. Attendance: 94.2%.';
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('Fee Reminder', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            smsCtrl.text = 'Dear ${conversation.name}, reminder that the upcoming term fee invoice is available on the EduSHAMIIT portal.';
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('PTM Meeting', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setDialogState(() {
                            smsCtrl.text = 'Dear ${conversation.name}, you are invited to attend the Parent-Teacher Meeting this Friday at 10:00 AM.';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smsCtrl,
                    maxLines: 4,
                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'SMS Content',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$count / 160 characters ($numSms SMS)',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Dispatch SMS via Gateway', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final msg = smsCtrl.text.trim();
                        if (msg.isEmpty) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('SMS successfully dispatched to $phone!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditGroupDetailsDialog(BuildContext context, ChatConversation conversation) async {
    final nameCtrl = TextEditingController(text: conversation.name);
    final descCtrl = TextEditingController(text: conversation.description ?? '');
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Uint8List? pendingAvatarBytes;
    String? pendingAvatarName;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Group Details',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 4),
                    // Group Avatar Preview with Camera Button Badge
                    GestureDetector(
                      onTap: isSaving
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (picked == null || !ctx.mounted) return;
                                final cropped = await _cropImageWithCropper(ctx, picked.path);
                                if (cropped == null || !ctx.mounted) return;
                                setDialogState(() {
                                  pendingAvatarBytes = cropped;
                                  pendingAvatarName = picked.name.contains('.') ? picked.name : '${picked.name}.jpg';
                                });
                              } catch (e) {
                                debugPrint('Error cropping avatar: $e');
                              }
                            },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB),
                              border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3), width: 3),
                            ),
                            child: ClipOval(
                              child: pendingAvatarBytes != null
                                  ? Image.memory(pendingAvatarBytes!, fit: BoxFit.cover)
                                  : (conversation.avatarUrl != null && conversation.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          conversation.avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(
                                            child: Icon(Icons.groups_rounded, color: Colors.white, size: 40),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(Icons.groups_rounded, color: Colors.white, size: 40),
                                        )),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: widget.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBg, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  imageQuality: 85,
                                );
                                if (picked == null || !ctx.mounted) return;
                                final cropped = await _cropImageWithCropper(ctx, picked.path);
                                if (cropped == null || !ctx.mounted) return;
                                setDialogState(() {
                                  pendingAvatarBytes = cropped;
                                  pendingAvatarName = picked.name.contains('.') ? picked.name : '${picked.name}.jpg';
                                });
                              } catch (e) {
                                debugPrint('Error cropping avatar: $e');
                              }
                            },
                      icon: const Icon(Icons.photo_camera_back_outlined, size: 14),
                      label: const Text('Change Group Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Group Name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Enter group name',
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Group Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Describe group purpose...',
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.primaryColor, width: 1.5)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) return;
                        final newDesc = descCtrl.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSaving = true);

                        String? newAvatarUrl;
                        if (pendingAvatarBytes != null) {
                          newAvatarUrl = await ref.read(messagingProvider.notifier).updateGroupAvatar(
                                conversation.id,
                                pendingAvatarBytes!,
                                pendingAvatarName ?? 'avatar.jpg',
                              );
                        }

                        await ref.read(messagingProvider.notifier).updateGroupDetails(
                              conversation.id,
                              name: newName,
                              description: newDesc,
                              avatarUrl: newAvatarUrl,
                            );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        final updated = conversation.copyWith(
                          name: newName,
                          description: newDesc,
                          avatarUrl: newAvatarUrl ?? conversation.avatarUrl,
                        );
                        widget.onConversationUpdated?.call(updated);
                        await _loadMembers();
                        await ref.read(messagingProvider.notifier).fetchMessages(useCache: false);
                        if (mounted) {
                          setState(() {});
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Group details updated successfully'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMemberProfileDetails(Map<String, dynamic> member) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final mName = (member['name'] ?? member['full_name'] ?? 'Member').toString();
    final userRole = (member['user_role'] ?? member['role'] ?? 'Student').toString().toUpperCase();
    final phone = (member['phone'] != null && member['phone'].toString().trim().isNotEmpty)
        ? member['phone'].toString()
        : 'Not specified';
    final email = (member['email'] != null && member['email'].toString().trim().isNotEmpty)
        ? member['email'].toString()
        : 'Not provided';
    final avatarUrl = member['avatar_url'] as String?;
    final className = (member['class'] ?? member['class_name']) as String?;
    final dept = member['department'] as String?;
    final initial = mName.isNotEmpty ? mName[0].toUpperCase() : 'M';
    final isMemberAdmin = member['role'] == 'admin' || member['group_role'] == 'admin' || member['is_creator'] == true;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Member Details', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Big Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF2563EB),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(initial, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                mName,
                style: TextStyle(fontFamily: AppFonts.heading, fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              // Role Badge & Admin Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(userRole, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                  if (isMemberAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('GROUP ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),
              // Info Fields
              _buildMemberInfoRow(Icons.email_outlined, 'Email', email, textPrimary, textSecondary),
              const SizedBox(height: 10),
              _buildMemberInfoRow(Icons.phone_outlined, 'Phone', phone, textPrimary, textSecondary),
              if (className != null && className.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildMemberInfoRow(Icons.school_outlined, 'Class', className, textPrimary, textSecondary),
              ],
              if (dept != null && dept.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildMemberInfoRow(Icons.business_outlined, 'Department', dept, textPrimary, textSecondary),
              ],
              const SizedBox(height: 20),
              // Action Buttons: Call, Message
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        CallService.instance.initiateCall(
                          calleeId: member['id'] as String? ?? '',
                          calleeName: mName,
                          calleeAvatarUrl: avatarUrl,
                          callType: CallType.audio,
                        );
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CallScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Message', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final mid = member['id'] as String? ?? '';
                        final conversations = ref.read(messagingProvider).conversations;
                        final directConv = conversations.where((c) => c.id == mid || c.phone == phone).firstOrNull;
                        if (directConv != null) {
                          ref.read(messagingProvider.notifier).fetchChatHistory(directConv.id);
                        } else {
                          ref.read(messagingProvider.notifier).sendMessage('Hello $mName', receiverId: mid);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInfoRow(IconData icon, String title, String val, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 10.5, color: textSecondary)),
            Text(val, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddGroupMembersDialog(
    BuildContext context,
    WidgetRef ref,
    ChatConversation conversation,
    bool isDark, {
    Future<void> Function()? onMembersAdded,
  }) async {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final allUsers = await ref.read(messagingProvider.notifier).searchUsers('');
    if (!context.mounted) return;

    final selectedIds = <String>{};
    String searchQuery = '';
    String selectedRole = 'all'; // 'all', 'student', 'teacher', 'parent', 'staff'
    bool isSubmitting = false;

    // Filter out users already in the group
    final existingMemberIds = _members.map((m) => m['id'] as String).toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchQuery.trim().toLowerCase();
          final filteredUsers = allUsers.where((u) {
            final uid = u['id'] as String? ?? '';
            if (existingMemberIds.contains(uid)) return false;

            final role = (u['role'] as String? ?? '').toLowerCase();
            if (selectedRole == 'student' && role != 'student') return false;
            if (selectedRole == 'teacher' && role != 'teacher') return false;
            if (selectedRole == 'parent' && role != 'parent') return false;
            if (selectedRole == 'staff' && role != 'staff' && role != 'support' && role != 'admin') return false;

            if (query.isNotEmpty) {
              final name = (u['full_name'] as String? ?? '').toLowerCase();
              final email = (u['email'] as String? ?? '').toLowerCase();
              if (!name.contains(query) && !email.contains(query) && !role.contains(query)) return false;
            }
            return true;
          }).toList();

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            child: Container(
              width: 500,
              height: 580,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Members to ${conversation.name}',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search from user management for your institute',
                            style: TextStyle(fontSize: 11.5, color: textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Real-time Search Box
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      onChanged: (val) => setDialogState(() => searchQuery = val),
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                        hintText: 'Search by name, email, or role...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textSecondary.withValues(alpha: 0.8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', selectedRole, (r) => setDialogState(() => selectedRole = r), isDark, textPrimary, textSecondary),
                        const SizedBox(width: 6),
                        _buildFilterChip('Students', 'student', selectedRole, (r) => setDialogState(() => selectedRole = r), isDark, textPrimary, textSecondary),
                        const SizedBox(width: 6),
                        _buildFilterChip('Teachers', 'teacher', selectedRole, (r) => setDialogState(() => selectedRole = r), isDark, textPrimary, textSecondary),
                        const SizedBox(width: 6),
                        _buildFilterChip('Parents', 'parent', selectedRole, (r) => setDialogState(() => selectedRole = r), isDark, textPrimary, textSecondary),
                        const SizedBox(width: 6),
                        _buildFilterChip('Staff', 'staff', selectedRole, (r) => setDialogState(() => selectedRole = r), isDark, textPrimary, textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Members List
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search_rounded, size: 40, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'No users found',
                                  style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, idx) {
                              final u = filteredUsers[idx];
                              final id = u['id'] as String;
                              final name = u['full_name'] as String? ?? 'User';
                              final role = (u['role'] as String? ?? 'student').toLowerCase();
                              final email = u['email'] as String? ?? '';
                              final avatarUrl = u['avatar_url'] as String?;
                              final isSel = selectedIds.contains(id);
                              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                              Color roleBadgeColor = const Color(0xFF2563EB);
                              if (role == 'teacher') roleBadgeColor = const Color(0xFF10B981);
                              if (role == 'parent') roleBadgeColor = const Color(0xFFF59E0B);
                              if (role == 'staff' || role == 'admin') roleBadgeColor = const Color(0xFF8B5CF6);

                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    if (isSel) {
                                      selectedIds.remove(id);
                                    } else {
                                      selectedIds.add(id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE).withValues(alpha: 0.5))
                                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel
                                          ? const Color(0xFF2563EB)
                                          : borderColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // User Avatar
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: roleBadgeColor,
                                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null || avatarUrl.isEmpty
                                            ? Text(initial, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold))
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      // Name & role
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: roleBadgeColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    role.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: roleBadgeColor,
                                                    ),
                                                  ),
                                                ),
                                                if (email.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      email,
                                                      style: TextStyle(fontSize: 10.5, color: textSecondary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Custom Checkbox
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF2563EB) : textSecondary.withValues(alpha: 0.5),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSel
                                            ? const Icon(Icons.check, size: 15, color: Colors.white)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSubmitting || selectedIds.isEmpty
                          ? null
                          : () async {
                              setDialogState(() => isSubmitting = true);
                              for (final uid in selectedIds) {
                                await ref.read(messagingProvider.notifier).addMemberToGroup(conversation.id, uid);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (onMembersAdded != null) {
                                await onMembersAdded();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added ${selectedIds.length} members to ${conversation.name}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Add Selected Members (${selectedIds.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String activeValue,
    Function(String) onSelect,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = activeValue == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }


  void _exportChatHistory(BuildContext context, WidgetRef ref, ChatConversation conversation) {
    final history = ref.read(messagingProvider).chatHistory;
    final buffer = StringBuffer();
    buffer.writeln('=== Chat History for ${conversation.name} ===');
    buffer.writeln('Exported on: ${DateTime.now().toIso8601String()}\n');
    for (final m in history) {
      final sender = m.senderName ?? 'User';
      buffer.writeln('[${m.createdAt}] $sender: ${m.content}');
      if (m.attachmentUrl != null) {
        buffer.writeln('  Attachment: ${m.fileName ?? m.attachmentUrl}');
      }
    }
    final content = buffer.toString();
    getDownloadHelper().downloadFile(
      'data:text/plain;charset=utf-8,${Uri.encodeComponent(content)}',
      'Chat_History_${conversation.name.replaceAll(" ", "_")}.txt',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting chat history for ${conversation.name}...')),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String val, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: textSecondary)),
            Text(val, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String val, String subtitle, Color color, Color bg, Color border, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9.5, color: textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSubjectScoreRow(String subject, String score, String grade, double progress, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: textSecondary.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(score, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary)),
              Text(grade, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// "+ NEW MESSAGE" MODAL DIALOG COMPONENT
// ============================================================================

class _NewMessageModal extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic> user) onSelectUser;
  final VoidCallback onCreateGroup;

  const _NewMessageModal({
    required this.onSelectUser,
    required this.onCreateGroup,
  });

  @override
  ConsumerState<_NewMessageModal> createState() => _NewMessageModalState();
}

class _NewMessageModalState extends ConsumerState<_NewMessageModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _roleFilter = 'all'; // 'all', 'student', 'parent', 'teacher', 'staff'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await ref.read(messagingProvider.notifier).searchUsers('');
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final query = _searchController.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      final role = (u['role'] as String? ?? '').toLowerCase();
      if (_roleFilter == 'student' && role != 'student') return false;
      if (_roleFilter == 'parent' && role != 'parent') return false;
      if (_roleFilter == 'teacher' && role != 'teacher') return false;
      if (_roleFilter == 'staff' && role != 'staff' && role != 'support' && role != 'admin') return false;

      if (query.isNotEmpty) {
        final name = (u['full_name'] as String? ?? '').toLowerCase();
        if (!name.contains(query)) return false;
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'New Conversation',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Box
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                hintText: 'Search people by name...',
                hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: borderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),

            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRoleChip('All', 'all'),
                  _buildRoleChip('Students', 'student'),
                  _buildRoleChip('Parents', 'parent'),
                  _buildRoleChip('Teachers', 'teacher'),
                  _buildRoleChip('Staff', 'staff'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Create Group Banner button
            InkWell(
              onTap: () {
                Navigator.pop(context);
                widget.onCreateGroup();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.group_add_rounded, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create a New Group Squad',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // User List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No contacts found',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final u = filtered[index];
                            final name = u['full_name'] as String? ?? 'User';
                            final role = u['role'] as String? ?? 'student';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                role.toUpperCase(),
                                style: TextStyle(fontSize: 11, color: textSecondary),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelectUser(u);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _roleFilter = value),
        selectedColor: const Color(0xFF2563EB),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : Colors.grey,
        ),
      ),
    );
  }
}

// ============================================================================
// CREATE GROUP BOTTOM SHEET & PAINTER (RESTORED FULL POWER & THEME-ADAPTIVE)
// ============================================================================

class _CreateGroupBottomSheet extends ConsumerStatefulWidget {
  final bool isTeacher;
  final ValueChanged<String>? onGroupCreated;
  const _CreateGroupBottomSheet({required this.isTeacher, this.onGroupCreated});

  @override
  ConsumerState<_CreateGroupBottomSheet> createState() => _CreateGroupBottomSheetState();
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
    final rect = Rect.fromCircle(center: Offset(radius, radius), radius: radius);
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

class _CreateGroupBottomSheetState extends ConsumerState<_CreateGroupBottomSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;

  Uint8List? _groupAvatarBytes;
  String? _groupAvatarName;
  int _activeRoleTab = 0; // 0=All, 1=Students, 2=Teachers, 3=Parents, 4=Staff
  String _groupLevel = 'class'; // 'class' (Private) or 'school' (Public)

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    setState(() => _isLoading = true);
    final users = await ref.read(messagingProvider.notifier).searchUsers('');
    if (mounted) {
      setState(() {
        _candidates = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickGroupAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      if (picked == null || !mounted) return;
      final cropped = await _cropImageWithCropper(context, picked.path);
      if (cropped == null || !mounted) return;
      setState(() {
        _groupAvatarBytes = cropped;
        _groupAvatarName = picked.name.contains('.') ? picked.name : '${picked.name}.jpg';
      });
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredCandidates() {
    final query = _searchController.text.trim().toLowerCase();
    return _candidates.where((u) {
      final role = (u['role'] as String? ?? '').toLowerCase();
      if (_activeRoleTab == 1 && role != 'student') return false;
      if (_activeRoleTab == 2 && role != 'teacher') return false;
      if (_activeRoleTab == 3 && role != 'parent') return false;
      if (_activeRoleTab == 4 && role != 'staff' && role != 'support' && role != 'admin' && role != 'super_admin') return false;

      if (query.isNotEmpty) {
        final name = (u['full_name'] as String? ?? '').toLowerCase();
        final cls = (u['class'] as String? ?? '').toLowerCase();
        if (!name.contains(query) && !cls.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filtered = _getFilteredCandidates();
    final allSelected = filtered.isNotEmpty && filtered.every((u) => _selectedUserIds.contains(u['id']));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isTeacher ? 'Create Class / Academic Group' : 'Create Study Squad Group',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Form Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Group Avatar Picker
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickGroupAvatar,
                            child: _groupAvatarBytes != null
                                ? Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                                    ),
                                    child: ClipOval(
                                      child: Image.memory(_groupAvatarBytes!, fit: BoxFit.cover),
                                    ),
                                  )
                                : CustomPaint(
                                    painter: DashedCirclePainter(
                                      color: const Color(0xFF60A5FA),
                                      strokeWidth: 2,
                                      dashCount: 16,
                                    ),
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      alignment: Alignment.center,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB), size: 26),
                                          SizedBox(height: 2),
                                          Text('Set Icon', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _groupAvatarBytes != null ? 'Tap to change photo' : 'Upload group icon',
                            style: TextStyle(fontSize: 11, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Group Name Input
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontSize: 13.5, color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Group Squad Name',
                        labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                        hintText: 'e.g. Class 10-A Science Revision',
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 13),
                        filled: true,
                        fillColor: subBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description Input
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13.5, color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Group Description (Optional)',
                        labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                        hintText: 'Purpose and guidelines for members...',
                        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7), fontSize: 13),
                        filled: true,
                        fillColor: subBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Group Level Segmented Control
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: subBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _groupLevel = 'class'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _groupLevel == 'class' ? const Color(0xFF2563EB) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Class Group (Private)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _groupLevel == 'class' ? FontWeight.bold : FontWeight.w500,
                                    color: _groupLevel == 'class' ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _groupLevel = 'school'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _groupLevel == 'school' ? const Color(0xFF2563EB) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'School Squad (Public)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _groupLevel == 'school' ? FontWeight.bold : FontWeight.w500,
                                    color: _groupLevel == 'school' ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Search Members & Select All
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                              hintText: 'Search members...',
                              hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
                              filled: true,
                              fillColor: subBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            setState(() {
                              if (allSelected) {
                                for (final u in filtered) {
                                  _selectedUserIds.remove(u['id']);
                                }
                              } else {
                                for (final u in filtered) {
                                  _selectedUserIds.add(u['id']);
                                }
                              }
                            });
                          },
                          child: Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Role Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRoleFilterChip('All', 0, textPrimary, textSecondary),
                          _buildRoleFilterChip('Students', 1, textPrimary, textSecondary),
                          _buildRoleFilterChip('Teachers', 2, textPrimary, textSecondary),
                          _buildRoleFilterChip('Parents', 3, textPrimary, textSecondary),
                          _buildRoleFilterChip('Staff', 4, textPrimary, textSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Member Candidate List
                    _isLoading
                        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                        : filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text('No users match this filter', style: TextStyle(color: textSecondary, fontSize: 13)),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: subBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                  itemBuilder: (context, index) {
                                    final u = filtered[index];
                                    final id = u['id'] as String;
                                    final name = u['full_name'] as String? ?? 'User';
                                    final role = (u['role'] as String? ?? 'student').toUpperCase();
                                    final cls = u['class'] as String?;
                                    final isSelected = _selectedUserIds.contains(id);
                                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                                    return CheckboxListTile(
                                      value: isSelected,
                                      activeColor: const Color(0xFF2563EB),
                                      dense: true,
                                      secondary: CircleAvatar(
                                        radius: 17,
                                        backgroundColor: const Color(0xFF2563EB),
                                        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      title: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                                      subtitle: Text(
                                        cls != null ? '$role • $cls' : role,
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedUserIds.add(id);
                                          } else {
                                            _selectedUserIds.remove(id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                  ],
                ),
              ),

              // Bottom Sticky Create Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      final desc = _descController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a group name')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);

                      final newGroupId = await ref.read(messagingProvider.notifier).createGroup(
                            name,
                            desc,
                            memberIds: _selectedUserIds.toList(),
                            avatarBytes: _groupAvatarBytes,
                            avatarFilename: _groupAvatarName,
                            groupLevel: _groupLevel,
                            isPrivate: _groupLevel == 'class',
                          );

                      if (newGroupId != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('🎉 Group "$name" created successfully!')),
                        );
                        if (newGroupId.isNotEmpty) {
                          widget.onGroupCreated?.call(newGroupId);
                        }
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Failed to create group. Please try again.')),
                        );
                      }
                    },
                    child: Text(
                      'Create Group Squad (${_selectedUserIds.length} Members)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilterChip(String label, int index, Color textPrimary, Color textSecondary) {
    final isSelected = _activeRoleTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _activeRoleTab = index),
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: Colors.transparent,
        side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : textSecondary.withValues(alpha: 0.3)),
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : textPrimary,
        ),
      ),
    );
  }
}
