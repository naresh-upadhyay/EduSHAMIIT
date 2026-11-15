import 'package:flutter/material.dart';
import '../models/broadcast_models.dart';

class LiveAnalyticsChart extends StatelessWidget {
  final List<AnalyticsPoint> points;
  final int currentPeak;

  const LiveAnalyticsChart({
    super.key,
    required this.points,
    required this.currentPeak,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Viewers (Last 30 Minutes)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$currentPeak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: Row(
            children: [
              // Y-axis labels
              const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('500', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('400', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('300', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('200', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('100', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                  Text('0', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(width: 8),
              // Chart Area
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ChartPainter(points: points),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // X-axis timestamps
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points.map((p) {
              return Text(
                p.minuteMark,
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<AnalyticsPoint> points;

  _ChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 5; i++) {
      final y = size.height * (i / 5.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const double maxY = 500.0;
    final List<Offset> offsets = [];

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? 0.0
          : size.width * (i / (points.length - 1));
      final normalizedY = (points[i].viewerCount / maxY).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * size.height);
      offsets.add(Offset(x, y));
    }

    if (offsets.isEmpty) return;

    // Build smooth curve path
    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Fill under path
    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x553B82F6), Color(0x053B82F6)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Dot at the end (active current viewer count)
    final lastOffset = offsets.last;
    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastOffset, 4, dotPaint);

    final dotHaloPaint = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(lastOffset, 6, dotHaloPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
