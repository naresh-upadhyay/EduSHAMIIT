import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

/// Singleton handoff registry to transfer active hardware media streams seamlessly
/// between [ExamPrestartScreen] and [TakeExamScreen] without triggering repeated
/// browser screen-share picker dialogs or interrupting active capture sessions.
class ExamPrestartHandoff {
  static lk.LocalVideoTrack? screenTrack;
  static rtc.MediaStream? screenStream;
  static bool screenSharedInPrestart = false;

  /// Hand off an active LiveKit screen-share track from pre-start checks to take-exam.
  static void handoffScreenTrack(lk.LocalVideoTrack track) {
    screenTrack = track;
    screenStream = track.mediaStream;
    screenSharedInPrestart = true;
    debugPrint('[ExamPrestartHandoff] LiveKit screen track handed off for seamless exam transition.');
  }

  /// Hand off an active screen-share stream from pre-start checks to take-exam.
  static void handoffScreen(rtc.MediaStream stream) {
    screenStream = stream;
    screenSharedInPrestart = true;
    debugPrint('[ExamPrestartHandoff] Screen stream handed off for seamless exam transition.');
  }

  /// Check whether an active, valid screen share track or stream is available for reuse.
  static bool hasActiveScreenTrack() {
    if (screenTrack != null && !screenTrack!.isDisposed) {
      return screenTrack!.isActive;
    }
    return hasActiveScreenStream();
  }

  /// Backward-compatible check for active screen stream.
  static bool hasActiveScreenStream() {
    if (screenTrack != null && !screenTrack!.isDisposed) {
      return screenTrack!.isActive;
    }
    if (screenStream == null) return false;
    final tracks = screenStream!.getVideoTracks();
    return tracks.isNotEmpty && tracks.any((t) => t.enabled);
  }

  /// Retrieve and consume the active LiveKit [LocalVideoTrack] for room publishing.
  static lk.LocalVideoTrack? takeScreenTrack() {
    if (screenTrack != null && !screenTrack!.isDisposed) {
      final track = screenTrack;
      screenTrack = null;
      screenStream = null;
      return track;
    }
    return null;
  }

  /// Backward-compatible method to get or take the LiveKit screen track.
  static lk.LocalVideoTrack? createLivekitScreenTrack() {
    return takeScreenTrack();
  }

  /// Stop all tracks and release camera, microphone and screen share hardware completely.
  static void stopAndReleaseAll() {
    if (screenTrack != null) {
      try {
        screenTrack!.stop();
        screenTrack!.dispose();
      } catch (_) {}
      screenTrack = null;
    }
    if (screenStream != null) {
      for (final t in screenStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      screenStream = null;
    }
    screenSharedInPrestart = false;
    debugPrint('[ExamPrestartHandoff] All pre-start hardware streams and tracks released.');
  }
}
