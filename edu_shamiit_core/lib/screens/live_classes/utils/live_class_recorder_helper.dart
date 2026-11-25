import 'dart:typed_data';

export 'live_class_recorder_helper_stub.dart'
    if (dart.library.html) 'live_class_recorder_helper_web.dart';

class StageCaptureFrame {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final bool isBoardOrOverlayActive;

  const StageCaptureFrame({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    required this.isBoardOrOverlayActive,
  });
}

typedef StageFrameProvider = Future<StageCaptureFrame?> Function({
  bool includeStandardStage,
});

class LiveClassCaptureStartResult {
  final bool started;
  final String sourceLabel;
  final String? errorMessage;

  const LiveClassCaptureStartResult({
    required this.started,
    this.sourceLabel = '',
    this.errorMessage,
  });
}

class LiveClassCaptureStopResult {
  final Uint8List? bytes;
  final String fileName;
  final String mimeType;
  final int durationSeconds;

  const LiveClassCaptureStopResult({
    this.bytes,
    this.fileName = 'live_class_recording.webm',
    this.mimeType = 'video/webm',
    this.durationSeconds = 0,
  });
}
