import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_admin/widgets/admin_bottom_nav.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:async';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final Widget child;
  const AdminDashboardScreen({super.key, required this.child});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  StreamSubscription? _tabChangeSubscription;

  @override
  void dispose() {
    _tabChangeSubscription?.cancel();
    super.dispose();
  }

  static const Map<String, String> _roleLabels = {
    'super_admin': 'Super Admin',
    'admin': 'School Admin',
    'teacher': 'Teacher',
    'student': 'Student',
    'parent': 'Parent',
    'student_admin': 'Student Admin',
    'teacher_admin': 'Teacher Admin',
    'director': 'Director',
    'principal': 'Principal',
    'finance': 'Finance Staff',
    'hr': 'HR Manager',
    'transport': 'Transport Mgr',
    'library': 'Librarian',
    'security': 'Security Head',
    'sports': 'Sports Coach',
    'support': 'Support Staff',
    'driver': 'Bus Driver',
    'hostel': 'Hostel Warden',
    'exam_ctrl': 'Exam Controller',
  };

  // Re-categorized navigation items matching professional ERP hierarchy
  static const _sidebarItems = [
    // Overview Console
    _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/admin/dashboard',
        section: NavSection.overview),
    _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        route: '/admin/calendar',
        section: NavSection.overview),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'My Profile',
        route: '/admin/my-profile',
        section: NavSection.overview),

    // General console
    _NavItem(
        icon: Icons.notifications_active_outlined,
        label: 'Alerts & Notifications',
        route: '/admin/alerts-notifications',
        section: NavSection.general),
    _NavItem(
        icon: Icons.shield_outlined,
        label: 'Emergency',
        route: '/admin/emergency',
        section: NavSection.general),

    // Organization console
    _NavItem(
        icon: Icons.school_outlined,
        label: 'Schools Directory',
        route: '/admin/schools',
        section: NavSection.organization),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'Staff Registry',
        route: '/admin/staff',
        section: NavSection.organization),
    _NavItem(
        icon: Icons.manage_accounts_rounded,
        label: 'User Management',
        route: '/admin/users',
        section: NavSection.organization),
    _NavItem(
        icon: Icons.admin_panel_settings_outlined,
        label: 'Manage Roles',
        route: '/admin/roles',
        section: NavSection.organization),

    // Operations consoles
    _NavItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New Admissions',
        route: '/admin/admissions',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        route: '/admin/announcements',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.support_agent_rounded,
        label: 'IT Support Tickets',
        route: '/admin/support',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.contact_mail_outlined,
        label: 'Public Contact Queries',
        route: '/admin/contact-queries',
        section: NavSection.operations),

    // Finance console
    _NavItem(
        icon: Icons.payments_outlined,
        label: 'Financial Suite',
        route: '/admin/finance',
        section: NavSection.finance),
    _NavItem(
        icon: Icons.warning_amber_rounded,
        label: 'Fee Defaulters',
        route: '/admin/defaulters',
        section: NavSection.finance),

    // Security & Guard log consoles
    _NavItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Gate Scanner Log',
        route: '/admin/gate-scanner',
        section: NavSection.security),
    _NavItem(
        icon: Icons.shield_outlined,
        label: 'Security & Controls',
        route: '/admin/system-control',
        section: NavSection.security),
    _NavItem(
        icon: Icons.lock_outline,
        label: 'Security Audit Logs',
        route: '/admin/audit-log',
        section: NavSection.security),

    // System config & Developers consoles
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Infra Monitor',
        route: '/admin/infra',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.settings_outlined,
        label: 'System Config',
        route: '/admin/config',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.extension_outlined,
        label: 'Module Management',
        route: '/admin/modules',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.tune_rounded,
        label: 'Lookup Management',
        route: '/admin/lookups',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.settings_input_component_outlined,
        label: 'Automations Engine',
        route: '/admin/automations',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.lightbulb_outline,
        label: 'AI Smart Insights',
        route: '/admin/insights',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.power_outlined,
        label: 'API Gateway',
        route: '/admin/apis',
        section: NavSection.systemDev),
    _NavItem(
        icon: Icons.vpn_key_outlined,
        label: 'Vault Secrets',
        route: '/admin/vault',
        section: NavSection.systemDev),

    // Fleet Management
    _NavItem(
        icon: Icons.insights_rounded,
        label: 'Live Dashboard',
        route: '/admin/vehicle-dashboard',
        section: NavSection.fleetManagement),
    _NavItem(
        icon: Icons.directions_bus_rounded,
        label: 'Fleet Management',
        route: '/admin/fleet',
        section: NavSection.fleetManagement),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Driver Management',
        route: '/admin/driver-management',
        section: NavSection.fleetManagement),
    _NavItem(
        icon: Icons.map_outlined,
        label: 'Route Management',
        route: '/admin/route-management',
        section: NavSection.fleetManagement),
  ];

  List<dynamic> _modules = [];
  Map<String, dynamic> _schoolToggles = {};
  bool _isLoadingModules = true;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _fetchModules();
    if (kIsWeb) {
      _tabChangeSubscription = html.window.on['tab_changed'].listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _fetchModules() async {
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
        });
      }

      final user = ref.read(authProvider).userData;
      final role = user?['role']?.toString().toLowerCase();
      final schoolId = user?['school_id']?.toString();
      if (role == 'director' && schoolId != null) {
        final schoolRes = await ApiService().get('/admin/schools', useCache: false);
        if (schoolRes['success'] == true) {
          final schools = schoolRes['data']['schools'] as List<dynamic>? ?? [];
          final currentSchool = schools.firstWhere((s) => s['id'] == schoolId, orElse: () => null);
          if (currentSchool != null) {
            setState(() {
              _schoolToggles = currentSchool['module_toggles'] as Map<String, dynamic>? ?? {};
            });
          }
        }
      }
      
      setState(() {
        _isLoadingModules = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingModules = false;
      });
    }
  }

  int _selectedIndex(String location, List<_NavItem> items) {
    int bestMatchIndex = 0;
    int maxLen = 0;
    for (int i = 0; i < items.length; i++) {
      final route = items[i].route;
      if (location == route ||
          (location == '/driver/dashboard' && route == '/admin/dashboard') ||
          (location == '/driver/dashboard' && route == '/driver/dashboard') ||
          (location == '/driver/timetable' && route == '/admin/calendar')) {
        return i;
      }
      if (location.startsWith(route) && route.length > maxLen) {
        maxLen = route.length;
        bestMatchIndex = i;
      }
    }
    return bestMatchIndex;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final role = user?['role']?.toString().toLowerCase() ?? 'super_admin';

    final userName = user?['full_name'] ?? 'System Administrator';
    final isDesktop = Responsive.isDesktop(context);
    final location = GoRouterState.of(context).uri.toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredItems = _sidebarItems.where((item) {
      for (final m in _modules) {
        final screens = m['screens'] as List<dynamic>? ?? [];
        if (screens.contains(item.route)) {
          if (m['is_enabled'] == false) {
            return false;
          }
          if (role == 'director' && _schoolToggles.containsKey(m['id'])) {
            if (_schoolToggles[m['id']] == false) {
              return false;
            }
          }
        }
      }

      // Role based permissions
      if (role == 'super_admin') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/schools' ||
               item.route == '/admin/users' ||
               item.route == '/admin/infra' ||
               item.route == '/admin/roles' ||
               item.route == '/admin/config' ||
               item.route == '/admin/modules' ||
               item.route == '/admin/lookups' ||
               item.route == '/admin/automations' ||
               item.route == '/admin/insights' ||
               item.route == '/admin/apis' ||
               item.route == '/admin/vault' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/announcements' ||
               item.route == '/admin/audit-log' ||
               item.route == '/admin/support' ||
               item.route == '/admin/contact-queries' ||
               item.route == '/admin/my-profile' ||
               item.route == '/admin/vehicle-dashboard' ||
               item.route.startsWith('/admin/fleet') ||
               item.route == '/admin/driver-management' ||
               item.route == '/admin/route-management' ||
               item.route == '/admin/trips-schedule' ||
               item.route == '/admin/stops';
      } else if (role == 'director') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/users' ||
               item.route == '/admin/roles' ||
               item.route == '/admin/lookups' ||
               item.route == '/admin/finance' ||
               item.route == '/admin/defaulters' ||
               item.route == '/admin/staff' ||
               item.route == '/admin/admissions' ||
               item.route == '/admin/gate-scanner' ||
               item.route == '/admin/system-control' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/announcements' ||
               item.route == '/admin/support' ||
               item.route == '/admin/my-profile' ||
               item.route == '/admin/vehicle-dashboard' ||
               item.route.startsWith('/admin/fleet') ||
               item.route == '/admin/driver-management' ||
               item.route == '/admin/route-management' ||
               item.route == '/admin/trips-schedule' ||
               item.route == '/admin/stops';
      } else if (role == 'transport') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile' ||
               item.route == '/admin/vehicle-dashboard' ||
               item.route.startsWith('/admin/fleet') ||
               item.route == '/admin/driver-management' ||
               item.route == '/admin/route-management' ||
               item.route == '/admin/trips-schedule' ||
               item.route == '/admin/stops';
      } else if (role == 'driver') {
        return item.route == '/admin/dashboard' ||
               item.route == '/driver/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      }
      return item.route == '/admin/dashboard' || item.route == '/admin/calendar' || item.route == '/admin/alerts-notifications' || item.route == '/admin/emergency' || item.route == '/admin/my-profile';
    }).toList();

    if (isDesktop) {
      final selected = _selectedIndex(location, filteredItems);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            // Sidebar Navigation (Desktop Only)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              width: _isSidebarCollapsed ? 76 : 260,
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                  right: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final currentWidth = constraints.maxWidth;
                  final showLabels = currentWidth > 140;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: showLabels ? 16 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand Header Section
                        _buildBrandHeader(isDark, showLabels),
                        const SizedBox(height: 30),

                        // Navigation Items List
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isSelected = index == selected;

                              // Section Headers
                              Widget? header;
                              final currentSection = item.section;
                              final prevSection = index > 0 ? filteredItems[index - 1].section : null;

                              if (prevSection != currentSection && showLabels) {
                                String headerText = '';
                                switch (currentSection) {
                                  case NavSection.overview:
                                    headerText = 'OVERVIEW';
                                    break;
                                  case NavSection.general:
                                    headerText = 'GENERAL';
                                    break;
                                  case NavSection.organization:
                                    headerText = 'ORGANIZATION';
                                    break;
                                  case NavSection.operations:
                                    headerText = 'OPERATIONS';
                                    break;
                                  case NavSection.finance:
                                    headerText = 'FINANCE';
                                    break;
                                  case NavSection.security:
                                    headerText = 'SECURITY & CONTROL';
                                    break;
                                  case NavSection.systemDev:
                                    headerText = 'SYSTEM & DEV TOOLS';
                                    break;
                                  case NavSection.fleetManagement:
                                    headerText = 'FLEET MANAGEMENT';
                                    break;
                                }

                                header = Padding(
                                  padding: EdgeInsets.only(
                                    left: 12,
                                    top: index == 0 ? 0 : 20,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    headerText,
                                    style: TextStyle(
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1),
                                  ),
                                );
                              }

                              if (item.label == 'Fleet Management') {
                                final expandableTile = _buildExpandableFleetTile(isDark, showLabels, location);
                                if (header != null) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [header, expandableTile],
                                  );
                                }
                                return expandableTile;
                              }

                              if (item.label == 'Driver Management') {
                                final expandableTile = _buildExpandableDriverTile(isDark, showLabels, location);
                                if (header != null) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [header, expandableTile],
                                  );
                                }
                                return expandableTile;
                              }

                              if (item.label == 'Route Management') {
                                final expandableTile = _buildExpandableRouteTile(isDark, showLabels, location);
                                if (header != null) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [header, expandableTile],
                                  );
                                }
                                return expandableTile;
                              }

                              final tile = _buildSidebarTile(
                                item: item,
                                isSelected: isSelected,
                                isDark: isDark,
                                showLabels: showLabels,
                                onTap: () {
                                  if (role == 'driver' && item.route == '/admin/dashboard') {
                                    context.go('/driver/dashboard');
                                  } else {
                                    context.go(item.route);
                                  }
                                },
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

                        // User Profile Section
                        Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        _buildProfileFooter(isDark, user, userName, showLabels),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Main Content Area
            Expanded(
              child: widget.child,
            ),
          ],
        ),
        floatingActionButton: AiFab(
          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
          onPressed: () => _showAiAssistantDialog(context),
        ),
      );
    } else {
      // Mobile / Tablet Layout (Uses bottom navigation)
      return Scaffold(
        backgroundColor: const Color(0xFF090B15),
        body: widget.child,
        bottomNavigationBar: AdminBottomNav(currentLocation: location),
        floatingActionButton: AiFab(
          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
          onPressed: () => _showAiAssistantDialog(context),
        ),
      );
    }
  }

  Widget _buildBrandHeader(bool isDark, bool showLabels) {
    if (!showLabels) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final config = ref.watch(systemConfigProvider);
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: config?.systemLogo != null
                      ? Image.network(
                          AppConfig.resolveUrl(config!.systemLogo),
                          width: 24,
                          height: 24,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFF4F46E5),
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Color(0xFF4F46E5),
                          size: 24,
                        ),
                );
              },
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isSidebarCollapsed = false;
                });
              },
            ),
          ],
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final config = ref.watch(systemConfigProvider);
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: config?.systemLogo != null
                          ? Image.network(
                              AppConfig.resolveUrl(config!.systemLogo),
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Color(0xFF4F46E5),
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Color(0xFF4F46E5),
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        config?.systemName ?? 'EduSHAMIIT Admin',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Outfit',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.menu_open_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isSidebarCollapsed = true;
              });
            },
          ),
        ],
      );
    }
  }

  Widget _buildSidebarTile({
    required _NavItem item,
    required bool isSelected,
    required bool isDark,
    required bool showLabels,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    if (!showLabels) {
      return Tooltip(
        message: item.label,
        preferBelow: false,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                        : const Color(0xFFEEF2FF))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                size: 20,
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                        : const Color(0xFFEEF2FF))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProfileFooter(bool isDark, Map<String, dynamic>? user, String userName, bool showLabels) {
    final role = user?['role']?.toString().toLowerCase() ?? 'super_admin';
    if (!showLabels) {
      return Tooltip(
        message: "$userName\n${_roleLabels[role] ?? role.toUpperCase().replaceAll('_', ' ')}",
        preferBelow: false,
        child: Center(
          child: InkWell(
            onTap: () => context.go('/admin/my-profile'),
            borderRadius: BorderRadius.circular(8),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              backgroundImage: user?['avatar_url'] != null
                  ? NetworkImage(user!['avatar_url'].toString())
                  : null,
              child: user?['avatar_url'] == null
                  ? const Icon(Icons.person, color: Color(0xFF4F46E5))
                  : null,
            ),
          ),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go('/admin/my-profile'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      backgroundImage: user?['avatar_url'] != null
                          ? NetworkImage(user!['avatar_url'].toString())
                          : null,
                      child: user?['avatar_url'] == null
                          ? const Icon(Icons.person, color: Color(0xFF4F46E5))
                          : null,
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
                          Text(
                            _roleLabels[role] ??
                                role.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  bool _isFleetExpanded = true;
  bool _isDriverExpanded = true;
  bool _isRouteExpanded = true;

  Widget _buildExpandableFleetTile(bool isDark, bool showLabels, String location) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isFleetRoute = location.startsWith('/admin/fleet') || currentUrl.contains('/admin/fleet');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.directions_bus_rounded,
            label: 'Fleet Management',
            route: '/admin/fleet',
            section: NavSection.fleetManagement,
          ),
          isSelected: isFleetRoute && !_isFleetExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            setState(() {
              _isFleetExpanded = !_isFleetExpanded;
            });
          },
          trailing: showLabels
              ? Icon(
                  _isFleetExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: isFleetRoute
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  size: 16,
                )
              : null,
        ),
        if (_isFleetExpanded && showLabels) ...[
          _buildSubTile('Overview', '/admin/fleet', 0, isFleetRoute && activeTab == 0, isDark),
          _buildSubTile('Vehicles', '/admin/fleet', 1, isFleetRoute && activeTab == 1, isDark),
          _buildSubTile('Vehicle Categories', '/admin/fleet', 2, isFleetRoute && activeTab == 2, isDark),
          _buildSubTile('Vehicle Documents', '/admin/fleet', 3, isFleetRoute && activeTab == 3, isDark),
        ],
      ],
    );
  }

  Widget _buildExpandableDriverTile(bool isDark, bool showLabels, String location) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isDriverRoute = location.startsWith('/admin/driver-management') || currentUrl.contains('/admin/driver-management');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Driver Management',
            route: '/admin/driver-management',
            section: NavSection.fleetManagement,
          ),
          isSelected: isDriverRoute && !_isDriverExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            setState(() {
              _isDriverExpanded = !_isDriverExpanded;
            });
          },
          trailing: showLabels
              ? Icon(
                  _isDriverExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: isDriverRoute
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  size: 16,
                )
              : null,
        ),
        if (_isDriverExpanded && showLabels) ...[
          _buildSubTile('Driver List', '/admin/driver-management', 0, isDriverRoute && activeTab == 0, isDark),
          _buildSubTile('License & Documents', '/admin/driver-management', 1, isDriverRoute && activeTab == 1, isDark),
          _buildSubTile('Performance', '/admin/driver-management', 2, isDriverRoute && activeTab == 2, isDark),
          _buildSubTile('Training', '/admin/driver-management', 3, isDriverRoute && activeTab == 3, isDark),
          _buildSubTile('Violations', '/admin/driver-management', 4, isDriverRoute && activeTab == 4, isDark),
        ],
      ],
    );
  }

  Widget _buildExpandableRouteTile(bool isDark, bool showLabels, String location) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isRouteRoute = location.startsWith('/admin/route-management') || currentUrl.contains('/admin/route-management');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.map_outlined,
            label: 'Route Management',
            route: '/admin/route-management',
            section: NavSection.fleetManagement,
          ),
          isSelected: isRouteRoute && !_isRouteExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            setState(() {
              _isRouteExpanded = !_isRouteExpanded;
            });
          },
          trailing: showLabels
              ? Icon(
                  _isRouteExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: isRouteRoute
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  size: 16,
                )
              : null,
        ),
        if (_isRouteExpanded && showLabels) ...[
          _buildSubTile('Overview', '/admin/route-management', 0, isRouteRoute && activeTab == 0, isDark),
          _buildSubTile('Route List', '/admin/route-management', 1, isRouteRoute && activeTab == 1, isDark),
          _buildSubTile('Live Tracking', '/admin/route-management', 2, isRouteRoute && activeTab == 2, isDark),
          _buildSubTile('Route Reports', '/admin/route-management', 3, isRouteRoute && activeTab == 3, isDark),
          _buildSubTile('Stops', '/admin/route-management', 4, isRouteRoute && activeTab == 4, isDark),
          _buildSubTile('Passenger Assignment', '/admin/route-management', 5, isRouteRoute && activeTab == 5, isDark),
        ],
      ],
    );
  }

  Widget _buildSubTile(String label, String baseRoute, int tabIndex, bool isSelected, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 28, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.go('$baseRoute?tab=$tabIndex');
            if (kIsWeb) {
              Future.microtask(() {
                try {
                  html.window.history.replaceState(null, '', '$baseRoute?tab=$tabIndex');
                  html.window.dispatchEvent(html.CustomEvent('tab_changed'));
                } catch (_) {}
              });
            }
            setState(() {});
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                      : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum NavSection { overview, general, organization, operations, finance, security, systemDev, fleetManagement }

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final NavSection section;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.section,
  });
}
