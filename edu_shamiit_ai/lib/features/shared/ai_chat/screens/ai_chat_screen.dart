import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile, FilePicker, FileType;
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/ai_chat_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/core/services/voice_recorder_service.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';
import 'package:edu_shamiit_ai/core/providers/documents_provider.dart';
import 'package:edu_shamiit_ai/core/services/tts_service.dart';

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
  PlatformFile? _selectedDocument;
  String? _currentlySpeakingMsgId;

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

    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).loadChatHistory(clearExisting: true);
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
    TtsService.instance.stop();
    _scrollController.removeListener(_scrollListener);
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
      padding: EdgeInsets.fromLTRB(8, Responsive.headerTopPadding(context), 8, 12),
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
    if (chatState.isLoading) {
      return _buildLoadingState();
    }

    final msgs = chatState.messages;
    final showLoading = chatState.isLoadingMore;

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Native reverse list - pins scroll to bottom and reverses indices
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: msgs.length + (showLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (showLoading && i == msgs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_gradStart),
                ),
              ),
            ),
          );
        }

        final msgIndex = msgs.length - 1 - i;
        final msg = msgs[msgIndex];

        // Animate only the newly added complete/static bubble at index 0 (bottom).
        // Skip streaming SSE chunks to avoid laggy animation loops.
        if (i == 0 && !msg.isStreaming) {
          return KeepAliveWrapper(
            key: ValueKey(msg.id),
            child: _buildBubble(msg)
                .animate()
                .fadeIn(duration: 200.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut, duration: 200.ms),
          );
        }

        return KeepAliveWrapper(
          key: ValueKey(msg.id),
          child: _buildBubble(msg),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: _botGrad,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gradStart.withValues(
                        alpha: 0.25 + 0.2 * _pulseController.value),
                    blurRadius: 20 + 10 * _pulseController.value,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 32)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_gradEnd),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Syncing with Shami AI…',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Retrieving your conversation history',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              color: _textMuted.withValues(alpha: 0.8),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
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
                          _buildAiResponseContent(msg.text, msg.isStreaming)
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
                        // Copy Button
                        _buildBubbleActionButton(
                          icon: Icons.copy_rounded,
                          tooltip: 'Copy Response',
                          label: 'Copy',
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
                        const SizedBox(width: 6),
                        // Speak/Stop Button (TTS)
                        _buildBubbleActionButton(
                          icon: _currentlySpeakingMsgId == msg.id
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          tooltip: _currentlySpeakingMsgId == msg.id
                              ? 'Stop Speaking'
                              : 'Speak Out Loud',
                          label: _currentlySpeakingMsgId == msg.id ? 'Stop' : 'Speak',
                          iconColor: _currentlySpeakingMsgId == msg.id
                              ? const Color(0xFFFF3B5C)
                              : _textMuted,
                          textColor: _currentlySpeakingMsgId == msg.id
                              ? const Color(0xFFFF3B5C)
                              : _textMuted,
                          bgColor: _currentlySpeakingMsgId == msg.id
                              ? const Color(0xFFFF3B5C).withValues(alpha: 0.08)
                              : null,
                          onTap: () {
                            if (_currentlySpeakingMsgId == msg.id) {
                              TtsService.instance.stop();
                              setState(() {
                                _currentlySpeakingMsgId = null;
                              });
                            } else {
                              final cleanText = _cleanMathExpressions(msg.text);
                              setState(() {
                                _currentlySpeakingMsgId = msg.id;
                              });
                              TtsService.instance.speak(cleanText, onComplete: () {
                                if (mounted) {
                                  setState(() {
                                    _currentlySpeakingMsgId = null;
                                  });
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        // Regenerate Button
                        _buildBubbleActionButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Regenerate Response',
                          label: 'Regenerate',
                          onTap: () {
                            // Stop speaking if currently speaking this message
                            if (_currentlySpeakingMsgId == msg.id) {
                              TtsService.instance.stop();
                              setState(() {
                                _currentlySpeakingMsgId = null;
                              });
                            }
                            ref.read(aiChatProvider.notifier).regenerateMessage(msg);
                          },
                        ),
                        const SizedBox(width: 6),
                        // Save Button
                        _buildSaveToDocsButton(msg),
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
                        if (!_isListening) {
                          _controller.clear();
                          return;
                        }
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

  Widget _buildSelectedDocumentPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_rounded, color: _gradEnd, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                _selectedDocument!.name,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${(_selectedDocument!.size / 1024).toStringAsFixed(1)} KB)',
            style: const TextStyle(color: _textMuted, fontSize: 11),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDocument = null;
              });
            },
            child: const Icon(
              Icons.close_rounded,
              color: Colors.redAccent,
              size: 16,
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
          if (_selectedDocument != null) _buildSelectedDocumentPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              _AttachButton(
                onImagePicked: (file) {
                  setState(() {
                    _selectedImage = file;
                    _selectedDocument = null;
                    _showSuggestions = false;
                  });
                  _scrollToBottom();
                },
                onDocumentPicked: (file) {
                  setState(() {
                    _selectedDocument = file;
                    _selectedImage = null;
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
                    onSubmitted: (_) => _sendTextOrImageOrDocument(),
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

              // Right action button: Send (if text or image or doc) | Mic (if empty, not recording)
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

    // Has text OR attached image OR attached document — SEND button
    if (hasText || _selectedImage != null || _selectedDocument != null) {
      return GestureDetector(
        onTap: _sendTextOrImageOrDocument,
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
          if (!_isListening) {
            _controller.clear();
            return;
          }
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

  void _sendTextOrImageOrDocument() {
    // If listening/recording, stop it first!
    if (_isListening) {
      _stopAndSendVoice();
      return;
    }

    final text = _controller.text.trim();
    final image = _selectedImage;
    final doc = _selectedDocument;
    if (text.isEmpty && image == null && doc == null) return;

    _controller.clear();
    setState(() {
      _selectedImage = null;
      _selectedDocument = null;
      _showSuggestions = false;
    });
    _inputFocus.unfocus();

    if (doc != null) {
      ref.read(aiChatProvider.notifier).sendMessageWithDocument(text, doc);
    } else if (image != null) {
      ref.read(aiChatProvider.notifier).sendMessageWithImage(text, image);
    } else {
      ref.read(aiChatProvider.notifier).sendMessage(text);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    // With reverse: true, the top of the list (older messages) is at maxScrollExtent
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final chatState = ref.read(aiChatProvider);
      if (!chatState.isLoading &&
          !chatState.isLoadingMore &&
          chatState.hasMoreHistory) {
        _loadMoreHistory();
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (!mounted) return;
    await ref.read(aiChatProvider.notifier).loadChatHistory(clearExisting: false);
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

  // ─── Unicode conversion helpers ───────────────────────────────────────────

  String _toSuperscript(String input) {
    const map = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
      'n': 'ⁿ', 'x': 'ˣ', 'i': 'ⁱ', 'r': 'ʳ', 't': 'ᵗ',
      'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
      'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'j': 'ʲ', 'k': 'ᵏ',
      'l': 'ˡ', 'm': 'ᵐ', 'o': 'ᵒ', 'p': 'ᵖ', 's': 'ˢ',
      'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'y': 'ʸ', 'z': 'ᶻ',
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  String _toSubscript(String input) {
    const map = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
      'a': 'ₐ', 'e': 'ₑ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ',
      'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ',
      'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ', 'v': 'ᵥ',
      'x': 'ₓ',
    };
    return input.split('').map((char) => map[char] ?? char).join();
  }

  /// Master LaTeX → Unicode conversion table (used everywhere in text).
  static const Map<String, String> _latexMap = {
    // Operators
    r'\cdot':       '·',
    r'\times':      '×',
    r'\div':        '÷',
    r'\pm':         '±',
    r'\mp':         '∓',
    r'\approx':     '≈',
    r'\neq':        '≠',
    r'\ne':         '≠',
    r'\leq':        '≤',
    r'\geq':        '≥',
    r'\le':         '≤',
    r'\ge':         '≥',
    r'\ll':         '≪',
    r'\gg':         '≫',
    r'\sim':        '~',
    r'\simeq':      '≃',
    r'\equiv':      '≡',
    r'\propto':     '∝',
    r'\in':         '∈',
    r'\notin':      '∉',
    r'\subset':     '⊂',
    r'\supset':     '⊃',
    r'\cup':        '∪',
    r'\cap':        '∩',
    r'\emptyset':   '∅',
    // Arrows
    r'\rightarrow': '→',
    r'\leftarrow':  '←',
    r'\Rightarrow': '⇒',
    r'\Leftarrow':  '⇐',
    r'\leftrightarrow': '↔',
    r'\Leftrightarrow': '⟺',
    r'\leftharpoons': '⇌',
    r'\rightleftharpoons': '⇌',
    r'\to':         '→',
    r'\gets':       '←',
    r'\uparrow':    '↑',
    r'\downarrow':  '↓',
    // Dots & misc
    r'\ldots':      '…',
    r'\cdots':      '···',
    r'\vdots':      '⋮',
    r'\ddots':      '⋱',
    r'\therefore':  '∴',
    r'\because':    '∵',
    r'\forall':     '∀',
    r'\exists':     '∃',
    // Geometry / trig
    r'\angle':      '∠',
    r'\perp':       '⊥',
    r'\parallel':   '∥',
    r'\circ':       '°',
    r'\degree':     '°',
    r'^\circ':      '°',
    r'^\degree':    '°',
    r'^o':          '°',
    // Calc / analysis
    r'\int':        '∫',
    r'\iint':       '∬',
    r'\iiint':      '∭',
    r'\oint':       '∮',
    r'\sum':        '∑',
    r'\prod':       '∏',
    r'\partial':    '∂',
    r'\nabla':      '∇',
    r'\infty':      '∞',
    r'\sqrt':       '√',
    // Named functions (keep as text)
    r'\sin':  'sin',
    r'\cos':  'cos',
    r'\tan':  'tan',
    r'\cot':  'cot',
    r'\sec':  'sec',
    r'\csc':  'csc',
    r'\arcsin': 'arcsin',
    r'\arccos': 'arccos',
    r'\arctan': 'arctan',
    r'\sinh': 'sinh',
    r'\cosh': 'cosh',
    r'\tanh': 'tanh',
    r'\log':  'log',
    r'\ln':   'ln',
    r'\exp':  'exp',
    r'\lim':  'lim',
    r'\max':  'max',
    r'\min':  'min',
    r'\gcd':  'gcd',
    r'\lcm':  'lcm',
    r'\det':  'det',
    r'\dim':  'dim',
    r'\ker':  'ker',
    // Lowercase Greek
    r'\alpha':   'α',
    r'\beta':    'β',
    r'\gamma':   'γ',
    r'\delta':   'δ',
    r'\epsilon': 'ε',
    r'\varepsilon': 'ε',
    r'\zeta':    'ζ',
    r'\eta':     'η',
    r'\theta':   'θ',
    r'\vartheta':'ϑ',
    r'\iota':    'ι',
    r'\kappa':   'κ',
    r'\lambda':  'λ',
    r'\mu':      'μ',
    r'\nu':      'ν',
    r'\xi':      'ξ',
    r'\pi':      'π',
    r'\varpi':   'ϖ',
    r'\rho':     'ρ',
    r'\varrho':  'ϱ',
    r'\sigma':   'σ',
    r'\varsigma':'ς',
    r'\tau':     'τ',
    r'\upsilon': 'υ',
    r'\phi':     'φ',
    r'\varphi':  'φ',
    r'\chi':     'χ',
    r'\psi':     'ψ',
    r'\omega':   'ω',
    // Uppercase Greek
    r'\Gamma':   'Γ',
    r'\Delta':   'Δ',
    r'\Theta':   'Θ',
    r'\Lambda':  'Λ',
    r'\Xi':      'Ξ',
    r'\Pi':      'Π',
    r'\Sigma':   'Σ',
    r'\Upsilon': 'Υ',
    r'\Phi':     'Φ',
    r'\Psi':     'Ψ',
    r'\Omega':   'Ω',
    // Brackets
    r'\lfloor': '⌊', r'\rfloor': '⌋',
    r'\lceil':  '⌈', r'\rceil':  '⌉',
    r'\langle': '⟨', r'\rangle': '⟩',
    // Font/style wrappers (remove, keep content via regex later)
    r'\text':    '',
    r'\mathrm':  '',
    r'\mathbf':  '',
    r'\mathit':  '',
    r'\mathbb':  '',
    r'\boldsymbol': '',
    r'\displaystyle': '',
    r'\textstyle': '',
    // Spacing (collapse to space or nothing)
    r'\,': ' ', r'\;': ' ', r'\:': ' ', r'\!': '',
    r'\quad': '  ', r'\qquad': '   ',
    // Brackets \left / \right (strip)
    r'\left(':  '(',  r'\right)': ')',
    r'\left[':  '[',  r'\right]': ']',
    r'\left\{': '{',  r'\right\}': '}',
    r'\left|':  '|',  r'\right|': '|',
    r'\left':   '',   r'\right':  '',
    // Misc
    r'\limits': '',
    r'\bullet': '•',
    r'\star':   '★',
    r'\dagger': '†',
    r'\ddagger': '‡',
    r'\hbar':   'ℏ',
    r'\ell':    'ℓ',
    r'\Re':     'ℜ',
    r'\Im':     'ℑ',
    r'\aleph':  'ℵ',
  };

  String _formatChemicalFormulas(String text) {
    // Match known element symbol followed by digits: H2O, CO2, H2SO4, C6H12O6
    const commonChem = {
      'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
      'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
      'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn',
      'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Y', 'Zr',
      'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I', 'Xe',
      'Ba', 'La', 'Ce', 'W', 'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg',
      'Tl', 'Pb', 'Bi', 'Ra', 'U', 'Pu',
    };
    final regex = RegExp(
      r'\b([A-Z][a-z]?)([0-9]+)(?=[A-Z0-9])|\b([A-Z][a-z]?)([0-9]+)\b',
    );
    return text.replaceAllMapped(regex, (match) {
      final element = match.group(1) ?? match.group(3) ?? '';
      final digits  = match.group(2) ?? match.group(4) ?? '';
      if (element.isEmpty || digits.isEmpty) return match.group(0)!;
      if (!commonChem.contains(element)) return match.group(0)!;
      return '$element${_toSubscript(digits)}';
    });
  }

  /// Convert the inside of a math block (already stripped of delimiters) to
  /// readable Unicode plain text.
  String _cleanSingleMathBlock(String math) {
    var r = math.trim();

    // 1. \text{...}, \mathrm{...} etc. → extract inner text
    final wrapperRx = RegExp(r'\\(?:text|mathrm|mathbf|mathit|mathbb|boldsymbol)\{([^{}]*)\}');
    while (wrapperRx.hasMatch(r)) {
      r = r.replaceAllMapped(wrapperRx, (m) => m.group(1)!);
    }

    // 2. \sqrt{x} → √(x),  \sqrt[n]{x} → ⁿ√(x)
    final sqrtNRx = RegExp(r'\\sqrt\[([^\]]+)\]\{([^{}]*)\}');
    while (sqrtNRx.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtNRx, (m) => '${_toSuperscript(m.group(1)!)}√(${m.group(2)!})');
    }
    final sqrtRx = RegExp(r'\\sqrt\{([^{}]*)\}');
    while (sqrtRx.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtRx, (m) => '√(${m.group(1)!})');
    }
    // bare \sqrt (no braces)
    r = r.replaceAll(r'\sqrt', '√');

    // 3. \frac{num}{den} → (num)/(den)  [handle nested up to 3 passes]
    final fracRx = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    for (int pass = 0; pass < 4; pass++) {
      if (!fracRx.hasMatch(r)) break;
      r = r.replaceAllMapped(fracRx, (m) {
        final n = m.group(1)!.trim();
        final d = m.group(2)!.trim();
        final nd = (n.contains(RegExp(r'[+\-]')) && n.length > 1) ? '($n)' : n;
        final dd = (d.contains(RegExp(r'[+\-]')) && d.length > 1) ? '($d)' : d;
        return '$nd/$dd';
      });
    }

    // 4. Apply the master symbol map (longest keys first to avoid partial hits)
    final keys = _latexMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      r = r.replaceAll(key, _latexMap[key]!);
    }

    // 5. Remove remaining unknown \cmd{...} → keep inner text
    final unknownCmd = RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}');
    while (unknownCmd.hasMatch(r)) {
      r = r.replaceAllMapped(unknownCmd, (m) => m.group(1)!);
    }
    // Remove remaining bare \cmd
    r = r.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    // 6. Superscripts ^{...} and ^x
    final supBrace = RegExp(r'\^\{([^{}]*)\}');
    while (supBrace.hasMatch(r)) {
      r = r.replaceAllMapped(supBrace, (m) => _toSuperscript(m.group(1)!));
    }
    r = r.replaceAllMapped(
      RegExp(r'\^([0-9a-zA-Z+\-])'),
      (m) => _toSuperscript(m.group(1)!),
    );

    // 7. Subscripts _{...} and _x
    final subBrace = RegExp(r'_\{([^{}]*)\}');
    while (subBrace.hasMatch(r)) {
      r = r.replaceAllMapped(subBrace, (m) => _toSubscript(m.group(1)!));
    }
    r = r.replaceAllMapped(
      RegExp(r'_([0-9a-zA-Z+\-])'),
      (m) => _toSubscript(m.group(1)!),
    );

    // 8. Braces remaining → strip
    r = r.replaceAll('{', '').replaceAll('}', '');

    // 9. Collapse \\\\ (newline in math) → space
    r = r.replaceAll(r'\\', ' ');

    // 10. Collapse multiple spaces
    r = r.replaceAll(RegExp(r'  +'), ' ').trim();

    return r;
  }

  /// Master entry point: converts ALL LaTeX in a full AI response to Unicode.
  /// Works on $...$, $$...$$, \(...\), \[...\], AND bare \cmd anywhere.
  String _cleanMathExpressions(String text) {
    var r = text;

    // ── 1. Display math blocks  $$...$$  (multiline) ─────────────────────────
    r = r.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (m) => '\n${_cleanSingleMathBlock(m.group(1)!)}\n',
    );

    // ── 2. Display math blocks  \[...\] ──────────────────────────────────────
    r = r.replaceAllMapped(
      RegExp(r'\\\[(.+?)\\\]', dotAll: true),
      (m) => '\n${_cleanSingleMathBlock(m.group(1)!)}\n',
    );

    // ── 3. Inline math blocks  $...$  (single line only) ─────────────────────
    r = r.replaceAllMapped(
      RegExp(r'\$([^\$\n]+)\$'),
      (m) => _cleanSingleMathBlock(m.group(1)!),
    );

    // ── 4. Inline math blocks  \(...\) ────────────────────────────────────────
    r = r.replaceAllMapped(
      RegExp(r'\\\((.+?)\\\)', dotAll: true),
      (m) => _cleanSingleMathBlock(m.group(1)!),
    );

    // ── 5. Bare LaTeX commands anywhere (outside delimiters) ──────────────────
    //  Apply in longest-key-first order to avoid partial replacements.
    final keys = _latexMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      // Skip font-wrapper keys — they need the {arg} form handled below.
      if (_latexMap[key]!.isEmpty) continue;
      r = r.replaceAll(key, _latexMap[key]!);
    }

    // ── 6. Bare \frac{a}{b} outside delimiters ────────────────────────────────
    final fracRx = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    for (int pass = 0; pass < 4; pass++) {
      if (!fracRx.hasMatch(r)) break;
      r = r.replaceAllMapped(fracRx, (m) {
        final n = m.group(1)!.trim();
        final d = m.group(2)!.trim();
        return '$n/$d';
      });
    }

    // ── 7. Bare \sqrt{x} outside delimiters ──────────────────────────────────
    final sqrtBrace = RegExp(r'√\{([^{}]*)\}');
    while (sqrtBrace.hasMatch(r)) {
      r = r.replaceAllMapped(sqrtBrace, (m) => '√(${m.group(1)!})');
    }
    // Remove remaining \cmd{...} font wrappers → keep content
    final wrapRx = RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}');
    while (wrapRx.hasMatch(r)) {
      r = r.replaceAllMapped(wrapRx, (m) => m.group(1)!);
    }
    // Remove any remaining bare \cmd (unknown)
    r = r.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');

    // ── 8. Bare superscripts ^2 / ^{n+1} outside math (in plain text) ────────
    //  Only convert when preceded by a word char (so markdown ^ headers are safe)
    r = r.replaceAllMapped(
      RegExp(r'(?<=\w)\^\{([^{}]+)\}'),
      (m) => _toSuperscript(m.group(1)!),
    );
    r = r.replaceAllMapped(
      RegExp(r'(?<=\w)\^([0-9+\-])'),
      (m) => _toSuperscript(m.group(1)!),
    );

    // ── 9. Bare subscripts _2 / _{i} outside math (in plain text) ────────────
    //  Only convert when preceded by a letter (avoids Markdown _italic_ clash)
    r = r.replaceAllMapped(
      RegExp(r'(?<=[A-Za-z])_\{([^{}]+)\}'),
      (m) => _toSubscript(m.group(1)!),
    );
    r = r.replaceAllMapped(
      RegExp(r'(?<=[A-Za-z])_([0-9])'),
      (m) => _toSubscript(m.group(1)!),
    );

    // ── 10. Chemical formula subscripts (e.g. H2O → H₂O) ────────────────────
    r = _formatChemicalFormulas(r);

    // ── 11. Strip any leftover stray dollar signs ─────────────────────────────
    //  (but preserve markdown \$ escape — convert it to literal $)
    r = r.replaceAll(r'\$', '\u0024'); // \$ → $ (escaped dollars)
    r = r.replaceAll(r'$', '');         // bare $ → remove

    // ── 12. Strip leftover bracket wrappers ──────────────────────────────────
    r = r.replaceAll(r'\(', '').replaceAll(r'\)', '');
    r = r.replaceAll(r'\[', '').replaceAll(r'\]', '');

    // ── 13. Replace caret-degree / caret-circle patterns ─────────────────────
    r = r.replaceAll('^°', '°').replaceAll('^∘', '°').replaceAll('^o', '°');

    return r;
  }

  Future<void> _handleLinkTap(String? href) async {
    if (href != null) {
      try {
        final uri = Uri.parse(href);
        final finalUri = href.startsWith('/api')
            ? Uri.parse('${AppConfig.baseUrl}$href')
            : href.startsWith('/') 
                ? Uri.parse('${AppConfig.apiBaseUrl}$href')
                : uri;
        
        final pathLower = href.toLowerCase();
        final isDownload = pathLower.contains('/download') ||
            pathLower.endsWith('.pdf') ||
            pathLower.endsWith('.xlsx') ||
            pathLower.endsWith('.csv') ||
            pathLower.endsWith('.docx') ||
            pathLower.endsWith('.txt');

        if (isDownload) {
          final fileName = uri.pathSegments.isNotEmpty
              ? Uri.decodeComponent(uri.pathSegments.last)
              : 'downloaded_file';
          await getDownloadHelper().downloadFile(finalUri.toString(), fileName);
        } else {
          await launchUrl(finalUri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error launching URL: $e');
        if (mounted) {
          final errMsg = e.toString().contains('404')
              ? 'Document not found on server. It may not have been generated yet.'
              : 'Download failed: $e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  MarkdownStyleSheet _getMarkdownStyle() {
    return MarkdownStyleSheet(
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
    );
  }

  Widget _buildAiResponseContent(String text, bool isStreaming) {
    final imgRegex = RegExp(r'!\[(.*?)\]\((https?://.*?)\)');
    
    if (!imgRegex.hasMatch(text)) {
      return MarkdownBody(
        data: text.isEmpty && isStreaming ? '▋' : _cleanMathExpressions(text),
        selectable: true,
        onTapLink: (t, href, tl) => _handleLinkTap(href),
        styleSheet: _getMarkdownStyle(),
      );
    }
    
    final List<Widget> children = [];
    int lastIndex = 0;
    
    for (final match in imgRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final precedingText = text.substring(lastIndex, match.start).trim();
        if (precedingText.isNotEmpty) {
          children.add(
            MarkdownBody(
              data: precedingText.isEmpty && isStreaming ? '▋' : _cleanMathExpressions(precedingText),
              selectable: true,
              onTapLink: (t, href, tl) => _handleLinkTap(href),
              styleSheet: _getMarkdownStyle(),
            ),
          );
          children.add(const SizedBox(height: 12));
        }
      }
      
      final altText = match.group(1) ?? 'Image';
      var imageUrl = match.group(2) ?? '';
      
      if (imageUrl.isNotEmpty) {
        if (imageUrl.startsWith('http')) {
          imageUrl = '${AppConfig.apiBaseUrl}/chat/image-proxy?url=${Uri.encodeComponent(imageUrl)}';
        }
        children.add(_buildPremiumAiImageCard(imageUrl, altText));
        children.add(const SizedBox(height: 12));
      }
      
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      final remainingText = text.substring(lastIndex).trim();
      if (remainingText.isNotEmpty) {
        children.add(
          MarkdownBody(
            data: remainingText.isEmpty && isStreaming ? '▋' : _cleanMathExpressions(remainingText),
            selectable: true,
            onTapLink: (t, href, tl) => _handleLinkTap(href),
            styleSheet: _getMarkdownStyle(),
          ),
        );
      }
    }
    
    if (children.isNotEmpty && children.last is SizedBox) {
      children.removeLast();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildPremiumAiImageCard(String url, String alt) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            GestureDetector(
              onTap: () => _showFullScreenImagePreview(url, alt),
              child: SizedBox(
                height: 280,
                width: double.infinity,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    
                    final totalBytes = loadingProgress.expectedTotalBytes;
                    final loadedBytes = loadingProgress.cumulativeBytesLoaded;
                    final progressValue = totalBytes != null ? loadedBytes / totalBytes : null;
                    
                    return Container(
                      color: _inputBg,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 45,
                              height: 45,
                              padding: const EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                value: progressValue,
                                valueColor: const AlwaysStoppedAnimation<Color>(_gradEnd),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Generating premium image...',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: _inputBg,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: _recordRed, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Failed to render image',
                            style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Please verify your connection or try again.',
                            style: TextStyle(color: _textMuted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      alt.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _gradEnd,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final fileName = 'shami_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
                      getDownloadHelper().downloadFile(url, fileName);
                    },
                    child: const Tooltip(
                      message: 'Download Image',
                      child: Icon(
                        Icons.download_for_offline_rounded,
                        color: _gradEnd,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: _gradEnd,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImagePreview(String url, String alt) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Preview',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Hero(
                    tag: url,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(_gradEnd),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image_rounded, color: _recordRed, size: 60),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_for_offline_rounded, color: _gradEnd, size: 28),
                        tooltip: 'Download Image',
                        onPressed: () {
                          final fileName = 'shami_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          getDownloadHelper().downloadFile(url, fileName);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Starting image download...'),
                              duration: Duration(seconds: 2),
                              backgroundColor: _inputBg,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBubbleActionButton({
    required IconData icon,
    required String tooltip,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    Color? bgColor,
    Border? border,
  }) {
    return Tooltip(
      message: tooltip.tr(ref),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: iconColor ?? _textMuted),
              const SizedBox(width: 4),
              Text(
                label.tr(ref),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Save to Documents" button shown below each completed AI response.
  Widget _buildSaveToDocsButton(ChatMessage msg) {
    return Tooltip(
      message: 'Save to Documents',
      child: GestureDetector(
        onTap: () => _showSaveToDocsDialog(msg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_add_rounded, size: 12, color: Color(0xFF4F46E5)),
              SizedBox(width: 4),
              Text(
                'Save',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                  fontFamily: AppFonts.body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveToDocsDialog(ChatMessage msg) {
    final chatState = ref.read(aiChatProvider);
    final titleCtrl = TextEditingController(
      text: msg.text.length > 60
          ? '${msg.text.substring(0, 60).trim()}…'
          : msg.text.trim(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '💾 Save to Documents',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Give this document a title and it will appear in your Documents Hub.',
              style: TextStyle(fontFamily: AppFonts.body, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Document title',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF4F46E5), width: 2),
                ),
              ),
              style: const TextStyle(fontFamily: AppFonts.body),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.save_rounded,
                color: Colors.white, size: 16),
            label: const Text('Save',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700)),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              final saved = await ref
                  .read(documentsProvider.notifier)
                  .saveAiDocument(
                    title: title,
                    content: msg.text,
                    sessionId: chatState.sessionId,
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(saved
                        ? '✅ Saved to Documents Hub!'
                        : '❌ Failed to save document'),
                    backgroundColor: saved
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
          ),
        ],
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
  final void Function(PlatformFile) onDocumentPicked;
  const _AttachButton({required this.onImagePicked, required this.onDocumentPicked});

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
                  onTap: () {
                    Navigator.pop(context);
                    ImagePicker()
                        .pickImage(source: ImageSource.gallery, imageQuality: 80)
                        .then((f) {
                      if (f != null) onImagePicked(f);
                    }).catchError((e) {
                      debugPrint('Gallery picker error: $e');
                    });
                  },
                ),
                _AttachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00BCD4)]),
                  onTap: () {
                    Navigator.pop(context);
                    ImagePicker()
                        .pickImage(source: ImageSource.camera, imageQuality: 80)
                        .then((f) {
                      if (f != null) onImagePicked(f);
                    }).catchError((e) {
                      debugPrint('Camera picker error: $e');
                    });
                  },
                ),
                _AttachOption(
                  icon: Icons.description_rounded,
                  label: 'Document',
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF9800)]),
                  onTap: () {
                    Navigator.pop(context);
                    FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'docx', 'doc', 'txt'],
                      withData: true,
                    ).then((result) {
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        if (kIsWeb ? (file.bytes != null) : (file.path != null || file.bytes != null)) {
                          onDocumentPicked(file);
                        }
                      }
                    }).catchError((e) {
                      debugPrint('File picking error: $e');
                    });
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

// ─────────────────────────────────────────────────────────────
//  Keep Alive Wrapper for Smooth Scroll Rendering
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
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}