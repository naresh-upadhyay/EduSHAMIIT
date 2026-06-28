/// Conditional import: uses dart:html on web, stub on other platforms.
library;

export 'app_config_host_stub.dart'
    if (dart.library.html) 'app_config_host_web.dart';
