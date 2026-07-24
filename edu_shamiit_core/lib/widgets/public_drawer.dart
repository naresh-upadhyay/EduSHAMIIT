import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class PublicDrawer extends StatelessWidget {
  final String systemName;
  final String? systemLogo;
  final Function(String section)? onScrollToSection;

  const PublicDrawer({
    super.key,
    required this.systemName,
    this.systemLogo,
    this.onScrollToSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Premium dark/slate theme matching our administration panel
    const drawerBgColor = Color(0xFF0F1123);
    const accentColor = Color(0xFF6366F1);
    const unselectedColor = Color(0xFF94A3B8);

    final items = [
      const _DrawerItem(
          icon: Icons.home_outlined,
          label: 'Home',
          section: 'Home',
          route: '/'),
      const _DrawerItem(
          icon: Icons.star_outline,
          label: 'Features',
          section: 'Features',
          route: '/'),
      const _DrawerItem(
          icon: Icons.widgets_outlined,
          label: 'Modules',
          section: 'Modules',
          route: '/'),
      const _DrawerItem(
          icon: Icons.check_circle_outline,
          label: 'Benefits',
          section: 'Benefits',
          route: '/'),
      const _DrawerItem(
          icon: Icons.attach_money_outlined,
          label: 'Pricing',
          section: 'Pricing',
          route: '/'),
      const _DrawerItem(
          icon: Icons.info_outline,
          label: 'About Us',
          section: 'About Us',
          route: '/'),
      const _DrawerItem(
          icon: Icons.mail_outline,
          label: 'Contact Us',
          section: 'Contact Us',
          route: '/contact'),
      const _DrawerItem(
          icon: Icons.help_outline,
          label: 'FAQ',
          section: 'FAQ',
          route: '/faq'),
      const _DrawerItem(
          icon: Icons.menu_book_outlined,
          label: 'Help Center',
          section: 'Help Center',
          route: '/help-center'),
      const _DrawerItem(
          icon: Icons.gavel_outlined,
          label: 'Terms & Conditions',
          section: 'Terms',
          route: '/terms'),
      const _DrawerItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          section: 'Privacy',
          route: '/privacy'),
    ];

    return Drawer(
      backgroundColor: drawerBgColor,
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Brand Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: systemLogo != null && systemLogo!.isNotEmpty
                              ? Image.network(
                                  AppConfig.resolveUrl(systemLogo!),
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.school,
                                    color: accentColor,
                                    size: 24,
                                  ),
                                )
                              : const Icon(
                                  Icons.school,
                                  color: accentColor,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            systemName,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: unselectedColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Navigation List
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  // Categories splitting
                  Widget? categoryHeader;
                  if (index == 0) {
                    categoryHeader = _buildCategoryHeader('WEBSITE NAVIGATION');
                  } else if (index == 6) {
                    categoryHeader = _buildCategoryHeader('SUPPORT & LEGAL');
                  }

                  final tile = Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (item.route == '/') {
                          if (onScrollToSection != null) {
                            onScrollToSection!(item.section);
                          } else {
                            context.go('/');
                          }
                        } else {
                          context.go(item.route);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon, color: unselectedColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  if (categoryHeader != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        categoryHeader,
                        tile,
                      ],
                    );
                  }
                  return tile;
                },
              ),
            ),

            // Drawer Action Buttons Footer
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      'Login',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/get-started');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: const Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final String section;
  final String route;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.route,
  });
}
