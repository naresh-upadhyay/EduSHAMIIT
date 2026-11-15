import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DevicesByTypeDonutCard extends StatelessWidget {
  final List<DeviceTypeBreakdown> types;
  final int totalDevices;
  final ValueChanged<String?>? onTypeSelected;
  final String? selectedType;

  const DevicesByTypeDonutCard({
    super.key,
    required this.types,
    required this.totalDevices,
    this.onTypeSelected,
    this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultTypes = types.isNotEmpty
        ? types
        : [
            const DeviceTypeBreakdown(type: 'Lighting', count: 6284, percentage: 71.9, colorHex: '#EAB308', icon: 'lightbulb'),
            const DeviceTypeBreakdown(type: 'AC (HVAC)', count: 428, percentage: 4.9, colorHex: '#38BDF8', icon: 'ac_unit'),
            const DeviceTypeBreakdown(type: 'Fans', count: 702, percentage: 8.0, colorHex: '#06B6D4', icon: 'mode_fan'),
            const DeviceTypeBreakdown(type: 'Power & Switches', count: 342, percentage: 3.9, colorHex: '#22C55E', icon: 'power'),
            const DeviceTypeBreakdown(type: 'Projectors', count: 126, percentage: 1.4, colorHex: '#8B5CF6', icon: 'videocam'),
            const DeviceTypeBreakdown(type: 'Access & Gates', count: 48, percentage: 0.5, colorHex: '#F43F5E', icon: 'door_front_door'),
            const DeviceTypeBreakdown(type: 'Audio / Speakers', count: 96, percentage: 1.1, colorHex: '#B45309', icon: 'volume_up'),
            const DeviceTypeBreakdown(type: 'LED Displays', count: 28, percentage: 0.3, colorHex: '#EC4899', icon: 'tv'),
            const DeviceTypeBreakdown(type: 'Others', count: 716, percentage: 8.2, colorHex: '#64748B', icon: 'devices_other'),
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
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Devices by Type',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Donut & Legend Split
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 310;
                  final donutSize = isTight ? 100.0 : 125.0;

                  return Row(
                    children: [
                      // Donut Chart on the Left
                      SizedBox(
                        width: donutSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(donutSize, donutSize),
                              painter: _DonutChartPainter(types: defaultTypes),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  totalDevices > 0 ? totalDevices.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},') : '8,742',
                                  style: TextStyle(
                                    fontSize: isTight ? 12 : 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Total\nDevices',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isTight ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Legend list on the Right
                      Expanded(
                        child: ListView.builder(
                          itemCount: defaultTypes.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final item = defaultTypes[index];
                            final color = _parseColor(item.colorHex);
                            final isSelected = selectedType != null &&
                                (selectedType!.toLowerCase() == item.type.toLowerCase() ||
                                 item.type.toLowerCase().contains(selectedType!.toLowerCase()));

                            return InkWell(
                              onTap: () {
                                if (onTypeSelected != null) {
                                  onTypeSelected!(isSelected ? null : item.type);
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const NeverScrollableScrollPhysics(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: isTight ? 65 : 85),
                                        child: Text(
                                          item.type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFF2563EB)
                                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTight
                                            ? '${item.percentage}%'
                                            : '${item.count.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} (${item.percentage}%)',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DeviceTypeBreakdown> types;

  _DonutChartPainter({required this.types});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 16.0;

    double startAngle = -math.pi / 2;

    for (var t in types) {
      final sweepAngle = (t.percentage / 100.0) * (2 * math.pi);
      final paint = Paint()
        ..color = _parseColor(t.colorHex)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
