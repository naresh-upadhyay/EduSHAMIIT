// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'live_class_recorder_helper.dart';

class LiveClassBrowserRecorder {
  LiveClassBrowserRecorder._();
  static final LiveClassBrowserRecorder instance = LiveClassBrowserRecorder._();

  // Full HD 1080p canvas for crystal-clear Whiteboard, Screen Share, and Video capture
  static const int _canvasW = 1920;
  static const int _canvasH = 1080;

  html.MediaRecorder? _recorder;
  html.MediaStream? _composedStream;
  final List<html.Blob> _chunks = [];

  html.DivElement? _hiddenHostEl;
  html.CanvasRenderingContext2D? _recordCtx;
  html.CanvasElement? _scratchCanvas;
  html.CanvasRenderingContext2D? _scratchCtx;
  Timer? _renderTimer;
  bool _isCapturingFrame = false;
  DateTime? _lastStageCaptureAt;
  StageCaptureFrame? _lastStageFrame;

  StageFrameProvider? _stageFrameProvider;
  DateTime? _startedAt;
  bool _isRecording = false;
  bool _isPaused = false;
  String _mimeType = 'video/webm';
  String _sourceLabel = '';

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String get sourceLabel => _sourceLabel;

  void registerStageFrameProvider(StageFrameProvider? provider) {
    _stageFrameProvider = provider;
  }

  void _ensureAudioMixerScripts() {
    try {
      js.context.callMethod('eval', [
        '''
        (function() {
          if (!window._eduIsScreenShareVideo) {
            window._eduIsScreenShareVideo = function(videoEl) {
              try {
                const s = videoEl && videoEl.srcObject;
                if (!s || typeof s.getVideoTracks !== 'function') return false;
                const vt = s.getVideoTracks()[0];
                if (!vt) return false;
                const label = (vt.label || '').toLowerCase();
                if (label.includes('screen') || label.includes('window') || label.includes('display') || label.includes('monitor') || label.includes('tab') || label.includes('entire')) {
                  return true;
                }
                const settings = typeof vt.getSettings === 'function' ? vt.getSettings() : {};
                if (settings && settings.displaySurface) return true;
              } catch (_) {}
              return false;
            };
          }

          if (!window._eduRecorderAudioMixer) {
            window._eduRecorderAudioMixer = {
              ctx: null,
              dest: null,
              osc: null,
              wiredTrackIds: new Set(),

              initAndAttachToStream: function(targetStream) {
                this.dispose();
                const AudioCtx = window.AudioContext || window.webkitAudioContext;
                if (!AudioCtx || !targetStream) return false;
                const ctx = new AudioCtx();
                if (ctx.state === 'suspended') {
                  try { ctx.resume(); } catch (_) {}
                }
                const dest = ctx.createMediaStreamDestination();

                // Silent carrier guarantees valid continuous Opus track even while meeting mic is muted
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                gain.gain.value = 0.0;
                osc.connect(gain);
                gain.connect(dest);
                osc.start();

                this.ctx = ctx;
                this.dest = dest;
                this.osc = osc;
                this.wiredTrackIds = new Set();
                this.syncTracks();
                const audioTracks = dest.stream ? dest.stream.getAudioTracks() : [];
                for (const at of audioTracks) {
                  targetStream.addTrack(at);
                }
                return audioTracks.length > 0;
              },

              _connectTrack: function(track) {
                if (!this.ctx || !this.dest || !track) return;
                if (track.readyState !== 'live' || !track.enabled) return;
                if (this.wiredTrackIds.has(track.id)) return;
                try {
                  this.wiredTrackIds.add(track.id);
                  const src = this.ctx.createMediaStreamSource(new MediaStream([track]));
                  src.connect(this.dest);
                } catch (_) {}
              },

              syncTracks: function() {
                if (!this.ctx || !this.dest) return;
                try {
                  if (this.ctx.state === 'suspended') {
                    try { this.ctx.resume(); } catch (_) {}
                  }
                  // 1. Passively tap already-active local meeting streams ONLY if user enabled them
                  const active = window._activeEduStreams;
                  if (Array.isArray(active)) {
                    for (const s of active) {
                      if (!s || typeof s.getAudioTracks !== 'function') continue;
                      for (const t of s.getAudioTracks()) {
                        this._connectTrack(t);
                      }
                    }
                  }
                  // 2. Passively tap active live meeting <audio>/<video srcObject> elements (ignore saved playback players)
                  const els = document.querySelectorAll('audio, video');
                  for (const el of els) {
                    if (el.id && el.id.startsWith('rec-video-')) continue;
                    const s = el.srcObject;
                    if (!s || s === this.dest.stream || typeof s.getAudioTracks !== 'function') continue;
                    if (el.muted) continue;
                    for (const t of s.getAudioTracks()) {
                      this._connectTrack(t);
                    }
                  }
                } catch (_) {}
              },

              dispose: function() {
                try { if (this.osc) this.osc.stop(); } catch (_) {}
                try { if (this.dest && this.dest.stream) this.dest.stream.getTracks().forEach(t => t.stop()); } catch (_) {}
                try { if (this.ctx && this.ctx.state !== 'closed') this.ctx.close(); } catch (_) {}
                this.ctx = null;
                this.dest = null;
                this.osc = null;
                this.wiredTrackIds = new Set();
              }
            };
          }
        })();
        '''
      ]);
    } catch (e) {
      debugPrint('[LiveClassRecorder] Audio mixer init notice: $e');
    }
  }

  String _pickSupportedMimeType({required bool hasAudio}) {
    final candidates = hasAudio
        ? const [
            'video/webm;codecs=vp9,opus',
            'video/webm;codecs=vp8,opus',
            'video/webm',
          ]
        : const [
            'video/webm;codecs=vp9',
            'video/webm;codecs=vp8',
            'video/webm',
          ];
    for (final c in candidates) {
      try {
        if (html.MediaRecorder.isTypeSupported(c)) return c;
      } catch (_) {}
    }
    return 'video/webm';
  }

  Future<LiveClassCaptureStartResult> startCapture() async {
    if (_isRecording) {
      return LiveClassCaptureStartResult(started: true, sourceLabel: _sourceLabel);
    }

    if (_stageFrameProvider == null) {
      return const LiveClassCaptureStartResult(
        started: false,
        errorMessage: 'Open a live classroom session first to start recording.',
      );
    }

    _cleanupStreams();
    _chunks.clear();
    _ensureAudioMixerScripts();

    try {
      // Mount 1920x1080 compositor canvas offscreen in DOM so Chrome ticks frames smoothly
      final hostDiv = html.DivElement()
        ..style.position = 'fixed'
        ..style.left = '-10000px'
        ..style.top = '-10000px'
        ..style.width = '1px'
        ..style.height = '1px'
        ..style.overflow = 'hidden'
        ..style.opacity = '0.01'
        ..style.pointerEvents = 'none';
      html.document.body?.append(hostDiv);
      _hiddenHostEl = hostDiv;

      final recCanvas = html.CanvasElement(width: _canvasW, height: _canvasH);
      final recCtx = recCanvas.context2D;
      recCtx.fillStyle = '#0F172A';
      recCtx.fillRect(0, 0, _canvasW, _canvasH);
      recCtx.imageSmoothingEnabled = true;
      try {
        js.JsObject.fromBrowserObject(recCtx)['imageSmoothingQuality'] = 'high';
      } catch (_) {}
      hostDiv.append(recCanvas);

      _recordCtx = recCtx;

      // Capture native 24fps MediaStream directly from 1080p canvas — NO getUserMedia hardware activation!
      final html.MediaStream finalStream = recCanvas.captureStream(24);

      // Attach passive Web Audio mixer track directly in JS (no JsObject->MediaStream cast)
      // and tag finalStream so LiveKit camera/mic cleanup NEVER stops recorder tracks
      try {
        final jsStream = js.JsObject.fromBrowserObject(finalStream);
        jsStream['_isEduRecorderStream'] = true;
        js.context['_eduRecorderCanvasStream'] = jsStream;
        final mixer = js.context['_eduRecorderAudioMixer'];
        if (mixer is js.JsObject) {
          mixer.callMethod('initAndAttachToStream', [jsStream]);
        }
      } catch (e) {
        debugPrint('[LiveClassRecorder] Passive audio mixer fallback notice: $e');
      }

      _composedStream = finalStream;
      final hasAudio = finalStream.getAudioTracks().isNotEmpty;
      _mimeType = _pickSupportedMimeType(hasAudio: hasAudio);
      _sourceLabel = 'Live Meeting Stage (1080p HD)';

      debugPrint(
        '[LiveClassRecorder] Passive 1080p recorder ready: '
        'videoTracks=${finalStream.getVideoTracks().length}, '
        'audioTracks=${finalStream.getAudioTracks().length}, mime=$_mimeType',
      );

      // Encode at 4 Mbps video + 128 kbps audio for crystal-clear quality without choking browser UI
      html.MediaRecorder rec;
      try {
        rec = html.MediaRecorder(finalStream, {
          'mimeType': _mimeType,
          'videoBitsPerSecond': 4000000,
          if (hasAudio) 'audioBitsPerSecond': 128000,
        });
      } catch (_) {
        rec = html.MediaRecorder(finalStream, {'mimeType': _mimeType});
      }

      _recorder = rec;
      _isPaused = false;
      _isRecording = true;
      _startedAt = DateTime.now();

      rec.addEventListener('dataavailable', (event) {
        try {
          final blob = (event as html.BlobEvent).data;
          if (blob != null && blob.size > 0) {
            _chunks.add(blob);
          }
        } catch (e) {
          debugPrint('[LiveClassRecorder] dataavailable error: $e');
        }
      });

      rec.addEventListener('error', (event) {
        debugPrint('[LiveClassRecorder] MediaRecorder error event: $event');
      });

      rec.start(1000);
      _startCompositorLoop();
      return LiveClassCaptureStartResult(started: true, sourceLabel: _sourceLabel);
    } catch (e) {
      debugPrint('[LiveClassRecorder] Failed creating passive MediaRecorder: $e');
      _cleanupStreams();
      return LiveClassCaptureStartResult(
        started: false,
        errorMessage: 'Browser could not initialize recording: $e',
      );
    }
  }

  void _syncPassiveAudioTracks() {
    try {
      final mixer = js.context['_eduRecorderAudioMixer'];
      if (mixer is js.JsObject) {
        mixer.callMethod('syncTracks');
      }
    } catch (_) {}
  }

  bool _isScreenShareVideo(html.VideoElement v) {
    try {
      return js.context.callMethod(
            '_eduIsScreenShareVideo',
            [js.JsObject.fromBrowserObject(v)],
          ) ==
          true;
    } catch (_) {}
    return false;
  }

  ({List<html.VideoElement> screens, List<html.VideoElement> cameras}) _collectLiveMeetingVideos() {
    final screens = <html.VideoElement>[];
    final cameras = <html.VideoElement>[];
    final seenStreamIds = <String>{};

    final allVideos = html.document.querySelectorAll('video');
    for (final node in allVideos) {
      if (node is! html.VideoElement) continue;
      if (node.id.startsWith('rec-video-')) continue;
      final srcObj = node.srcObject;
      if (srcObj is! html.MediaStream) continue;
      if (node.videoWidth <= 0 || node.videoHeight <= 0 || node.readyState < 2) continue;

      final vTracks = srcObj.getVideoTracks();
      if (vTracks.isEmpty || vTracks.every((t) => t.readyState != 'live' || !(t.enabled ?? true))) {
        continue;
      }

      // Skip zero-sized hidden video nodes
      if (node.offsetWidth <= 0 || node.offsetHeight <= 0) continue;

      final streamKey = '${srcObj.id}_${vTracks.first.id}';
      if (!seenStreamIds.add(streamKey)) continue;

      if (_isScreenShareVideo(node)) {
        screens.add(node);
      } else {
        cameras.add(node);
      }
    }

    return (screens: screens, cameras: cameras);
  }

  void _drawAspectFitVideo(
    html.CanvasRenderingContext2D ctx,
    html.VideoElement v,
    double boxX,
    double boxY,
    double boxW,
    double boxH,
  ) {
    final vw = v.videoWidth.toDouble();
    final vh = v.videoHeight.toDouble();
    if (vw <= 0 || vh <= 0) return;
    final scale = (boxW / vw) < (boxH / vh) ? (boxW / vw) : (boxH / vh);
    final dw = vw * scale;
    final dh = vh * scale;
    final dx = boxX + (boxW - dw) / 2;
    final dy = boxY + (boxH - dh) / 2;
    ctx.drawImageScaled(v, dx, dy, dw, dh);
  }

  void _drawCameraPip(html.CanvasRenderingContext2D ctx, html.VideoElement camEl) {
    const pipW = 320.0;
    const pipH = 180.0;
    const pipX = _canvasW - pipW - 28.0;
    const pipY = _canvasH - pipH - 28.0;
    ctx.fillStyle = '#0B1120';
    ctx.fillRect(pipX - 4, pipY - 4, pipW + 8, pipH + 8);
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 2;
    ctx.strokeRect(pipX - 4, pipY - 4, pipW + 8, pipH + 8);
    _drawAspectFitVideo(ctx, camEl, pipX, pipY, pipW, pipH);
  }

  void _drawStageCapture(html.CanvasRenderingContext2D ctx, StageCaptureFrame stageFrame) {
    final sw = stageFrame.width;
    final sh = stageFrame.height;
    if (_scratchCanvas == null || _scratchCanvas!.width != sw || _scratchCanvas!.height != sh) {
      _scratchCanvas = html.CanvasElement(width: sw, height: sh);
      _scratchCtx = _scratchCanvas!.context2D..imageSmoothingEnabled = true;
    }
    final sCtx = _scratchCtx!;
    final imgData = sCtx.createImageData(sw, sh);
    // Bulk TypedArray.set() copies millions of pixels natively in <0.5ms (zero Dart loop freeze)
    try {
      js.JsObject.fromBrowserObject(imgData.data).callMethod('set', [stageFrame.rgbaBytes]);
    } catch (_) {
      imgData.data.setRange(0, stageFrame.rgbaBytes.length, stageFrame.rgbaBytes);
    }
    sCtx.putImageData(imgData, 0, 0);

    final scale = (_canvasW / sw) < (_canvasH / sh) ? (_canvasW / sw) : (_canvasH / sh);
    final dw = sw * scale;
    final dh = sh * scale;
    final dx = (_canvasW - dw) / 2;
    final dy = (_canvasH - dh) / 2;
    ctx.drawImageScaled(_scratchCanvas!, dx, dy, dw, dh);
  }

  void _startCompositorLoop() {
    _renderTimer?.cancel();
    _lastStageCaptureAt = null;
    _lastStageFrame = null;
    _renderTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!_isRecording || _isPaused || _isCapturingFrame) return;
      final ctx = _recordCtx;
      if (ctx == null) return;

      _isCapturingFrame = true;
      try {
        _syncPassiveAudioTracks();

        final liveVideos = _collectLiveMeetingVideos();
        final hasScreenShare = liveVideos.screens.isNotEmpty;
        final hasMeetingCam = liveVideos.cameras.isNotEmpty;

        // Throttle Flutter RepaintBoundary snapshot to ~5 fps (every 200ms) so Chrome UI & drawing stay 60fps smooth
        final now = DateTime.now();
        final shouldRefreshFlutterStage = _lastStageCaptureAt == null ||
            now.difference(_lastStageCaptureAt!).inMilliseconds >= 200;

        if (_stageFrameProvider != null && shouldRefreshFlutterStage) {
          _lastStageCaptureAt = now;
          final captured = await _stageFrameProvider!(
            includeStandardStage: !hasScreenShare && !hasMeetingCam,
          );
          if (captured != null) {
            _lastStageFrame = captured;
          }
        }
        final stageFrame = _lastStageFrame;

        if (!_isRecording || _recordCtx == null) return;

        ctx.fillStyle = '#0F172A';
        ctx.fillRect(0, 0, _canvasW, _canvasH);

        final hasBoardFrame = stageFrame != null &&
            stageFrame.width > 0 &&
            stageFrame.height > 0 &&
            stageFrame.rgbaBytes.length == stageFrame.width * stageFrame.height * 4 &&
            stageFrame.isBoardOrOverlayActive;

        if (hasBoardFrame) {
          // 1. Interactive Whiteboard active: render crystal-clear board (+ camera PiP if camera is ON)
          _drawStageCapture(ctx, stageFrame);
          if (hasMeetingCam) {
            _drawCameraPip(ctx, liveVideos.cameras.first);
          }
        } else if (hasScreenShare) {
          // 2. Shared Screen / Video active: render shared video full-screen 1080p (+ camera PiP if camera is ON)
          _drawAspectFitVideo(ctx, liveVideos.screens.first, 0, 0, _canvasW.toDouble(), _canvasH.toDouble());
          if (hasMeetingCam) {
            _drawCameraPip(ctx, liveVideos.cameras.first);
          }
        } else if (hasMeetingCam) {
          // 3. Only meeting camera(s) active (user turned Camera ON in meeting controls)
          if (liveVideos.cameras.length == 1) {
            _drawAspectFitVideo(ctx, liveVideos.cameras.first, 0, 0, _canvasW.toDouble(), _canvasH.toDouble());
          } else {
            final count = liveVideos.cameras.length.clamp(1, 4);
            final cols = count <= 2 ? 2 : 2;
            final rows = count <= 2 ? 1 : 2;
            final cellW = _canvasW / cols;
            final cellH = _canvasH / rows;
            for (var i = 0; i < count; i++) {
              final r = i ~/ cols;
              final c = i % cols;
              _drawAspectFitVideo(ctx, liveVideos.cameras[i], c * cellW, r * cellH, cellW, cellH);
            }
          }
        } else if (stageFrame != null &&
            stageFrame.width > 0 &&
            stageFrame.height > 0 &&
            stageFrame.rgbaBytes.length == stageFrame.width * stageFrame.height * 4) {
          // 4. Camera & Screen Share are both OFF and Whiteboard closed: record active Flutter stage card cleanly
          _drawStageCapture(ctx, stageFrame);
        }
      } catch (e) {
        debugPrint('[LiveClassRecorder] Composite frame notice: $e');
      } finally {
        _isCapturingFrame = false;
      }
    });
  }

  void pause() {
    if (_recorder != null && _isRecording && !_isPaused) {
      try {
        _recorder!.pause();
        _isPaused = true;
      } catch (_) {}
    }
  }

  void resume() {
    if (_recorder != null && _isRecording && _isPaused) {
      try {
        _recorder!.resume();
        _isPaused = false;
      } catch (_) {}
    }
  }

  Future<LiveClassCaptureStopResult> stopAndCollect() async {
    _renderTimer?.cancel();
    _renderTimer = null;
    final wasRec = _isRecording;
    _isRecording = false;
    _isPaused = false;
    _lastStageFrame = null;
    _lastStageCaptureAt = null;

    final rec = _recorder;
    if (rec == null || !wasRec) {
      _cleanupStreams();
      return const LiveClassCaptureStopResult();
    }

    final elapsedSec = _startedAt != null
        ? DateTime.now().difference(_startedAt!).inSeconds.clamp(1, 36000)
        : 60;

    final stopCompleter = Completer<void>();
    void onStopHandler(html.Event _) {
      if (!stopCompleter.isCompleted) stopCompleter.complete();
    }

    rec.addEventListener('stop', onStopHandler);
    try {
      if (rec.state != 'inactive') {
        rec.stop();
      } else {
        if (!stopCompleter.isCompleted) stopCompleter.complete();
      }
    } catch (_) {
      if (!stopCompleter.isCompleted) stopCompleter.complete();
    }

    await stopCompleter.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    await Future.delayed(const Duration(milliseconds: 140));
    rec.removeEventListener('stop', onStopHandler);

    Uint8List? resultBytes;
    if (_chunks.isNotEmpty) {
      try {
        final fullBlob = html.Blob(_chunks, _mimeType);
        final reader = html.FileReader();
        final readCompleter = Completer<Uint8List?>();
        reader.onLoadEnd.listen((_) {
          final r = reader.result;
          if (r is Uint8List) {
            readCompleter.complete(r);
          } else if (r is ByteBuffer) {
            readCompleter.complete(r.asUint8List());
          } else {
            readCompleter.complete(null);
          }
        });
        reader.onError.listen((_) => readCompleter.complete(null));
        reader.readAsArrayBuffer(fullBlob);
        resultBytes = await readCompleter.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
      } catch (e) {
        debugPrint('[LiveClassRecorder] Read blob error: $e');
      }
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final mime = _mimeType;
    _cleanupStreams();

    return LiveClassCaptureStopResult(
      bytes: resultBytes,
      fileName: 'live_class_$ts.webm',
      mimeType: mime,
      durationSeconds: elapsedSec,
    );
  }

  void _cleanupStreams() {
    _renderTimer?.cancel();
    _renderTimer = null;
    _isRecording = false;
    _isPaused = false;
    _recorder = null;

    // Dispose passive audio mixer without touching LiveKit meeting camera/mic tracks
    try {
      final mixer = js.context['_eduRecorderAudioMixer'];
      if (mixer is js.JsObject) {
        mixer.callMethod('dispose');
      }
    } catch (_) {}

    try {
      _hiddenHostEl?.remove();
    } catch (_) {}
    _hiddenHostEl = null;
    _recordCtx = null;
    _scratchCanvas = null;
    _scratchCtx = null;

    if (_composedStream != null) {
      try {
        for (final t in _composedStream!.getTracks()) {
          t.stop();
        }
      } catch (_) {}
      _composedStream = null;
    }
    _chunks.clear();
  }
}
