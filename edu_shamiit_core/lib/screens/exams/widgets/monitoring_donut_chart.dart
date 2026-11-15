import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Donut summary chart & mutually-exclusive breakdown legend for Live Monitoring.
class MonitoringDonutSummaryCard extends StatelessWidget {
  final int activeInExam;
  final int totalStudents;
  final List<Map<String, dynamic>> breakdown;
  final Color cardBg;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;

  const MonitoringDonutSummaryCard({
    super.key,
    required this.activeInExam,
    required this.totalStudents,
    required this.breakdown,
    required this.cardBg,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
  });

  static Color colorForKey(String key) {
    switch (key.toLowerCase()) {
      case 'in_exam':
        return const Color(0xFF16A34A);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'violation':
        return const Color(0xFFEF4444);
      case 'paused':
        return const Color(0xFF8B5CF6);
      case 'disconnected':
        return const Color(0xFF94A3B8);
      case 'completed':
        return const Color(0xFF0EA5E9);
      case 'not_started':
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = breakdown.where((row) {
      final k = (row['key'] ?? '').toString().toLowerCase();
      final cnt = (row['count'] as num?)?.toInt() ?? 0;
      if (k == 'in_exam' || k == 'warning' || k == 'violation' || k == 'disconnected' || k == 'completed') {
        return true;
      }
      return cnt > 0;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exam & Monitoring Summary',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 290;
              final chart = SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _DonutRingPainter(
                    segments: visibleRows
                        .map((r) => _DonutSegment(
                              value: ((r['count'] as num?)?.toDouble() ?? 0),
                              color: colorForKey((r['key'] ?? '').toString()),
                            ))
                        .toList(),
                    trackColor: borderColor.withValues(alpha: 0.4),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$activeInExam/$totalStudents',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                        Text(
                          'Students\nIn Exam',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, color: secondaryText, height: 1.15),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: visibleRows.map((row) {
                  final key = (row['key'] ?? '').toString();
                  final label = (row['label'] ?? key).toString();
                  final count = (row['count'] as num?)?.toInt() ?? 0;
                  final pct = (row['percentage'] as num?)?.toDouble() ?? 0.0;
                  final dotColor = colorForKey(key);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryText),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11.5, color: secondaryText),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (narrow) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 14),
                    legend,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  chart,
                  const SizedBox(width: 14),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment({required this.value, required this.color});
}

class _DonutRingPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final Color trackColor;

  _DonutRingPainter({required this.segments, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = const Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final total = segments.fold<double>(0.0, (sum, s) => sum + s.value);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, math.max(0.03, sweep - 0.015), false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutRingPainter oldDelegate) => oldDelegate.segments != segments;
}
