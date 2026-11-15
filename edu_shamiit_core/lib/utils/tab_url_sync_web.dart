// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void syncTabUrl(String path, int tabIndex) {
  try {
    html.window.history.replaceState(null, '', '$path?tab=$tabIndex');
    html.window.dispatchEvent(html.CustomEvent('tab_changed'));
  } catch (_) {}
}

void notifyTabChanged() {
  try {
    html.window.dispatchEvent(html.CustomEvent('tab_changed'));
  } catch (_) {}
}
