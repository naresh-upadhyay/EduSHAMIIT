// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

void triggerBrowserFullscreen() {
  try {
    if (html.document.fullscreenElement == null) {
      html.document.documentElement?.requestFullscreen();
    }
  } catch (_) {}
}

void exitBrowserFullscreen() {
  try {
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    }
  } catch (_) {}
}

bool isBrowserInFullscreen() {
  try {
    return html.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

Stream<bool> get onBrowserFullscreenChange {
  return html.document.onFullscreenChange.map((_) => isBrowserInFullscreen());
}
