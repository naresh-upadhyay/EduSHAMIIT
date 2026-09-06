// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';

void _ensureHlsScriptLoaded(void Function() onReady) {
  if (js.context.hasProperty('Hls')) {
    onReady();
    return;
  }
  final existing = html.document.querySelector('script[src*="hls.js"]');
  if (existing != null) {
    existing.onLoad.listen((_) => onReady());
    return;
  }

  final script = html.ScriptElement()
    ..src = 'https://cdn.jsdelivr.net/npm/hls.js@latest'
    ..type = 'text/javascript';
  script.onLoad.listen((_) => onReady());
  html.document.head?.append(script);
}

String _transformVideoUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';

  // YouTube standard
  final ytWatchRegex = RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w\-]+)');
  final ytMatch = ytWatchRegex.firstMatch(trimmed);
  if (ytMatch != null) {
    final videoId = ytMatch.group(1);
    return 'https://www.youtube.com/embed/$videoId?autoplay=1&enablejsapi=1&rel=0';
  }

  // Vimeo standard
  final vimeoRegex = RegExp(r'vimeo\.com\/(\d+)');
  final vimeoMatch = vimeoRegex.firstMatch(trimmed);
  if (vimeoMatch != null) {
    final videoId = vimeoMatch.group(1);
    return 'https://player.vimeo.com/video/$videoId?autoplay=1';
  }

  return trimmed;
}

void registerDigitalVideoView(
  String viewKey,
  String rawStreamUrl, {
  bool isLive = false,
  void Function(int durationSec)? onDurationLoaded,
}) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewKey,
    (int viewId) {
      final streamUrl = _transformVideoUrl(rawStreamUrl);

      if (streamUrl.isEmpty) {
        final div = html.DivElement()
          ..style.display = 'flex'
          ..style.flexDirection = 'column'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#0F172A'
          ..style.color = '#94A3B8'
          ..style.fontSize = '14px'
          ..style.fontFamily = 'sans-serif';
        div.append(html.SpanElement()..text = '⚠️ No video or stream URL specified.');
        return div;
      }

      // Check if embed (YouTube / Vimeo / IFrame embed)
      if (streamUrl.contains('youtube.com/embed') || streamUrl.contains('player.vimeo.com')) {
        return html.IFrameElement()
          ..id = 'video-element-$viewKey'
          ..width = '100%'
          ..height = '100%'
          ..src = streamUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
          ..attributes['allowfullscreen'] = 'true';
      }

      // Standard HTML5 Video Element (HLS or Direct MP4/WebM)
      final video = html.VideoElement()
        ..id = 'video-element-$viewKey'
        ..controls = true
        ..autoplay = true
        ..muted = true // Start muted to satisfy browser autoplay requirements
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.background = '#000000'
        ..style.objectFit = 'contain';

      video.setAttribute('playsinline', '');
      video.setAttribute('webkit-playsinline', '');
      video.setAttribute('crossorigin', 'anonymous');

      // Expose video element globally for reliable asynchronous JS access across render cycles
      js.context['__activeVideo_$viewKey'] = video;

      // Listen for duration
      video.onLoadedMetadata.listen((_) {
        try {
          final dur = video.duration;
          if (dur > 0 && dur.isFinite && onDurationLoaded != null) {
            onDurationLoaded(dur.round());
          }
        } catch (e) {
          debugPrint('[DigitalVideo] Duration read error: $e');
        }
      });

      final isHls = streamUrl.contains('.m3u8') || streamUrl.contains('live') || isLive;

      if (isHls) {
        _ensureHlsScriptLoaded(() {
          try {
            js.context.callMethod('eval', [
              """
              (function() {
                function startHls(attempt) {
                  var vid = window['__activeVideo_$viewKey'] || document.getElementById('video-element-$viewKey');
                  if (!vid) {
                    if ((attempt || 0) < 25) {
                      setTimeout(function() { startHls((attempt || 0) + 1); }, 40);
                    }
                    return;
                  }

                  if (vid.__hlsInstance) {
                    try { vid.__hlsInstance.destroy(); } catch(e) {}
                    vid.__hlsInstance = null;
                  }

                  if (typeof Hls !== 'undefined' && Hls.isSupported()) {
                    var hls = new Hls({
                      enableWorker: true,
                      lowLatencyMode: true,
                      backBufferLength: 90,
                      autoStartLoad: true
                    });
                    vid.__hlsInstance = hls;
                    hls.loadSource('$streamUrl');
                    hls.attachMedia(vid);
                    hls.on(Hls.Events.MANIFEST_PARSED, function() {
                      vid.play().catch(function() {
                        vid.muted = true;
                        vid.play().catch(function() {});
                      });
                    });
                    hls.on(Hls.Events.ERROR, function(event, data) {
                      if (data.fatal) {
                        switch (data.type) {
                          case Hls.ErrorTypes.NETWORK_ERROR:
                            hls.startLoad();
                            break;
                          case Hls.ErrorTypes.MEDIA_ERROR:
                            hls.recoverMediaError();
                            break;
                          default:
                            hls.destroy();
                            vid.src = '$streamUrl';
                            vid.play().catch(function() {});
                            break;
                        }
                      }
                    });
                  } else if (vid.canPlayType('application/vnd.apple.mpegurl')) {
                    vid.src = '$streamUrl';
                    vid.play().catch(function() {});
                  } else {
                    vid.src = '$streamUrl';
                    vid.play().catch(function() {});
                  }
                }

                startHls(0);
              })();
              """
            ]);
          } catch (e) {
            debugPrint('[DigitalVideo] Hls.js initialization fallback: $e');
            video.src = streamUrl;
            video.play().catchError((_) {});
          }
        });
      } else {
        video.src = streamUrl;
        video.play().catchError((_) {});
      }

      return video;
    },
  );
}

void registerDigitalAudioView(
  String viewKey,
  String rawAudioUrl, {
  void Function(int durationSec)? onDurationLoaded,
  void Function(double positionSec)? onTimeUpdate,
  void Function()? onPlay,
  void Function()? onPause,
  void Function()? onEnded,
}) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewKey,
    (int viewId) {
      final audioUrl = rawAudioUrl.trim();
      final audio = html.AudioElement()
        ..id = 'audio-element-$viewKey'
        ..controls = false
        ..autoplay = true
        ..style.display = 'none';

      // Store globally for direct access
      js.context['__activeAudio_$viewKey'] = audio;

      audio.onLoadedMetadata.listen((_) {
        try {
          final dur = audio.duration;
          if (dur > 0 && dur.isFinite && onDurationLoaded != null) {
            onDurationLoaded(dur.round());
          }
        } catch (e) {
          debugPrint('[DigitalAudio] Duration read error: $e');
        }
      });

      audio.onTimeUpdate.listen((_) {
        try {
          final pos = audio.currentTime;
          if (pos.isFinite && onTimeUpdate != null) {
            onTimeUpdate(pos.toDouble());
          }
        } catch (_) {}
      });

      audio.onPlay.listen((_) {
        if (onPlay != null) onPlay();
      });

      audio.onPause.listen((_) {
        if (onPause != null) onPause();
      });

      audio.onEnded.listen((_) {
        if (onEnded != null) onEnded();
      });

      if (audioUrl.isNotEmpty) {
        audio.src = audioUrl;
        audio.play().catchError((err) {
          debugPrint('[DigitalAudio] Autoplay handled by browser: $err');
        });
      }
      return audio;
    },
  );
}

html.AudioElement? _getAudioElement(String viewKey) {
  try {
    final direct = js.context['__activeAudio_$viewKey'] as html.AudioElement?;
    if (direct != null) return direct;
    return html.document.getElementById('audio-element-$viewKey') as html.AudioElement?;
  } catch (_) {
    return null;
  }
}

void playWebAudio(String viewKey) {
  try {
    final audio = _getAudioElement(viewKey);
    audio?.play();
  } catch (e) {
    debugPrint('[DigitalAudio] play error: $e');
  }
}

void pauseWebAudio(String viewKey) {
  try {
    final audio = _getAudioElement(viewKey);
    audio?.pause();
  } catch (e) {
    debugPrint('[DigitalAudio] pause error: $e');
  }
}

void toggleWebAudio(String viewKey) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null) {
      if (audio.paused) {
        audio.play();
      } else {
        audio.pause();
      }
    }
  } catch (e) {
    debugPrint('[DigitalAudio] toggle error: $e');
  }
}

void seekWebAudio(String viewKey, double seconds) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null && seconds >= 0) {
      audio.currentTime = seconds;
    }
  } catch (e) {
    debugPrint('[DigitalAudio] seek error: $e');
  }
}

void seekRelativeWebAudio(String viewKey, double deltaSeconds) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null) {
      final cur = audio.currentTime;
      final dur = audio.duration.isFinite ? audio.duration : 999999.0;
      final newTime = (cur + deltaSeconds).clamp(0.0, dur);
      audio.currentTime = newTime;
    }
  } catch (e) {
    debugPrint('[DigitalAudio] seekRelative error: $e');
  }
}

void setAudioSpeedWeb(String viewKey, double speed) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null && speed > 0) {
      audio.playbackRate = speed;
    }
  } catch (e) {
    debugPrint('[DigitalAudio] speed error: $e');
  }
}

void setAudioVolumeWeb(String viewKey, double volume) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null) {
      audio.volume = volume.clamp(0.0, 1.0);
    }
  } catch (e) {
    debugPrint('[DigitalAudio] volume error: $e');
  }
}

void disposeWebAudio(String viewKey) {
  try {
    final audio = _getAudioElement(viewKey);
    if (audio != null) {
      audio.pause();
      audio.src = '';
      js.context.deleteProperty('__activeAudio_$viewKey');
    }
  } catch (_) {}
}

void registerDigitalPdfView(
  String viewKey,
  String rawPdfUrl,
) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewKey,
    (int viewId) {
      final pdfUrl = rawPdfUrl.trim();
      if (pdfUrl.isEmpty) {
        final div = html.DivElement()
          ..style.display = 'flex'
          ..style.flexDirection = 'column'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#0F172A'
          ..style.color = '#94A3B8'
          ..style.fontSize = '14px'
          ..style.fontFamily = 'sans-serif';
        div.append(html.SpanElement()..text = '⚠️ No PDF document URL available.');
        return div;
      }

      String finalUrl = pdfUrl;
      if (!finalUrl.contains('#') && finalUrl.toLowerCase().contains('.pdf')) {
        finalUrl = '$finalUrl#toolbar=1&navpanes=1&scrollbar=1';
      }

      final iframe = html.IFrameElement()
        ..id = 'pdf-frame-$viewKey'
        ..src = finalUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';

      return iframe;
    },
  );
}

void pauseWebMedia(String elementId) {
  try {
    final el = html.document.getElementById('video-element-$elementId') as html.VideoElement?;
    el?.pause();
  } catch (_) {}
}

void playWebMedia(String elementId) {
  try {
    final el = html.document.getElementById('video-element-$elementId') as html.VideoElement?;
    el?.play();
  } catch (_) {}
}
