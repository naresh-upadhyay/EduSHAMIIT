/// Conditional import: uses dart:html on web, stub on other platforms.
library;

export 'fullscreen_helper_stub.dart'
    if (dart.library.html) 'fullscreen_helper_web.dart';
