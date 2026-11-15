import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';

class HostelTurnoverForecastCard extends ConsumerStatefulWidget {
  const HostelTurnoverForecastCard({super.key});

  @override
  ConsumerState<HostelTurnoverForecastCard> createState() => _HostelTurnoverForecastCardState();
}

class _HostelTurnoverForecastCardState extends ConsumerState<HostelTurnoverForecastCard> {
  bool _isExpanded = false;
  double _graduatingPercentage = 30.0;
  bool _initializedFromDb = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(hostelProvider).turnoverForecast == null) {
        ref.read(hostelProvider.notifier).fetchTurnoverForecast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tf = state.turnoverForecast ?? {};
    final totalCapacity = tf['total_capacity'] as int? ?? (state.kpis.totalBeds > 0 ? state.kpis.totalBeds : 0);
    final totalOccupied = tf['current_occupancy'] as int? ?? (state.kpis.occupiedBeds > 0 ? state.kpis.occupiedBeds : 0);
    final terminalResidents = tf['terminal_residents'] as int? ?? (totalCapacity > 0 ? ((totalOccupied * 0.3).round()) : 0);
    final dbTerminalPct = (tf['terminal_percentage'] as num?)?.toDouble();

    if (!_initializedFromDb && dbTerminalPct != null && dbTerminalPct > 0) {
      _graduatingPercentage = dbTerminalPct.clamp(10.0, 60.0);
      _initializedFromDb = true;
    }

    final graduatingCount = totalCapacity > 0 ? ((totalOccupied * _graduatingPercentage) / 100).round() : 0;
    final postTurnoverVacancies = totalCapacity > 0 ? (totalCapacity - totalOccupied) + graduatingCount : 0;
    final projectedOccupancyRate = totalCapacity > 0 ? (((totalOccupied - graduatingCount) / totalCapacity) * 100).toStringAsFixed(1) : '0.0';

    // Financial turnover estimates based on active database calculations
    final avgDeposit = (tf['caution_deposit_liability'] as num?)?.toDouble() != null && terminalResidents > 0
        ? ((tf['caution_deposit_liability'] as num).toDouble() / terminalResidents)
        : (state.kpis.occupiedBeds > 0 ? 5000.0 : 0.0);
    final estimatedDepositRefundLiability = graduatingCount * avgDeposit;
    final avgAnnualFee = (tf['average_annual_fee'] as num?)?.toDouble() ?? (state.kpis.occupiedBeds > 0 ? 36000.0 : 0.0);
    final projectedNewSessionIntakeRevenue = (graduatingCount + (totalCapacity - totalOccupied)) * avgAnnualFee;

    final currencyFmt = NumberFormat('#,##,###');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header clickable strip
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_graph_rounded, color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Session Turnover & Capacity Forecasting',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'AI FORECAST',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimated seat vacancies, caution deposit refunds, and onboarding capacity for next term',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Interactive Slider
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Projected Final-Term Passing-Out Cohort: ${_graduatingPercentage.toInt()}% of Occupancy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '$graduatingCount Residents Leaving',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                  Slider(
                    value: _graduatingPercentage,
                    min: 10,
                    max: 60,
                    divisions: 10,
                    activeColor: const Color(0xFF7C3AED),
                    label: '${_graduatingPercentage.toInt()}%',
                    onChanged: (v) => setState(() => _graduatingPercentage = v),
                  ),
                  const SizedBox(height: 14),

                  // 4 Intelligence Projection Metric Cards (Responsive Grid)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 750;

                      final card1 = _buildMetricCard(
                        'Available for New Admissions',
                        '$postTurnoverVacancies Beds',
                        'Post-graduation vacancy pool',
                        const Color(0xFF2563EB),
                        isDark,
                      );
                      final card2 = _buildMetricCard(
                        'Interim Base Occupancy',
                        '$projectedOccupancyRate%',
                        'Retained continuing residents',
                        const Color(0xFF16A34A),
                        isDark,
                      );
                      final card3 = _buildMetricCard(
                        'Deposit Liquidity Needed',
                        '₹ ${currencyFmt.format(estimatedDepositRefundLiability)}',
                        'Est. caution refunds liability',
                        const Color(0xFFDC2626),
                        isDark,
                      );
                      final card4 = _buildMetricCard(
                        'Projected New Intake Revenue',
                        '₹ ${currencyFmt.format(projectedNewSessionIntakeRevenue)}',
                        'Refill potential at full capacity',
                        const Color(0xFF059669),
                        isDark,
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 10),
                                Expanded(child: card2),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: card3),
                                const SizedBox(width: 10),
                                Expanded(child: card4),
                              ],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 12),
                          Expanded(child: card2),
                          const SizedBox(width: 12),
                          Expanded(child: card3),
                          const SizedBox(width: 12),
                          Expanded(child: card4),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Recommended Maintenance Window Alert
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Maintenance & Deep Sanitization Window',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'A 14-day transition period between the outgoing cohort checkout and the incoming session onboarding is advised to complete deep cleaning, paint retouching, and asset inspection for all $postTurnoverVacancies vacating beds.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
