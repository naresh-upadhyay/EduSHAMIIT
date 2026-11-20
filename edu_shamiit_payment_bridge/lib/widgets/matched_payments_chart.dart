import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/analytics_model.dart';

class MatchedPaymentsChart extends StatelessWidget {
  final List<ChartDataPoint> points;
  final String timeframe;

  const MatchedPaymentsChart({
    super.key,
    required this.points,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text('No matched transaction data available for this range', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    final maxAmount = points.map((p) => p.amount).fold<double>(0.0, math.max);

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _ChartPainter(points: points, maxAmount: maxAmount > 0 ? maxAmount : 1000.0),
          ),
        ),
        const SizedBox(height: 8),
        // X-Axis Labels Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _buildXAxisLabels(),
        ),
      ],
    );
  }

  List<Widget> _buildXAxisLabels() {
    if (points.length <= 6) {
      return points.map((p) => Text(p.label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600))).toList();
    }
    // Downsample labels for display
    final step = (points.length / 5).ceil();
    final List<Widget> labels = [];
    for (int i = 0; i < points.length; i += step) {
      labels.add(Text(points[i].label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)));
    }
    if (points.length > 1 && (points.length - 1) % step != 0) {
      labels.add(Text(points.last.label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)));
    }
    return labels;
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final double maxAmount;

  _ChartPainter({required this.points, required this.maxAmount});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const double paddingBottom = 16.0;
    const double paddingTop = 16.0;
    final double graphHeight = size.height - paddingBottom - paddingTop;
    final double graphWidth = size.width;

    // Background Grid lines (3 horizontal guide lines)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 3; i++) {
      final y = paddingTop + (graphHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(graphWidth, y), gridPaint);
    }

    // Coordinates calculation
    final List<Offset> offsets = [];
    final double stepX = points.length > 1 ? graphWidth / (points.length - 1) : graphWidth / 2;

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? graphWidth / 2 : i * stepX;
      final normalizedY = (points[i].amount / maxAmount).clamp(0.0, 1.0);
      final y = paddingTop + graphHeight - (normalizedY * graphHeight);
      offsets.add(Offset(x, y));
    }

    // Gradient Fill Path under the curve
    final fillPath = Path();
    fillPath.moveTo(offsets.first.dx, size.height - paddingBottom);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(offsets.last.dx, size.height - paddingBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryBlue.withValues(alpha: 0.35),
          AppColors.primaryBlue.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Path
    final strokePath = Path();
    strokePath.moveTo(offsets.first.dx, offsets.first.dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      strokePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(strokePath, strokePaint);

    // Draw Data Point Dots & Peaks
    final dotPaint = Paint()..color = Colors.white;
    final dotRingPaint = Paint()
      ..color = AppColors.primaryNavy
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < offsets.length; i++) {
      final pt = offsets[i];
      final amount = points[i].amount;

      // Draw point circle
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 4.0, dotRingPaint);

      // Draw peak amount tag on top values
      if (amount > 0 && (amount >= maxAmount * 0.7 || points.length <= 7)) {
        final textSpan = TextSpan(
          text: '₹${amount >= 1000 ? '${(amount / 1000).toStringAsFixed(1)}k' : amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.primaryNavy,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(pt.dx - (textPainter.width / 2), pt.dy - 16),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxAmount != maxAmount;
  }
}
