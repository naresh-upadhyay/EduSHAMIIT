import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';
import '../../../../utils/digital_media_player_helper.dart';

/// In-App Secure Audiobook Player with Real-Time Audio Streaming, Bi-Directional Controls & Chapter Playlist
class AudiobookPlayerDialog extends ConsumerStatefulWidget {
  final BookModel book;
  final String streamToken;
  final String watermarkText;
  final String? initialFileId;
  final int initialAssetIndex;

  const AudiobookPlayerDialog({
    super.key,
    required this.book,
    required this.streamToken,
    required this.watermarkText,
    this.initialFileId,
    this.initialAssetIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required BookModel book,
    required String streamToken,
    required String watermarkText,
    String? initialFileId,
    int initialAssetIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AudiobookPlayerDialog(
        book: book,
        streamToken: streamToken,
        watermarkText: watermarkText,
        initialFileId: initialFileId,
        initialAssetIndex: initialAssetIndex,
      ),
    );
  }

  @override
  ConsumerState<AudiobookPlayerDialog> createState() => _AudiobookPlayerDialogState();
}

class _AudiobookPlayerDialogState extends ConsumerState<AudiobookPlayerDialog> {
  bool _isPlaying = true;
  bool _isSeeking = false;
  double _currentPositionSeconds = 0.0;
  double _totalDurationSeconds = 180.0; // Fallback 3 mins if not loaded yet
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;
  int _selectedTrackIndex = 0;
  bool _isPlaylistOpen = false;
  String _audioViewKey = '';
  Timer? _fallbackTicker;

  List<DigitalFileModel> _audioTracks = [];

  final List<double> _availableSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initTracks();
    _currentPositionSeconds = widget.book.userProgress?.positionSeconds ?? 0.0;
    _registerAudioPlayer();
    _startFallbackTicker();
  }

  void _initTracks() {
    _audioTracks = widget.book.digitalFiles.where((f) => f.isAudio || f.fileType.startsWith('AUDIO')).toList();
    if (_audioTracks.isEmpty && widget.book.digitalFiles.isNotEmpty) {
      _audioTracks = widget.book.digitalFiles;
    }

    if (widget.initialFileId != null && widget.initialFileId!.isNotEmpty) {
      final found = _audioTracks.indexWhere((f) => f.id == widget.initialFileId);
      _selectedTrackIndex = found != -1 ? found : 0;
    } else if (widget.initialAssetIndex >= 0 && widget.initialAssetIndex < _audioTracks.length) {
      _selectedTrackIndex = widget.initialAssetIndex;
    } else {
      _selectedTrackIndex = 0;
    }

    if (_selectedTrackIndex < 0 || _selectedTrackIndex >= _audioTracks.length) {
      _selectedTrackIndex = 0;
    }

    if (_audioTracks.isNotEmpty) {
      final curTrack = _audioTracks[_selectedTrackIndex];
      _totalDurationSeconds = curTrack.durationSeconds > 0 ? curTrack.durationSeconds.toDouble() : 180.0;
    }
  }

  void _registerAudioPlayer() {
    if (_audioTracks.isEmpty || _selectedTrackIndex < 0 || _selectedTrackIndex >= _audioTracks.length) {
      return;
    }
    final curTrack = _audioTracks[_selectedTrackIndex];
    final rawStream = curTrack.streamUrl?.trim() ?? '';
    final rawStorage = curTrack.storageKey.trim();
    final audioUrl = rawStream.isNotEmpty ? rawStream : rawStorage;

    if (_audioViewKey.isNotEmpty) {
      disposeWebAudio(_audioViewKey);
    }

    _audioViewKey = 'audio_track_${curTrack.id}_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb && audioUrl.isNotEmpty) {
      registerDigitalAudioView(
        _audioViewKey,
        audioUrl,
        onDurationLoaded: (dur) {
          if (mounted && dur > 0) {
            setState(() {
              _totalDurationSeconds = dur.toDouble();
            });
          }
        },
        onTimeUpdate: (pos) {
          if (mounted && !_isSeeking) {
            setState(() {
              _currentPositionSeconds = pos;
            });
          }
        },
        onPlay: () {
          if (mounted && !_isPlaying) {
            setState(() => _isPlaying = true);
          }
        },
        onPause: () {
          if (mounted && _isPlaying) {
            setState(() => _isPlaying = false);
          }
        },
        onEnded: () {
          if (mounted) {
            if (_selectedTrackIndex < _audioTracks.length - 1) {
              _switchTrack(_selectedTrackIndex + 1);
            } else {
              setState(() {
                _isPlaying = false;
                _currentPositionSeconds = _totalDurationSeconds;
              });
            }
          }
        },
      );
    }
  }

  void _switchTrack(int index) {
    if (index < 0 || index >= _audioTracks.length) return;
    _syncProgress();
    setState(() {
      _selectedTrackIndex = index;
      final curTrack = _audioTracks[index];
      _totalDurationSeconds = curTrack.durationSeconds > 0 ? curTrack.durationSeconds.toDouble() : 180.0;
      _currentPositionSeconds = 0.0;
      _isPlaying = true;
      _registerAudioPlayer();
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      pauseWebAudio(_audioViewKey);
      setState(() => _isPlaying = false);
    } else {
      playWebAudio(_audioViewKey);
      setState(() => _isPlaying = true);
    }
  }

  void _seekRelative(double deltaSec) {
    seekRelativeWebAudio(_audioViewKey, deltaSec);
    setState(() {
      _currentPositionSeconds = (_currentPositionSeconds + deltaSec).clamp(0.0, _totalDurationSeconds);
    });
  }

  void _seekTo(double targetSec) {
    seekWebAudio(_audioViewKey, targetSec);
    setState(() {
      _currentPositionSeconds = targetSec.clamp(0.0, _totalDurationSeconds);
    });
  }

  void _cycleSpeed() {
    final curIndex = _availableSpeeds.indexOf(_playbackSpeed);
    final nextIndex = (curIndex + 1) % _availableSpeeds.length;
    final newSpeed = _availableSpeeds[nextIndex];
    setAudioSpeedWeb(_audioViewKey, newSpeed);
    setState(() {
      _playbackSpeed = newSpeed;
    });
  }

  void _toggleMute() {
    final nextMute = !_isMuted;
    setAudioVolumeWeb(_audioViewKey, nextMute ? 0.0 : _volume);
    setState(() {
      _isMuted = nextMute;
    });
  }

  void _setVolume(double newVol) {
    setAudioVolumeWeb(_audioViewKey, newVol);
    setState(() {
      _volume = newVol;
      _isMuted = newVol <= 0.01;
    });
  }

  void _startFallbackTicker() {
    // Ticker only runs as fallback for non-web environments
    if (!kIsWeb) {
      _fallbackTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_isPlaying && mounted && !_isSeeking) {
          setState(() {
            _currentPositionSeconds += _playbackSpeed;
            if (_currentPositionSeconds >= _totalDurationSeconds) {
              if (_selectedTrackIndex < _audioTracks.length - 1) {
                _switchTrack(_selectedTrackIndex + 1);
              } else {
                _currentPositionSeconds = _totalDurationSeconds;
                _isPlaying = false;
              }
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _fallbackTicker?.cancel();
    disposeWebAudio(_audioViewKey);
    _syncProgress();
    super.dispose();
  }

  Future<void> _syncProgress() async {
    final pct = (_totalDurationSeconds > 0) ? (_currentPositionSeconds / _totalDurationSeconds) * 100.0 : 0.0;
    await ref.read(bookProvider.notifier).recordDigitalProgress(widget.book.id, {
      'media_type': 'AUDIOBOOK',
      'position_seconds': _currentPositionSeconds,
      'total_duration_seconds': _totalDurationSeconds,
      'progress_pct': double.parse(pct.clamp(0.0, 100.0).toStringAsFixed(2)),
      'playback_speed': _playbackSpeed,
      'session_seconds': 60,
      'is_completed': _currentPositionSeconds >= _totalDurationSeconds && _totalDurationSeconds > 0,
    });
  }

  String _formatTime(double totalSec) {
    if (totalSec.isNaN || totalSec.isInfinite || totalSec < 0) return '00:00';
    final mins = (totalSec / 60).floor();
    final secs = (totalSec % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final curTrack = (_audioTracks.isNotEmpty && _selectedTrackIndex >= 0 && _selectedTrackIndex < _audioTracks.length)
        ? _audioTracks[_selectedTrackIndex]
        : null;
    final trackTitle = curTrack != null ? curTrack.displayTitle : widget.book.title;
    final rawStream = curTrack?.streamUrl?.trim() ?? '';
    final rawStorage = curTrack?.storageKey.trim() ?? '';
    final audioUrl = rawStream.isNotEmpty ? rawStream : rawStorage;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 860,
        height: 640,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // Mount background web audio element in the DOM
            if (kIsWeb && _audioViewKey.isNotEmpty)
              SizedBox(
                width: 1,
                height: 1,
                child: HtmlElementView(
                  key: ValueKey(_audioViewKey),
                  viewType: _audioViewKey,
                ),
              ),

            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.headphones_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.book.author.isNotEmpty)
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Open External Link Button
                  if (audioUrl.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.open_in_new_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 19),
                      tooltip: 'Open audio in external tab',
                      onPressed: () async {
                        final uri = Uri.tryParse(audioUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),

                  IconButton(
                    icon: Icon(
                      Icons.queue_music_rounded,
                      color: _isPlaylistOpen ? const Color(0xFF8B5CF6) : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    tooltip: 'Tracks & Chapters Playlist',
                    onPressed: () => setState(() => _isPlaylistOpen = !_isPlaylistOpen),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    tooltip: 'Close player',
                    onPressed: () {
                      _syncProgress();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Main Body: Audio Visualization + Optional Track Playlist Sidebar
            Expanded(
              child: Row(
                children: [
                  // Player Center Area
                  Expanded(
                    flex: 6,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Album / Cover Art Container with Glowing Purple Ambient Shadow
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: _isPlaying ? 0.35 : 0.15),
                                      blurRadius: _isPlaying ? 24 : 12,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  image: widget.book.coverUrl != null && widget.book.coverUrl!.isNotEmpty
                                      ? DecorationImage(image: NetworkImage(widget.book.coverUrl!), fit: BoxFit.cover)
                                      : null,
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                ),
                                child: widget.book.coverUrl == null || widget.book.coverUrl!.isEmpty
                                    ? const Icon(Icons.auto_stories, color: Color(0xFF8B5CF6), size: 48)
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Track Title & Progress Counter
                              Text(
                                trackTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _audioTracks.length > 1
                                    ? 'Chapter ${_selectedTrackIndex + 1} of ${_audioTracks.length}'
                                    : 'Full Audiobook Audio Stream',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),

                              // Dynamic Responsive Sound Waveform Visualizer
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(28, (index) {
                                  final height = _isPlaying
                                      ? (10.0 + ((index * 9 + (_currentPositionSeconds * 5).toInt()) % 38).toDouble())
                                      : 6.0;
                                  final isActive = (index / 28.0) <= (_totalDurationSeconds > 0 ? (_currentPositionSeconds / _totalDurationSeconds) : 0.0);
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    width: 3.5,
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? const Color(0xFF8B5CF6)
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 18),

                              // Seek Bar Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  thumbColor: const Color(0xFF8B5CF6),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _currentPositionSeconds.clamp(0.0, _totalDurationSeconds > 0 ? _totalDurationSeconds : 1.0),
                                  max: _totalDurationSeconds > 0 ? _totalDurationSeconds : 1.0,
                                  onChangeStart: (_) {
                                    _isSeeking = true;
                                  },
                                  onChanged: (val) {
                                    setState(() => _currentPositionSeconds = val);
                                  },
                                  onChangeEnd: (val) {
                                    _seekTo(val);
                                    _isSeeking = false;
                                  },
                                ),
                              ),

                              // Timestamps
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTime(_currentPositionSeconds),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(_totalDurationSeconds),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Primary Interactive Playback Controls Toolbar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Playback Speed Button (0.75x, 1x, 1.25x, 1.5x, 2x)
                                  InkWell(
                                    onTap: _cycleSpeed,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        '${_playbackSpeed}x',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Previous Track (if multiple tracks exist)
                                  if (_audioTracks.length > 1) ...[
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous_rounded),
                                      tooltip: 'Previous Track',
                                      color: _selectedTrackIndex > 0 ? (isDark ? Colors.white70 : const Color(0xFF334155)) : Colors.grey.withValues(alpha: 0.3),
                                      onPressed: _selectedTrackIndex > 0 ? () => _switchTrack(_selectedTrackIndex - 1) : null,
                                    ),
                                    const SizedBox(width: 6),
                                  ],

                                  // Rewind 10s Button
                                  IconButton(
                                    icon: const Icon(Icons.replay_10_rounded, size: 26),
                                    tooltip: 'Back 10 Seconds',
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    onPressed: () => _seekRelative(-10),
                                  ),
                                  const SizedBox(width: 12),

                                  // Big Play / Pause Button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _togglePlayPause,
                                      borderRadius: BorderRadius.circular(30),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Forward 10s Button
                                  IconButton(
                                    icon: const Icon(Icons.forward_10_rounded, size: 26),
                                    tooltip: 'Forward 10 Seconds',
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    onPressed: () => _seekRelative(10),
                                  ),

                                  // Next Track (if multiple tracks exist)
                                  if (_audioTracks.length > 1) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next_rounded),
                                      tooltip: 'Next Track',
                                      color: _selectedTrackIndex < _audioTracks.length - 1 ? (isDark ? Colors.white70 : const Color(0xFF334155)) : Colors.grey.withValues(alpha: 0.3),
                                      onPressed: _selectedTrackIndex < _audioTracks.length - 1 ? () => _switchTrack(_selectedTrackIndex + 1) : null,
                                    ),
                                  ],
                                  const SizedBox(width: 14),

                                  // Mute / Volume Control
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _isMuted || _volume <= 0.01 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          size: 20,
                                        ),
                                        tooltip: _isMuted ? 'Unmute' : 'Mute',
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        onPressed: _toggleMute,
                                      ),
                                      SizedBox(
                                        width: 65,
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: const Color(0xFF8B5CF6),
                                            inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                            thumbColor: const Color(0xFF8B5CF6),
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                                            trackHeight: 3,
                                          ),
                                          child: Slider(
                                            value: _isMuted ? 0.0 : _volume,
                                            min: 0.0,
                                            max: 1.0,
                                            onChanged: (val) => _setVolume(val),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Anti-Piracy Floating Watermark
                        IgnorePointer(
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Text(
                                widget.watermarkText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Track Playlist Sidebar
                  if (_isPlaylistOpen) ...[
                    VerticalDivider(width: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.queue_music_rounded, color: Color(0xFF8B5CF6), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Audiobook Playlist',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_audioTracks.length} chapters',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _audioTracks.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                itemBuilder: (context, idx) {
                                  final track = _audioTracks[idx];
                                  final isSelected = idx == _selectedTrackIndex;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                    leading: Icon(
                                      isSelected && _isPlaying ? Icons.volume_up_rounded : Icons.audiotrack_rounded,
                                      color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      size: 20,
                                    ),
                                    title: Text(
                                      track.displayTitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF8B5CF6) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      track.formattedDuration,
                                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                    onTap: () => _switchTrack(idx),
                                  );
                                },
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
          ],
        ),
      ),
    );
  }
}
