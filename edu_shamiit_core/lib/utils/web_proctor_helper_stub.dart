import 'package:flutter/foundation.dart';

class WebProctorLifecycleSubscription {
  final VoidCallback _onDispose;
  const WebProctorLifecycleSubscription(this._onDispose);
  void dispose() => _onDispose();
}

WebProctorLifecycleSubscription registerWebProctorLifecycleListeners({
  VoidCallback? onVisibilityHidden,
  VoidCallback? onVisibilityVisible,
  VoidCallback? onBlur,
  void Function(bool isFullscreen)? onFullscreenChanged,
  void Function(bool isOnline)? onNetworkChanged,
}) {
  return const WebProctorLifecycleSubscription(_noop);
}

void _noop() {}

void registerWebFocusListener(void Function() onFocusLost) {
  // No-op on mobile/native platforms
}

bool isProctorNetworkOnline() => true;

Map<String, dynamic> getProctorBrowserSummary() => {
  'userAgent': 'Antigravity / Flutter',
  'language': 'en',
  'platform': 'native',
};
