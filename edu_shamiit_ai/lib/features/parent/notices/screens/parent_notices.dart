import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentNotices extends ConsumerWidget {
  const ParentNotices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final noticesAsync = ref.watch(parentNoticesProvider);

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
                    'Notices'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: noticesAsync.when(
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
    final notices = data['notices'] as List<dynamic>? ?? [];

    if (notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No notices'.tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'School notices will appear here'.tr(ref),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? ParentColors.darkText3 : ParentColors.text3,
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          ...notices.map((n) {
            final notice = n as Map<String, dynamic>;
            return _buildNoticeCard(context, ref, notice, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context, WidgetRef ref,
      Map<String, dynamic> notice, bool isDark) {
    final title = notice['title'] ?? 'Notice';
    final content = notice['content'] ?? '';
    final category = notice['category'] ?? 'general';
    final priority = notice['priority'] ?? 'normal';
    final publishedAt = notice['published_at'] ?? '';
    final author = notice['author'] ?? '';

    final categoryColor = category == 'academic'
        ? Colors.blue
        : category == 'sports'
            ? Colors.green
            : category == 'cultural'
                ? Colors.purple
                : category == 'emergency'
                    ? Colors.red
                    : ParentColors.primary;

    final categoryIcon = category == 'academic'
        ? '📖'
        : category == 'sports'
            ? '⚽'
            : category == 'cultural'
                ? '🎭'
                : category == 'emergency'
                    ? '🚨'
                    : '📢';

    final isUrgent = priority == 'high' || priority == 'urgent';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? ParentColors.darkBorder : ParentColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: category + priority
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(categoryIcon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      category[0].toUpperCase() + category.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isUrgent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 8)),
                      const SizedBox(width: 4),
                      Text(
                        'Urgent'.tr(ref),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),

          // Content
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Footer: author + date
          const SizedBox(height: 10),
          Row(
            children: [
              if (author.isNotEmpty) ...[
                Icon(Icons.person_outline,
                    size: 14,
                    color:
                        isDark ? ParentColors.darkText3 : ParentColors.text3),
                const SizedBox(width: 4),
                Text(
                  author,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (publishedAt.isNotEmpty) ...[
                Icon(Icons.access_time,
                    size: 14,
                    color:
                        isDark ? ParentColors.darkText3 : ParentColors.text3),
                const SizedBox(width: 4),
                Text(
                  _formatDate(publishedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load notices'.tr(ref),
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentNoticesProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
