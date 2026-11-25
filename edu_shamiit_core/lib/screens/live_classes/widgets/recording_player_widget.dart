import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/live_class_models.dart';
import '../utils/recording_player_helper.dart';

class RecordingPlayerWidget extends StatefulWidget {
  final RecordingItem item;
  final String? resolvedStreamUrl;
  final double height;
  final bool autoplay;
  final VoidCallback? onFirstPlay;
  final VoidCallback? onOpenFullscreenModal;
  final VoidCallback? onDownload;

  const RecordingPlayerWidget({
    super.key,
    required this.item,
    required this.resolvedStreamUrl,
    this.height = 195,
    this.autoplay = false,
    this.onFirstPlay,
    this.onOpenFullscreenModal,
    this.onDownload,
  });

  @override
  State<RecordingPlayerWidget> createState() => _RecordingPlayerWidgetState();
}

class _RecordingPlayerWidgetState extends State<RecordingPlayerWidget> {
  String? _viewType;
  String? _registeredUrl;
  bool _isPlaying = false;
  bool _isMuted = false;
  final double _volume = 1.0;
  double _playbackRate = 1.0;
  int _positionSec = 0;
  int _durationSec = 0;
  String? _errorText;
  bool _trackedFirstPlay = false;

  @override
  void initState() {
    super.initState();
    _durationSec = widget.item.durationSeconds;
    _initPlayerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RecordingPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.resolvedStreamUrl != widget.resolvedStreamUrl) {
      _positionSec = 0;
      _durationSec = widget.item.durationSeconds;
      _isPlaying = false;
      _errorText = null;
      _trackedFirstPlay = false;
      _playbackRate = 1.0;
      _initPlayerIfNeeded();
    }
  }

  void _initPlayerIfNeeded() {
    final url = (widget.resolvedStreamUrl ?? '').trim();
    if (!kIsWeb || url.isEmpty || url == _registeredUrl) return;

    final vt =
        'shamiit-rec-${widget.item.id}-${DateTime.now().microsecondsSinceEpoch}';
    _registeredUrl = url;
    _viewType = vt;

    registerRecordingVideoElement(
      vt,
      url,
      autoplay: widget.autoplay,
      showNativeControls: true,
      onPlayStateChanged: (playing) {
        if (!mounted) return;
        setState(() => _isPlaying = playing);
        if (playing && !_trackedFirstPlay) {
          _trackedFirstPlay = true;
          widget.onFirstPlay?.call();
        }
      },
      onTimeUpdate: (pos, dur) {
        if (!mounted) return;
        setState(() {
          _positionSec = pos;
          if (dur > 0) _durationSec = dur;
        });
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _errorText = msg);
      },
    );
  }

  String _fmt(int sec) {
    final s = sec < 0 ? 0 : sec;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final r = s % 60;
    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  void _cycleSpeed() {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackRate);
    final next = speeds[(idx + 1) % speeds.length];
    setState(() => _playbackRate = next);
    if (_viewType != null) {
      setRecordingSpeed(_viewType!, next);
    }
  }

  void _toggleMute() {
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    if (_viewType != null) {
      setRecordingVolume(_viewType!, _volume, nextMuted);
    }
  }

  Future<void> _openExternal() async {
    final url = (widget.resolvedStreamUrl ?? '').trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = (widget.resolvedStreamUrl ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (!hasUrl)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Preparing secure video stream...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else if (kIsWeb && _viewType != null)
                Positioned.fill(
                  child: HtmlElementView(viewType: _viewType!),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _openExternal,
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Play Video', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_errorText != null)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xEE0F172A),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.video_file_outlined,
                            color: Color(0xFFF59E0B),
                            size: 30,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                          if (widget.onDownload != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: widget.onDownload,
                              icon: const Icon(Icons.file_download_outlined, size: 14),
                              label: const Text('Download Recording', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Quick top-right Theater Expand button
              if (widget.onOpenFullscreenModal != null && _errorText == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: widget.onOpenFullscreenModal,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.open_in_full_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Theater Mode',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Interactive Quick Control Strip (Play/Pause, Seek, Time, Volume, Speed, PiP, Native Fullscreen)
        if (hasUrl && _errorText == null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (_viewType != null) {
                      toggleRecordingPlayback(_viewType!);
                    } else {
                      _openExternal();
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_fmt(_positionSec)} / ${_fmt(_durationSec > 0 ? _durationSec : widget.item.durationSeconds)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white70, fontFeatures: []),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF3B82F6),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: (_durationSec > 0
                              ? _positionSec / _durationSec
                              : 0.0)
                          .clamp(0.0, 1.0),
                      onChanged: (v) {
                        if (_viewType != null && _durationSec > 0) {
                          seekRecordingTo(_viewType!, v * _durationSec);
                        }
                      },
                    ),
                  ),
                ),
                InkWell(
                  onTap: _toggleMute,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: _cycleSpeed,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_playbackRate}x',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Picture-in-Picture',
                    child: InkWell(
                      onTap: () {
                        if (_viewType != null) requestRecordingPiP(_viewType!);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.picture_in_picture_alt_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Native Fullscreen',
                    child: InkWell(
                      onTap: () {
                        if (_viewType != null) {
                          final ok = requestRecordingFullscreen(_viewType!);
                          if (!ok) widget.onOpenFullscreenModal?.call();
                        } else {
                          widget.onOpenFullscreenModal?.call();
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class RecordingFullscreenDialog {
  static Future<void> show(
    BuildContext context, {
    required RecordingItem item,
    required String resolvedUrl,
    VoidCallback? onFirstPlay,
    VoidCallback? onDownload,
  }) {
    final mq = MediaQuery.of(context);
    final playerHeight = (mq.size.height * 0.68).clamp(280.0, 620.0);

    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.ondemand_video_rounded, color: Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${item.classSection}  •  ${item.subjectName}  •  ${item.teacherName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (onDownload != null)
                      TextButton.icon(
                        onPressed: onDownload,
                        icon: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF60A5FA)),
                        label: const Text('Download', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RecordingPlayerWidget(
                  item: item,
                  resolvedStreamUrl: resolvedUrl,
                  height: playerHeight,
                  autoplay: true,
                  onFirstPlay: onFirstPlay,
                  onDownload: onDownload,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
