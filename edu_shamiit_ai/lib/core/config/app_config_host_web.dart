// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Returns the browser's hostname (e.g. "192.168.1.10" or "localhost").
String getWebHostname() {
  try {
    return html.window.location.hostname ?? '127.0.0.1';
  } catch (_) {
    return '127.0.0.1';
  }
}
