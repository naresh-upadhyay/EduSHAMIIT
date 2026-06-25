/// Returns the browser's hostname (e.g. "192.168.1.10" or "localhost").
/// Uses Uri.base (works without dart:html imports).
String getWebHostname() {
  final host = Uri.base.host;
  return host.isNotEmpty ? host : '127.0.0.1';
}
