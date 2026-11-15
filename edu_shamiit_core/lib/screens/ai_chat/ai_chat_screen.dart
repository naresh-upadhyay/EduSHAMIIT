import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile, FilePicker, FileType;
import 'package:url_launcher/url_launcher.dart';

import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../providers/ai_chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/voice_recorder_service.dart';
import '../../utils/nav_helper.dart';
import 'package:edu_shamiit_core/services/tts_service.dart';

// ─────────────────────────────────────────────────────────────
//  Premium Shami AI Assistant Screen (Three-Panel Workspace)
// ─────────────────────────────────────────────────────────────

class AiChatScreen extends ConsumerStatefulWidget {
  final String? launchedFrom;
  const AiChatScreen({super.key, this.launchedFrom});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _searchDebounceTimer;

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(aiChatProvider.notifier).loadSessions(
          search: query.trim(),
          archived: ref.read(aiChatProvider).isArchivedView,
        );
      }
    });
  }

  // Real-time speech-to-text (Google mic style)
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  final bool _isRecordingFallback = false;
  String _liveWords = '';
  String _sttLocale = 'en_US';

  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final AnimationController _micPulseController;

  XFile? _selectedImage;
  PlatformFile? _selectedDocument;
  String? _currentlySpeakingMsgId;
  String? _activeContext;

  // ── Dynamic Enterprise Theme Palette ─────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _darkBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _panelBg => _isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC);
  Color get _inputBg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get _borderCol => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  
  // Brand Blue Colors matching Reference UI
  static const _primaryBlue = Color(0xFF2563EB);
  
  Color get _userBubble => _isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF);
  Color get _userBubbleText => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
  Color get _aiBubble => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _textPrimary => _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get _textMuted => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static const _accentGreen = Color(0xFF10B981);
  static const _recordRed = Color(0xFFEF4444);

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _activeContext = widget.launchedFrom;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).loadChatHistory(clearExisting: true);
      ref.read(aiChatProvider.notifier).loadSessions();
      ref.read(aiChatProvider.notifier).loadSuggestions();
      _initStt();
    });
  }

  Future<void> _initStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (e) {
          debugPrint('STT error: $e');
          if (mounted) setState(() { _isListening = false; });
        },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted && _isListening) {
            _onSttDone();
          }
        },
      );
      if (_sttAvailable) {
        final systemLoc = await _stt.systemLocale();
        if (systemLoc != null && mounted) {
          setState(() {
            _sttLocale = systemLoc.localeId;
          });
        }
      }
    } catch (e) {
      debugPrint('STT initialization error: $e');
      _sttAvailable = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    TtsService.instance.stop();
    _scrollController.removeListener(_scrollListener);
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _micPulseController.dispose();
    if (_isListening) {
      if (_isRecordingFallback) {
        VoiceRecorderService.instance.cancelRecording();
      } else {
        try {
          _stt.stop();
        } catch (_) {}
      }
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Main Screen Build (Three-Panel Layout)
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: _cardBg,
        child: SafeArea(child: _buildConversationsLeftPanel(chatState, isDrawer: true)),
      ),
      endDrawer: Drawer(
        backgroundColor: _cardBg,
        child: SafeArea(child: _buildRightContextPanel(chatState, isDrawer: true)),
      ),
      backgroundColor: _darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 990;
          final isMedium = constraints.maxWidth >= 640 && !isDesktop;
          final showLeftInline = isDesktop || isMedium;
          final showRightInline = isDesktop;

          return Column(
            children: [
              // 1. Top Screen Banner (AI Assistant Beta)
              _buildTopBanner(
                chatState,
                showLeftMenuButton: !showLeftInline,
                showRightMenuButton: !showRightInline,
              ),

              // 2. Main Three-Panel Workspace Body
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Panel: Conversations
                          SizedBox(
                            width: 280,
                            child: _buildConversationsLeftPanel(chatState),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: _borderCol),

                          // Center Panel: Chat Workspace
                          Expanded(
                            child: _buildCenterChatWorkspace(chatState),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: _borderCol),

                          // Right Panel: Quick Actions & Context
                          SizedBox(
                            width: 300,
                            child: _buildRightContextPanel(chatState),
                          ),
                        ],
                      );
                    } else if (isMedium) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 260,
                            child: _buildConversationsLeftPanel(chatState),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: _borderCol),
                          Expanded(
                            child: _buildCenterChatWorkspace(chatState),
                          ),
                        ],
                      );
                    } else {
                      // Mobile Single-Column Workspace
                      return _buildCenterChatWorkspace(chatState);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  1. Top Banner (Matching Screenshot Header)
  // ─────────────────────────────────────────────────────────

  Widget _buildTopBanner(
    AiChatState chatState, {
    bool showLeftMenuButton = false,
    bool showRightMenuButton = false,
  }) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context) + 4, 16, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderCol)),
      ),
      child: Row(
        children: [
          if (canPop || !Responsive.isDesktop(context)) ...[
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
              onPressed: () => safeGoBack(context, dashboardFallback(context)),
              tooltip: 'Back',
            ),
          ],
          if (showLeftMenuButton) ...[
            IconButton(
              icon: Icon(Icons.menu_rounded, color: _textPrimary, size: 20),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Conversations',
            ),
            const SizedBox(width: 4),
          ],
          
          // Robot icon inside light blue square
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded, color: _primaryBlue, size: 24),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
                      ),
                      child: const Text(
                        'Beta',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Get instant answers, generate reports, and simplify your school management tasks with AI.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    color: _textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          if (showRightMenuButton)
            IconButton(
              icon: const Icon(Icons.dashboard_customize_outlined, color: _primaryBlue, size: 22),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              tooltip: 'Quick Actions & AI Tools',
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  2. Left Panel: Recent Conversations
  // ─────────────────────────────────────────────────────────

  Widget _buildConversationsLeftPanel(AiChatState chatState, {bool isDrawer = false}) {
    final sessions = chatState.sessions;

    return Container(
      color: _panelBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid Blue "+ New Chat" Button
          InkWell(
            onTap: () {
              ref.read(aiChatProvider.notifier).startNewChat();
              if (isDrawer) Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'New Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: "Recent Conversations"
          Row(
            children: [
              Text(
                'Recent Conversations',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              if (chatState.isArchivedView)
                GestureDetector(
                  onTap: () => ref.read(aiChatProvider.notifier).loadSessions(archived: false),
                  child: const Text('Active', style: TextStyle(color: _primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                GestureDetector(
                  onTap: () => ref.read(aiChatProvider.notifier).loadSessions(archived: true),
                  child: Text('Archived', style: TextStyle(color: _textMuted, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _borderCol),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 12, color: _textPrimary),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                hintStyle: TextStyle(fontSize: 12, color: _textMuted),
                prefixIcon: Icon(Icons.search, size: 16, color: _textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Conversations List
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      'No conversations found',
                      style: TextStyle(fontSize: 12, color: _textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final item = sessions[idx];
                      final sid = (item['session_id'] ?? '').toString();
                      final isSelected = sid == chatState.sessionId;
                      final title = (item['title'] ?? 'New Chat').toString();
                      final timeStr = _formatSessionTime(item['last_message_at']);
                      final snippet = (item['last_message'] ?? item['title'] ?? '').toString();
                      final isPinned = item['is_pinned'] == true;

                      return _buildConversationListItem(
                        title: title,
                        snippet: snippet,
                        timeStr: timeStr,
                        isSelected: isSelected,
                        isPinned: isPinned,
                        onTap: () {
                          ref.read(aiChatProvider.notifier).selectSession(
                            sid,
                            title: title,
                            subtitle: snippet.isNotEmpty ? snippet : 'School management assistance and queries.',
                          );
                          if (isDrawer) Navigator.pop(context);
                        },
                        onMenuSelected: (action) {
                          if (action == 'rename') _showRenameDialog(sid, title);
                          if (action == 'pin') ref.read(aiChatProvider.notifier).togglePinSession(sid, !isPinned);
                          if (action == 'archive') ref.read(aiChatProvider.notifier).toggleArchiveSession(sid, true);
                          if (action == 'export') _exportCurrentConversation();
                          if (action == 'delete') _confirmDeleteSession(sid);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationListItem({
    required String title,
    required String snippet,
    required String timeStr,
    required bool isSelected,
    required bool isPinned,
    required VoidCallback onTap,
    required ValueChanged<String> onMenuSelected,
  }) {
    IconData itemIcon = Icons.chat_bubble_outline_rounded;
    Color iconColor = _primaryBlue;

    final lower = title.toLowerCase();
    if (lower.contains('fee') || lower.contains('payment') || lower.contains('dues')) {
      itemIcon = Icons.description_outlined;
      iconColor = const Color(0xFF2563EB);
    } else if (lower.contains('attendance') || lower.contains('absent')) {
      itemIcon = Icons.groups_outlined;
      iconColor = const Color(0xFF0EA5E9);
    } else if (lower.contains('timetable') || lower.contains('schedule')) {
      itemIcon = Icons.calendar_month_outlined;
      iconColor = const Color(0xFF6366F1);
    } else if (lower.contains('tc') || lower.contains('certificate') || lower.contains('document')) {
      itemIcon = Icons.article_outlined;
      iconColor = const Color(0xFF3B82F6);
    } else if (lower.contains('library') || lower.contains('book')) {
      itemIcon = Icons.menu_book_outlined;
      iconColor = const Color(0xFF8B5CF6);
    } else if (lower.contains('bus') || lower.contains('route') || lower.contains('transport')) {
      itemIcon = Icons.directions_bus_outlined;
      iconColor = const Color(0xFF0284C7);
    } else if (lower.contains('admission') || lower.contains('statistics') || lower.contains('report')) {
      itemIcon = Icons.trending_up_rounded;
      iconColor = const Color(0xFF10B981);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? iconColor.withValues(alpha: 0.15)
                    : (_isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(itemIcon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 10, color: _textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snippet,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      color: _textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 15, color: _textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onSelected: onMenuSelected,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(isPinned ? 'Unpin' : 'Pin')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
                const PopupMenuItem(value: 'export', child: Text('Export Chat')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  3. Center Panel: AI Chat Workspace
  // ─────────────────────────────────────────────────────────

  Widget _buildCenterChatWorkspace(AiChatState chatState) {
    return Container(
      color: _cardBg,
      child: Column(
        children: [
          // Header Bar of Active Chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderCol)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.description_outlined, color: _primaryBlue, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chatState.activeTitle,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _cleanSubtitleText(chatState.activeSubtitle),
                        style: TextStyle(fontSize: 11, color: _textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Export Chat Action
                InkWell(
                  onTap: _exportCurrentConversation,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, color: _textMuted, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          'Export',
                          style: TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Clear Chat Action
                InkWell(
                  onTap: _confirmClear,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: _textMuted, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          'Clear Chat',
                          style: TextStyle(fontSize: 11.5, color: _textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message Stream
          Expanded(child: _buildMessageList(chatState)),

          // Voice Listening Bar
          if (_isListening) _buildVoiceListeningBar(),

          // Input Composer Bar
          _buildInputBar(chatState),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Messages Rendering with Action Cards
  // ─────────────────────────────────────────────────────────

  Widget _buildMessageList(AiChatState chatState) {
    if (chatState.isLoading) {
      return _buildLoadingState();
    }

    final msgs = chatState.messages;
    if (msgs.isEmpty) {
      return _buildEmptyState();
    }

    final showLoading = chatState.isLoadingMore;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: msgs.length + (showLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (showLoading && i == msgs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue)),
              ),
            ),
          );
        }

        final msgIndex = msgs.length - 1 - i;
        final msg = msgs[msgIndex];

        return KeepAliveWrapper(
          key: ValueKey(msg.id),
          child: _buildBubble(msg),
        );
      },
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Robot Avatar on left
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: _isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded, color: _primaryBlue, size: 18),
              ),
            ),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * (Responsive.isDesktop(context) ? 0.55 : 0.78),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? _userBubble : _aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      border: Border.all(
                        color: isUser
                            ? (_isDark ? const Color(0xFF2563EB).withValues(alpha: 0.3) : const Color(0xFFDBEAFE))
                            : _borderCol,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Preview if any
                        if (msg.imagePath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(msg.imagePath!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                : Image.file(File(msg.imagePath!), height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // User message content
                        if (isUser)
                          SelectableText(
                            msg.text,
                            style: TextStyle(fontSize: 13.5, color: _userBubbleText, height: 1.45),
                          )
                        // Assistant message content with Scratchpad & Cards
                        else ...[
                          if (msg.scratchpadSteps.isNotEmpty || (msg.isStreaming && msg.text.isEmpty))
                            _ScratchpadCard(msg: msg, isDark: _isDark),
                          if (msg.text.isNotEmpty)
                            _buildAiResponseContent(msg.text, msg.isStreaming),
                          if (msg.isStreaming && msg.text.isEmpty && msg.scratchpadSteps.isEmpty)
                            _buildTypingDots(),
                        ],

                        const SizedBox(height: 6),
                        // Timestamp and checkmarks for user
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Text(
                              msg.formattedTime,
                              style: TextStyle(fontSize: 10, color: _textMuted),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all_rounded, size: 13, color: _primaryBlue),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // AI Action Row (Copy, TTS, Regenerate, Feedback)
                if (!isUser && !msg.isStreaming && msg.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBubbleActionButton(
                        icon: Icons.copy_rounded,
                        tooltip: 'Copy Response',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _cleanMathExpressions(msg.text)));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard'), behavior: SnackBarBehavior.floating),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildBubbleActionButton(
                        icon: _currentlySpeakingMsgId == msg.id ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        tooltip: _currentlySpeakingMsgId == msg.id ? 'Stop Speaking' : 'Read Aloud',
                        onTap: () {
                          if (_currentlySpeakingMsgId == msg.id) {
                            TtsService.instance.stop();
                            setState(() => _currentlySpeakingMsgId = null);
                          } else {
                            final clean = _cleanMathExpressions(msg.text);
                            setState(() => _currentlySpeakingMsgId = msg.id);
                            TtsService.instance.speak(clean, onComplete: () {
                              if (mounted) setState(() => _currentlySpeakingMsgId = null);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildBubbleActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Regenerate',
                        onTap: () => ref.read(aiChatProvider.notifier).regenerateMessage(msg, launchedFrom: _activeContext),
                      ),
                      const SizedBox(width: 6),
                      // Thumbs Up / Thumbs Down Feedback
                      _buildBubbleActionButton(
                        icon: msg.feedbackRating == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                        tooltip: 'Helpful',
                        iconColor: msg.feedbackRating == 1 ? _primaryBlue : _textMuted,
                        onTap: () => ref.read(aiChatProvider.notifier).submitFeedback(msg, 1),
                      ),
                      const SizedBox(width: 4),
                      _buildBubbleActionButton(
                        icon: msg.feedbackRating == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                        tooltip: 'Not Helpful',
                        iconColor: msg.feedbackRating == -1 ? Colors.redAccent : _textMuted,
                        onTap: () => ref.read(aiChatProvider.notifier).submitFeedback(msg, -1),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // User Avatar on right
          if (isUser) ...[
            Builder(
              builder: (ctx) {
                final authState = ref.watch(authProvider);
                final name = (authState.userData?['full_name'] as String? ?? '').trim();
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                return Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 10, top: 2),
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  AI Response Content with Embedded Cards & KPIs
  // ─────────────────────────────────────────────────────────

  Widget _buildAiResponseContent(String text, bool isStreaming) {
    // Check for :::card type="..." title="..." subtitle="..." action="..." url="..." :::
    final cardRegex = RegExp(r':::card\s+type="([^"]+)"\s+title="([^"]+)"\s+subtitle="([^"]+)"\s+action="([^"]+)"\s+url="([^"]+)"\s*:::');

    if (cardRegex.hasMatch(text)) {
      final List<Widget> items = [];
      int lastPos = 0;

      for (final match in cardRegex.allMatches(text)) {
        if (match.start > lastPos) {
          final chunk = text.substring(lastPos, match.start).trim();
          if (chunk.isNotEmpty) {
            items.add(_buildMarkdownText(chunk));
          }
        }

        final title = match.group(2) ?? '';
        final subtitle = match.group(3) ?? '';
        final action = match.group(4) ?? 'View Report';
        final url = match.group(5) ?? '/admin/fee-management';

        items.add(const SizedBox(height: 10));
        items.add(_buildEmbeddedCard(title: title, subtitle: subtitle, action: action, url: url));
        items.add(const SizedBox(height: 10));

        lastPos = match.end;
      }

      if (lastPos < text.length) {
        final rest = text.substring(lastPos).trim();
        if (rest.isNotEmpty) {
          items.add(_buildMarkdownText(rest));
        }
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
    }

    // Standard markdown rendering
    return _buildMarkdownText(text.isEmpty && isStreaming ? '▋' : text);
  }

  Widget _buildMarkdownText(String text) {
    final cleanData = _preprocessMarkdownLinks(_cleanMathExpressions(text));
    return MarkdownBody(
      data: cleanData,
      selectable: true,
      onTapLink: (t, href, tl) => _handleLinkTap(href),
      imageBuilder: (Uri uri, String? title, String? alt) => _buildChatImage(uri, title, alt),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 13.5, color: _textPrimary, height: 1.5, fontFamily: AppFonts.body),
        strong: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _textPrimary),
        listBullet: const TextStyle(fontSize: 13.5, color: _primaryBlue),
        a: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3B82F6),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF3B82F6),
        ),
        code: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          backgroundColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          color: _primaryBlue,
        ),
      ),
    );
  }

  String _resolveImageUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return clean;
    if (clean.startsWith('/api/')) {
      return '${AppConfig.baseUrl}$clean';
    }
    if (clean.startsWith('/')) {
      return '${AppConfig.baseUrl}$clean';
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      if (clean.contains('/api/chat/media') || clean.contains('/api/chat/image-proxy')) {
        return clean;
      }
      return '${AppConfig.apiBaseUrl}/chat/image-proxy?url=${Uri.encodeComponent(clean)}';
    }
    return clean;
  }

  Widget _buildChatImage(Uri uri, String? title, String? alt) {
    final rawUrl = uri.toString().trim();
    if (rawUrl.isEmpty) return const SizedBox.shrink();

    // Resolve full, valid display URL
    final displayUrl = _resolveImageUrl(rawUrl);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 520 ? 520.0 : constraints.maxWidth;
          return Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderCol),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.3 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showFullscreenImage(displayUrl, alt ?? title ?? 'Generated AI Image'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      children: [
                        Image.network(
                          displayUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            final total = loadingProgress.expectedTotalBytes;
                            final loaded = loadingProgress.cumulativeBytesLoaded;
                            final progress = (total != null && total > 0) ? loaded / total : null;

                            return Container(
                              height: 240,
                              color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 2.5,
                                        color: _primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Rendering AI Image...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Generating photorealistic details',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: _textMuted.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              padding: const EdgeInsets.all(16),
                              color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.broken_image_outlined, size: 36, color: Colors.amber),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image loading delayed',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click below to view or reload the image',
                                      style: TextStyle(fontSize: 11, color: _textMuted),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => launchUrl(Uri.parse(displayUrl), mode: LaunchMode.externalApplication),
                                      icon: const Icon(Icons.open_in_new, size: 14),
                                      label: const Text('Open Direct Image', style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: _primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Top-right full-screen hint
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if ((alt != null && alt.isNotEmpty) || (title != null && title.isNotEmpty))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: _primaryBlue.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            alt ?? title ?? '',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          tooltip: 'Open in new tab',
                          onPressed: () => launchUrl(Uri.parse(displayUrl), mode: LaunchMode.externalApplication),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: _textMuted,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullscreenImage(String imageUrl, String title) {
    final resolvedUrl = _resolveImageUrl(imageUrl);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        const Icon(Icons.image, size: 18, color: _primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: 'Open in new tab',
                          onPressed: () => launchUrl(Uri.parse(resolvedUrl), mode: LaunchMode.externalApplication),
                          color: _textMuted,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                          color: _textMuted,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: Image.network(
                        resolvedUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 300,
                            child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
                          );
                        },
                        errorBuilder: (c, e, s) => Container(
                          height: 250,
                          alignment: Alignment.center,
                          child: const Text('Could not load full preview'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Embedded Action Card matching Reference UI (Green checkmark, Title, Subtitle, View Report button)
  Widget _buildEmbeddedCard({
    required String title,
    required String subtitle,
    required String action,
    required String url,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: _accentGreen, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: _textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action button
          InkWell(
            onTap: () => _handleLinkTap(url),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 15, color: _primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primaryBlue,
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

  // ─────────────────────────────────────────────────────────
  //  4. Right Panel: Quick Actions, AI Context & Suggestions
  // ─────────────────────────────────────────────────────────

  Widget _buildRightContextPanel(AiChatState chatState, {bool isDrawer = false}) {
    final authState = ref.watch(authProvider);
    final roleState = ref.watch(roleProvider);
    final userFullName = (authState.userData?['full_name'] as String? ?? '').trim();
    final userRoleName = roleState.role != UserRole.unknown ? roleState.role.value.toUpperCase() : 'Admin';
    final greetingTitle = userFullName.isNotEmpty ? 'Hello $userFullName!' : 'Hello $userRoleName!';

    return Container(
      color: _panelBg,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Assistant Greeting Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderCol),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: _primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetingTitle,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "I'm your EduSHAMIIT AI Assistant. I can help you with reports, queries, student information and more.",
                          style: TextStyle(fontSize: 11.5, color: _textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Header
            Text(
              'Quick Actions',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Quick Actions Grid (Dynamic from Role & Activity)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.35,
              children: chatState.quickActions.isNotEmpty
                  ? chatState.quickActions.map((qa) {
                      final label = qa['label'] as String? ?? 'Action';
                      final prompt = qa['prompt'] as String? ?? label;
                      final iconStr = qa['icon'] as String? ?? '';
                      IconData ic = Icons.bolt_rounded;
                      if (iconStr == 'bar_chart') {
                        ic = Icons.bar_chart_rounded;
                      } else if (iconStr == 'person_search') {
                        ic = Icons.person_search_rounded;
                      } else if (iconStr == 'event_available' || iconStr == 'fact_check') {
                        ic = Icons.fact_check_outlined;
                      } else if (iconStr == 'currency_rupee') {
                        ic = Icons.currency_rupee_rounded;
                      } else if (iconStr == 'schedule' || iconStr == 'calendar_month') {
                        ic = Icons.calendar_month_outlined;
                      } else if (iconStr == 'campaign') {
                        ic = Icons.campaign_outlined;
                      } else if (iconStr == 'directions_bus') {
                        ic = Icons.directions_bus_outlined;
                      } else if (iconStr == 'assignment') {
                        ic = Icons.assignment_outlined;
                      } else if (iconStr == 'menu_book') {
                        ic = Icons.menu_book_outlined;
                      } else if (iconStr == 'quiz') {
                        ic = Icons.quiz_outlined;
                      }
                      return _buildQuickActionTile(label, ic, prompt);
                    }).toList()
                  : [
                      _buildQuickActionTile('Generate Report', Icons.bar_chart_rounded, 'Generate a fee and attendance report.'),
                      _buildQuickActionTile('Student Search', Icons.person_search_rounded, 'Search for student information.'),
                      _buildQuickActionTile('Attendance Query', Icons.fact_check_outlined, "Show me today's attendance summary."),
                      _buildQuickActionTile('Fee Report', Icons.currency_rupee_rounded, 'Show me the fee collection report for this month for all classes.'),
                      _buildQuickActionTile('Timetable', Icons.calendar_month_outlined, 'Show me class timetable.'),
                      _buildQuickActionTile('Send Notice', Icons.campaign_outlined, 'Draft a notice for parents.'),
                    ],
            ),
            _buildConnectedModules(chatState.connectedModules),
            const SizedBox(height: 22),

            // Suggested Questions Header
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: _primaryBlue, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Suggested Questions',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showAllSuggestedQuestions(chatState.suggestedQuestions),
                  child: const Text('View All', style: TextStyle(color: _primaryBlue, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Suggested Questions List
            ...chatState.suggestedQuestions.map((q) => _buildSuggestedQuestionItem(q)),

            const SizedBox(height: 22),

            // Helpful Tip Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need something specific?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Just type your question in simple language. I'm here to help!",
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Privacy Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: _textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI uses only the information you are authorized to access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: _textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(String label, IconData icon, String prompt) {
    return InkWell(
      onTap: () {
        _controller.text = prompt;
        _sendTextOrImageOrDocument();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderCol),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestionItem(String question) {
    return InkWell(
      onTap: () {
        _controller.text = question;
        _sendTextOrImageOrDocument();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.radio_button_unchecked_rounded, size: 13, color: _textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  fontSize: 12,
                  color: _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 13, color: _textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedModules(List<Map<String, dynamic>> modules) {
    if (modules.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.hub_outlined, color: _primaryBlue, size: 16),
            const SizedBox(width: 6),
            Text(
              'Connected ERP Modules',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: modules.map((m) {
            final name = (m['name'] ?? 'Module').toString();
            final route = (m['route'] ?? '').toString();
            final iconStr = (m['icon'] ?? '').toString();
            IconData ic = Icons.open_in_new_rounded;
            if (iconStr == 'school') {
              ic = Icons.school_outlined;
            } else if (iconStr == 'fact_check') {
              ic = Icons.fact_check_outlined;
            } else if (iconStr == 'payments') {
              ic = Icons.payments_outlined;
            } else if (iconStr == 'badge') {
              ic = Icons.badge_outlined;
            } else if (iconStr == 'directions_bus') {
              ic = Icons.directions_bus_outlined;
            } else if (iconStr == 'menu_book') {
              ic = Icons.menu_book_outlined;
            } else if (iconStr == 'apartment') {
              ic = Icons.apartment_outlined;
            } else if (iconStr == 'campaign') {
              ic = Icons.campaign_outlined;
            }

            return InkWell(
              onTap: () {
                if (route.isNotEmpty) {
                  context.go(route);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderCol),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic, size: 14, color: _primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAllSuggestedQuestions(List<String> questions) {
    showDialog(
      context: context,
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = questions.where((q) => q.toLowerCase().contains(filter.toLowerCase())).toList();
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _borderCol)),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: _primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'All Suggested Prompts',
                    style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: TextStyle(fontSize: 13, color: _textPrimary),
                      onChanged: (v) => setDialogState(() => filter = v),
                      decoration: InputDecoration(
                        hintText: 'Search suggestions...',
                        hintStyle: TextStyle(fontSize: 12, color: _textMuted),
                        prefixIcon: Icon(Icons.search, size: 16, color: _textMuted),
                        filled: true,
                        fillColor: _inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderCol)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: filtered.isEmpty
                          ? Center(child: Text('No matching suggestions', style: TextStyle(color: _textMuted, fontSize: 12)))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(color: _borderCol, height: 1),
                              itemBuilder: (c, idx) {
                                final q = filtered[idx];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.chat_bubble_outline, size: 16, color: _primaryBlue),
                                  title: Text(q, style: TextStyle(fontSize: 12.5, color: _textPrimary)),
                                  trailing: Icon(Icons.arrow_forward_rounded, size: 14, color: _textMuted),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _controller.text = q;
                                    _sendTextOrImageOrDocument();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Composer Bar & Voice
  // ─────────────────────────────────────────────────────────

  Widget _buildInputBar(AiChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _borderCol)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null) _buildSelectedImagePreview(),
          if (_selectedDocument != null) _buildSelectedDocumentPreview(),
          Row(
            children: [
              // Attachment paperclip
              _AttachButton(
                onImagePicked: (f) => setState(() => _selectedImage = f),
                onDocumentPicked: (d) => setState(() => _selectedDocument = d),
              ),
              const SizedBox(width: 10),

              // Text Field
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: _borderCol),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    style: TextStyle(fontSize: 13.5, color: _textPrimary),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _sendTextOrImageOrDocument(),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about your school...',
                      hintStyle: TextStyle(fontSize: 13, color: _textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Mic button
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded, color: _isListening ? _recordRed : _textMuted),
                onPressed: _isListening ? _stopAndSendVoice : _startVoice,
                tooltip: 'Voice Search',
              ),

              // Stop Generation or Solid Blue Send Button
              if (chatState.isTyping)
                GestureDetector(
                  onTap: () => ref.read(aiChatProvider.notifier).stopGeneration(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.stop_rounded, color: Colors.redAccent, size: 22),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _sendTextOrImageOrDocument,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: _primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Disclaimer
          Text(
            'AI can make mistakes. Verify important information before taking action.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Voice and Message Dispatch
  // ─────────────────────────────────────────────────────────

  Future<void> _startVoice() async {
    if (!_sttAvailable) {
      try {
        _sttAvailable = await _stt.initialize();
      } catch (_) {}
    }

    if (_sttAvailable) {
      setState(() {
        _isListening = true;
        _liveWords = '';
      });
      _micPulseController.repeat(reverse: true);
      _stt.listen(
        onResult: (r) {
          if (mounted) {
            setState(() {
              _liveWords = r.recognizedWords;
              _controller.text = _liveWords;
            });
          }
        },
        localeId: _sttLocale,
      );
    }
  }

  void _stopAndSendVoice() {
    _stt.stop();
    _micPulseController.stop();
    setState(() => _isListening = false);
    if (_controller.text.trim().isNotEmpty) {
      _sendTextOrImageOrDocument();
    }
  }

  void _onSttDone() {
    if (_isListening) _stopAndSendVoice();
  }

  Widget _buildVoiceListeningBar() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _recordRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _recordRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic, color: _recordRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _liveWords.isEmpty ? 'Listening...' : _liveWords,
              style: TextStyle(fontSize: 12, color: _textPrimary),
            ),
          ),
          TextButton(
            onPressed: _stopAndSendVoice,
            child: const Text('Send', style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendTextOrImageOrDocument() {
    if (_isListening) {
      _stopAndSendVoice();
      return;
    }

    final text = _controller.text.trim();
    final img = _selectedImage;
    final doc = _selectedDocument;

    if (text.isEmpty && img == null && doc == null) return;

    _controller.clear();
    setState(() {
      _selectedImage = null;
      _selectedDocument = null;
    });
    _inputFocus.unfocus();

    if (doc != null) {
      ref.read(aiChatProvider.notifier).sendMessageWithDocument(
        text,
        doc,
        imageFile: img,
        launchedFrom: _activeContext,
      );
    } else if (img != null) {
      ref.read(aiChatProvider.notifier).sendMessageWithImage(text, img, launchedFrom: _activeContext);
    } else {
      ref.read(aiChatProvider.notifier).sendMessage(text, launchedFrom: _activeContext);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final chatState = ref.read(aiChatProvider);
      if (chatState.hasMoreHistory && !chatState.isLoadingMore && !chatState.isLoading) {
        ref.read(aiChatProvider.notifier).loadChatHistory(clearExisting: false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  //  UI Helpers & Dialogs
  // ─────────────────────────────────────────────────────────

  Widget _buildBubbleActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: iconColor ?? _textMuted),
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: _primaryBlue,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image, size: 16, color: _primaryBlue),
          const SizedBox(width: 6),
          Text(_selectedImage?.name ?? 'Image', style: TextStyle(fontSize: 11, color: _textPrimary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _selectedImage = null),
            child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDocumentPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description, size: 16, color: _primaryBlue),
          const SizedBox(width: 6),
          Text(_selectedDocument?.name ?? 'Document', style: TextStyle(fontSize: 11, color: _textPrimary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _selectedDocument = null),
            child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: _primaryBlue));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: _primaryBlue),
          const SizedBox(height: 12),
          Text('Welcome to EduSHAMIIT AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Ask any question or pick a quick action to start.', style: TextStyle(fontSize: 12, color: _textMuted)),
        ],
      ),
    );
  }

  String _cleanMathExpressions(String text) {
    return text.replaceAll(RegExp(r'\$\$(.*?)\$\$'), r'$1').replaceAll(RegExp(r'\$(.*?)\$'), r'$1');
  }

  String _cleanSubtitleText(String text) {
    if (text.isEmpty) return text;
    var cleaned = text;
    // Strip markdown links [label](url) -> label
    cleaned = cleaned.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '');
    // Strip bold/italic/code markers
    cleaned = cleaned.replaceAll(RegExp(r'[*_`#]'), '');
    return cleaned.trim();
  }

  String _preprocessMarkdownLinks(String text) {
    var result = text;

    // 1. Convert lines like: "• View Full Pending Fee List in ERP: /admin/student-fees"
    // or "• Finance & Accounting Dashboard: `/admin/finance`"
    final actionLineRegex = RegExp(
      r'^([\s*•\-\d\.]+\s*)([^:\n\[]+?):\s*`?(/admin/[a-zA-Z0-9_\-]+)`?\s*$',
      multiLine: true,
    );
    result = result.replaceAllMapped(actionLineRegex, (m) {
      final prefix = m.group(1) ?? '';
      final label = m.group(2)?.trim() ?? 'Open';
      final route = m.group(3)?.trim() ?? '';
      return '$prefix[$label ↗]($route)';
    });

    // 2. Convert any remaining bare or code-wrapped `/admin/...` that isn't already inside a markdown link
    final bareRouteRegex = RegExp(
      r'(?<!\]\()(?<!\[)`?(/admin/[a-zA-Z0-9_\-]+)`?(?!\))',
    );
    result = result.replaceAllMapped(bareRouteRegex, (m) {
      final route = m.group(1)?.trim() ?? '';
      return '[$route ↗]($route)';
    });

    // 3. Convert any bare download links e.g. /api/chat/download/filename.xlsx
    final bareDownloadRegex = RegExp(
      r'(?<!\]\()(?<!\[)`?(/api/chat/download/([a-zA-Z0-9_\-\.]+))`?(?!\))',
    );
    result = result.replaceAllMapped(bareDownloadRegex, (m) {
      final fullUrl = m.group(1)?.trim() ?? '';
      final filename = m.group(2)?.trim() ?? 'Document';
      return '[📄 Download $filename]($fullUrl)';
    });

    return result;
  }

  String _resolveDownloadUrl(String url) {
    String clean = url.trim();
    if (clean.isEmpty) return clean;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (!clean.startsWith('/')) {
      clean = '/$clean';
    }
    if (!clean.startsWith('/api/')) {
      clean = '/api$clean';
    }
    return '${AppConfig.baseUrl}$clean';
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (kIsWeb) {
        await launchUrl(uri, webOnlyWindowName: '_blank');
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL $url: $e');
    }
  }

  void _handleLinkTap(String? href) {
    if (href == null || href.isEmpty) return;
    final trimmed = href.trim();

    // 1. Download URLs (/api/chat/download/...)
    if (trimmed.contains('/chat/download/')) {
      final downloadUrl = _resolveDownloadUrl(trimmed);
      final filename = trimmed.split('/').last.split('?').first;
      try {
        getDownloadHelper().downloadFile(downloadUrl, filename.isNotEmpty ? filename : 'downloaded_file');
      } catch (_) {
        _launchExternalUrl(downloadUrl);
      }
      return;
    }

    // 2. Media / Image URLs (/api/chat/media/...)
    if (trimmed.contains('/chat/media/')) {
      final mediaUrl = _resolveImageUrl(trimmed);
      _launchExternalUrl(mediaUrl);
      return;
    }

    // 3. External HTTP(S) links
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      _launchExternalUrl(trimmed);
      return;
    }

    // 4. Internal ERP Navigation routes (e.g. /admin/student-fees, /admin/finance)
    String route = trimmed;
    if (route.startsWith('#')) route = route.substring(1);
    if (!route.startsWith('/')) route = '/$route';

    final routeMap = <String, String>{
      '/admin/fee-management': '/admin/student-fees',
      '/admin/fees': '/admin/student-fees',
      '/admin/fee': '/admin/student-fees',
      '/fee-management': '/admin/student-fees',
      '/fees': '/admin/student-fees',
      '/student-fees': '/admin/student-fees',
      '/admin/defaulters': '/admin/student-fees',
      '/defaulters': '/admin/student-fees',
      '/admin/timetable': '/admin/classes',
      '/admin/timetables': '/admin/classes',
      '/timetable': '/admin/classes',
      '/timetables': '/admin/classes',
      '/classes': '/admin/classes',
      '/finance': '/admin/finance',
      '/attendance': '/admin/attendance',
      '/documents': '/admin/documents',
      '/notices': '/admin/notices',
      '/dashboard': '/admin/dashboard',
    };

    final targetRoute = routeMap[route] ?? route;
    try {
      context.go(targetRoute);
    } catch (e) {
      debugPrint('Navigation error for $targetRoute: $e');
      try {
        context.go('/admin/dashboard');
      } catch (_) {}
    }
  }

  String _formatSessionTime(dynamic timeVal) {
    if (timeVal == null) return '';
    try {
      final dt = DateTime.parse(timeVal.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
      final diff = now.difference(dt);
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day} ${_monthName(dt.month)}';
    } catch (_) {
      return '';
    }
  }

  String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  void _exportCurrentConversation() {
    final text = ref.read(aiChatProvider.notifier).exportChat();
    final bytes = utf8.encode(text);
    final sid = ref.read(aiChatProvider).sessionId;
    final shortSid = sid.length >= 8 ? sid.substring(0, 8) : sid;
    getDownloadHelper().downloadBytes(bytes, 'chat_export_$shortSid.txt');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat exported successfully!'), duration: Duration(seconds: 2)),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Clear Chat', style: TextStyle(color: _textPrimary)),
        content: Text('Are you sure you want to clear current chat messages?', style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _textMuted))),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearChat();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSession(String sid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Delete Conversation', style: TextStyle(color: _textPrimary)),
        content: Text('Delete this conversation permanently?', style: TextStyle(color: _textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _textMuted))),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).deleteSession(sid);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(String sid, String currentTitle) {
    final c = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Rename Conversation', style: TextStyle(color: _textPrimary)),
        content: TextField(
          controller: c,
          style: TextStyle(color: _textPrimary),
          decoration: const InputDecoration(hintText: 'Enter new title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _textMuted))),
          TextButton(
            onPressed: () {
              if (c.text.trim().isNotEmpty) {
                ref.read(aiChatProvider.notifier).renameSession(sid, c.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: _primaryBlue)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Attachment Button Helper
// ─────────────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final ValueChanged<XFile> onImagePicked;
  final ValueChanged<PlatformFile> onDocumentPicked;

  const _AttachButton({required this.onImagePicked, required this.onDocumentPicked});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Attach File',
      icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF64748B), size: 20),
      onSelected: (v) async {
        if (v == 'image') {
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery);
          if (file != null) onImagePicked(file);
        } else if (v == 'document') {
          final res = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'docx', 'doc', 'txt'],
          );
          if (res != null && res.files.isNotEmpty) {
            onDocumentPicked(res.files.first);
          }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'document',
          child: Row(children: [
            Icon(Icons.description_outlined, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Document (PDF, Excel, Word)'),
          ]),
        ),
        const PopupMenuItem(
          value: 'image',
          child: Row(children: [
            Icon(Icons.image_outlined, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Photo or Image'),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Keep Alive Wrapper for Smooth Scrolling
// ─────────────────────────────────────────────────────────────

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────
//  Live Scratchpad / Thought Process Component
// ─────────────────────────────────────────────────────────────

class _ScratchpadCard extends StatefulWidget {
  final ChatMessage msg;
  final bool isDark;

  const _ScratchpadCard({
    required this.msg,
    required this.isDark,
  });

  @override
  State<_ScratchpadCard> createState() => _ScratchpadCardState();
}

class _ScratchpadCardState extends State<_ScratchpadCard> with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.msg.isStreaming && widget.msg.text.isEmpty;
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ScratchpadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.msg.isStreaming && widget.msg.text.isEmpty && !_expanded) {
      _expanded = true;
    }
  }

  @override
  void dispose() {
    _pulseAnim.dispose();
    super.dispose();
  }

  IconData _stageIcon(String stage) {
    switch (stage.toLowerCase()) {
      case 'tool_running':
        return Icons.build_circle_outlined;
      case 'tool_done':
        return Icons.check_circle_outline_rounded;
      case 'synthesizing':
        return Icons.auto_awesome_rounded;
      case 'fallback':
        return Icons.info_outline_rounded;
      case 'done':
        return Icons.task_alt_rounded;
      case 'planning':
        return Icons.alt_route_rounded;
      case 'thinking':
      default:
        return Icons.psychology_outlined;
    }
  }

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'tool_running':
        return const Color(0xFFF59E0B);
      case 'tool_done':
      case 'done':
        return const Color(0xFF10B981);
      case 'synthesizing':
        return const Color(0xFF8B5CF6);
      case 'fallback':
        return const Color(0xFF64748B);
      case 'planning':
        return const Color(0xFF06B6D4);
      case 'thinking':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  String _currentStageLabel(List<ScratchpadStep> steps) {
    if (steps.isEmpty) return 'Brainstorming...';
    final last = steps.last;
    switch (last.stage.toLowerCase()) {
      case 'tool_running':
        return 'Executing Tools...';
      case 'tool_done':
        return 'Tools Finished';
      case 'synthesizing':
        return 'Synthesizing Response...';
      case 'done':
        return 'Completed';
      case 'thinking':
      default:
        return 'Brainstorming...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.msg.scratchpadSteps.isNotEmpty
        ? widget.msg.scratchpadSteps
        : [
            ScratchpadStep(
              title: 'Brainstorming & Planning...',
              detail: 'Analyzing inquiry and selecting academic tools',
              stage: 'thinking',
            )
          ];

    final isStreaming = widget.msg.isStreaming;
    final cardBg = widget.isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark
        ? const Color(0xFF2563EB).withValues(alpha: 0.25)
        : const Color(0xFFDBEAFE);
    final textPrimary = widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final textMuted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar (Clickable to toggle expand/collapse)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Animated Brain/Sparkles Icon
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      final double scale = isStreaming ? 1.0 + (_pulseAnim.value * 0.15) : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isStreaming ? Icons.psychology_rounded : Icons.auto_awesome_rounded,
                            size: 15,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Title
                  Text(
                    'Thought Process',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Live Stage Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isStreaming
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isStreaming) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _currentStageLabel(steps),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ] else ...[
                          Text(
                            '${steps.length} steps completed',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Chevron Icon
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: textMuted,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Steps Body
          if (_expanded) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(steps.length, (idx) {
                  final s = steps[idx];
                  final isLast = idx == steps.length - 1;
                  final stageCol = _stageColor(s.stage);
                  final stageIco = _stageIcon(s.stage);

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stage Icon
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(stageIco, size: 14, color: stageCol),
                        ),
                        const SizedBox(width: 8),
                        // Title + Detail
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  height: 1.25,
                                ),
                              ),
                              if (s.detail.isNotEmpty) ...[
                                const SizedBox(height: 1.5),
                                Text(
                                  s.detail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textMuted,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Subtle spinner or dot for the currently active last step
                        if (isStreaming && isLast) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(stageCol),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
