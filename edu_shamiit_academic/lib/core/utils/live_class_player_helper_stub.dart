void registerVideoPlayerView(
  String viewKey,
  String resolvedUrl,
  bool isDirectVideo,
  String embedUrl,
  void Function(int durationSec) onDurationLoaded,
) {}

bool seekWebVideo(int seconds) => false;

bool unmuteWebVideo() => false;

void setWebPointerEvents(bool enabled) {}

String getWebWindowUrl() {
  return '';
}
