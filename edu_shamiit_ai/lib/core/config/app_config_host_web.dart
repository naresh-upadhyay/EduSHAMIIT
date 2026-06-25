import 'dart:html' show window;

/// Returns the browser's hostname (e.g. "192.168.1.10" or "localhost").
/// On GitHub Pages, detects that and returns the appropriate info.
String getWebHostname() {
  final host = Uri.base.host;
  return host.isNotEmpty ? host : '127.0.0.1';
}

/// Returns the base path for the site.
/// On GitHub Pages (user.github.io/repo-name), this is "/repo-name/".
/// On custom domains, this is "/".
String getWebBasePath() {
  final path = Uri.base.path;
  // If the path is just "/" or empty, no subfolder
  if (path.isEmpty || path == '/') return '/';
  // Return the first path segment as the base
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return '/';
  return '/${segments.first}/';
}