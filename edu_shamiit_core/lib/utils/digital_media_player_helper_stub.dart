// Stub implementation for non-web platforms

void registerDigitalVideoView(
  String viewKey,
  String streamUrl, {
  bool isLive = false,
  void Function(int durationSec)? onDurationLoaded,
}) {}

void registerDigitalAudioView(
  String viewKey,
  String streamUrl, {
  void Function(int durationSec)? onDurationLoaded,
  void Function(double positionSec)? onTimeUpdate,
  void Function()? onPlay,
  void Function()? onPause,
  void Function()? onEnded,
}) {}

void registerDigitalPdfView(
  String viewKey,
  String pdfUrl,
) {}

void pauseWebMedia(String elementId) {}
void playWebMedia(String elementId) {}

void playWebAudio(String viewKey) {}
void pauseWebAudio(String viewKey) {}
void toggleWebAudio(String viewKey) {}
void seekWebAudio(String viewKey, double seconds) {}
void seekRelativeWebAudio(String viewKey, double deltaSeconds) {}
void setAudioSpeedWeb(String viewKey, double speed) {}
void setAudioVolumeWeb(String viewKey, double volume) {}
void disposeWebAudio(String viewKey) {}
