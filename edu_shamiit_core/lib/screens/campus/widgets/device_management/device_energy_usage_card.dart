import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceEnergyUsageCard extends StatelessWidget {
  final List<EnergyDataPoint> data;
  final String currentPeriod;
  final ValueChanged<String> onPeriodChanged;

  const DeviceEnergyUsageCard({
    super.key,
    required this.data,
    required this.currentPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPoints = data.isNotEmpty
        ? data
        : [
            const EnergyDataPoint(time: '12 AM', loadKw: 180, consumptionKwh: 1800),
            const EnergyDataPoint(time: '2 AM', loadKw: 170, consumptionKwh: 1700),
            const EnergyDataPoint(time: '4 AM', loadKw: 190, consumptionKwh: 1900),
            const EnergyDataPoint(time: '6 AM', loadKw: 260, consumptionKwh: 2600),
            const EnergyDataPoint(time: '8 AM', loadKw: 420, consumptionKwh: 4200),
            const EnergyDataPoint(time: '10 AM', loadKw: 510, consumptionKwh: 5100),
            const EnergyDataPoint(time: '12 PM', loadKw: 490, consumptionKwh: 4900),
            const EnergyDataPoint(time: '2 PM', loadKw: 460, consumptionKwh: 4600),
            const EnergyDataPoint(time: '4 PM', loadKw: 390, consumptionKwh: 3900),
            const EnergyDataPoint(time: '6 PM', loadKw: 320, consumptionKwh: 3200),
            const EnergyDataPoint(time: '8 PM', loadKw: 240, consumptionKwh: 2400),
            const EnergyDataPoint(time: '10 PM', loadKw: 200, consumptionKwh: 2000),
          ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Horizontal Scroll Protection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Energy & Usage',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Period Selector (Day, Week, Month, Year)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: ['Day', 'Week', 'Month', 'Year'].map((p) {
                        final isActive = currentPeriod == p;
                        return InkWell(
                          onTap: () => onPeriodChanged(p),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Power Load (kW)', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFBAE6FD), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Energy Consumption (kWh)', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Dual Axis Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
              child: CustomPaint(
                painter: _DualAxisEnergyPainter(data: defaultPoints, isDark: isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DualAxisEnergyPainter extends CustomPainter {
  final List<EnergyDataPoint> data;
  final bool isDark;

  _DualAxisEnergyPainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftMargin = 38.0;
    const rightMargin = 45.0;
    const bottomMargin = 20.0;
    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - bottomMargin;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: 0.6)
      ..strokeWidth = 0.8;

    final textStyle = TextStyle(
      fontSize: 8.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );

    for (int i = 0; i <= 4; i++) {
      final y = chartHeight * (1 - (i / 4.0));
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      // Left axis label (0 to 600 kW)
      final kwVal = (i * 150).toInt();
      final tpKw = TextPainter(
        text: TextSpan(text: '${kwVal}kW', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpKw.paint(canvas, Offset(leftMargin - tpKw.width - 4, y - 5));

      // Right axis label (0 to 6000 kWh)
      final kwhVal = (i * 1500).toInt();
      final tpKwh = TextPainter(
        text: TextSpan(text: '${kwhVal}kWh', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpKwh.paint(canvas, Offset(size.width - rightMargin + 4, y - 5));
    }

    // Draw Bars (Energy Consumption)
    final barPaint = Paint()..color = const Color(0xFFBAE6FD).withValues(alpha: 0.7);
    final barWidth = (chartWidth / data.length) * 0.45;

    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + (i * (chartWidth / (data.length - 1)));
      final normKwh = math.min(1.0, data[i].consumptionKwh / 6000.0);
      final barH = chartHeight * normKwh;
      final barRect = Rect.fromLTWH(x - barWidth / 2, chartHeight - barH, barWidth, barH);
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(3)), barPaint);

      // X-axis label
      if (i % 2 == 0 || i == data.length - 1) {
        final tpTime = TextPainter(
          text: TextSpan(text: data[i].time, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tpTime.paint(canvas, Offset(x - tpTime.width / 2, chartHeight + 4));
      }
    }

    // Draw Line & Dots (Power Load kW)
    final linePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = const Color(0xFF0284C7);
    final dotCenterPaint = Paint()..color = Colors.white;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + (i * (chartWidth / (data.length - 1)));
      final normKw = math.min(1.0, data[i].loadKw / 600.0);
      final y = chartHeight * (1 - normKw);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + (i * (chartWidth / (data.length - 1)));
      final normKw = math.min(1.0, data[i].loadKw / 600.0);
      final y = chartHeight * (1 - normKw);

      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      canvas.drawCircle(Offset(x, y), 1.8, dotCenterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
