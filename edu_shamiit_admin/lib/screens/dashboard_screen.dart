import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/widgets/admin_bottom_nav.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final Widget child;
  const AdminDashboardScreen({super.key, required this.child});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  static const _sidebarItems = [
    _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/admin/dashboard'),
    _NavItem(
        icon: Icons.school_outlined,
        label: 'Schools Directory',
        route: '/admin/schools'),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'User Management',
        route: '/admin/users'),
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Infra Monitor',
        route: '/admin/infra'),
    _NavItem(
        icon: Icons.settings_outlined,
        label: 'System Config',
        route: '/admin/config'),
    // Operations
    _NavItem(
        icon: Icons.payments_outlined,
        label: 'Financial Suite',
        route: '/admin/finance'),
    _NavItem(
        icon: Icons.warning_amber_rounded,
        label: 'Fee Defaulters',
        route: '/admin/defaulters'),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'Staff Registry',
        route: '/admin/staff'),
    _NavItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New Admissions',
        route: '/admin/admissions'),
    _NavItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Gate Scanner Log',
        route: '/admin/gate-scanner'),
    _NavItem(
        icon: Icons.support_agent_rounded,
        label: 'IT Support Tickets',
        route: '/admin/support'),
    _NavItem(
        icon: Icons.security_rounded,
        label: 'Security & Controls',
        route: '/admin/system-control'),
    // Quick Access Modules
    _NavItem(
        icon: Icons.palette_outlined,
        label: 'White Label Branding',
        route: '/admin/white-label'),
    _NavItem(
        icon: Icons.extension_outlined,
        label: 'Module Toggle',
        route: '/admin/modules'),
    _NavItem(
        icon: Icons.account_tree_outlined,
        label: 'Academic Workflows',
        route: '/admin/workflows'),
    _NavItem(
        icon: Icons.settings_input_component_outlined,
        label: 'Automations Engine',
        route: '/admin/automations'),
    _NavItem(
        icon: Icons.shield_outlined,
        label: 'Permissions Matrix',
        route: '/admin/permissions'),
    _NavItem(
        icon: Icons.bar_chart_outlined,
        label: 'Real-Time Telemetry',
        route: '/admin/real-time'),
    _NavItem(
        icon: Icons.lightbulb_outline,
        label: 'AI Smart Insights',
        route: '/admin/insights'),
    _NavItem(
        icon: Icons.corporate_fare_outlined,
        label: 'Institutional Groups',
        route: '/admin/groups'),
    _NavItem(
        icon: Icons.power_outlined,
        label: 'API Gateway',
        route: '/admin/apis'),
    _NavItem(
        icon: Icons.lock_outline,
        label: 'Security Audit Logs',
        route: '/admin/audit-log'),
    _NavItem(
        icon: Icons.assignment_outlined,
        label: 'Roles Configuration',
        route: '/admin/roles'),
    _NavItem(
        icon: Icons.smart_toy_outlined,
        label: 'AI Ops Telemetry',
        route: '/admin/ai-ops'),
    _NavItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        route: '/admin/announcements'),
    _NavItem(
        icon: Icons.rocket_launch_outlined,
        label: 'Tenant Onboarding Wizard',
        route: '/admin/onboard'),
    _NavItem(
        icon: Icons.credit_card_outlined,
        label: 'SaaS Subscription Plans',
        route: '/admin/saas-plans'),
  ];

  int _selectedIndex(String location) {
    for (int i = 0; i < _sidebarItems.length; i++) {
      if (location.startsWith(_sidebarItems[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'System Administrator';
    final isDesktop = Responsive.isDesktop(context);
    final location = GoRouterState.of(context).uri.toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isDesktop) {
      final selected = _selectedIndex(location);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            // Sidebar Navigation (Desktop Only)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Color(0xFF4F46E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'EduVerse Admin',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Navigation Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sidebarItems.length,
                      itemBuilder: (context, index) {
                        final item = _sidebarItems[index];
                        final isSelected = index == selected;

                        // Add section headers
                        Widget? header;
                        if (index == 0) {
                          header = Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 8),
                            child: Text(
                              'CORE CONSOLES',
                              style: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          );
                        } else if (index == 5) {
                          header = Padding(
                            padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
                            child: Text(
                              'OPERATIONAL UTILITIES',
                              style: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          );
                        } else if (index == 12) {
                          header = Padding(
                            padding: const EdgeInsets.only(left: 12, top: 16, bottom: 8),
                            child: Text(
                              'SYSTEM QUICK ACCESS',
                              style: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          );
                        }

                        final tile = Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              onTap: () => context.go(item.route),
                              leading: Icon(
                                item.icon,
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                size: 20,
                              ),
                              title: Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              selected: isSelected,
                              selectedTileColor: isDark
                                  ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                                  : const Color(0xFFEEF2FF),
                              dense: true,
                            ),
                          ),
                        );

                        if (header != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [header, tile],
                          );
                        }
                        return tile;
                      },
                    ),
                  ),

                  // User profile & logout
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Super Admin',
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout,
                            color: Color(0xFFEF4444), size: 18),
                        onPressed: () {
                          ref.read(authProvider.notifier).signOut();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content Panel
            Expanded(
              child: widget.child,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAiAssistantDialog(context),
          backgroundColor: const Color(0xFF4F46E5),
          child: const Icon(Icons.assistant, color: Colors.white),
        ),
      );
    } else {
      // Mobile / Tablet View
      return Scaffold(
        backgroundColor: const Color(0xFF090B15),
        body: widget.child,
        bottomNavigationBar: AdminBottomNav(currentLocation: location),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAiAssistantDialog(context),
          backgroundColor: const Color(0xFF4F46E5),
          child: const Icon(Icons.assistant, color: Colors.white),
        ),
      );
    }
  }

  void _showAiAssistantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF13182C),
          title: const Row(
            children: [
              Icon(Icons.assistant, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Shami — AI Admin Assistant',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How can I help you customize or control school operations today?',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., Send notice to 10A, check collections...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0B0D19),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final prompt = textController.text.trim();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('AI processing request: "$prompt"')),
                );
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Execute Prompt',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
