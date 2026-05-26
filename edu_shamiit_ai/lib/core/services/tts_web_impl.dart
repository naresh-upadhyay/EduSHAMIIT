// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui';
import 'package:flutter/foundation.dart';

void speakWeb(String text, String lang, VoidCallback onComplete) {
  try {
    // 1. Stop any currently speaking speech
    html.window.speechSynthesis?.cancel();

    // 2. Clean any remaining markdown tags or special chars just in case
    final cleanText = text.replaceAll(RegExp(r'\*\*|__|\*|_|`|#'), '');

    // 3. Create the utterance
    final utterance = html.SpeechSynthesisUtterance(cleanText);
    utterance.lang = lang;
    utterance.rate = 1.0;
    utterance.volume = 1.0;
    utterance.pitch = 1.0;

    // 4. Attach completion listeners
    utterance.onEnd.listen((_) {
      onComplete();
    });

    utterance.onError.listen((e) {
      debugPrint("Web TTS Utterance Error: $e");
      onComplete();
    });

    // 5. Speak synchronously to maintain the clicked gesture context!
    html.window.speechSynthesis?.speak(utterance);
  } catch (e) {
    debugPrint("Web SpeechSynthesis Error: $e");
    onComplete();
  }
}

void stopWeb() {
  try {
    html.window.speechSynthesis?.cancel();
  } catch (e) {
    debugPrint("Web SpeechSynthesis Stop Error: $e");
  }
}
