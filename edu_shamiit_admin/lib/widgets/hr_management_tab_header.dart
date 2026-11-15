import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:go_router/go_router.dart';

enum HRTab { overview, recruitment, onboarding, training, policies }

/// Premium Unified Header for all HR Management tabs.
/// Combines an executive-tier title bar with the tab navigation switcher.
class HRManagementHeader extends StatelessWidget {
  final HRTab activeTab;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final List<Widget> actions;
  final String eyebrow;
  final Widget? bottom;

  const HRManagementHeader({
    super.key,
    required this.activeTab,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onRefresh,
    this.isRefreshing = false,
    this.actions = const [],
    this.eyebrow = 'ORGANIZATION • HR MANAGEMENT',
    this.bottom,
  });

  /// Standardized Primary Action Button
  static Widget primaryButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// Standardized Secondary / Outlined Action Button
  static Widget secondaryButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
        label: Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            fontSize: 13,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const brandColor = Color(0xFF4F46E5);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Executive Top Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 800;

                final iconWidget = Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E1B4B),
                              const Color(0xFF312E81),
                            ]
                          : [
                              const Color(0xFFEEF2FF),
                              const Color(0xFFE0E7FF),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                          : const Color(0xFFC7D2FE),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: brandColor.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 24,
                      color: isDark ? const Color(0xFF818CF8) : brandColor,
                    ),
                  ),
                );

                final titleColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Eyebrow badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF818CF8) : brandColor,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? const Color(0xFF818CF8) : brandColor)
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            eyebrow,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF818CF8) : brandColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontFamily: 'Inter',
                        color: textSecondary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final actionsWrap = Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onRefresh != null)
                      Tooltip(
                        message: 'Refresh Data',
                        child: InkWell(
                          onTap: isRefreshing ? null : onRefresh,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Center(
                              child: isRefreshing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ...actions.map((act) => SizedBox(height: 38, child: act)),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          iconWidget,
                          const SizedBox(width: 16),
                          Expanded(child: titleColumn),
                        ],
                      ),
                      if (actions.isNotEmpty || onRefresh != null) ...[
                        const SizedBox(height: 14),
                        actionsWrap,
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 16),
                    Expanded(child: titleColumn),
                    const SizedBox(width: 16),
                    actionsWrap,
                  ],
                );
              },
            ),
          ),

          if (bottom != null) bottom!,

          // Subtle Divider above tabs
          Divider(height: 1, thickness: 1, color: borderColor),

          // 2. Tab Navigation Switcher
          HRManagementTabHeader(activeTab: activeTab),
        ],
      ),
    );
  }
}

/// The horizontal tab navigation switcher for HR Management screens.
class HRManagementTabHeader extends StatelessWidget {
  final HRTab activeTab;

  const HRManagementTabHeader({
    super.key,
    required this.activeTab,
  });

  static const _tabs = [
    {
      'tab': HRTab.overview,
      'title': 'Overview',
      'icon': Icons.dashboard_rounded,
      'route': '/admin/hr/overview',
    },
    {
      'tab': HRTab.recruitment,
      'title': 'Recruitment',
      'icon': Icons.badge_outlined,
      'route': '/admin/hr/recruitment',
    },
    {
      'tab': HRTab.onboarding,
      'title': 'Onboarding',
      'icon': Icons.person_add_alt_1_outlined,
      'route': '/admin/hr/onboarding',
    },
    {
      'tab': HRTab.training,
      'title': 'Training & Learning',
      'icon': Icons.school_outlined,
      'route': '/admin/hr/training',
    },
    {
      'tab': HRTab.policies,
      'title': 'Policies & Documents',
      'icon': Icons.folder_shared_outlined,
      'route': '/admin/hr/policies',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _tabs.map((item) {
            final tabType = item['tab'] as HRTab;
            final isSelected = tabType == activeTab;
            final title = item['title'] as String;
            final icon = item['icon'] as IconData;
            final route = item['route'] as String;

            return InkWell(
              onTap: () {
                if (!isSelected) {
                  context.go(route);
                  Future.microtask(() {
                    dispatchTabChanged();
                  });
                }
              },
              hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.12 : 0.06)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected
                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontFamily: 'Inter',
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

