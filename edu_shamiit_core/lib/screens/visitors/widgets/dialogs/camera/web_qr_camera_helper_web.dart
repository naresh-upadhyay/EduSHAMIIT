// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum CameraFeedState {
  uninitialized,
  initializing,
  streaming,
  permissionDenied,
  error,
}

class WebQrCameraHelper {
  static bool get isSupported => kIsWeb;

  static html.VideoElement? _videoElement;
  static html.MediaStream? _mediaStream;
  static Timer? _scanTimer;
  static bool _isDetecting = false;
  static final Set<String> _registeredViews = <String>{};

  static Future<CameraFeedState> startCamera({
    required String viewTypeId,
    required void Function(String qrData) onQrDetected,
    required void Function(String base64Frame) onFrameCaptured,
    required void Function(String errorMsg) onError,
  }) async {
    try {
      stopCamera();

      final nav = html.window.navigator;
      if (nav.mediaDevices == null) {
        onError('Your browser does not support HTML5 mediaDevices camera access.');
        return CameraFeedState.error;
      }

      // 1. Create Video element
      _videoElement = html.VideoElement()
        ..id = 'qr-webcam-video'
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      // 2. Register Platform View with Flutter Web
      if (!_registeredViews.contains(viewTypeId)) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewTypeId,
          (int viewId) => _videoElement!,
        );
        _registeredViews.add(viewTypeId);
      }

      // 3. Request user camera access
      try {
        final constraints = {
          'video': {
            'facingMode': {'ideal': 'environment'},
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
          'audio': false,
        };
        _mediaStream = await nav.mediaDevices!.getUserMedia(constraints);
      } catch (camErr) {
        final errStr = camErr.toString().toLowerCase();
        if (errStr.contains('notallowed') ||
            errStr.contains('permission') ||
            errStr.contains('denied')) {
          onError('Camera permission denied. Please allow camera permissions in your browser address bar.');
          return CameraFeedState.permissionDenied;
        } else {
          try {
            // Fallback: any video device
            _mediaStream = await nav.mediaDevices!.getUserMedia({'video': true, 'audio': false});
          } catch (fallbackErr) {
            onError('Could not connect to camera: $fallbackErr');
            return CameraFeedState.error;
          }
        }
      }

      if (_mediaStream == null) {
        onError('No video stream received from camera.');
        return CameraFeedState.error;
      }

      _videoElement!.srcObject = _mediaStream;
      await _videoElement!.play();

      // 4. Start automatic frame capture & decode loop
      _startFrameLoop(onQrDetected, onFrameCaptured);

      return CameraFeedState.streaming;
    } catch (e) {
      debugPrint('[WebQrCameraHelper] Failed to start camera: $e');
      onError('Failed to access camera: $e');
      return CameraFeedState.error;
    }
  }

  static void _startFrameLoop(
    void Function(String qrData) onQrDetected,
    void Function(String base64Frame) onFrameCaptured,
  ) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 750), (_) async {
      if (_videoElement == null || _isDetecting) return;
      if (_videoElement!.readyState < 2) return; // HAVE_CURRENT_DATA or higher

      _isDetecting = true;
      try {
        // Try native BarcodeDetector if available in browser
        try {
          final jsResult = js.context.callMethod('eval', [
            '''
            (function() {
              if (window._qrBarcodeResult) {
                const res = window._qrBarcodeResult;
                window._qrBarcodeResult = null;
                return res;
              }
              if (window.BarcodeDetector && !window._qrDetectorRunning) {
                if (!window._qrDetectorInstance) {
                  try {
                    window._qrDetectorInstance = new BarcodeDetector({
                      formats: ['qr_code', 'code_128', 'code_39', 'ean_13', 'ean_8', 'upc_a', 'upc_e', 'codabar', 'itf']
                    });
                  } catch (e) {
                    window._qrDetectorInstance = new BarcodeDetector();
                  }
                }
                const v = document.getElementById('qr-webcam-video');
                if (v && v.readyState >= 2) {
                  window._qrDetectorRunning = true;
                  window._qrDetectorInstance.detect(v).then(function(barcodes) {
                    window._qrDetectorRunning = false;
                    if (barcodes && barcodes.length > 0) {
                      window._qrBarcodeResult = barcodes[0].rawValue;
                    }
                  }).catch(function() {
                    window._qrDetectorRunning = false;
                  });
                }
              }
              return null;
            })()
            '''
          ]);

          if (jsResult != null && jsResult.toString().trim().isNotEmpty) {
            onQrDetected(jsResult.toString().trim());
            _isDetecting = false;
            return;
          }
        } catch (_) {}

        // Capture frame to canvas for OpenCV backend detection
        final width = _videoElement!.videoWidth > 0 ? _videoElement!.videoWidth : 640;
        final height = _videoElement!.videoHeight > 0 ? _videoElement!.videoHeight : 480;

        final canvas = html.CanvasElement(width: width, height: height);
        final ctx = canvas.context2D;
        ctx.drawImage(_videoElement!, 0, 0);

        final dataUrl = canvas.toDataUrl('image/jpeg', 0.82);
        if (dataUrl.isNotEmpty && dataUrl.contains(',')) {
          final base64Part = dataUrl.split(',').last;
          onFrameCaptured(base64Part);
        }
      } catch (e) {
        debugPrint('[WebQrCameraHelper] Frame scan error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  static void stopCamera() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _isDetecting = false;

    if (_mediaStream != null) {
      try {
        final tracks = _mediaStream!.getTracks();
        for (final track in tracks) {
          track.stop();
        }
      } catch (e) {
        debugPrint('[WebQrCameraHelper] Error stopping tracks: $e');
      }
      _mediaStream = null;
    }

    if (_videoElement != null) {
      try {
        _videoElement!.pause();
        _videoElement!.srcObject = null;
      } catch (_) {}
    }

    try {
      js.context.callMethod('eval', [
        'window._qrBarcodeResult = null; window._qrDetectorRunning = false;'
      ]);
    } catch (_) {}
  }

  static Widget buildCameraView(String viewTypeId) {
    return HtmlElementView(viewType: viewTypeId);
  }
}
