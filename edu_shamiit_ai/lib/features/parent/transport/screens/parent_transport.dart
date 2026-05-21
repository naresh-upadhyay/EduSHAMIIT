import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentTransport extends ConsumerWidget {
  const ParentTransport({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transportAsync = ref.watch(parentTransportProvider);

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
                    'Transport'.tr(ref),
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

          // ── Body ──
          Expanded(
            child: transportAsync.when(
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
    final routeInfo = data['route'] as Map<String, dynamic>? ?? {};
    final stops = data['stops'] as List<dynamic>? ?? [];
    final driverInfo = data['driver'] as Map<String, dynamic>? ?? {};

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          // ── Route Info Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('🚌', style: TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routeInfo['route_name'] ?? 'Bus Route'.tr(ref),
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Bus No: ${routeInfo['bus_number'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoItem('Pickup'.tr(ref), routeInfo['pickup_time'] ?? '-',
                        Icons.access_time),
                    _infoItem('Drop'.tr(ref), routeInfo['drop_time'] ?? '-',
                        Icons.access_time_filled),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Driver Info ──
          if (driverInfo.isNotEmpty) ...[
            Text(
              'Driver Information'.tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? ParentColors.darkText : ParentColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? ParentColors.darkSurface : ParentColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        isDark ? ParentColors.darkBorder : ParentColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ParentColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('👨‍✈️', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverInfo['name'] ?? 'Driver',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? ParentColors.darkText
                                : ParentColors.text,
                          ),
                        ),
                        Text(
                          driverInfo['phone'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? ParentColors.darkText3
                                : ParentColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (driverInfo['phone'] != null)
                    IconButton(
                      icon:
                          const Icon(Icons.phone, color: ParentColors.success),
                      onPressed: () {
                        // Launch phone call
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Bus Stops ──
          if (stops.isNotEmpty) ...[
            Text(
              'Route Stops'.tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? ParentColors.darkText : ParentColors.text,
              ),
            ),
            const SizedBox(height: 12),
            ...stops.asMap().entries.map((entry) {
              final index = entry.key;
              final stop = entry.value as Map<String, dynamic>;
              final isLast = index == stops.length - 1;
              return _buildStopItem(stop, isLast, isDark);
            }),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildStopItem(Map<String, dynamic> stop, bool isLast, bool isDark) {
    final name = stop['stop_name'] ?? 'Stop';
    final time = stop['time'] ?? '';
    final isPickup = stop['is_pickup'] == true;

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color:
                        isPickup ? ParentColors.primary : ParentColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark
                          ? ParentColors.darkBorder
                          : ParentColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? ParentColors.darkSurface : ParentColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        isDark ? ParentColors.darkBorder : ParentColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? ParentColors.darkText : ParentColors.text,
                      ),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ParentColors.darkText3
                            : ParentColors.text3,
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

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load transport info'.tr(ref),
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
            onPressed: () => ref.invalidate(parentTransportProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
