import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Singleton service that manages the full voice recording lifecycle:
///   1. Request microphone permission
///   2. Start recording to a temp .wav file (preferred) or .m4a fallback
///   3. Stop and return the File for upload
///   4. Expose real-time amplitude stream for the animated waveform
///
/// WAV is preferred because:
///   - The backend's SpeechRecognition fallback works natively with WAV
///   - No ffmpeg conversion needed → simpler backend, faster response
class VoiceRecorderService {
  VoiceRecorderService._();
  static final VoiceRecorderService instance = VoiceRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  // ── Permission ─────────────────────────────────────────────

  /// Returns true if the user has (or just granted) mic permission.
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      final hasPermission = await _recorder.hasPermission();
      return hasPermission;
    }

    try {
      final hasPermission = await _recorder.hasPermission();
      if (hasPermission) return true;
    } catch (e) {
      debugPrint('VoiceRecorder: recorder.hasPermission error ($e)');
    }

    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('VoiceRecorder: microphone permission denied ($status)');
      return false;
    }
    return true;
  }

  // ── Recording lifecycle ────────────────────────────────────

  /// Start recording. Returns false if permission is denied or already recording.
  Future<bool> startRecording() async {
    if (_isRecording) return false;
    if (!await requestPermission()) return false;

    try {
      final RecordConfig config;
      String extension;

      if (kIsWeb) {
        // Web: prefer WAV → AAC/M4A → Opus/WebM
        if (await _recorder.isEncoderSupported(AudioEncoder.wav)) {
          config = const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 16000,  // 16 kHz is ideal for speech recognition
            numChannels: 1,
          );
          extension = 'wav';
        } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          config = const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 16000,
            numChannels: 1,
          );
          extension = 'm4a';
        } else {
          config = const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 64000,
            sampleRate: 16000,
            numChannels: 1,
          );
          extension = 'webm';
        }
        _currentPath = 'shami_voice_${DateTime.now().millisecondsSinceEpoch}.$extension';
      } else {
        // Mobile (Android / iOS): prefer WAV for best transcription compatibility
        // WAV works natively with the backend's SpeechRecognition fallback
        bool wavSupported = false;
        try {
          wavSupported = await _recorder.isEncoderSupported(AudioEncoder.wav);
        } catch (_) {}

        if (wavSupported) {
          config = const RecordConfig(
            encoder: AudioEncoder.wav,
            bitRate: 128000,
            sampleRate: 16000,  // 16 kHz speech-optimised
            numChannels: 1,
          );
          extension = 'wav';
        } else {
          // Fallback to M4A (AAC) – Gemini handles this natively
          config = const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 16000,
            numChannels: 1,
          );
          extension = 'm4a';
        }

        final dir = await getTemporaryDirectory();
        final filename = 'shami_voice_${DateTime.now().millisecondsSinceEpoch}.$extension';
        _currentPath = p.join(dir.path, filename);
      }

      await _recorder.start(config, path: _currentPath!);

      _isRecording = true;
      debugPrint('VoiceRecorder: started → $_currentPath');
      return true;
    } catch (e) {
      debugPrint('VoiceRecorder: start failed — $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the recorded file.
  /// Returns null if nothing was being recorded.
  Future<XFile?> stopRecording() async {
    if (!_isRecording) return null;
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        debugPrint('VoiceRecorder: stop returned null path');
        return null;
      }

      if (kIsWeb) {
        debugPrint('VoiceRecorder: stopped on web → $path');
        return XFile(path);
      } else {
        final file = File(path);
        if (!file.existsSync() || file.lengthSync() == 0) {
          debugPrint('VoiceRecorder: output file missing or empty');
          return null;
        }
        debugPrint('VoiceRecorder: stopped → $path (${file.lengthSync()} bytes)');
        return XFile(path);
      }
    } catch (e) {
      debugPrint('VoiceRecorder: stop failed — $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel without saving.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.cancel();
    } catch (_) {}
    _isRecording = false;
    if (_currentPath != null && !kIsWeb) {
      try {
        File(_currentPath!).deleteSync();
      } catch (_) {}
    }
  }

  /// Stream of amplitude values in dBFS for the waveform visualiser.
  /// Emits every 80 ms while recording is active.
  Stream<double> get amplitudeStream async* {
    while (_isRecording) {
      try {
        final amp = await _recorder.getAmplitude();
        // current is in dBFS (max = 0). Normalise to 0.0–1.0
        final normalised = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        yield normalised;
      } catch (_) {
        yield 0.0;
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
