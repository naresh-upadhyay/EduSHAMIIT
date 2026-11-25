// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';

final Map<String, html.VideoElement> _videoRegistry = {};

void registerRecordingVideoElement(
  String viewType,
  String url, {
  bool autoplay = false,
  bool showNativeControls = true,
  void Function(bool isPlaying)? onPlayStateChanged,
  void Function(int positionSec, int durationSec)? onTimeUpdate,
  void Function(String message)? onError,
}) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final video = html.VideoElement()
      ..id = 'rec-video-$viewType'
      ..src = url
      ..controls = showNativeControls
      ..autoplay = autoplay
      ..preload = 'metadata'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0B1120'
      ..style.objectFit = 'contain'
      ..style.outline = 'none'
      ..style.borderRadius = '8px';

    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('controlsList', '');

    _videoRegistry[viewType] = video;

    video.onLoadedMetadata.listen((_) {
      final dur = video.duration;
      onTimeUpdate?.call(
        video.currentTime.isFinite ? video.currentTime.round() : 0,
        dur.isFinite ? dur.round() : 0,
      );
    });

    video.onTimeUpdate.listen((_) {
      final dur = video.duration;
      onTimeUpdate?.call(
        video.currentTime.isFinite ? video.currentTime.round() : 0,
        dur.isFinite ? dur.round() : 0,
      );
    });

    video.onPlay.listen((_) => onPlayStateChanged?.call(true));
    video.onPause.listen((_) => onPlayStateChanged?.call(false));
    video.onEnded.listen((_) => onPlayStateChanged?.call(false));

    video.onError.listen((_) {
      final code = video.error?.code;
      String msg = 'Video file could not be loaded';
      if (code == 4) {
        msg = 'Video binary is unavailable or unsupported in this browser.';
      } else if (code == 2) {
        msg = 'Network error interrupted video stream.';
      }
      debugPrint('[RecordingVideoWeb] Error ($code) for $url');
      onError?.call(msg);
    });

    return video;
  });
}

html.VideoElement? _findVideo(String viewType) {
  return _videoRegistry[viewType] ??
      html.document.getElementById('rec-video-$viewType') as html.VideoElement?;
}

bool toggleRecordingPlayback(String viewType) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    if (v.paused) {
      v.play();
      return true;
    } else {
      v.pause();
      return true;
    }
  } catch (_) {
    return false;
  }
}

bool seekRecordingTo(String viewType, double seconds) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    v.currentTime = seconds.clamp(0.0, v.duration.isFinite ? v.duration : seconds);
    return true;
  } catch (_) {
    return false;
  }
}

bool setRecordingVolume(String viewType, double volume, bool muted) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    v.volume = volume.clamp(0.0, 1.0);
    v.muted = muted;
    return true;
  } catch (_) {
    return false;
  }
}

bool setRecordingSpeed(String viewType, double rate) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    v.playbackRate = rate;
    return true;
  } catch (_) {
    return false;
  }
}

bool requestRecordingFullscreen(String viewType) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    v.requestFullscreen();
    return true;
  } catch (_) {
    try {
      js.JsObject.fromBrowserObject(v).callMethod('webkitRequestFullscreen', []);
      return true;
    } catch (_) {
      return false;
    }
  }
}

bool requestRecordingPiP(String viewType) {
  final v = _findVideo(viewType);
  if (v == null) return false;
  try {
    js.JsObject.fromBrowserObject(v).callMethod('requestPictureInPicture', []);
    return true;
  } catch (_) {
    return false;
  }
}
