// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web implementation using HTML5 Fullscreen API.
void toggleBrowserFullscreen(bool enter) {
  try {
    final doc = html.document;
    if (enter) {
      doc.documentElement?.requestFullscreen();
    } else {
      if (doc.fullscreenElement != null) {
        doc.exitFullscreen();
      }
    }
  } catch (e) {
    debugPrint('[FullscreenHelper] Error toggling fullscreen: $e');
  }
}

/// Listen to browser fullscreen state changes.
Object? subscribeToFullscreenChanges(VoidCallback onFullscreenExit) {
  try {
    final subscription = html.document.onFullscreenChange.listen((event) {
      if (html.document.fullscreenElement == null) {
        onFullscreenExit();
      }
    });
    return subscription;
  } catch (e) {
    return null;
  }
}

/// Unsubscribe from browser fullscreen state changes.
void unsubscribeFromFullscreenChanges(Object? subscription) {
  if (subscription is StreamSubscription) {
    subscription.cancel();
  }
}
