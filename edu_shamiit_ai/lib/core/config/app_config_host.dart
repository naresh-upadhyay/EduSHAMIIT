/// Conditional import: uses dart:html on web, stub on other platforms.
export 'app_config_host_stub.dart'
    if (dart.library.html) 'app_config_host_web.dart';
