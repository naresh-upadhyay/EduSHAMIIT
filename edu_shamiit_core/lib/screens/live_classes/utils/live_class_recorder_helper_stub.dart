import 'live_class_recorder_helper.dart';

class LiveClassBrowserRecorder {
  LiveClassBrowserRecorder._();
  static final LiveClassBrowserRecorder instance = LiveClassBrowserRecorder._();

  bool get isRecording => false;
  bool get isPaused => false;
  String get sourceLabel => '';

  void registerStageFrameProvider(StageFrameProvider? provider) {}

  Future<LiveClassCaptureStartResult> startCapture() async {
    return const LiveClassCaptureStartResult(
      started: false,
      errorMessage: 'Browser media capture is only active in web sessions.',
    );
  }

  void pause() {}
  void resume() {}

  Future<LiveClassCaptureStopResult> stopAndCollect() async {
    return const LiveClassCaptureStopResult();
  }
}
