import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Singleton service that manages the full voice recording lifecycle:
///   1. Request microphone permission
///   2. Start recording to a temp .m4a file
///   3. Stop and return the File for upload
///   4. Expose real-time amplitude stream for the animated waveform
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
      final dir = await getTemporaryDirectory();
      final filename = 'shami_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentPath = p.join(dir.path, filename);

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,   // produces .m4a — Gemini accepts audio/mp4
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

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
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        debugPrint('VoiceRecorder: stop returned null path');
        return null;
      }
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) {
        debugPrint('VoiceRecorder: output file missing or empty');
        return null;
      }
      debugPrint('VoiceRecorder: stopped → $path (${file.lengthSync()} bytes)');
      return file;
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
    if (_currentPath != null) {
      try { File(_currentPath!).deleteSync(); } catch (_) {}
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
