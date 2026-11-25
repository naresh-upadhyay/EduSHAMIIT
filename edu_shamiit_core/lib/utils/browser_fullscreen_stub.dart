import 'dart:async';

void triggerBrowserFullscreen() {}
void exitBrowserFullscreen() {}
bool isBrowserInFullscreen() => false;
Stream<bool> get onBrowserFullscreenChange => const Stream.empty();
