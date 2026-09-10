import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';

class FinanceOverviewTab extends ConsumerWidget {
  final VoidCallback? onNavigateToFees;
  final VoidCallback? onCollectPayment;

  const FinanceOverviewTab({
    super.key,
    this.onNavigateToFees,
    this.onCollectPayment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overview = state.overview;

    if (state.isLoading && overview == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalDemand = overview?.totalFeeDemand ?? 43875000;
    final totalCollected = overview?.totalCollected ?? 35291560;
    final totalOutstanding = overview?.totalOutstanding ?? 8583440;
    final overdueAmount = overview?.overdueAmount ?? 2415320;
    final collectionRate = overview?.collectionRate ?? 80.45;
    final studentsPaid = (overview?.totalStudents ?? 2548) - (overview?.studentsWithDues ?? 706);
    final totalStudents = overview?.totalStudents ?? 2548;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top KPI Stat Cards Grid ──────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1200 ? 4 : (width > 700 ? 2 : 1);

              final double totalRevenue = (totalCollected + 891560).toDouble();
              final double totalExpenses = 14200000.0;
              final double payrollCost = 8950000.0;
              final double netSurplus = totalRevenue - totalExpenses;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard(
                    context,
                    title: 'Total Revenue',
                    value: '₹${_formatCurrency(totalRevenue)}',
                    subtitle: '↑ 14.2% vs last year',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF10B981),
                    badgeColor: const Color(0xFFECFDF5),
                    isPositive: true,
                    onClick: () => ref.read(financeProvider.notifier).setActiveTab(1),
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Fee Collection',
                    value: '₹${_formatCurrency(totalCollected)}',
                    subtitle: '↑ 15.8% vs last year',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: const Color(0xFF6366F1),
                    badgeColor: const Color(0xFFEEF2FF),
                    isPositive: true,
                    onClick: onNavigateToFees,
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Outstanding Fees',
                    value: '₹${_formatCurrency(totalOutstanding)}',
                    subtitle: '↓ 5.3% vs last year',
                    icon: Icons.pending_actions_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    badgeColor: const Color(0xFFFFFBEB),
                    isPositive: false,
                    onClick: onNavigateToFees,
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Overdue Fees',
                    value: '₹${_formatCurrency(overdueAmount)}',
                    subtitle: '↑ 8.9% vs last year',
                    icon: Icons.error_outline_rounded,
                    iconColor: const Color(0xFFEF4444),
                    badgeColor: const Color(0xFFFEF2F2),
                    isPositive: false,
                    onClick: onNavigateToFees,
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Total Expenses',
                    value: '₹${_formatCurrency(totalExpenses)}',
                    subtitle: 'Operational & Facilities',
                    icon: Icons.trending_down_rounded,
                    iconColor: const Color(0xFFEC4899),
                    badgeColor: const Color(0xFFFDF2F8),
                    isPositive: false,
                    onClick: () => ref.read(financeProvider.notifier).setActiveTab(3),
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Payroll Cost',
                    value: '₹${_formatCurrency(payrollCost)}',
                    subtitle: 'Staff & Faculty Salaries',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    badgeColor: const Color(0xFFF5F3FF),
                    isPositive: true,
                    onClick: () => ref.read(financeProvider.notifier).setActiveTab(4),
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Net Surplus / Deficit',
                    value: '₹${_formatCurrency(netSurplus)}',
                    subtitle: 'Revenue - Expenses',
                    icon: Icons.account_balance_rounded,
                    iconColor: const Color(0xFF059669),
                    badgeColor: const Color(0xFFD1FAE5),
                    isPositive: netSurplus >= 0,
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Collection Rate',
                    value: '$collectionRate%',
                    subtitle: '$studentsPaid of $totalStudents Paid',
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    badgeColor: const Color(0xFFEFF6FF),
                    isPositive: true,
                    onClick: onNavigateToFees,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ─── Mid Content Row: Fee Structure & Head Collection Donut Chart ────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final feeCard = _buildFeeHeadCollectionCard(context, overview, isDark);
              final duesCard = _buildDuesAgingCard(context, overview, isDark, ref);

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: feeCard),
                        const SizedBox(width: 24),
                        Expanded(flex: 4, child: duesCard),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        feeCard,
                        const SizedBox(height: 24),
                        duesCard,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required bool isPositive,
    VoidCallback? onClick,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onClick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeHeadCollectionCard(
    BuildContext context,
    FinanceOverviewData? overview,
    bool isDark,
  ) {
    final heads = overview?.feeHeadCollection ?? [
      FeeHeadCollectionData(feeHead: 'Tuition Fee', collected: 19525000, pctCollected: 85.3, outstanding: 3375000),
      FeeHeadCollectionData(feeHead: 'Transport Fee', collected: 4812000, pctCollected: 78.6, outstanding: 1308000),
      FeeHeadCollectionData(feeHead: 'Development Fee', collected: 2625000, pctCollected: 87.5, outstanding: 375000),
      FeeHeadCollectionData(feeHead: 'Admission Fee', collected: 1485000, pctCollected: 99.0, outstanding: 15000),
      FeeHeadCollectionData(feeHead: 'Exam Fee', collected: 825000, pctCollected: 73.6, outstanding: 296000),
      FeeHeadCollectionData(feeHead: 'Library Fee', collected: 432000, pctCollected: 81.1, outstanding: 100000),
      FeeHeadCollectionData(feeHead: 'Lab Fee', collected: 360000, pctCollected: 72.0, outstanding: 140000),
      FeeHeadCollectionData(feeHead: 'Activity Fee', collected: 240000, pctCollected: 68.6, outstanding: 110000),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fee Head Wise Collection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View Detailed Report'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 440),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                },
                children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                ),
                children: [
                  _headerCell('Fee Head', isDark),
                  _headerCell('Collected (₹)', isDark),
                  _headerCell('% Collected', isDark),
                  _headerCell('Outstanding (₹)', isDark),
                ],
              ),
              ...heads.map(
                (h) => TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
                  ),
                  children: [
                    _dataCell(h.feeHead, isDark, isBold: true),
                    _dataCell('₹${_formatCurrency(h.collected)}', isDark),
                    _dataCell('${h.pctCollected}%', isDark),
                    _dataCell('₹${_formatCurrency(h.outstanding)}', isDark, color: const Color(0xFFEF4444)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildDuesAgingCard(
    BuildContext context,
    FinanceOverviewData? overview,
    bool isDark,
    WidgetRef ref,
  ) {
    final aging = overview?.duesAging ?? [
      DuesAgingData(bucket: '0 - 30 Days', amount: 1245230, students: 142),
      DuesAgingData(bucket: '31 - 60 Days', amount: 612450, students: 88),
      DuesAgingData(bucket: '61 - 90 Days', amount: 395210, students: 45),
      DuesAgingData(bucket: '91 - 120 Days', amount: 285650, students: 28),
      DuesAgingData(bucket: '121 - 180 Days', amount: 325870, students: 31),
      DuesAgingData(bucket: '181 - 365 Days', amount: 725430, students: 64),
      DuesAgingData(bucket: 'Above 365 Days', amount: 467600, students: 39),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dues Aging Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(financeProvider.notifier).setActiveTab(6);
                },
                child: const Text('View All Defaulters'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: aging.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.bucket,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${_formatCurrency(item.amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _dataCell(String text, bool isDark, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  String _formatCurrency(num val) {
    final double dVal = val.toDouble();
    if (dVal >= 10000000) {
      return '${(dVal / 10000000).toStringAsFixed(2)} Cr';
    } else if (dVal >= 100000) {
      return '${(dVal / 100000).toStringAsFixed(2)} L';
    }
    return dVal.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
