import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/ai_chat_provider.dart';
import 'package:edu_shamiit_ai/core/services/voice_recorder_service.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

// ─────────────────────────────────────────────────────────────
//  Shami AI Chat Screen
// ─────────────────────────────────────────────────────────────

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final VoiceRecorderService _voice = VoiceRecorderService.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final AnimationController _micPulseController;

  bool _showSuggestions = true;
  bool _isRecording = false;
  double _micAmplitude = 0.0;     // 0.0 – 1.0 for live waveform

  // ── Palette ──────────────────────────────────────────────
  static const _darkBg      = Color(0xFF0A0C1B);
  static const _cardBg      = Color(0xFF12152A);
  static const _inputBg     = Color(0xFF1A1E35);
  static const _gradStart   = Color(0xFF5B4FFF);
  static const _gradEnd     = Color(0xFF00D4FF);
  static const _userBubble  = Color(0xFF4A3FD4);
  static const _aiBubble    = Color(0xFF1E2240);
  static const _textPrimary = Color(0xFFF0F2FF);
  static const _textMuted   = Color(0xFF6E7AAB);
  static const _accentGreen = Color(0xFF00E676);
  static const _recordRed   = Color(0xFFFF3B5C);

  static const _botGrad = LinearGradient(
    colors: [_gradStart, _gradEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).loadChatHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _micPulseController.dispose();
    if (_isRecording) _voice.cancelRecording();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    ref.listen<AiChatState>(aiChatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildHistoryDrawer(chatState),
      backgroundColor: _darkBg,
      body: Column(
        children: [
          _buildHeader(chatState),
          Expanded(child: _buildMessageList(chatState)),
          if (_isRecording) _buildVoiceRecordingBar(),
          if (!_isRecording &&
              _showSuggestions &&
              chatState.messages.length <= 2 &&
              chatState.suggestions.isNotEmpty)
            _buildSuggestionChips(chatState.suggestions),
          _buildInputBar(chatState),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Header
  // ─────────────────────────────────────────────────────────

  Widget _buildHeader(AiChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
            color: _gradStart.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          // Bot avatar with animated glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: _botGrad,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gradStart.withValues(
                        alpha: 0.3 + 0.2 * _pulseController.value),
                    blurRadius: 12 + 8 * _pulseController.value,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 20))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shami AI',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? _recordRed
                            : chatState.isTyping
                                ? _gradEnd
                                : _accentGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? _recordRed
                                    : chatState.isTyping
                                        ? _gradEnd
                                        : _accentGreen)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isRecording
                          ? 'Recording...'
                          : chatState.isTyping
                              ? 'Typing...'
                              : 'Always Online',
                      style: const TextStyle(fontSize: 11, color: _textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: _textPrimary, size: 22),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _textMuted),
            color: _cardBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'export') _exportChat();
              if (v == 'clear') _confirmClear();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  const Icon(Icons.download_rounded,
                      size: 18, color: _textMuted),
                  const SizedBox(width: 8),
                  Text('Export Chat'.tr(ref),
                      style: const TextStyle(color: _textPrimary)),
                ]),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text('Clear Chat'.tr(ref),
                      style: const TextStyle(color: Colors.redAccent)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Message List
  // ─────────────────────────────────────────────────────────

  Widget _buildMessageList(AiChatState chatState) {
    final msgs = chatState.messages;
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _buildBubble(msgs[i])
          .animate()
          .fadeIn(duration: 250.ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOut, duration: 250.ms),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Chat Bubble
  // ─────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                  gradient: _botGrad, shape: BoxShape.circle),
              child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 14))),
            ),

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? _userBubble : _aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: isUser
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser ? _gradStart : Colors.black)
                              .withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.imagePath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(msg.imagePath!),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Voice bubble
                        if (msg.type == MessageType.voice && isUser)
                          _VoiceMessageBubble(text: msg.text)
                        // AI markdown with math formatting and selectability
                        else if (!isUser)
                          MarkdownBody(
                            data: msg.text.isEmpty && msg.isStreaming
                                ? '▋'
                                : _cleanMathExpressions(msg.text),
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                  fontSize: 13.5, color: _textPrimary, height: 1.55),
                              code: TextStyle(
                                fontFamily: 'monospace',
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.07),
                                color: _gradEnd,
                                fontSize: 12,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              strong: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700),
                              listBullet:
                                  const TextStyle(color: _gradEnd),
                            ),
                          )
                        // User text with selectability
                        else
                          SelectableText(msg.text,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: _textPrimary,
                                  height: 1.5)),

                        // Streaming dots (empty AI bubble)
                        if (msg.isStreaming && msg.text.isEmpty)
                          _buildTypingDots(),

                        const SizedBox(height: 4),
                        Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(msg.formattedTime,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _textMuted.withValues(alpha: 0.7))),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Copy action button row for AI messages (below the bubble)
                if (!isUser && !msg.isStreaming && msg.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBubbleActionButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Copy Response',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _cleanMathExpressions(msg.text)));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Response copied to clipboard!'),
                                backgroundColor: _aiBubble,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (isUser)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                color: _userBubble,
                shape: BoxShape.circle,
                border:
                    Border.all(color: _gradStart.withValues(alpha: 0.5), width: 2),
              ),
              child: const Center(
                  child: Text('😊', style: TextStyle(fontSize: 14))),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Typing Dots
  // ─────────────────────────────────────────────────────────

  Widget _buildTypingDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) {
              final phase =
                  (_waveController.value - i * 0.15).clamp(0.0, 1.0);
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  gradient: _botGrad,
                  shape: BoxShape.circle,
                ),
                transform: Matrix4.translationValues(
                    0, -sin(phase * pi) * 5, 0),
              );
            },
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Voice Recording Bar (shown while recording)
  // ─────────────────────────────────────────────────────────

  Widget _buildVoiceRecordingBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _recordRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _recordRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Pulsing red dot
          AnimatedBuilder(
            animation: _micPulseController,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recordRed,
                boxShadow: [
                  BoxShadow(
                    color: _recordRed.withValues(
                        alpha: 0.4 + 0.4 * _micPulseController.value),
                    blurRadius: 8 + 6 * _micPulseController.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Live waveform bars
          Expanded(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(20, (i) {
                  final phase = _waveController.value + i * 0.15;
                  final base = _micAmplitude * 28;
                  final h = (sin(phase * pi * 2) * base * 0.5 + base * 0.5)
                      .clamp(3.0, 30.0);
                  return Container(
                    width: 3,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Color.lerp(_recordRed, _gradEnd,
                          (i / 20) * _micAmplitude),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Cancel button
          GestureDetector(
            onTap: _cancelVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0);
  }

  // ─────────────────────────────────────────────────────────
  //  Suggestion Chips
  // ─────────────────────────────────────────────────────────

  Widget _buildSuggestionChips(List<String> suggestions) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = suggestions[i];
          return GestureDetector(
            onTap: () {
              setState(() => _showSuggestions = false);
              ref.read(aiChatProvider.notifier).useSuggestion(s);
              _scrollToBottom();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    _gradStart.withValues(alpha: 0.2),
                    _gradEnd.withValues(alpha: 0.2)
                  ],
                ),
                border:
                    Border.all(color: _gradStart.withValues(alpha: 0.4)),
              ),
              child: Text(s,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
            ),
          ).animate().fadeIn(delay: (i * 80).ms, duration: 300.ms);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Input Bar
  // ─────────────────────────────────────────────────────────

  Widget _buildInputBar(AiChatState chatState) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          _AttachButton(
            onImagePicked: (file) {
              setState(() => _showSuggestions = false);
              ref.read(aiChatProvider.notifier).sendImage(file);
              _scrollToBottom();
            },
          ),
          const SizedBox(width: 8),

          // Text Field — listens to changes to toggle send/mic
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _inputFocus,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: 'Ask Shami anything...',
                  hintStyle: TextStyle(
                      fontSize: 14,
                      color: _textMuted.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right action button: Send (if text) | Mic (if empty, not recording)
          // | Stop (if recording)
          _buildActionButton(chatState, hasText),
        ],
      ),
    );
  }

  Widget _buildActionButton(AiChatState chatState, bool hasText) {
    // While AI is responding — show spinner
    if (chatState.isTyping && !_isRecording) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _inputBg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: const CircularProgressIndicator(
            strokeWidth: 2, color: _textMuted),
      );
    }

    // While recording — show STOP button (red)
    if (_isRecording) {
      return GestureDetector(
        onTap: _stopAndSendVoice,
        child: AnimatedBuilder(
          animation: _micPulseController,
          builder: (_, __) => Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _recordRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _recordRed.withValues(
                      alpha: 0.35 + 0.35 * _micPulseController.value),
                  blurRadius: 14 + 8 * _micPulseController.value,
                ),
              ],
            ),
            child: const Icon(Icons.stop_rounded,
                color: Colors.white, size: 24),
          ),
        ),
      );
    }

    // Has text — SEND button
    if (hasText) {
      return GestureDetector(
        onTap: _sendText,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: _botGrad,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _gradStart.withValues(alpha: 0.4), blurRadius: 10),
            ],
          ),
          child: const Icon(Icons.send_rounded,
              color: Colors.white, size: 20),
        ),
      );
    }

    // Empty text + not recording — MIC button
    return GestureDetector(
      onTap: _startVoice,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: _botGrad,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: _gradStart.withValues(alpha: 0.35), blurRadius: 10),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  Voice Actions
  // ─────────────────────────────────────────────────────────

  Future<void> _startVoice() async {
    final started = await _voice.startRecording();
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            '🎤 Microphone access denied. Please allow it in Settings.'),
        backgroundColor: _recordRed,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() {
      _isRecording = true;
      _showSuggestions = false;
    });
    _micPulseController.repeat(reverse: true);

    // Drive amplitude updates from the service stream
    _voice.amplitudeStream.listen((amp) {
      if (mounted && _isRecording) {
        setState(() => _micAmplitude = amp);
      }
    });
  }

  Future<void> _stopAndSendVoice() async {
    _micPulseController.stop();
    final file = await _voice.stopRecording();

    setState(() {
      _isRecording = false;
      _micAmplitude = 0.0;
    });

    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⚠️ Recording failed. Please try again.'),
        backgroundColor: _aiBubble,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    ref.read(aiChatProvider.notifier).sendVoice(file);
    _scrollToBottom();
  }

  Future<void> _cancelVoice() async {
    _micPulseController.stop();
    await _voice.cancelRecording();
    setState(() {
      _isRecording = false;
      _micAmplitude = 0.0;
    });
  }

  // ─────────────────────────────────────────────────────────
  //  Text Actions
  // ─────────────────────────────────────────────────────────

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _inputFocus.unfocus();
    setState(() => _showSuggestions = false);
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom({bool instant = false}) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: instant
              ? const Duration(milliseconds: 100)
              : const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _exportChat() {
    final text = ref.read(aiChatProvider.notifier).exportChat();
    Clipboard.setData(ClipboardData(text: _cleanMathExpressions(text)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Chat copied to clipboard!'),
      backgroundColor: _aiBubble,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _toSuperscript(String input) {
    const map = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾', 'n': 'ⁿ', 'x': 'ˣ', 'i': 'ⁱ', 'r': 'ʳ', 't': 'ᵗ'
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  String _toSubscript(String input) {
    const map = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎', 'n': 'ₙ', 'x': 'ₓ', 'i': 'ᵢ', 'r': 'ᵣ', 't': 'ₜ',
      'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'j': 'ⱼ', 'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'p': 'ₚ', 's': 'ₛ', 'u': 'ᵤ', 'v': 'ᵥ'
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  String _cleanMathExpressions(String text) {
    var result = text;
    // 1. Remove LaTeX layout directives
    result = result.replaceAll(r'\displaystyle', '');
    result = result.replaceAll(r'\limits', '');
    result = result.replaceAll(r'\,', ' ').replaceAll(r'\;', ' ').replaceAll(r'\!', '');
    result = result.replaceAll(r'\quad', '  ').replaceAll(r'\qquad', '    ');
    result = result.replaceAll(r'\left(', '(').replaceAll(r'\right)', ')');
    result = result.replaceAll(r'\left[', '[').replaceAll(r'\right]', ']');
    result = result.replaceAll(r'\left\{', '{').replaceAll(r'\right\}', '}');
    
    // 2. Replaces basic symbols/functions
    result = result.replaceAll(r'\int', '∫');
    result = result.replaceAll(r'\ln', 'ln');
    result = result.replaceAll(r'\log', 'log');
    result = result.replaceAll(r'\sin', 'sin');
    result = result.replaceAll(r'\cos', 'cos');
    result = result.replaceAll(r'\tan', 'tan');
    result = result.replaceAll(r'\partial', '∂');
    result = result.replaceAll(r'\rightarrow', '→');
    result = result.replaceAll(r'\to', '→');
    result = result.replaceAll(r'\Rightarrow', '⇒');
    result = result.replaceAll(r'\pi', 'π');
    result = result.replaceAll(r'\infty', '∞');
    result = result.replaceAll(r'\sqrt', '√');
    result = result.replaceAll(r'\pm', '±');
    result = result.replaceAll(r'\geq', '≥');
    result = result.replaceAll(r'\leq', '≤');
    result = result.replaceAll(r'\neq', '≠');
    result = result.replaceAll(r'\approx', '≈');
    result = result.replaceAll(r'\times', '×');
    result = result.replaceAll(r'\cdot', '·');
    result = result.replaceAll(r'\sum', '∑');
    result = result.replaceAll(r'\prod', '∏');
    result = result.replaceAll(r'\le', '≤');
    result = result.replaceAll(r'\ge', '≥');
    result = result.replaceAll(r'\ne', '≠');
    result = result.replaceAll(r'\theta', 'θ');
    result = result.replaceAll(r'\alpha', 'α');
    result = result.replaceAll(r'\beta', 'β');
    result = result.replaceAll(r'\gamma', 'γ');
    result = result.replaceAll(r'\delta', 'δ');
    result = result.replaceAll(r'\Delta', 'Δ');
    result = result.replaceAll(r'\lambda', 'λ');
    result = result.replaceAll(r'\sigma', 'σ');
    result = result.replaceAll(r'\omega', 'ω');
    result = result.replaceAll(r'\phi', 'φ');
    result = result.replaceAll(r'\psi', 'ψ');
    result = result.replaceAll(r'\mu', 'μ');
    result = result.replaceAll(r'\nu', 'ν');
    result = result.replaceAll(r'\tau', 'τ');
    result = result.replaceAll(r'\epsilon', 'ε');
    result = result.replaceAll(r'\eta', 'η');
    result = result.replaceAll(r'\rho', 'ρ');

    // 3. Format fractions: \frac{num}{den} -> num/den
    final fracRegex = RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}');
    while (fracRegex.hasMatch(result)) {
      result = result.replaceAllMapped(fracRegex, (match) {
        final num = match.group(1)!;
        final den = match.group(2)!;
        final displayNum = num.length > 1 && (num.contains('+') || num.contains('-') || num.contains('x')) ? '($num)' : num;
        final displayDen = den.length > 1 && (den.contains('+') || den.contains('-') || den.contains('x')) ? '($den)' : den;
        return '$displayNum/$displayDen';
      });
    }

    // 4. Format superscripts: ^{2} or ^2
    final superRegex = RegExp(r'\^\{([^{}]+)\}');
    while (superRegex.hasMatch(result)) {
      result = result.replaceAllMapped(superRegex, (match) {
        return _toSuperscript(match.group(1)!);
      });
    }
    final superSingleRegex = RegExp(r'\^([0-9a-zA-Z\+\-\(\)])');
    result = result.replaceAllMapped(superSingleRegex, (match) {
      return _toSuperscript(match.group(1)!);
    });

    // 5. Format subscripts: _{i} or _i
    final subRegex = RegExp(r'_\{([^{}]+)\}');
    while (subRegex.hasMatch(result)) {
      result = result.replaceAllMapped(subRegex, (match) {
        return _toSubscript(match.group(1)!);
      });
    }
    final subSingleRegex = RegExp(r'_([0-9a-zA-Z\+\-\(\)])');
    result = result.replaceAllMapped(subSingleRegex, (match) {
      return _toSubscript(match.group(1)!);
    });

    // 6. Remove remaining LaTeX inline math delimiters and replace display math delimiters with newlines
    result = result.replaceAll(r'\(', '').replaceAll(r'\)', '');
    result = result.replaceAll(r'\[', '\n').replaceAll(r'\]', '\n');

    return result;
  }

  Widget _buildBubbleActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip.tr(ref),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: _textMuted),
              const SizedBox(width: 4),
              Text(
                'Copy'.tr(ref),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat',
            style: TextStyle(color: _textPrimary)),
        content: Text(
          'Are you sure you want to clear all chat history?'.tr(ref),
          style: const TextStyle(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearChat();
              setState(() => _showSuggestions = true);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  String _formatSessionTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      } else {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return '';
    }
  }

  void _confirmDeleteSession(String sessionId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _cardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Chat',
            style: TextStyle(color: _textPrimary)),
        content: Text(
          'Are you sure you want to delete this chat session?'.tr(ref),
          style: const TextStyle(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(aiChatProvider.notifier).deleteSession(sessionId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer(AiChatState chatState) {
    return Drawer(
      backgroundColor: _darkBg,
      child: Builder(
        builder: (drawerCtx) {
          return SafeArea(
            child: Column(
              children: [
                // Drawer Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: _gradEnd, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Chat History',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _textMuted),
                        onPressed: () => Navigator.pop(drawerCtx),
                      ),
                    ],
                  ),
                ),
                
                // New Chat Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(aiChatProvider.notifier).startNewChat();
                      Navigator.pop(drawerCtx); // close drawer
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: _botGrad,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _gradStart.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'New Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 20),
                
                // Sessions List
                Expanded(
                  child: chatState.sessions.isEmpty
                      ? const Center(
                          child: Text(
                            'No recent chats',
                            style: TextStyle(color: _textMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          itemCount: chatState.sessions.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (itemCtx, idx) {
                            final s = chatState.sessions[idx];
                            final sid = s['session_id'] as String? ?? '';
                            final title = s['title'] as String? ?? 'New Chat';
                            final lastTime = s['last_message_at'] as String?;
                            final isSelected = sid == chatState.sessionId;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? _cardBg : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? _gradStart.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  leading: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: isSelected ? _gradEnd : _textMuted,
                                    size: 18,
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? _textPrimary : _textPrimary.withValues(alpha: 0.7),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: lastTime != null && lastTime.isNotEmpty
                                      ? Text(
                                          _formatSessionTime(lastTime),
                                          style: TextStyle(
                                            color: _textMuted.withValues(alpha: 0.5),
                                            fontSize: 10,
                                          ),
                                        )
                                      : null,
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => _confirmDeleteSession(sid),
                                  ),
                                  onTap: () {
                                    ref.read(aiChatProvider.notifier).selectSession(sid);
                                    Navigator.pop(drawerCtx); // close drawer
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Voice Message Bubble (user side)
// ─────────────────────────────────────────────────────────────

class _VoiceMessageBubble extends StatelessWidget {
  final String text;
  const _VoiceMessageBubble({required this.text});

  static const _gradEnd = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _gradEnd.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic_rounded, color: _gradEnd, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.isEmpty ? '🎤 Voice message' : text,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFF0F2FF),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Attachment Button
// ─────────────────────────────────────────────────────────────

class _AttachButton extends StatelessWidget {
  final void Function(File) onImagePicked;
  const _AttachButton({required this.onImagePicked});

  static const _inputBg   = Color(0xFF1A1E35);
  static const _textMuted = Color(0xFF6E7AAB);
  static const _cardBg    = Color(0xFF12152A);
  static const _textPrimary = Color(0xFFF0F2FF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAttachMenu(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _inputBg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.add_rounded, color: _textMuted, size: 22),
      ),
    );
  }

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Attach',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF5B4FFF), Color(0xFF00D4FF)]),
                  onTap: () async {
                    Navigator.pop(context);
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery, imageQuality: 80);
                    if (f != null) onImagePicked(File(f.path));
                  },
                ),
                _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00BCD4)]),
                  onTap: () async {
                    Navigator.pop(context);
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.camera, imageQuality: 80);
                    if (f != null) onImagePicked(File(f.path));
                  },
                ),
                _AttachOption(
                  icon: Icons.description_rounded,
                  label: 'Document',
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF9800)]),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Document upload coming soon!'),
                      backgroundColor: const Color(0xFF1E2240),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _AttachOption(
      {required this.icon,
      required this.label,
      required this.gradient,
      required this.onTap});

  static const _textMuted = Color(0xFF6E7AAB);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: _textMuted)),
        ],
      ),
    );
  }
}