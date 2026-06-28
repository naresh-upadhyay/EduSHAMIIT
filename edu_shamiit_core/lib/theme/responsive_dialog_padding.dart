import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A premium responsive inset padding that enforces a maximum dialog width of 480dp
/// on desktop/web/large screens, while scaling down gracefully on mobile devices.
class ResponsiveInsetPadding extends EdgeInsets {
  const ResponsiveInsetPadding() : super.fromLTRB(24, 24, 24, 24);

  @override
  EdgeInsets resolve(TextDirection? direction) {
    try {
      final ui.FlutterView view = ui.PlatformDispatcher.instance.implicitView ?? ui.PlatformDispatcher.instance.views.first;
      final double screenWidth = view.physicalSize.width / view.devicePixelRatio;
      
      const double maxDialogWidth = 480.0;
      final double horizontalPadding = screenWidth > (maxDialogWidth + 48)
          ? (screenWidth - maxDialogWidth) / 2
          : 24.0;
          
      return EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24);
    } catch (_) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
    }
  }
}
