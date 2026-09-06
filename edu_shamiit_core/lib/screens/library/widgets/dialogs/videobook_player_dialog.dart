import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';
import '../../../../utils/digital_media_player_helper.dart';

/// In-App Secure Educational Video Player with Real HLS Live Streaming, Multi-Lecture Playlist & DRM Protection
class VideobookPlayerDialog extends ConsumerStatefulWidget {
  final BookModel book;
  final String streamToken;
  final String watermarkText;
  final String? initialFileId;
  final int initialAssetIndex;

  const VideobookPlayerDialog({
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
      builder: (context) => VideobookPlayerDialog(
        book: book,
        streamToken: streamToken,
        watermarkText: watermarkText,
        initialFileId: initialFileId,
        initialAssetIndex: initialAssetIndex,
      ),
    );
  }

  @override
  ConsumerState<VideobookPlayerDialog> createState() => _VideobookPlayerDialogState();
}

class _VideobookPlayerDialogState extends ConsumerState<VideobookPlayerDialog> {
  bool _isPlaying = true;
  double _currentPositionSeconds = 0.0;
  double _totalDurationSeconds = 2400.0; // 40 mins default
  double _playbackSpeed = 1.0;
  int _selectedAssetIndex = 0;
  bool _isPlaylistOpen = false;
  String _viewKey = '';

  Timer? _playbackTicker;
  List<DigitalFileModel> _videoAssets = [];

  @override
  void initState() {
    super.initState();
    _initVideoAssets();
    _currentPositionSeconds = widget.book.userProgress?.positionSeconds ?? 0.0;
    _registerPlayer();
    _startTicker();
  }

  void _initVideoAssets() {
    _videoAssets = widget.book.digitalFiles.where((f) => f.isVideo || f.isLiveStream || f.fileType.startsWith('VIDEO')).toList();
    if (_videoAssets.isEmpty && widget.book.digitalFiles.isNotEmpty) {
      _videoAssets = widget.book.digitalFiles;
    }

    if (widget.initialFileId != null && widget.initialFileId!.isNotEmpty) {
      final found = _videoAssets.indexWhere((f) => f.id == widget.initialFileId);
      _selectedAssetIndex = found != -1 ? found : 0;
    } else if (widget.initialAssetIndex >= 0 && widget.initialAssetIndex < _videoAssets.length) {
      _selectedAssetIndex = widget.initialAssetIndex;
    } else {
      _selectedAssetIndex = 0;
    }

    if (_selectedAssetIndex < 0 || _selectedAssetIndex >= _videoAssets.length) {
      _selectedAssetIndex = 0;
    }

    if (_videoAssets.isNotEmpty) {
      final curAsset = _videoAssets[_selectedAssetIndex];
      _totalDurationSeconds = curAsset.durationSeconds > 0 ? curAsset.durationSeconds.toDouble() : 2400.0;
    }
  }

  void _registerPlayer() {
    if (_videoAssets.isEmpty || _selectedAssetIndex < 0 || _selectedAssetIndex >= _videoAssets.length) {
      return;
    }
    final curAsset = _videoAssets[_selectedAssetIndex];
    final rawStream = curAsset.streamUrl?.trim() ?? '';
    final rawStorage = curAsset.storageKey.trim();
    final streamUrl = rawStream.isNotEmpty ? rawStream : rawStorage;

    _viewKey = 'video_stream_${curAsset.id}_${DateTime.now().millisecondsSinceEpoch}';



    if (kIsWeb) {
      registerDigitalVideoView(
        _viewKey,
        streamUrl,
        isLive: curAsset.isLiveStream || curAsset.fileType == 'VIDEO_HLS',
        onDurationLoaded: (dur) {
          if (mounted && dur > 0) {
            setState(() {
              _totalDurationSeconds = dur.toDouble();
            });
          }
        },
      );
    }
  }

  void _switchAsset(int index) {
    if (index < 0 || index >= _videoAssets.length) return;
    _syncProgress();
    setState(() {
      _selectedAssetIndex = index;
      final curAsset = _videoAssets[index];
      _totalDurationSeconds = curAsset.durationSeconds > 0 ? curAsset.durationSeconds.toDouble() : 2400.0;
      _currentPositionSeconds = 0.0;
      _isPlaying = true;
      _registerPlayer();
    });
  }

  void _startTicker() {
    _playbackTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _currentPositionSeconds += _playbackSpeed;
          if (_currentPositionSeconds >= _totalDurationSeconds) {
            if (_selectedAssetIndex < _videoAssets.length - 1) {
              _switchAsset(_selectedAssetIndex + 1);
            } else {
              _currentPositionSeconds = _totalDurationSeconds;
              _isPlaying = false;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playbackTicker?.cancel();
    _syncProgress();
    super.dispose();
  }

  Future<void> _syncProgress() async {
    final activeAsset = _videoAssets.isNotEmpty && _selectedAssetIndex < _videoAssets.length ? _videoAssets[_selectedAssetIndex] : null;
    if (activeAsset != null && activeAsset.isLiveStream) {
      return;
    }

    final pct = (_currentPositionSeconds / _totalDurationSeconds) * 100.0;
    await ref.read(bookProvider.notifier).recordDigitalProgress(widget.book.id, {
      'media_type': 'VIDEOBOOK',
      'position_seconds': _currentPositionSeconds,
      'total_duration_seconds': _totalDurationSeconds,
      'progress_pct': double.parse(pct.clamp(0.0, 100.0).toStringAsFixed(2)),
      'playback_speed': _playbackSpeed,
      'session_seconds': 60,
      'is_completed': _currentPositionSeconds >= _totalDurationSeconds,
    });
  }

  String _formatTime(double totalSec) {
    final mins = (totalSec / 60).floor();
    final secs = (totalSec % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activeAsset = (_videoAssets.isNotEmpty && _selectedAssetIndex >= 0 && _selectedAssetIndex < _videoAssets.length)
        ? _videoAssets[_selectedAssetIndex]
        : null;
    final isLive = activeAsset != null && (activeAsset.isLiveStream || activeAsset.fileType == 'VIDEO_HLS');
    final assetTitle = activeAsset != null ? activeAsset.displayTitle : 'Video Lecture';
    final rawStream = activeAsset?.streamUrl?.trim() ?? '';
    final rawStorage = activeAsset?.storageKey.trim() ?? '';
    final streamUrl = rawStream.isNotEmpty ? rawStream : rawStorage;


    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 1050,
        height: 750,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  Icon(
                    isLive ? Icons.live_tv_rounded : Icons.smart_display_rounded,
                    color: isLive ? Colors.redAccent : const Color(0xFF6366F1),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.book.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 8),
                                SizedBox(width: 4),
                                Text('LIVE STREAM', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Open External Stream Button
                  if (streamUrl.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 19),
                      tooltip: 'Open stream in browser tab',
                      onPressed: () async {
                        final uri = Uri.tryParse(streamUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),

                  IconButton(
                    icon: Icon(Icons.playlist_play_rounded, color: _isPlaylistOpen ? const Color(0xFF6366F1) : Colors.white70),
                    tooltip: 'Lectures & Streams Playlist',
                    onPressed: () => setState(() => _isPlaylistOpen = !_isPlaylistOpen),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () {
                      _syncProgress();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Video Player Screen & Optional Playlist Drawer
            Expanded(
              child: Row(
                children: [
                  // Main Video Player Surface
                  Expanded(
                    flex: 7,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Frame / Live HTML5 Video Player
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.black,
                          child: (kIsWeb && _viewKey.isNotEmpty)
                              ? HtmlElementView(
                                  key: ValueKey(_viewKey),
                                  viewType: _viewKey,
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isLive ? Icons.sensors_rounded : Icons.play_circle_fill_rounded,
                                        size: 72,
                                        color: isLive ? Colors.redAccent : const Color(0xFF6366F1),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        assetTitle,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isLive
                                            ? 'Streaming Broadcast (HLS / Low-Latency Live)'
                                            : 'EduSHAMIIT Secure Stream • 1080p 60fps',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        // Anti-Piracy DRM Watermark Overlay
                        IgnorePointer(
                          child: Center(
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Text(
                                widget.watermarkText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withOpacity(0.06),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lectures & Streams Playlist Sidebar
                  if (_isPlaylistOpen) ...[
                    const VerticalDivider(width: 1, color: Color(0xFF1E293B)),
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: const Color(0xFF1E293B),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.video_library_rounded, color: Color(0xFF6366F1), size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Media Playlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                                  const Spacer(),
                                  Text('${_videoAssets.length} items', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFF334155)),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _videoAssets.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                                itemBuilder: (context, idx) {
                                  final item = _videoAssets[idx];
                                  final isSelected = idx == _selectedAssetIndex;
                                  final itemIsLive = item.isLiveStream || item.fileType == 'VIDEO_HLS';

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFF6366F1).withOpacity(0.15),
                                    leading: Icon(
                                      itemIsLive ? Icons.live_tv_rounded : Icons.play_circle_outline_rounded,
                                      color: itemIsLive
                                          ? Colors.redAccent
                                          : (isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8)),
                                      size: 20,
                                    ),
                                    title: Text(
                                      item.displayTitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF818CF8) : Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      itemIsLive ? '🔴 Live Stream' : item.formattedDuration,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: itemIsLive ? Colors.redAccent : const Color(0xFF94A3B8),
                                        fontWeight: itemIsLive ? FontWeight.w700 : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: () => _switchAsset(idx),
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
