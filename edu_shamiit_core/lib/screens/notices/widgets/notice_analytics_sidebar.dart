import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/notice_models.dart';
import '../providers/notice_provider.dart';
import 'dialogs/bulk_upload_notice_dialog.dart';
import 'dialogs/create_edit_notice_dialog.dart';
import 'dialogs/notice_categories_dialog.dart';

class NoticeAnalyticsSidebar extends ConsumerWidget {
  final String userRole;

  const NoticeAnalyticsSidebar({
    super.key,
    required this.userRole,
  });

  bool get canCreateNotice {
    final r = userRole.toLowerCase();
    return r == 'super_admin' ||
        r == 'admin' ||
        r == 'principal' ||
        r == 'vice_principal' ||
        r == 'director' ||
        r == 'teacher' ||
        r == 'class_teacher' ||
        r == 'transport_manager' ||
        r == 'hr' ||
        r == 'accountant' ||
        r == 'librarian';
  }

  void _downloadSampleTemplate() {
    const csvContent =
        "title,content,category,priority,status,target_scope,target_roles,target_classes,requires_acknowledgement,is_urgent\n"
        "Annual Sports Day Announcement,All students and staff are invited to participate in the Annual Sports Meet.,Event,high,published,entire_institute,,,true,false\n"
        "Parent Teacher Meeting Notice,Term-1 Parent Teacher Meeting will be conducted this Saturday.,Meeting,normal,published,roles,\"parent,teacher\",,false,false\n"
        "Class 10 Revision Schedule,Extra revision classes schedule for Class 10 Board Examinations.,Academic,high,published,classes,,\"10A, 10B\",true,false\n";

    final uri = Uri.dataFromString(
      csvContent,
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = state.summary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Quick Actions Card
          if (canCreateNotice) ...[
            _buildQuickActionsCard(context, isDark),
            const SizedBox(height: 16),
          ],

          // 2. Notice Summary Metrics Card
          _buildNoticeSummaryCard(context, summary, isDark),
          const SizedBox(height: 16),

          // 3. Engagement Overview Donut Chart Card (Real Data Only)
          _buildEngagementOverviewCard(context, summary, isDark),
          const SizedBox(height: 16),

          // 4. Top Categories Progress Bars Card (Real Data Only)
          _buildTopCategoriesCard(context, summary, isDark),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 1. Quick Actions Card
  // --------------------------------------------------------------------------
  Widget _buildQuickActionsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Create Notice Primary
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const CreateEditNoticeDialog(),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Notice / Circular', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Actions Grid
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const BulkUploadNoticeDialog(),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 15, color: Color(0xFF10B981)),
                  label: const Text('Bulk Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadSampleTemplate,
                  icon: const Icon(Icons.file_download_outlined, size: 15, color: Color(0xFFF59E0B)),
                  label: const Text('Export Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. Notice Summary Card
  // --------------------------------------------------------------------------
  Widget _buildNoticeSummaryCard(BuildContext context, NoticeSummaryModel summary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notice Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2x3 Metric Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              _buildMetricTile('Total Notices', '${summary.totalNotices}', const Color(0xFF4F46E5), isDark),
              _buildMetricTile('Published', '${summary.published}', const Color(0xFF10B981), isDark),
              _buildMetricTile('Scheduled', '${summary.scheduled}', const Color(0xFF0EA5E9), isDark),
              _buildMetricTile('Drafts', '${summary.drafts}', const Color(0xFFF59E0B), isDark),
              _buildMetricTile('Expired', '${summary.expired}', const Color(0xFFEF4444), isDark),
              _buildMetricTile('Archived', '${summary.archived}', const Color(0xFF6B7280), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. Engagement Overview Donut Chart Card (Pure Real Data)
  // --------------------------------------------------------------------------
  Widget _buildEngagementOverviewCard(BuildContext context, NoticeSummaryModel summary, bool isDark) {
    final int viewed = summary.viewed;
    final int notViewed = summary.notViewed;
    final int partially = summary.partiallyViewed;
    final int totalRecipients = viewed + notViewed + partially;

    final double viewedPct = totalRecipients > 0 ? (viewed / totalRecipients * 100) : 0.0;
    final double notViewedPct = totalRecipients > 0 ? (notViewed / totalRecipients * 100) : 0.0;
    final double partiallyPct = totalRecipients > 0 ? (partially / totalRecipients * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Donut Chart
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  viewedPct: viewedPct,
                  notViewedPct: notViewedPct,
                  partiallyPct: partiallyPct,
                  isDark: isDark,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Views',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.totalViews}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend with Real Counts and Percentages
          _buildLegendRow('Viewed', '$viewed (${viewedPct.toStringAsFixed(1)}%)', const Color(0xFF10B981), isDark),
          const SizedBox(height: 6),
          _buildLegendRow('Not Viewed', '$notViewed (${notViewedPct.toStringAsFixed(1)}%)', const Color(0xFFEF4444), isDark),
          const SizedBox(height: 6),
          _buildLegendRow('Partially Viewed', '$partially (${partiallyPct.toStringAsFixed(1)}%)', const Color(0xFFF59E0B), isDark),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String valueText, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 4. Top Categories Card (Pure Real Data)
  // --------------------------------------------------------------------------
  Widget _buildTopCategoriesCard(BuildContext context, NoticeSummaryModel summary, bool isDark) {
    final list = summary.categoryDistribution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          if (list.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'No category data available yet',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            )
          else
            // Real Categories Progress Bars
            ...list.take(5).map((cat) {
              final color = _getCategoryColor(cat.category);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '${cat.count} (${cat.percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (cat.percentage / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 4),

          // Manage Categories Button
          if (canCreateNotice)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const NoticeCategoriesDialog(),
                  );
                },
                icon: const Icon(Icons.category_outlined, size: 14),
                label: const Text('Manage Categories', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return const Color(0xFFF97316);
      case 'meeting':
        return const Color(0xFF8B5CF6);
      case 'event':
        return const Color(0xFF10B981);
      case 'holiday':
        return const Color(0xFFEC4899);
      case 'academic':
        return const Color(0xFF0EA5E9);
      case 'exam':
      case 'examination':
        return const Color(0xFFF59E0B);
      case 'transport':
        return const Color(0xFF06B6D4);
      case 'fee':
      case 'fee & accounts':
        return const Color(0xFF14B8A6);
      case 'emergency':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }
}

// ============================================================================
// Donut Chart Custom Painter
// ============================================================================

class _DonutChartPainter extends CustomPainter {
  final double viewedPct;
  final double notViewedPct;
  final double partiallyPct;
  final bool isDark;

  _DonutChartPainter({
    required this.viewedPct,
    required this.notViewedPct,
    required this.partiallyPct,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final paintBg = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, paintBg);

    final total = viewedPct + notViewedPct + partiallyPct;
    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    void drawSegment(double pct, Color color) {
      if (pct <= 0) return;
      final sweepAngle = (pct / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
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

    drawSegment(viewedPct, const Color(0xFF10B981));
    drawSegment(notViewedPct, const Color(0xFFEF4444));
    drawSegment(partiallyPct, const Color(0xFFF59E0B));
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.viewedPct != viewedPct ||
        oldDelegate.notViewedPct != notViewedPct ||
        oldDelegate.partiallyPct != partiallyPct ||
        oldDelegate.isDark != isDark;
  }
}
