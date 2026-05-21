import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentFees extends ConsumerStatefulWidget {
  const ParentFees({super.key});

  @override
  ConsumerState<ParentFees> createState() => _ParentFeesState();
}

class _ParentFeesState extends ConsumerState<ParentFees> {
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['Pending', 'Paid', 'All'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feesAsync = ref.watch(parentFeesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fees & Payments'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const ChildSwitcher(),
              ],
            ),
          ),

          // ── Filter Chips ──
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: ParentColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? ParentColors.darkText2
                            : ParentColors.text2),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                );
              },
            ),
          ),

          // ── Body ──
          Expanded(
            child: feesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final fees = data['fees'] as List<dynamic>? ?? [];
    final totalOutstanding =
        (data['total_outstanding'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (data['total_paid'] as num?)?.toDouble() ?? 0.0;

    final filtered = _selectedFilter == 'All'
        ? fees
        : fees.where((f) {
            final status = (f as Map<String, dynamic>)['status'] ?? '';
            return _selectedFilter.toLowerCase() == status.toLowerCase();
          }).toList();

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 8, bottom: 16),
        children: [
          // ── Summary Cards ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ParentColors.darkSurface
                        : ParentColors.errorBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? ParentColors.darkBorder
                          : ParentColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outstanding'.tr(ref),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? ParentColors.darkText2
                              : ParentColors.text2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalOutstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ParentColors.darkSurface
                        : ParentColors.successBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? ParentColors.darkBorder
                          : ParentColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Paid'.tr(ref),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? ParentColors.darkText2
                              : ParentColors.text2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalPaid.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ParentColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Fee Items ──
          Text(
            'Fee Details'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'No ${_selectedFilter.toLowerCase()} fees'.tr(ref),
                      style: TextStyle(
                          color: isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((f) {
              final fee = f as Map<String, dynamic>;
              return _buildFeeCard(fee, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> fee, bool isDark) {
    final title = fee['title'] ?? fee['month'] ?? 'Fee';
    final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
    final dueDate = fee['due_date'] ?? '';
    final status = fee['status'] ?? 'pending';
    final paidAmount = (fee['paid_amount'] as num?)?.toDouble() ?? 0;

    final statusColor = status == 'paid'
        ? ParentColors.success
        : status == 'partial'
            ? ParentColors.warning
            : ParentColors.error;
    final statusBg = status == 'paid'
        ? ParentColors.successBg
        : status == 'partial'
            ? ParentColors.warningBg
            : ParentColors.errorBg;
    final statusIcon = status == 'paid'
        ? '✅'
        : status == 'partial'
            ? '⏳'
            : '⏰';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? statusColor.withValues(alpha: 0.2) : statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(statusIcon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                if (dueDate.isNotEmpty)
                  Text(
                    'Due: $dueDate',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                  ),
                if (status == 'partial')
                  Text(
                    'Paid: ₹${paidAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11, color: ParentColors.warning),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? statusColor.withValues(alpha: 0.2) : statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load fees'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentFeesProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
