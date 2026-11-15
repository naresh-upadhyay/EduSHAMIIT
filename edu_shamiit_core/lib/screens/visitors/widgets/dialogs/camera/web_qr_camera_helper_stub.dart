import 'package:flutter/material.dart';

enum CameraFeedState {
  uninitialized,
  initializing,
  streaming,
  permissionDenied,
  error,
}

abstract class WebQrCameraHelper {
  static bool get isSupported => false;

  static Future<CameraFeedState> startCamera({
    required String viewTypeId,
    required void Function(String qrData) onQrDetected,
    required void Function(String base64Frame) onFrameCaptured,
    required void Function(String errorMsg) onError,
  }) async {
    return CameraFeedState.uninitialized;
  }

  static void stopCamera() {}

  static Widget buildCameraView(String viewTypeId) {
    return const SizedBox.shrink();
  }
}
