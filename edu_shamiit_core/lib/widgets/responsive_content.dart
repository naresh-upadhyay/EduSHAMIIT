import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Wraps child content in a centered, width-constrained container
/// so that on large screens (tablet/desktop) the content doesn't
/// stretch across the full viewport width.
///
/// On mobile this is a transparent pass-through (no constraint).
///
/// Usage:
/// ```dart
/// ResponsiveContent(
///   child: ListView(...),
/// )
/// ```
class ResponsiveContent extends StatelessWidget {
  final Widget child;

  /// Override the default max width from [Responsive.contentMaxWidth].
  final double? maxWidth;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? Responsive.contentMaxWidth(context);

    if (mw == double.infinity) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}
