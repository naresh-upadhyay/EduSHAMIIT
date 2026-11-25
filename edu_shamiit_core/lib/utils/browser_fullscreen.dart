export 'browser_fullscreen_stub.dart'
    if (dart.library.html) 'browser_fullscreen_web.dart';

import 'browser_fullscreen_stub.dart'
    if (dart.library.html) 'browser_fullscreen_web.dart';

void toggleNativeBrowserFullscreen({bool? forceState}) {
  final inFs = isBrowserInFullscreen();
  if (forceState != null) {
    if (forceState) {
      triggerBrowserFullscreen();
    } else {
      exitBrowserFullscreen();
    }
  } else {
    if (inFs) {
      exitBrowserFullscreen();
    } else {
      triggerBrowserFullscreen();
    }
  }
}

void leaveBrowserFullscreen() {
  exitBrowserFullscreen();
}
