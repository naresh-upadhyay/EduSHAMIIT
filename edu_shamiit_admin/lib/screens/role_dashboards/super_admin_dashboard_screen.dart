import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SuperAdminDashboardScreen extends ConsumerStatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  ConsumerState<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends ConsumerState<SuperAdminDashboardScreen> {
  final List<Map<String, dynamic>> _quickActions = [

    {
      'title': 'Module Toggle',
      'icon': Icons.extension_outlined,
      'color': Colors.green,
      'bg': 0xFFF0FDF4,
      'route': '/admin/modules',
    },
    {
      'title': 'Module Setup',
      'icon': Icons.settings_applications_outlined,
      'color': Colors.indigo,
      'bg': 0xFFEEF2FF,
      'route': '/admin/modules-config',
    },
    {
      'title': 'Automations',
      'icon': Icons.settings_input_component_outlined,
      'color': Colors.teal,
      'bg': 0xFFECFDF5,
      'route': '/admin/automations',
    },

    {
      'title': 'Smart Insights',
      'icon': Icons.lightbulb_outline,
      'color': Colors.amber,
      'bg': 0xFFFFFBEB,
      'route': '/admin/insights',
    },

    {
      'title': 'APIs',
      'icon': Icons.power_outlined,
      'color': Colors.deepPurple,
      'bg': 0xFFFAF5FF,
      'route': '/admin/apis',
    },
    {
      'title': 'Audit Log',
      'icon': Icons.lock_outline,
      'color': Colors.orange,
      'bg': 0xFFFFF7ED,
      'route': '/admin/audit-log',
    },

    {
      'title': 'Global Tenants',
      'icon': Icons.satellite_alt_outlined,
      'color': Colors.lightBlue,
      'bg': 0xFFEFF6FF,
      'route': '/admin/schools',
    },
    {
      'title': 'Announcements',
      'icon': Icons.campaign_outlined,
      'color': Colors.redAccent,
      'bg': 0xFFFEF2F2,
      'route': '/admin/announcements',
    },
    {
      'title': 'Impersonate/Support',
      'icon': Icons.contact_support_outlined,
      'color': Colors.pink,
      'bg': 0xFFFDF2F8,
      'route': '/admin/support',
    },
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeaderBanner(context),
              SliverToBoxAdapter(
                child: ResponsiveContent(
                  child: Padding(
                    padding: Responsive.contentPadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildQuickAccessHeader(),
                        const SizedBox(height: 14),
                        _buildSmartAiInsightCard(),
                        const SizedBox(height: 20),
                        _buildQuickActionsGrid(theme),
                        const SizedBox(height: 20),
                        _buildActiveTaskBoard(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'Rahul Kapoor';

    final hour = DateTime.now().hour;
    final String greeting;
    final String greetingIcon;
    if (hour >= 5 && hour < 7) {
      greeting = 'Good Morning';
      greetingIcon = '🌅';
    } else if (hour >= 7 && hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = '☀️';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = '🌤️';
    } else if (hour >= 17 && hour < 20) {
      greeting = 'Good Evening';
      greetingIcon = '🌆';
    } else if (hour >= 20 && hour < 24) {
      greeting = 'Good Evening';
      greetingIcon = '🌙';
    } else {
      greeting = 'Good Evening';
      greetingIcon = '⭐';
    }

    return SliverAppBar(
      expandedHeight: Responsive.headerExpandedHeight(context) - 20,
      pinned: true,
      backgroundColor: const Color(0xFF302B63),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting $greetingIcon',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Super Admin - ID: SA-001',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.go('/admin/support'),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => context.go('/admin/config'),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1.5),
                                ),
                                child: const ClipRRect(
                                  borderRadius: BorderRadius.all(Radius.circular(9)),
                                  child: Icon(Icons.person, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Streak-style bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '⚡ System Operations Streak',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              Text(
                                'Noida cluster running healthy',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                          const Column(
                            children: [
                              Text(
                                '99.9%',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 4. Stats items row inside the banner (clean text, no cards)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBannerStatItem(context, '12', 'Schools', '/admin/schools'),
                        _buildBannerStatItem(context, '28.4K', 'Students', '/admin/users'),
                        _buildBannerStatItem(context, '1,840', 'Staff', '/admin/staff'),
                        _buildBannerStatItem(context, '99.9%', 'Uptime', '/admin/infra'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerStatItem(BuildContext context, String value, String label, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        const Text(
          'Quick Access Dashboard',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/admin/config'),
              icon: const Icon(Icons.folder_open_outlined, size: 14, color: Color(0xFF4F46E5)),
              label: const Text(
                'All Modules',
                style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined, size: 14, color: Color(0xFF64748B)),
              label: const Text(
                'Personalize',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmartAiInsightCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 12, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'Smart AI Insight',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Academic admissions increased 14%. Noida server CPU spikes during peak 9-10 AM biometric sync.',
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              fontSize: 11,
              height: 1.4,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final double gridWidth = constraints.maxWidth;
          final int columns = gridWidth > 600 ? 6 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: _quickActions.length,
            itemBuilder: (context, index) {
              final action = _quickActions[index];
              final Color actionBg = isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Color(action['bg'] ?? 0xFFEEF2FF);

              return GestureDetector(
                onTap: () => context.go(action['route']),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: actionBg,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Icon(
                            action['icon'],
                            color: action['color'],
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action['title'],
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildActiveTaskBoard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Colors.orangeAccent, size: 16),
            SizedBox(width: 6),
            Text(
              'Active Task Board',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.go('/admin/schools'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '3 schools need renewal',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
