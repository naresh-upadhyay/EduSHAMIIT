import 'dart:html' as html;

void registerWebFocusListener(void Function() onFocusLost) {
  html.window.onBlur.listen((event) {
    onFocusLost();
  });
}
