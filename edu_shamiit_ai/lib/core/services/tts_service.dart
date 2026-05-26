import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:edu_shamiit_ai/core/services/tts_web_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/services/tts_web_impl.dart';

class TtsService {
  TtsService._() {
    if (!kIsWeb) {
      init();
    }
  }
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  VoidCallback? _onCompleteCallback;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    try {
      // Set properties for premium quality speech
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        if (_onCompleteCallback != null) {
          _onCompleteCallback!();
        }
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        if (_onCompleteCallback != null) {
          _onCompleteCallback!();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint("TTS Error: $msg");
        if (_onCompleteCallback != null) {
          _onCompleteCallback!();
        }
      });
    } catch (e) {
      debugPrint("TTS Init Error: $e");
    }
  }

  Future<void> speak(String text, {required VoidCallback onComplete}) async {
    _onCompleteCallback = onComplete;
    
    // Auto-detect Hindi/English and set appropriate language
    final hasHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    final lang = hasHindi ? "hi-IN" : "en-US";

    if (kIsWeb) {
      _isSpeaking = true;
      speakWeb(text, lang, () {
        _isSpeaking = false;
        onComplete();
      });
      return;
    }

    try {
      await stop();
      if (text.isEmpty) return;

      await _flutterTts.setLanguage(lang);
      await _flutterTts.speak(text);
      _isSpeaking = true;
    } catch (e) {
      debugPrint("TTS Speak Error: $e");
      onComplete();
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      _isSpeaking = false;
      stopWeb();
      if (_onCompleteCallback != null) {
        _onCompleteCallback!();
        _onCompleteCallback = null;
      }
      return;
    }

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _onCompleteCallback = null;
    } catch (e) {
      debugPrint("TTS Stop Error: $e");
    }
  }
}
