import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentAchievements extends ConsumerWidget {
  const ParentAchievements({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final achievementsAsync = ref.watch(parentAchievementsProvider);

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
                    'Achievements'.tr(ref),
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
            child: achievementsAsync.when(
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
    final xpPoints = data['xp_points'] ?? 0;
    final learningStreak = data['learning_streak'] ?? 0;
    final bestStreak = data['best_streak'] ?? 0;
    final achievements = data['achievements'] as List<dynamic>? ?? [];

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          // ── Stats Row ──
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '⚡',
                  'XP Points'.tr(ref),
                  '$xpPoints',
                  ParentColors.accent,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  '🔥',
                  'Current Streak'.tr(ref),
                  '$learningStreak days',
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  '🏆',
                  'Best Streak'.tr(ref),
                  '$bestStreak days',
                  ParentColors.primary,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Section Title ──
          Text(
            'Earned Badges'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (achievements.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text('🏅', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      'No achievements yet'.tr(ref),
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? ParentColors.darkText2
                            : ParentColors.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep going! Achievements will appear here.'.tr(ref),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? ParentColors.darkText3
                            : ParentColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...achievements.map((a) {
              final achievement = a as Map<String, dynamic>;
              return _buildAchievementCard(achievement, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String emoji, String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? ParentColors.darkBorder : ParentColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? ParentColors.darkText3 : ParentColors.text3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement, bool isDark) {
    final achievementData =
        achievement['achievements'] as Map<String, dynamic>? ?? {};
    final name = achievementData['name'] ?? 'Achievement';
    final description = achievementData['description'] ?? '';
    final icon = achievementData['icon'] ?? '🏅';
    final rarity = achievementData['rarity'] ?? 'common';
    final xpReward = achievementData['xp_reward'] ?? 0;
    final earnedAt = achievement['earned_at'] ?? '';

    final rarityColor = rarity == 'legendary'
        ? Colors.purple
        : rarity == 'epic'
            ? Colors.deepPurple
            : rarity == 'rare'
                ? Colors.blue
                : rarity == 'uncommon'
                    ? Colors.green
                    : ParentColors.text3;

    final rarityLabel = rarity[0].toUpperCase() + rarity.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? ParentColors.darkText
                              : ParentColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rarityLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: rarityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ParentColors.darkText3
                            : ParentColors.text3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (xpReward > 0) ...[
                      Text(
                        '⚡ +$xpReward XP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ParentColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (earnedAt.isNotEmpty)
                      Text(
                        _formatDate(earnedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3,
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
            'Failed to load achievements'.tr(ref),
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
            onPressed: () => ref.invalidate(parentAchievementsProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
