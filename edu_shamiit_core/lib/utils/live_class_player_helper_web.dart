// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';

void registerVideoPlayerView(
  String viewKey,
  String resolvedUrl,
  bool isDirectVideo,
  String embedUrl,
  void Function(int durationSec) onDurationLoaded,
) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewKey,
    (int viewId) {
      if (resolvedUrl.isEmpty) {
        final div = html.DivElement()
          ..style.display = 'flex'
          ..style.flexDirection = 'column'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#0F172A'
          ..style.color = 'rgba(255,255,255,0.6)'
          ..style.fontSize = '16px'
          ..style.fontFamily = 'sans-serif';

        final textSpan = html.SpanElement()
          ..text = '🎥 Recording not generated yet';
        div.append(textSpan);
        return div;
      } else if (isDirectVideo) {
        final video = html.VideoElement()
          ..id = 'live-class-video-player'
          ..width = 1280
          ..height = 720
          ..src = resolvedUrl
          ..controls = true
          ..autoplay = true
          ..muted = true
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '#000';
        video.setAttribute('playsinline', '');
        video.setAttribute('webkit-playsinline', '');

        // Listen for metadata load to capture actual duration
        video.onLoadedMetadata.listen((event) {
          try {
            final num actualDur = video.duration;
            if (actualDur > 0 && actualDur.isFinite) {
              onDurationLoaded(actualDur.round());
            }
          } catch (e) {
            debugPrint('[Player] Error reading video duration: $e');
          }
        });

        return video;
      } else {
        return html.IFrameElement()
          ..id = 'live-class-iframe-player'
          ..width = '100%'
          ..height = '100%'
          ..src = embedUrl
          ..style.border = 'none'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
          ..attributes['allowfullscreen'] = 'true';
      }
    },
  );
}

bool seekWebVideo(int seconds) {
  try {
    final video = html.document.getElementById('live-class-video-player')
        as html.VideoElement?;
    if (video != null) {
      video.currentTime = seconds;
      video.play();
      return true;
    }
  } catch (e) {
    debugPrint('Error seeking: $e');
  }
  return false;
}

bool unmuteWebVideo() {
  try {
    final video = html.document.getElementById('live-class-video-player')
        as html.VideoElement?;
    if (video != null) {
      video.muted = false;
      return true;
    }
  } catch (e) {
    debugPrint('Error unmuting: $e');
  }
  return false;
}

void setWebPointerEvents(bool enabled) {
  try {
    final video = html.document.getElementById('live-class-video-player');
    if (video != null) {
      video.style.pointerEvents = enabled ? 'auto' : 'none';
    }
    final iframe = html.document.getElementById('live-class-iframe-player');
    if (iframe != null) {
      iframe.style.pointerEvents = enabled ? 'auto' : 'none';
    }
  } catch (e) {
    debugPrint('Error setting pointer events: $e');
  }
}

String getWebWindowUrl() {
  try {
    return html.window.location.href;
  } catch (e) {
    debugPrint('Error getting window location: $e');
    return '';
  }
}
