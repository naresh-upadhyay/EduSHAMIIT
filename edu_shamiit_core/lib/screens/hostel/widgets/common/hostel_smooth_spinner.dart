import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sleek, modern loading spinner designed for silky-smooth, constant 60/120 FPS
/// linear rotation without the jarring indeterminate pauses/hesitations of default
/// Material [CircularProgressIndicator].
class HostelSmoothSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Duration duration;

  const HostelSmoothSpinner({
    super.key,
    this.size = 20,
    this.strokeWidth = 2.2,
    this.color,
    this.trackColor,
    this.duration = const Duration(milliseconds: 850),
  });

  @override
  State<HostelSmoothSpinner> createState() => _HostelSmoothSpinnerState();
}

class _HostelSmoothSpinnerState extends State<HostelSmoothSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant HostelSmoothSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = widget.color ??
        (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
    final effectiveTrackColor = widget.trackColor ??
        (widget.color != null
            ? widget.color!.withValues(alpha: 0.2)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)));

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RotationTransition(
          turns: _controller,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _SmoothArcSpinnerPainter(
              color: effectiveColor,
              trackColor: effectiveTrackColor,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmoothArcSpinnerPainter extends CustomPainter {
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _SmoothArcSpinnerPainter({
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    // Subtle 360-degree background track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Smooth spinning arc (~270 degrees) with rounded ends
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * math.pi, // 270 degrees sweep
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SmoothArcSpinnerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
