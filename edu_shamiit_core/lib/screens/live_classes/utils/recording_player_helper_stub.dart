void registerRecordingVideoElement(
  String viewType,
  String url, {
  bool autoplay = false,
  bool showNativeControls = true,
  void Function(bool isPlaying)? onPlayStateChanged,
  void Function(int positionSec, int durationSec)? onTimeUpdate,
  void Function(String message)? onError,
}) {}

bool toggleRecordingPlayback(String viewType) => false;
bool seekRecordingTo(String viewType, double seconds) => false;
bool setRecordingVolume(String viewType, double volume, bool muted) => false;
bool setRecordingSpeed(String viewType, double rate) => false;
bool requestRecordingFullscreen(String viewType) => false;
bool requestRecordingPiP(String viewType) => false;
void disposeRecordingVideoElement(String viewType) {}
