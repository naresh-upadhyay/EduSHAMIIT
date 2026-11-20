import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/space_booking_models.dart';

// ============================================================================
// 1. HOURLY OCCUPANCY & TRAFFIC CURVE (SMOOTH AREA CHART)
// ============================================================================

class HourlyOccupancyChart extends StatelessWidget {
  final List<SpaceHourlyOccupancy> data;
  final bool isDark;

  const HourlyOccupancyChart({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hourly occupancy data available')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: 220,
          child: CustomPaint(
            size: Size(constraints.maxWidth, 220),
            painter: _HourlyChartPainter(data: data, isDark: isDark),
          ),
        );
      },
    );
  }
}

class _HourlyChartPainter extends CustomPainter {
  final List<SpaceHourlyOccupancy> data;
  final bool isDark;

  _HourlyChartPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 42.0;
    const double rightPad = 16.0;
    const double topPad = 20.0;
    const double bottomPad = 32.0;

    final double chartWidth = size.width - leftPad - rightPad;
    final double chartHeight = size.height - topPad - bottomPad;

    if (chartWidth <= 0 || chartHeight <= 0 || data.length < 2) return;

    final gridLinePaint = Paint()
      ..color = isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // 1. Draw horizontal grid lines and Y-axis labels (0%, 25%, 50%, 75%, 100%)
    for (int i = 0; i <= 4; i++) {
      final double y = topPad + (chartHeight * (4 - i) / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridLinePaint);

      final label = '${i * 25}%';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - (tp.height / 2)));
    }

    // Compute coordinate points
    final points = <Offset>[];
    final double dx = chartWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final double pct = data[i].occupancyPct.clamp(0.0, 100.0);
      final double x = leftPad + (i * dx);
      final double y = topPad + chartHeight - (chartHeight * (pct / 100.0));
      points.add(Offset(x, y));
    }

    // 2. Build Smooth Path using Catmull-Rom or Cubic Beziers
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    // 3. Fill Area under the curve with Gradient
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, topPad + chartHeight)
      ..lineTo(points.first.dx, topPad + chartHeight)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.40 : 0.28),
        const Color(0xFF3B82F6).withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 4. Draw Stroke Line
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // 5. Draw data points and bottom time labels
    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    final dotInnerPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      // Only draw bottom labels for every 2nd hour or key points to avoid clutter
      if (i % 2 == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(text: data[i].hourLabel, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(pt.dx - (tp.width / 2), topPad + chartHeight + 8));
      }

      // Peak highlight dot (highest occupancy)
      if (data[i].occupancyPct >= 85.0) {
        canvas.drawCircle(pt, 5.0, dotPaint);
        canvas.drawCircle(pt, 2.5, dotInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyChartPainter oldDelegate) => true;
}

// ============================================================================
// 2. SPACE TYPE BREAKDOWN (INTERACTIVE DONUT CHART)
// ============================================================================

class SpaceTypeDonutChart extends StatelessWidget {
  final List<SpaceTypeBreakdownItem> items;
  final int totalSpaces;
  final bool isDark;

  const SpaceTypeDonutChart({
    super.key,
    required this.items,
    required this.totalSpaces,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No breakdown data')));
    }

    final totalCount = totalSpaces > 0 ? totalSpaces : items.fold<int>(0, (sum, e) => sum + e.count);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Donut Canvas
            SizedBox(
              width: isCompact ? 130 : 160,
              height: isCompact ? 130 : 160,
              child: CustomPaint(
                size: Size(isCompact ? 130 : 160, isCompact ? 130 : 160),
                painter: _DonutChartPainter(
                  items: items,
                  totalCount: totalCount,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Legend Items List
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  final color = _hexToColor(item.colorHex);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.typeName,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${item.count})',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<SpaceTypeBreakdownItem> items;
  final int totalCount;
  final bool isDark;

  _DonutChartPainter({required this.items, required this.totalCount, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 4;
    const double strokeWidth = 24.0;
    final innerRadius = outerRadius - strokeWidth;

    double startAngle = -math.pi / 2;

    for (final item in items) {
      final sweepAngle = (item.percentage / 100.0) * 2 * math.pi;
      final paint = Paint()
        ..color = SpaceTypeDonutChart._hexToColor(item.colorHex)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + strokeWidth / 2),
        startAngle,
        sweepAngle - 0.04, // slight spacing between arcs
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Center text: total spaces
    final countTextPainter = TextPainter(
      text: TextSpan(
        text: '$totalCount',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    countTextPainter.paint(canvas, Offset(center.dx - countTextPainter.width / 2, center.dy - countTextPainter.height / 2 - 6));

    final subTextPainter = TextPainter(
      text: TextSpan(
        text: 'Spaces',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTextPainter.paint(canvas, Offset(center.dx - subTextPainter.width / 2, center.dy + 8));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

// ============================================================================
// 3. DAY OF WEEK OCCUPANCY BAR CHART (MON TO SAT)
// ============================================================================

class DayOfWeekBarChart extends StatelessWidget {
  final List<SpaceDayOfWeekTraffic> days;
  final bool isDark;

  const DayOfWeekBarChart({
    super.key,
    required this.days,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text('No weekly data')));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: 200,
          child: CustomPaint(
            size: Size(constraints.maxWidth, 200),
            painter: _DayOfWeekBarPainter(days: days, isDark: isDark),
          ),
        );
      },
    );
  }
}

class _DayOfWeekBarPainter extends CustomPainter {
  final List<SpaceDayOfWeekTraffic> days;
  final bool isDark;

  _DayOfWeekBarPainter({required this.days, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 12.0;
    const double rightPad = 12.0;
    const double topPad = 26.0;
    const double bottomPad = 28.0;

    final double chartWidth = size.width - leftPad - rightPad;
    final double chartHeight = size.height - topPad - bottomPad;

    if (chartWidth <= 0 || chartHeight <= 0 || days.isEmpty) return;

    final double groupWidth = chartWidth / days.length;
    final double barWidth = math.min(groupWidth * 0.45, 34.0);

    final textStyle = TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final valueStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      fontSize: 10,
      fontWeight: FontWeight.w700,
    );

    // Draw baseline
    final baseLinePaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(leftPad, topPad + chartHeight),
      Offset(size.width - rightPad, topPad + chartHeight),
      baseLinePaint,
    );

    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final double centerX = leftPad + (i * groupWidth) + (groupWidth / 2);
      final double barLeft = centerX - (barWidth / 2);
      final double pct = d.utilizationPct.clamp(0.0, 100.0);
      final double barH = (pct / 100.0) * chartHeight;
      final double barTop = topPad + chartHeight - barH;

      // Modern Gradient Bar
      final barGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          d.utilizationPct > 85
              ? const Color(0xFF2563EB)
              : const Color(0xFF3B82F6),
          const Color(0xFF8B5CF6).withValues(alpha: 0.85),
        ],
      );

      final barRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(barLeft, barTop, barWidth, barH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final barPaint = Paint()..shader = barGradient.createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      // Percentage value text above bar
      final valTp = TextPainter(
        text: TextSpan(text: '${d.utilizationPct.toStringAsFixed(0)}%', style: valueStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      valTp.paint(canvas, Offset(centerX - (valTp.width / 2), barTop - valTp.height - 4));

      // Day Short label below bar
      final lblTp = TextPainter(
        text: TextSpan(text: d.dayShort, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      lblTp.paint(canvas, Offset(centerX - (lblTp.width / 2), topPad + chartHeight + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _DayOfWeekBarPainter oldDelegate) => true;
}

// ============================================================================
// 4. BUILDING UTILIZATION PROGRESS MATRIX
// ============================================================================

class BuildingUtilizationList extends StatelessWidget {
  final List<SpaceBuildingUtilization> buildings;
  final bool isDark;

  const BuildingUtilizationList({
    super.key,
    required this.buildings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (buildings.isEmpty) {
      return const SizedBox(height: 120, child: Center(child: Text('No building data available')));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: buildings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final b = buildings[index];
        final pct = b.utilizationPct.clamp(0.0, 100.0);

        Color statusColor;
        String statusLabel;
        if (pct >= 80.0) {
          statusColor = const Color(0xFFEF4444);
          statusLabel = 'High Demand';
        } else if (pct >= 65.0) {
          statusColor = const Color(0xFF10B981);
          statusLabel = 'Optimal';
        } else {
          statusColor = const Color(0xFF3B82F6);
          statusLabel = 'Available';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        b.buildingCode,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.buildingName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100.0,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${b.bookedRooms} booked out of ${b.totalRooms} bookable spaces',
                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  Text(
                    '${b.totalRooms - b.bookedRooms} free',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// 5. TODAY'S SPACE UTILIZATION STATUS DONUT CHART
// ============================================================================

class TodaySpaceUtilizationDonutChart extends StatelessWidget {
  final SpaceUtilizationStats stats;
  final bool isDark;

  const TodaySpaceUtilizationDonutChart({
    super.key,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _SpaceDonutChartPainter(
                inUsePct: stats.inUsePct / 100.0,
                availPct: stats.availablePct / 100.0,
                maintPct: stats.maintenancePct / 100.0,
                notBookPct: stats.notBookablePct / 100.0,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.overallRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Utilization',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Legend breakdown
        _buildLegendRow('In Use', '${stats.inUseCount} (${stats.inUsePct.toStringAsFixed(1)}%)', const Color(0xFF10B981), isDark),
        const SizedBox(height: 6),
        _buildLegendRow('Available', '${stats.availableCount} (${stats.availablePct.toStringAsFixed(1)}%)', const Color(0xFF06B6D4), isDark),
        const SizedBox(height: 6),
        _buildLegendRow('Under Maintenance', '${stats.maintenanceCount} (${stats.maintenancePct.toStringAsFixed(1)}%)', const Color(0xFFF59E0B), isDark),
        const SizedBox(height: 6),
        _buildLegendRow('Not Bookable', '${stats.notBookableCount} (${stats.notBookablePct.toStringAsFixed(1)}%)', const Color(0xFFEC4899), isDark),
      ],
    );
  }

  Widget _buildLegendRow(String title, String countText, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          countText,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
        ),
      ],
    );
  }
}

class _SpaceDonutChartPainter extends CustomPainter {
  final double inUsePct;
  final double availPct;
  final double maintPct;
  final double notBookPct;

  _SpaceDonutChartPainter({
    required this.inUsePct,
    required this.availPct,
    required this.maintPct,
    required this.notBookPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    // 1. In Use (Green)
    paint.color = const Color(0xFF10B981);
    final sweep1 = inUsePct * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep1, false, paint);
    startAngle += sweep1;

    // 2. Available (Cyan)
    paint.color = const Color(0xFF06B6D4);
    final sweep2 = availPct * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep2, false, paint);
    startAngle += sweep2;

    // 3. Under Maintenance (Amber)
    paint.color = const Color(0xFFF59E0B);
    final sweep3 = maintPct * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep3, false, paint);
    startAngle += sweep3;

    // 4. Not Bookable (Pink)
    paint.color = const Color(0xFFEC4899);
    final sweep4 = notBookPct * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SpaceDonutChartPainter oldDelegate) => true;
}

