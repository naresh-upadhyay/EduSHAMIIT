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
  String? _errorText;
  bool _trackedFirstPlay = false;

  @override
  void initState() {
    super.initState();
    _initPlayerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant RecordingPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.resolvedStreamUrl != widget.resolvedStreamUrl) {
      _errorText = null;
      _trackedFirstPlay = false;
      _initPlayerIfNeeded();
    }
  }

  void _initPlayerIfNeeded() {
    final url = (widget.resolvedStreamUrl ?? '').trim();
    if (!kIsWeb || url.isEmpty || url == _registeredUrl) return;

    if (_viewType != null) {
      disposeRecordingVideoElement(_viewType!);
    }

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
        if (playing && !_trackedFirstPlay) {
          _trackedFirstPlay = true;
          widget.onFirstPlay?.call();
        }
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _errorText = msg);
      },
    );
  }

  @override
  void dispose() {
    if (_viewType != null) {
      disposeRecordingVideoElement(_viewType!);
    }
    super.dispose();
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

    return Container(
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
        ],
      ),
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
                  key: ValueKey('rec-fs-${item.id}'),
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
