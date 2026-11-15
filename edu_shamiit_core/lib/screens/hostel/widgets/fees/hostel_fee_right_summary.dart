import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'dialogs/collect_payment_dialog.dart';

class HostelFeeRightSummary extends ConsumerWidget {
  const HostelFeeRightSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final donut = state.feeSummaryDonut;
    final recent = state.recentPayments;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Fee Summary Donut Card
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Fee Summary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${donut.collectionPercentage.toStringAsFixed(1)}% Collected',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Donut Chart Graphic
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        collectedPct: donut.collectionPercentage / 100.0,
                        pendingPct: donut.pendingPercentage / 100.0,
                        overduePct: donut.overduePercentage / 100.0,
                        isDark: isDark,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${donut.collectionPercentage.toInt()}%',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Collected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Donut Legend
                _buildLegendRow('Collected', donut.collectedFormatted, const Color(0xFF16A34A), isDark),
                const SizedBox(height: 8),
                _buildLegendRow('Pending', donut.pendingFormatted, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 8),
                _buildLegendRow('Overdue', donut.overdueFormatted, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _buildLegendRow('Total Billed', donut.totalFormatted, const Color(0xFF2563EB), isDark, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Recent Payments Card
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Recent Payments',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const CollectPaymentDialog(),
                        );
                      },
                      child: const Text(
                        '+ Collect',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No recent payments logged',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  ...recent.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Color(0xFF16A34A),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.studentName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${p.paymentMode} • ${p.relativeTime}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            p.amountFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLegendRow(String title, String amount, Color dotColor, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double collectedPct;
  final double pendingPct;
  final double overduePct;
  final bool isDark;

  _DonutChartPainter({
    required this.collectedPct,
    required this.pendingPct,
    required this.overduePct,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 14.0;

    // Background track
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -math.pi / 2;

    // 1. Collected Arc (Green)
    if (collectedPct > 0) {
      final sweepAngle = 2 * math.pi * collectedPct;
      final paint = Paint()
        ..color = const Color(0xFF16A34A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // 2. Pending Arc (Amber)
    if (pendingPct > 0) {
      final sweepAngle = 2 * math.pi * pendingPct;
      final paint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // 3. Overdue Arc (Red)
    if (overduePct > 0) {
      final sweepAngle = 2 * math.pi * overduePct;
      final paint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.collectedPct != collectedPct ||
        oldDelegate.pendingPct != pendingPct ||
        oldDelegate.overduePct != overduePct ||
        oldDelegate.isDark != isDark;
  }
}
