import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/ai_chat_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/core/services/voice_recorder_service.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Real-time speech-to-text (Google mic style)
  final SpeechToText _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isRecordingFallback = false; // fallback when STT is not available
  String _liveWords = '';       // words recognised so far in current session
  String _sttLocale = 'en_US'; // default listening language

  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final AnimationController _micPulseController;

  bool _showSuggestions = true;
  XFile? _selectedImage;

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
          debugPrint('STT status: $s');
          // Auto-stop when device finishes listening
          if ((s == 'done' || s == 'notListening') && mounted && _isListening) {
            _onSttDone();
          }
        },
      );
      if (_sttAvailable) {
        final systemLoc = await _stt.systemLocale();
        if (systemLoc != null) {
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
    _controller.dispose();
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
          if (_isListening) _buildVoiceListeningBar(),
          if (!_isListening &&
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
                        color: _isListening
                            ? _recordRed
                            : chatState.isTyping
                                ? _gradEnd
                                : _accentGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
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
                      _isListening
                          ? 'Listening...'
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
                            child: kIsWeb
                                ? Image.network(msg.imagePath!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover)
                                : Image.file(File(msg.imagePath!),
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
                                  fontSize: 13.8, color: _textPrimary, height: 1.6),
                              code: TextStyle(
                                fontFamily: 'monospace',
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.07),
                                color: _gradEnd,
                                fontSize: 12.5,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              codeblockPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              strong: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700),
                              listBullet:
                                  const TextStyle(color: _gradEnd, fontSize: 13.8),
                              h1: const TextStyle(fontSize: 18, color: _textPrimary, fontWeight: FontWeight.bold, height: 1.5),
                              h2: const TextStyle(fontSize: 16, color: _textPrimary, fontWeight: FontWeight.bold, height: 1.5),
                              h3: const TextStyle(fontSize: 14.5, color: _textPrimary, fontWeight: FontWeight.bold, height: 1.5),
                              blockquote: const TextStyle(color: _textMuted, fontStyle: FontStyle.italic),
                              blockquoteDecoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                border: const Border(left: BorderSide(color: _gradEnd, width: 4)),
                              ),
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

  /// Live listening bar — shows real-time transcript as you speak
  Widget _buildVoiceListeningBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _recordRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _recordRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          // Pulsing red mic icon
          AnimatedBuilder(
            animation: _micPulseController,
            builder: (_, __) => Icon(
              Icons.mic_rounded,
              color: _recordRed.withValues(
                  alpha: 0.5 + 0.5 * _micPulseController.value),
              size: 20 + 4 * _micPulseController.value,
            ),
          ),
          const SizedBox(width: 10),

          // Live transcript text
          Expanded(
            child: Text(
              _isRecordingFallback
                  ? 'Recording audio... speak now'
                  : _liveWords.isEmpty
                      ? 'Listening... speak now'
                      : _liveWords,
              style: TextStyle(
                fontSize: 13.5,
                color: (_isRecordingFallback || _liveWords.isEmpty)
                    ? _textMuted
                    : _textPrimary,
                fontStyle: (_isRecordingFallback || _liveWords.isEmpty)
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),

          // Language selector pill (floating switcher)
          if (!_isRecordingFallback) ...[
            GestureDetector(
              onTap: () {
                final nextLocale = _sttLocale.startsWith('hi') ? 'en_US' : 'hi_IN';
                setState(() {
                  _sttLocale = nextLocale;
                  _liveWords = '';
                  _controller.clear();
                });
                _stt.stop().then((_) {
                  if (_isListening) {
                    _stt.listen(
                      onResult: (result) {
                        if (!mounted) return;
                        if (!_isListening) return;
                        setState(() {
                          _liveWords = result.recognizedWords;
                          _controller.text = _liveWords;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: _liveWords.length),
                          );
                        });
                        if (result.finalResult && _liveWords.trim().isNotEmpty) {
                          _stopAndSendVoice();
                        }
                      },
                      listenFor: const Duration(seconds: 30),
                      pauseFor: const Duration(seconds: 3),
                      localeId: _sttLocale,
                      listenOptions: SpeechListenOptions(
                        cancelOnError: true,
                        partialResults: true,
                      ),
                    );
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: _botGrad,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _gradStart.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sttLocale.startsWith('hi') ? '🇮🇳 HI' : '🇬🇧 EN',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],

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

  Widget _buildSelectedImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: kIsWeb
                  ? Image.network(
                      _selectedImage!.path,
                      height: 76,
                      width: 76,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_selectedImage!.path),
                      height: 76,
                      width: 76,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedImage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: _recordRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0);
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImage != null) _buildSelectedImagePreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              _AttachButton(
                onImagePicked: (file) {
                  setState(() {
                    _selectedImage = file;
                    _showSuggestions = false;
                  });
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
                    onSubmitted: (_) => _sendTextOrImage(),
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

              // Right action button: Send (if text or image) | Mic (if empty, not recording)
              // | Stop (if recording)
              _buildActionButton(chatState, hasText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(AiChatState chatState, bool hasText) {
    // While AI is responding — show spinner
    if (chatState.isTyping && !_isListening) {
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

    // While listening — show SEND button (green/red, send what was heard so far)
    if (_isListening) {
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
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      );
    }

    // Has text OR attached image — SEND button
    if (hasText || _selectedImage != null) {
      return GestureDetector(
        onTap: _sendTextOrImage,
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
  //  Real-time Voice Actions (Google-mic style)
  // ─────────────────────────────────────────────────────────

  Future<void> _startVoice() async {
    debugPrint('[_startVoice] mic tapped');
    
    // Try to initialize STT if not available yet
    if (!_sttAvailable) {
      try {
        debugPrint('[_startVoice] STT not available, trying to initialize...');
        _sttAvailable = await _stt.initialize(
          onError: (e) {
            debugPrint('STT error: $e');
            if (mounted) setState(() { _isListening = false; });
          },
          onStatus: (s) {
            debugPrint('STT status: $s');
            if ((s == 'done' || s == 'notListening') && mounted && _isListening) {
              _onSttDone();
            }
          },
        );
        debugPrint('[_startVoice] STT initialization result: $_sttAvailable');
      } catch (e) {
        debugPrint('STT initialize exception in _startVoice: $e');
        _sttAvailable = false;
      }
    }

    if (!_sttAvailable) {
      // Fallback to standard voice recording
      debugPrint('[_startVoice] STT not available. Falling back to standard voice recording...');
      final voice = VoiceRecorderService.instance;
      
      setState(() {
        _isListening = true;
        _isRecordingFallback = true;
        _liveWords = '';
        _showSuggestions = false;
      });
      _micPulseController.repeat(reverse: true);

      final success = await voice.startRecording();
      if (!success) {
        debugPrint('[_startVoice] Failed to start standard recording.');
        if (mounted) {
          setState(() {
            _isListening = false;
            _isRecordingFallback = false;
          });
          _micPulseController.stop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                'Microphone permission denied or recording failed.'),
            backgroundColor: _recordRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
      return;
    }

    // SpeechToText path
    setState(() {
      _isListening = true;
      _isRecordingFallback = false;
      _liveWords = '';
      _showSuggestions = false;
    });
    _micPulseController.repeat(reverse: true);

    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted) return;
          if (!_isListening) return;
          setState(() {
            _liveWords = result.recognizedWords;
            _controller.text = _liveWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _liveWords.length),
            );
          });
          if (result.finalResult && _liveWords.trim().isNotEmpty) {
            _stopAndSendVoice();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: _sttLocale,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('STT listen exception: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        _micPulseController.stop();
      }
    }
  }

  /// Called when user taps Send during listening, OR when STT auto-finishes.
  Future<void> _stopAndSendVoice() async {
    if (!_isListening) return;

    if (_isRecordingFallback) {
      final voice = VoiceRecorderService.instance;
      _micPulseController.stop();
      setState(() {
        _isListening = false;
        _isRecordingFallback = false;
        _liveWords = '';
        _controller.clear();
      });

      final file = await voice.stopRecording();
      if (file != null) {
        setState(() => _showSuggestions = false);
        ref.read(aiChatProvider.notifier).sendVoice(file, locale: _sttLocale);
        _scrollToBottom();
      }
      return;
    }

    // SpeechToText path
    final text = _liveWords.trim();
    setState(() {
      _isListening = false;
      _liveWords = '';
      _controller.clear();
    });
    _micPulseController.stop();
    try {
      _stt.stop();
    } catch (_) {}

    if (text.isEmpty) return;

    // Send as normal text message — no upload needed!
    setState(() => _showSuggestions = false);
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  /// Called when STT auto-finishes (status done/notListening)
  void _onSttDone() {
    if (!_isListening) return;
    _stopAndSendVoice();
  }

  Future<void> _cancelVoice() async {
    if (_isRecordingFallback) {
      final voice = VoiceRecorderService.instance;
      await voice.cancelRecording();
      _micPulseController.stop();
      setState(() {
        _isListening = false;
        _isRecordingFallback = false;
        _liveWords = '';
        _controller.clear();
      });
      return;
    }

    setState(() {
      _isListening = false;
      _liveWords = '';
      _controller.clear();
    });
    _micPulseController.stop();
    try {
      _stt.stop();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────
  //  Text Actions
  // ─────────────────────────────────────────────────────────

  void _sendTextOrImage() {
    // If listening/recording, stop it first!
    if (_isListening) {
      _stopAndSendVoice();
      return;
    }

    final text = _controller.text.trim();
    final image = _selectedImage;
    if (text.isEmpty && image == null) return;

    _controller.clear();
    setState(() {
      _selectedImage = null;
      _showSuggestions = false;
    });
    _inputFocus.unfocus();

    if (image != null) {
      ref.read(aiChatProvider.notifier).sendMessageWithImage(text, image);
    } else {
      ref.read(aiChatProvider.notifier).sendMessage(text);
    }
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

  String _formatChemicalFormulas(String text) {
    // Match element symbol (1 capital + optional 1 lowercase) followed by 1 or more digits
    // e.g. H2, O2, CO2, H2SO4, C6H12O6
    final regex = RegExp(r'\b([A-Z][a-z]?)(\d+)\b|([A-Z][a-z]?)(\d+)(?=[A-Z\d])|([A-Z][a-z]?)(\d+)');
    return text.replaceAllMapped(regex, (match) {
      final element = match.group(1) ?? match.group(3) ?? match.group(5) ?? '';
      final digits = match.group(2) ?? match.group(4) ?? match.group(6) ?? '';
      if (element.isEmpty || digits.isEmpty) return match.group(0)!;
      
      const commonChem = {
        'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne', 
        'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca', 
        'Fe', 'Cu', 'Zn', 'Ag', 'Au', 'Pt', 'Hg', 'Pb', 'Sn', 'I', 'Br', 'Co', 'Ni', 'Mn', 'Cr'
      };
      if (!commonChem.contains(element)) {
        return match.group(0)!;
      }
      
      return '$element${_toSubscript(digits)}';
    });
  }

  String _cleanSingleMathBlock(String math) {
    var result = math;
    
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
    result = result.replaceAll(r'\times', ' × ');
    result = result.replaceAll(r'\cdot', ' · ');
    result = result.replaceAll(r'\div', ' ÷ ');
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

    // 3. Extract text from \text{...}
    final textRegex = RegExp(r'\\text\{([^{}]+)\}');
    while (textRegex.hasMatch(result)) {
      result = result.replaceAllMapped(textRegex, (match) => match.group(1)!);
    }

    // 4. Format fractions: \frac{num}{den} -> num/den
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

    // 5. Format superscripts: ^{2} or ^2
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

    // 6. Format subscripts: _{i} or _i
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
    
    // 7. General cleanup of double spaces or backslashes
    result = result.replaceAll(r'\\', '\n');

    return result;
  }

  String _cleanMathExpressions(String text) {
    var result = text;

    // A. Format chemical equations globally across the entire text
    result = _formatChemicalFormulas(result);

    // B. Clean double dollar display math blocks: $$...$$
    final displayMathRegex = RegExp(r'\$\$([^\$]+)\$\$');
    while (displayMathRegex.hasMatch(result)) {
      result = result.replaceAllMapped(displayMathRegex, (match) {
        final math = match.group(1)!;
        return '\n${_cleanSingleMathBlock(math)}\n';
      });
    }

    // C. Clean single dollar inline math blocks: $...$
    final inlineMathRegex = RegExp(r'\$([^\$\n]+)\$');
    while (inlineMathRegex.hasMatch(result)) {
      result = result.replaceAllMapped(inlineMathRegex, (match) {
        final math = match.group(1)!;
        return _cleanSingleMathBlock(math);
      });
    }

    // D. Clean \( ... \) LaTeX inline blocks
    final parenMathRegex = RegExp(r'\\\(([^\\]+)\\\)');
    while (parenMathRegex.hasMatch(result)) {
      result = result.replaceAllMapped(parenMathRegex, (match) {
        final math = match.group(1)!;
        return _cleanSingleMathBlock(math);
      });
    }

    // E. Clean \[ ... \] LaTeX display blocks
    final bracketMathRegex = RegExp(r'\\\[([^\\\]]+)\\\]');
    while (bracketMathRegex.hasMatch(result)) {
      result = result.replaceAllMapped(bracketMathRegex, (match) {
        final math = match.group(1)!;
        return '\n${_cleanSingleMathBlock(math)}\n';
      });
    }

    // F. Final failsafe strip of general math wrappers if any remain unclosed
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
  final void Function(XFile) onImagePicked;
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
                    if (f != null) onImagePicked(f);
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
                    if (f != null) onImagePicked(f);
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