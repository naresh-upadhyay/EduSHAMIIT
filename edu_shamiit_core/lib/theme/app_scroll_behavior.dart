import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A custom [ScrollBehavior] for EduSHAMIIT that ensures:
/// 1. Interactive, visible horizontal and vertical scrollbars for all scrollable views (especially DataTables and grids).
/// 2. Mouse drag scrolling enabled across desktop, web, and touch devices (so mouse users can swipe horizontally just like touch users).
/// 3. Polished scrollbar appearance with theme-aware track and thumb visibility.
class EduShamiitScrollBehavior extends MaterialScrollBehavior {
  const EduShamiitScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          thickness: 8.0,
          radius: const Radius.circular(4),
          child: child,
        );
      case Axis.vertical:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          trackVisibility: false,
          interactive: true,
          thickness: 8.0,
          radius: const Radius.circular(4),
          child: child,
        );
    }
  }
}
