// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class WebProctorLifecycleSubscription {
  final VoidCallback _onDispose;
  WebProctorLifecycleSubscription(this._onDispose);
  void dispose() => _onDispose();
}

WebProctorLifecycleSubscription registerWebProctorLifecycleListeners({
  VoidCallback? onVisibilityHidden,
  VoidCallback? onVisibilityVisible,
  VoidCallback? onBlur,
  void Function(bool isFullscreen)? onFullscreenChanged,
  void Function(bool isOnline)? onNetworkChanged,
}) {
  final subscriptions = <StreamSubscription>[];

  if (onVisibilityHidden != null || onVisibilityVisible != null) {
    subscriptions.add(html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) {
        onVisibilityHidden?.call();
      } else {
        onVisibilityVisible?.call();
      }
    }));
  }

  if (onBlur != null) {
    subscriptions.add(html.window.onBlur.listen((_) {
      onBlur();
    }));
  }

  if (onFullscreenChanged != null) {
    subscriptions.add(html.document.onFullscreenChange.listen((_) {
      onFullscreenChanged(html.document.fullscreenElement != null);
    }));
  }

  if (onNetworkChanged != null) {
    subscriptions.add(html.window.onOnline.listen((_) {
      onNetworkChanged(true);
    }));
    subscriptions.add(html.window.onOffline.listen((_) {
      onNetworkChanged(false);
    }));
  }

  return WebProctorLifecycleSubscription(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });
}

void registerWebFocusListener(void Function() onFocusLost) {
  html.window.onBlur.listen((event) {
    onFocusLost();
  });
}

bool isProctorNetworkOnline() {
  return html.window.navigator.onLine ?? true;
}

Map<String, dynamic> getProctorBrowserSummary() {
  return {
    'userAgent': html.window.navigator.userAgent,
    'language': html.window.navigator.language,
    'platform': html.window.navigator.platform ?? 'web',
  };
}
