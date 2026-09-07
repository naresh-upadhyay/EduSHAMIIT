import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/request_models.dart';
import '../providers/request_provider.dart';

class RequestSidePanels extends ConsumerWidget {
  final Function(String requestId)? onViewRequest;

  const RequestSidePanels({
    Key? key,
    this.onViewRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final kpis = state.kpis;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel 1: Request Types Breakdown Card
          _buildRequestTypesCard(context, kpis.typeCounts, state.selectedType, notifier),
          const SizedBox(height: 18),

          // Panel 2: Status Distribution Donut Chart Card
          _buildStatusDistributionCard(context, kpis.statusDistribution),
          const SizedBox(height: 18),

          // Panel 3: Recent Requests Feed
          _buildRecentRequestsCard(context, kpis.recentRequests, notifier),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeStyling(String type) {
    final t = type.toLowerCase();
    if (t.contains('audio')) {
      return {'icon': Icons.headphones_rounded, 'color': const Color(0xFFDB2777), 'bg': const Color(0xFFFCE7F3)};
    } else if (t.contains('e-book') || t.contains('ebook')) {
      return {'icon': Icons.tablet_mac_rounded, 'color': const Color(0xFF7C3AED), 'bg': const Color(0xFFEDE9FE)};
    } else if (t.contains('digital') || t.contains('resource')) {
      return {'icon': Icons.folder_zip_rounded, 'color': const Color(0xFF0284C7), 'bg': const Color(0xFFE0F2FE)};
    } else if (t.contains('journal') || t.contains('magazine')) {
      return {'icon': Icons.auto_stories_rounded, 'color': const Color(0xFFD97706), 'bg': const Color(0xFFFEF3C7)};
    } else if (t.contains('book')) {
      return {'icon': Icons.menu_book_rounded, 'color': const Color(0xFF2563EB), 'bg': const Color(0xFFEFF6FF)};
    }
    return {'icon': Icons.more_horiz_rounded, 'color': const Color(0xFF64748B), 'bg': const Color(0xFFF1F5F9)};
  }

  Widget _buildRequestTypesCard(
    BuildContext context,
    List<RequestTypeCount> typeCounts,
    String selectedType,
    RequestNotifier notifier,
  ) {
    final itemsToDisplay = typeCounts.isNotEmpty
        ? typeCounts
        : [
            const RequestTypeCount(type: 'Book', count: 0),
            const RequestTypeCount(type: 'E-Book', count: 0),
            const RequestTypeCount(type: 'Digital Resource', count: 0),
            const RequestTypeCount(type: 'Audiobook', count: 0),
            const RequestTypeCount(type: 'Journal / Magazine', count: 0),
            const RequestTypeCount(type: 'Other', count: 0),
          ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Request Types',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (selectedType != 'ALL')
                  GestureDetector(
                    onTap: () => notifier.setTypeFilter('ALL'),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Dynamic List of types directly from DB
          ...itemsToDisplay.map((item) {
            final tName = item.type;
            final isSelected = selectedType.toLowerCase() == tName.toLowerCase();
            final style = _getTypeStyling(tName);
            final count = item.count;

            return Material(
              color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (isSelected) {
                    notifier.setTypeFilter('ALL');
                  } else {
                    notifier.setTypeFilter(tName);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: style['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(style['icon'] as IconData, size: 16, color: style['color'] as Color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? (style['color'] as Color).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? (style['color'] as Color) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusDistributionCard(
    BuildContext context,
    List<StatusDistributionItem> distribution,
  ) {
    final displayItems = distribution;
    final totalCount = displayItems.fold<int>(0, (sum, e) => sum + e.count);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Distribution',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),

          if (displayItems.isEmpty || totalCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No status distribution data',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Donut Chart Graphic & Center Metric
            Center(
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _DonutChartPainter(items: displayItems),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Legend list with percentages
            ...displayItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.getColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.status,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }


  Widget _buildRecentRequestsCard(
    BuildContext context,
    List<RecentRequestItem> recentList,
    RequestNotifier notifier,
  ) {
    if (recentList.isEmpty) {
      return const SizedBox();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              'Recent Requests',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Items
          ...recentList.take(4).map((item) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  notifier.openRequestDetail(item.id);
                  onViewRequest?.call(item.id);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.requestNumber} • ${item.requesterName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      _buildSmallStatusDot(item.status),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSmallStatusDot(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        color = const Color(0xFF2563EB);
        break;
      case 'IN_PROGRESS':
      case 'ACTIVE':
        color = const Color(0xFF7C3AED);
        break;
      case 'RESOLVED':
      case 'COMPLETED':
        color = const Color(0xFF10B981);
        break;
      case 'REJECTED':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFF94A3B8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<StatusDistributionItem> items;

  _DonutChartPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 14.0;

    double startAngle = -math.pi / 2;

    for (var item in items) {
      final sweepAngle = (item.percentage / 100.0) * (2 * math.pi);
      final paint = Paint()
        ..color = item.getColor()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
