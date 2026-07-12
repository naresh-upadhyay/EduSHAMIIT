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

  static const _sidebarItems = [
    _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/admin/dashboard',
        section: NavSection.core),
    _NavItem(
        icon: Icons.school_outlined,
        label: 'Schools Directory',
        route: '/admin/schools',
        section: NavSection.core),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'User Management',
        route: '/admin/users',
        section: NavSection.core),
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Infra Monitor',
        route: '/admin/infra',
        section: NavSection.core),
    _NavItem(
        icon: Icons.admin_panel_settings_outlined,
        label: 'Manage Roles',
        route: '/admin/roles',
        section: NavSection.core),
    _NavItem(
        icon: Icons.settings_outlined,
        label: 'System Config',
        route: '/admin/config',
        section: NavSection.core),
    // Operations
    _NavItem(
        icon: Icons.payments_outlined,
        label: 'Financial Suite',
        route: '/admin/finance',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.warning_amber_rounded,
        label: 'Fee Defaulters',
        route: '/admin/defaulters',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'Staff Registry',
        route: '/admin/staff',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New Admissions',
        route: '/admin/admissions',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Gate Scanner Log',
        route: '/admin/gate-scanner',
        section: NavSection.operations),
    _NavItem(
        icon: Icons.security_rounded,
        label: 'Security & Controls',
        route: '/admin/system-control',
        section: NavSection.operations),
    // Quick Access Modules

    _NavItem(
        icon: Icons.extension_outlined,
        label: 'Module Toggle',
        route: '/admin/modules',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.settings_applications_outlined,
        label: 'Module Setup',
        route: '/admin/modules-config',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.settings_input_component_outlined,
        label: 'Automations Engine',
        route: '/admin/automations',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.lightbulb_outline,
        label: 'AI Smart Insights',
        route: '/admin/insights',
        section: NavSection.quickAccess),

    _NavItem(
        icon: Icons.power_outlined,
        label: 'API Gateway',
        route: '/admin/apis',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.vpn_key_outlined,
        label: 'Vault Secrets',
        route: '/admin/vault',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.lock_outline,
        label: 'Security Audit Logs',
        route: '/admin/audit-log',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        route: '/admin/announcements',
        section: NavSection.quickAccess),
    _NavItem(
        icon: Icons.support_agent_rounded,
        label: 'IT Support Tickets',
        route: '/admin/support',
        section: NavSection.quickAccess),
  ];

  List<dynamic> _modules = [];
  Map<String, dynamic> _schoolToggles = {};
  bool _isLoadingModules = true;

  @override
  void initState() {
    super.initState();
    _fetchModules();
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
      if (location == route) {
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
    final userName = user?['full_name'] ?? 'System Administrator';
    final isDesktop = Responsive.isDesktop(context);
    final location = GoRouterState.of(context).uri.toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = user?['role']?.toString().toLowerCase() ?? 'super_admin';

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

      if (role == 'super_admin') {
        // Remove all operations items
        if (item.section == NavSection.operations) {
          return false;
        }
        return true;
      } else if (role == 'director') {
        // Director sees CORE and OPERATIONS
        if (item.section == NavSection.quickAccess) {
          return false;
        }
        return true;
      }
      // Fallback for other roles
      return item.section == NavSection.core;
    }).toList();

    if (isDesktop) {
      final selected = _selectedIndex(location, filteredItems);
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
                        'EduSHAMIIT Admin',
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
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = index == selected;

                        // Add section headers dynamically
                        Widget? header;
                        final currentSection = item.section;
                        final prevSection = index > 0 ? filteredItems[index - 1].section : null;

                        if (prevSection != currentSection) {
                          String headerText = '';
                          if (currentSection == NavSection.core) {
                            headerText = 'CORE CONSOLES';
                          } else if (currentSection == NavSection.operations) {
                            headerText = 'OPERATIONAL UTILITIES';
                          } else if (currentSection == NavSection.quickAccess) {
                            headerText = 'SYSTEM QUICK ACCESS';
                          }

                          header = Padding(
                            padding: EdgeInsets.only(
                              left: 12,
                              top: index == 0 ? 0 : 16,
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
                            Text(
                              _roleLabels[user?['role']?.toString().toLowerCase() ?? ''] ??
                                  (user?['role']?.toString() ?? 'SUPER ADMIN')
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                              style: const TextStyle(
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

enum NavSection { core, operations, quickAccess }

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
