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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription? _tabChangeSubscription;
  final TextEditingController _searchController = TextEditingController();
  String _navSearchQuery = "";

  // By default, nested navigation options are NOT expanded
  bool _isWorkExpanded = false;
  bool _isFleetExpanded = false;
  bool _isDriverExpanded = false;
  bool _isRouteExpanded = false;
  bool _isHrExpanded = false;
  bool _isClassesExpanded = false;
  bool _isLibraryExpanded = false;
  bool _isHostelExpanded = false;
  bool _isRolesExpanded = false;
  bool _isModulesExpanded = false;
  bool _isAttendanceExpanded = false;
  bool _isLiveClassExpanded = false;
  bool _isVisitorsExpanded = false;
  bool _isInventoryExpanded = false;
  bool _isCampusExpanded = false;
  bool _isExamsExpanded = false;
  bool _isAnnouncementsExpanded = false;
  bool _isSystemConfigExpanded = false;
  bool _isSidebarCollapsed = false;
  String? _lastNavPath;

  List<dynamic> _modules = [];
  Map<String, dynamic> _schoolToggles = {};
  bool _isLoadingModules = true;

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

  @override
  void dispose() {
    _tabChangeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  static const Map<String, String> _roleLabels = {
    'super_admin': 'Super Admin',
    'admin': 'School Admin',
    'teacher': 'Teacher',
    'student': 'Student',
    'parent': 'Parent',
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

  // Senior Enterprise ERP Navigation Architecture (Organized in 7 Logical Pillars)
  static const _sidebarItems = [
    // 1. EXECUTIVE HUB
    _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/admin/dashboard',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.layers_rounded,
        label: 'Work Management',
        route: '/admin/work',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar & Schedules',
        route: '/admin/calendar',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'Messages',
        route: '/admin/messaging',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.smart_toy_outlined,
        label: 'AI Chat',
        route: '/admin/ai-chat',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.folder_shared_outlined,
        label: 'My Documents',
        route: '/admin/documents',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.notifications_active_outlined,
        label: 'Alerts & Notifications',
        route: '/admin/alerts-notifications',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.shield_outlined,
        label: 'Emergency SOS Center',
        route: '/admin/emergency',
        section: NavSection.executive),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'My Profile',
        route: '/admin/my-profile',
        section: NavSection.executive),

    // 2. ACADEMIC & CAMPUS
    _NavItem(
        icon: Icons.person_add_alt_1_outlined,
        label: 'New Admissions',
        route: '/admin/admissions',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.meeting_room_outlined,
        label: 'Classes & Facilities',
        route: '/admin/classes',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.checklist_rounded,
        label: 'Attendance Hub',
        route: '/admin/attendance',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.video_camera_front_rounded,
        label: 'Live Class Management',
        route: '/admin/live-classes',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.local_library_outlined,
        label: 'Library Management',
        route: '/admin/library',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.apartment_rounded,
        label: 'Hostel Management',
        route: '/admin/hostel',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.groups_rounded,
        label: 'Visitors Management',
        route: '/admin/visitors',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory Management',
        route: '/admin/inventory',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.domain_rounded,
        label: 'Campus Management',
        route: '/admin/campus',
        section: NavSection.academicsCampus),
    _NavItem(
        icon: Icons.quiz_outlined,
        label: 'Exams Management',
        route: '/admin/exams',
        section: NavSection.academicsCampus),

    // 3. TRANSPORTATION & FLEET
    _NavItem(
        icon: Icons.insights_rounded,
        label: 'Live Tracking Dashboard',
        route: '/admin/vehicle-dashboard',
        section: NavSection.transportFleet),
    _NavItem(
        icon: Icons.directions_bus_rounded,
        label: 'Fleet Management',
        route: '/admin/fleet',
        section: NavSection.transportFleet),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Driver Management',
        route: '/admin/driver-management',
        section: NavSection.transportFleet),
    _NavItem(
        icon: Icons.map_outlined,
        label: 'Route Management',
        route: '/admin/route-management',
        section: NavSection.transportFleet),

    // 4. HUMAN RESOURCES & ROLES
    _NavItem(
        icon: Icons.manage_accounts_rounded,
        label: 'User Management',
        route: '/admin/users',
        section: NavSection.humanResources),
    _NavItem(
        icon: Icons.people_outline_rounded,
        label: 'Staff Registry',
        route: '/admin/staff',
        section: NavSection.humanResources),
    _NavItem(
        icon: Icons.badge_outlined,
        label: 'HR Suite',
        route: '/admin/hr/overview',
        section: NavSection.humanResources),
    _NavItem(
        icon: Icons.admin_panel_settings_outlined,
        label: 'Roles & Permissions',
        route: '/admin/roles',
        section: NavSection.humanResources),

    // 5. FINANCE & OPERATIONS
    _NavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Student Fee Management',
        route: '/admin/student-fees',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.payments_outlined,
        label: 'Staff Salary Management',
        route: '/admin/staff-salary',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Financial Suite',
        route: '/admin/finance',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.warning_amber_rounded,
        label: 'Fee Defaulters',
        route: '/admin/defaulters',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        route: '/admin/announcements',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.support_agent_rounded,
        label: 'IT Support Helpdesk',
        route: '/admin/support',
        section: NavSection.financeOperations),
    _NavItem(
        icon: Icons.contact_mail_outlined,
        label: 'Public Contact Queries',
        route: '/admin/contact-queries',
        section: NavSection.financeOperations),

    // 6. SECURITY & COMPLIANCE
    _NavItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Gate Scanner Log',
        route: '/admin/gate-scanner',
        section: NavSection.securityAudit),
    _NavItem(
        icon: Icons.security_rounded,
        label: 'Security & Controls',
        route: '/admin/system-control',
        section: NavSection.securityAudit),
    _NavItem(
        icon: Icons.lock_outline,
        label: 'Security Audit Logs',
        route: '/admin/audit-log',
        section: NavSection.securityAudit),

    // 7. SYSTEM ADMINISTRATION & DEV
    _NavItem(
        icon: Icons.school_outlined,
        label: 'Schools Directory',
        route: '/admin/schools',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.settings_outlined,
        label: 'System Config',
        route: '/admin/config',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.extension_outlined,
        label: 'Module Management',
        route: '/admin/modules',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Infra Monitor',
        route: '/admin/infra',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.tune_rounded,
        label: 'Lookup Management',
        route: '/admin/lookups',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.settings_input_component_outlined,
        label: 'Automations Engine',
        route: '/admin/automations',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.lightbulb_outline,
        label: 'AI Smart Insights',
        route: '/admin/insights',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.power_outlined,
        label: 'API Gateway',
        route: '/admin/apis',
        section: NavSection.systemDeveloper),
    _NavItem(
        icon: Icons.vpn_key_outlined,
        label: 'Vault Secrets',
        route: '/admin/vault',
        section: NavSection.systemDeveloper),
  ];

  Future<void> _fetchModules() async {
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        if (!mounted) return;
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
        });
      }

      final user = ref.read(authProvider).userData;
      final role = user?['role']?.toString().toLowerCase();
      final schoolId = user?['school_id']?.toString();
      if (role == 'director' && schoolId != null) {
        final schoolRes = await ApiService().get('/admin/schools', useCache: false);
        if (schoolRes['success'] == true && mounted) {
          final schools = schoolRes['data']['schools'] as List<dynamic>? ?? [];
          final currentSchool = schools.firstWhere((s) => s['id'] == schoolId, orElse: () => null);
          if (currentSchool != null) {
            setState(() {
              _schoolToggles = currentSchool['module_toggles'] as Map<String, dynamic>? ?? {};
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoadingModules = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModules = false;
        });
      }
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
      if ((location.startsWith('/admin/messaging') || location.startsWith('/admin/messages')) && route == '/admin/messaging') {
        return i;
      }
      if (location.startsWith('/admin/ai-chat') && route == '/admin/ai-chat') {
        return i;
      }
      if (location.startsWith('/admin/documents') && route == '/admin/documents') {
        return i;
      }
      if (location.startsWith('/admin/hr') && (route.startsWith('/admin/hr') || items[i].label == 'HR Suite')) {
        return i;
      }
      if ((location.startsWith('/admin/classes') || location.startsWith('/classes')) && (route.startsWith('/admin/classes') || items[i].label == 'Classes & Facilities')) {
        return i;
      }
      if ((location.startsWith('/admin/library') || location.startsWith('/library')) && (route.startsWith('/admin/library') || items[i].label == 'Library Management')) {
        return i;
      }
      if ((location.startsWith('/admin/hostel') || location.startsWith('/hostel')) && (route.startsWith('/admin/hostel') || items[i].label == 'Hostel Management')) {
        return i;
      }
      if (location.startsWith('/admin/roles') && (route.startsWith('/admin/roles') || items[i].label == 'Roles & Permissions')) {
        return i;
      }
      if (location.startsWith('/admin/modules') && (route.startsWith('/admin/modules') || items[i].label == 'Module Management')) {
        return i;
      }
      if (location.startsWith('/admin/fleet') && (route.startsWith('/admin/fleet') || items[i].label == 'Fleet Management')) {
        return i;
      }
      if (location.startsWith('/admin/driver-management') && (route.startsWith('/admin/driver-management') || items[i].label == 'Driver Management')) {
        return i;
      }
      if (location.startsWith('/admin/route-management') && (route.startsWith('/admin/route-management') || items[i].label == 'Route Management')) {
        return i;
      }
      if ((location.startsWith('/admin/attendance') || location.startsWith('/attendance')) && (route.startsWith('/admin/attendance') || items[i].label == 'Attendance Hub')) {
        return i;
      }
      if ((location.startsWith('/admin/live-classes') || location.startsWith('/live-classes')) && (route.startsWith('/admin/live-classes') || items[i].label == 'Live Class Management')) {
        return i;
      }
      if ((location.startsWith('/admin/visitors') || location.startsWith('/visitors')) && (route.startsWith('/admin/visitors') || items[i].label == 'Visitors Management')) {
        return i;
      }
      if ((location.startsWith('/admin/inventory') || location.startsWith('/inventory')) && (route.startsWith('/admin/inventory') || items[i].label == 'Inventory Management')) {
        return i;
      }
      if ((location.startsWith('/admin/campus') || location.startsWith('/campus')) && (route.startsWith('/admin/campus') || items[i].label == 'Campus Management')) {
        return i;
      }
      if ((location.startsWith('/admin/exams') || location.startsWith('/exams')) && (route.startsWith('/admin/exams') || items[i].label == 'Exams Management')) {
        return i;
      }
      if ((location.startsWith('/admin/announcements') || location.startsWith('/admin/notices') || location.startsWith('/notices')) && (route.startsWith('/admin/announcements') || items[i].label == 'Announcements')) {
        return i;
      }
      if ((location.startsWith('/admin/student-fees') || location.startsWith('/student-fees')) && (route.startsWith('/admin/student-fees') || items[i].label == 'Student Fee Management')) {
        return i;
      }
      if ((location.startsWith('/admin/staff-salary') || location.startsWith('/staff-salary')) && (route.startsWith('/admin/staff-salary') || items[i].label == 'Staff Salary Management')) {
        return i;
      }
      if (location.startsWith('/admin/config') && (route.startsWith('/admin/config') || items[i].label == 'System Config')) {
        return i;
      }
      if (location.startsWith(route) && route.length > maxLen) {
        maxLen = route.length;
        bestMatchIndex = i;
      }
    }
    return bestMatchIndex;
  }

  String _getSectionHeader(NavSection section) {
    switch (section) {
      case NavSection.executive:
        return 'EXECUTIVE HUB';
      case NavSection.academicsCampus:
        return 'ACADEMIC & CAMPUS';
      case NavSection.transportFleet:
        return 'TRANSPORTATION & FLEET';
      case NavSection.humanResources:
        return 'HUMAN RESOURCES & ROLES';
      case NavSection.financeOperations:
        return 'FINANCE & OPERATIONS';
      case NavSection.securityAudit:
        return 'SECURITY & COMPLIANCE';
      case NavSection.systemDeveloper:
        return 'SYSTEM ADMINISTRATION & DEV';
    }
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

    // Auto-collapse inactive expandable sections so left navigation NEVER stays stuck open across route changes
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isWorkRoute = location.startsWith('/admin/work') || currentUrl.contains('/admin/work') || location.startsWith('/work') || currentUrl.contains('/work');
    final isFleetRoute = location.startsWith('/admin/fleet') || currentUrl.contains('/admin/fleet');
    final isDriverRoute = location.startsWith('/admin/driver-management') || currentUrl.contains('/admin/driver-management');
    final isRouteRoute = location.startsWith('/admin/route-management') || currentUrl.contains('/admin/route-management');
    final isHrRoute = location.startsWith('/admin/hr') || currentUrl.contains('/admin/hr') || location.startsWith('/hr') || currentUrl.contains('/hr');
    final isClassesRoute = location.startsWith('/admin/classes') || currentUrl.contains('/admin/classes') || location.startsWith('/classes') || currentUrl.contains('/classes');
    final isLibraryRoute = location.startsWith('/admin/library') || currentUrl.contains('/admin/library') || location.startsWith('/library') || currentUrl.contains('/library');
    final isHostelRoute = location.startsWith('/admin/hostel') || currentUrl.contains('/admin/hostel') || location.startsWith('/hostel') || currentUrl.contains('/hostel');
    final isRolesRoute = location.startsWith('/admin/roles') || currentUrl.contains('/admin/roles');
    final isModulesRoute = location.startsWith('/admin/modules') || currentUrl.contains('/admin/modules');
    final isAttendanceRoute = location.startsWith('/admin/attendance') || currentUrl.contains('/admin/attendance') || location.startsWith('/attendance') || currentUrl.contains('/attendance');
    final isLiveClassRoute = location.startsWith('/admin/live-classes') || currentUrl.contains('/admin/live-classes') || location.startsWith('/live-classes') || currentUrl.contains('/live-classes');
    final isVisitorsRoute = location.startsWith('/admin/visitors') || currentUrl.contains('/admin/visitors') || location.startsWith('/visitors') || currentUrl.contains('/visitors');
    final isInventoryRoute = location.startsWith('/admin/inventory') || currentUrl.contains('/admin/inventory') || location.startsWith('/inventory') || currentUrl.contains('/inventory');
    final isCampusRoute = location.startsWith('/admin/campus') || currentUrl.contains('/admin/campus') || location.startsWith('/campus') || currentUrl.contains('/campus');
    final isExamsRoute = location.startsWith('/admin/exams') || currentUrl.contains('/admin/exams') || location.startsWith('/exams') || currentUrl.contains('/exams');
    final isAnnouncementsRoute = location.startsWith('/admin/announcements') || currentUrl.contains('/admin/announcements') || location.startsWith('/admin/notices') || currentUrl.contains('/admin/notices') || location.startsWith('/notices') || currentUrl.contains('/notices');
    final isSystemConfigRoute = location.startsWith('/admin/config') || currentUrl.contains('/admin/config');

    // Only auto-expand active sections when the route actually changes (Accordion style: only 1 section open)
    final currentRoutePath = location.split('?').first;
    if (_lastNavPath != currentRoutePath) {
      _lastNavPath = currentRoutePath;
      if (isWorkRoute) {
        _expandOnlySection('work');
      } else if (isFleetRoute) {
        _expandOnlySection('fleet');
      } else if (isDriverRoute) {
        _expandOnlySection('driver');
      } else if (isRouteRoute) {
        _expandOnlySection('route');
      } else if (isHrRoute) {
        _expandOnlySection('hr');
      } else if (isClassesRoute) {
        _expandOnlySection('classes');
      } else if (isLibraryRoute) {
        _expandOnlySection('library');
      } else if (isHostelRoute) {
        _expandOnlySection('hostel');
      } else if (isRolesRoute) {
        _expandOnlySection('roles');
      } else if (isModulesRoute) {
        _expandOnlySection('modules');
      } else if (isAttendanceRoute) {
        _expandOnlySection('attendance');
      } else if (isLiveClassRoute) {
        _expandOnlySection('live_classes');
      } else if (isVisitorsRoute) {
        _expandOnlySection('visitors');
      } else if (isInventoryRoute) {
        _expandOnlySection('inventory');
      } else if (isCampusRoute) {
        _expandOnlySection('campus');
      } else if (isExamsRoute) {
        _expandOnlySection('exams');
      } else if (isAnnouncementsRoute) {
        _expandOnlySection('announcements');
      } else if (isSystemConfigRoute) {
        _expandOnlySection('config');
      } else {
        _collapseAllSections();
      }
    }

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

      // Fast module search filter
      if (_navSearchQuery.trim().isNotEmpty) {
        final query = _navSearchQuery.trim().toLowerCase();
        final matchesLabel = item.label.toLowerCase().contains(query);
        final matchesSection = _getSectionHeader(item.section).toLowerCase().contains(query);
        if (!matchesLabel && !matchesSection) {
          return false;
        }
      }

      // Work Management is universal across all institutional roles
      if (item.route == '/admin/work' || item.route.startsWith('/admin/work')) {
        return true;
      }

      // Live Class Management is accessible for administration and teaching staff
      if (item.route == '/admin/live-classes' || item.route.startsWith('/admin/live-classes')) {
        return true;
      }

      // Role based permissions
      if (role == 'super_admin' || role == 'superadmin' || role == 'admin' || role == 'school_admin') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route == '/admin/schools' ||
               item.route == '/admin/users' ||
               item.route.startsWith('/admin/hr') ||
               item.route == '/admin/classes' ||
               item.route == '/admin/attendance' ||
               item.route == '/admin/live-classes' ||
               item.route == '/admin/library' ||
               item.route.startsWith('/admin/hostel') ||
               item.route.startsWith('/admin/visitors') ||
               item.route.startsWith('/admin/inventory') ||
               item.route.startsWith('/admin/campus') ||
               item.route == '/admin/campus' ||
               item.route.startsWith('/admin/exams') ||
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
               item.route == '/admin/stops' ||
               item.route == '/admin/student-fees' ||
               item.route == '/admin/staff-salary';
      } else if (role == 'director' || role == 'principal') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route == '/admin/users' ||
               item.route.startsWith('/admin/hr') ||
               item.route == '/admin/classes' ||
               item.route == '/admin/attendance' ||
               item.route == '/admin/live-classes' ||
               item.route == '/admin/library' ||
               item.route.startsWith('/admin/hostel') ||
               item.route.startsWith('/admin/visitors') ||
               item.route.startsWith('/admin/inventory') ||
               item.route.startsWith('/admin/campus') ||
               item.route == '/admin/campus' ||
               item.route.startsWith('/admin/exams') ||
               item.route == '/admin/roles' ||
               item.route == '/admin/lookups' ||
               item.route == '/admin/finance' ||
               item.route == '/admin/defaulters' ||
               item.route == '/admin/student-fees' ||
               item.route == '/admin/staff-salary' ||
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
      } else if (role == 'hostel_warden' || role == 'warden' || role == 'hostel_manager' || role == 'caretaker') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/hostel') ||
               item.route.startsWith('/admin/visitors') ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'hr') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/hr') ||
               item.route == '/admin/staff' ||
               item.route == '/admin/staff-salary' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'finance' || role == 'accountant') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/inventory') ||
               item.route == '/admin/finance' ||
               item.route == '/admin/defaulters' ||
               item.route == '/admin/student-fees' ||
               item.route == '/admin/staff-salary' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'inventory_manager' || role == 'store_keeper' || role == 'inventory') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/inventory') ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'librarian') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route == '/admin/library' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'transport') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
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
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'exam_ctrl' || role == 'exam_controller') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/exams') ||
               item.route == '/admin/classes' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      } else if (role == 'teacher') {
        return item.route == '/admin/dashboard' ||
               item.route == '/admin/calendar' ||
               item.route == '/admin/messaging' ||
               item.route == '/admin/ai-chat' ||
               item.route == '/admin/documents' ||
               item.route.startsWith('/admin/exams') ||
               item.route == '/admin/classes' ||
               item.route == '/admin/attendance' ||
               item.route == '/admin/live-classes' ||
               item.route == '/admin/alerts-notifications' ||
               item.route == '/admin/emergency' ||
               item.route == '/admin/my-profile';
      }
      return item.route == '/admin/dashboard' || item.route == '/admin/calendar' || item.route == '/admin/messaging' || item.route == '/admin/ai-chat' || item.route == '/admin/documents' || item.route == '/admin/alerts-notifications' || item.route == '/admin/emergency' || item.route == '/admin/my-profile';
    }).toList();

    final selected = _selectedIndex(location, filteredItems);

    if (isDesktop) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Row(
          children: [
            // Permanent Sidebar (Desktop)
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
              child: _buildSidebarContent(
                isDark: isDark,
                showLabels: !_isSidebarCollapsed,
                selected: selected,
                filteredItems: filteredItems,
                user: user,
                userName: userName,
                role: role,
                location: location,
                isDrawer: false,
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
      // Mobile / Tablet Layout: Full Left Navigation Available via Drawer & Bottom Bar
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: Drawer(
          backgroundColor: theme.cardColor,
          width: 285,
          child: SafeArea(
            child: _buildSidebarContent(
              isDark: isDark,
              showLabels: true,
              selected: selected,
              filteredItems: filteredItems,
              user: user,
              userName: userName,
              role: role,
              location: location,
              isDrawer: true,
            ),
          ),
        ),
        body: Stack(
          children: [
            widget.child,
            // Sleek Floating Drawer Button for 1-Tap Access on Mobile/Tablet
            Positioned(
              top: 10,
              left: 10,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu_rounded, size: 16, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Text(
                            'Menu',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          currentLocation: location,
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        floatingActionButton: AiFab(
          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
          onPressed: () => _showAiAssistantDialog(context),
        ),
      );
    }
  }

  // Unified Reusable Sidebar Widget Shared across Desktop, Tablet & Mobile Drawer
  Widget _buildSidebarContent({
    required bool isDark,
    required bool showLabels,
    required int selected,
    required List<_NavItem> filteredItems,
    required Map<String, dynamic>? user,
    required String userName,
    required String role,
    required String location,
    required bool isDrawer,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 16,
        horizontal: showLabels ? 14 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header Section
          _buildBrandHeader(isDark, showLabels, isDrawer),
          const SizedBox(height: 16),

          // Search Box (when expanded/drawer)
          if (showLabels) ...[
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _navSearchQuery = val;
                  });
                },
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _navSearchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_isLoadingModules)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(minHeight: 2, color: Color(0xFF4F46E5)),
                ),
              ),
            const SizedBox(height: 14),
          ],

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
                  final headerText = _getSectionHeader(currentSection);

                  header = Padding(
                    padding: EdgeInsets.only(
                      left: 10,
                      top: index == 0 ? 0 : 18,
                      bottom: 6,
                    ),
                    child: Text(
                      headerText,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  );
                }

                // Expandable Option Tiles (Default collapsed)
                if (item.label == 'Fleet Management') {
                  final expandableTile = _buildExpandableFleetTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Driver Management') {
                  final expandableTile = _buildExpandableDriverTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Route Management') {
                  final expandableTile = _buildExpandableRouteTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Work Management') {
                  final expandableTile = _buildExpandableWorkTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'HR Suite') {
                  final expandableTile = _buildExpandableHrTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Classes & Facilities') {
                  final expandableTile = _buildExpandableClassesTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Library Management') {
                  final expandableTile = _buildExpandableLibraryTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Hostel Management') {
                  final expandableTile = _buildExpandableHostelTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Roles & Permissions') {
                  final expandableTile = _buildExpandableRolesTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Module Management') {
                  final expandableTile = _buildExpandableModulesTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Attendance Hub') {
                  final expandableTile = _buildExpandableAttendanceTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Live Class Management') {
                  final expandableTile = _buildExpandableLiveClassTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Visitors Management') {
                  final expandableTile = _buildExpandableVisitorsTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Inventory Management') {
                  final expandableTile = _buildExpandableInventoryTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Campus Management') {
                  final expandableTile = _buildExpandableCampusTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Exams Management') {
                  final expandableTile = _buildExpandableExamsTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'Announcements') {
                  final expandableTile = _buildExpandableAnnouncementsTile(isDark, showLabels, location, isDrawer);
                  if (header != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [header, expandableTile],
                    );
                  }
                  return expandableTile;
                }

                if (item.label == 'System Config') {
                  final expandableTile = _buildExpandableSystemConfigTile(isDark, showLabels, location, isDrawer);
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
                    if (isDrawer) Navigator.of(context).pop();
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
          const SizedBox(height: 8),
          _buildProfileFooter(isDark, user, userName, showLabels, isDrawer),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark, bool showLabels, bool isDrawer) {
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
                        config?.systemName ?? 'EduSHAMIIT ERP',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(
              isDrawer ? Icons.close_rounded : Icons.menu_open_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 20,
            ),
            onPressed: () {
              if (isDrawer) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _isSidebarCollapsed = true;
                });
              }
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
    final primaryColor = Theme.of(context).primaryColor;
    if (!showLabels) {
      return Tooltip(
        message: item.label,
        preferBelow: false,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
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
                        ? primaryColor.withValues(alpha: 0.15)
                        : primaryColor.withValues(alpha: 0.1))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon,
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                size: 20,
              ),
            ),
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? primaryColor.withValues(alpha: 0.15)
                  : primaryColor.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border(
                  left: BorderSide(
                    color: primaryColor,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.horizontal(
                    left: const Radius.circular(8),
                    right: trailing == null ? const Radius.circular(8) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.5, horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? primaryColor
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? primaryColor
                                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12.5,
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
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: trailing,
              ),
          ],
        ),
      );
    }
  }

  void _collapseAllSections() {
    _isWorkExpanded = false;
    _isFleetExpanded = false;
    _isDriverExpanded = false;
    _isRouteExpanded = false;
    _isHrExpanded = false;
    _isClassesExpanded = false;
    _isLibraryExpanded = false;
    _isHostelExpanded = false;
    _isRolesExpanded = false;
    _isModulesExpanded = false;
    _isAttendanceExpanded = false;
    _isLiveClassExpanded = false;
    _isVisitorsExpanded = false;
    _isInventoryExpanded = false;
    _isCampusExpanded = false;
    _isExamsExpanded = false;
    _isAnnouncementsExpanded = false;
    _isSystemConfigExpanded = false;
  }

  void _expandOnlySection(String sectionKey) {
    _collapseAllSections();
    switch (sectionKey) {
      case 'work': _isWorkExpanded = true; break;
      case 'fleet': _isFleetExpanded = true; break;
      case 'driver': _isDriverExpanded = true; break;
      case 'route': _isRouteExpanded = true; break;
      case 'hr': _isHrExpanded = true; break;
      case 'classes': _isClassesExpanded = true; break;
      case 'library': _isLibraryExpanded = true; break;
      case 'hostel': _isHostelExpanded = true; break;
      case 'roles': _isRolesExpanded = true; break;
      case 'modules': _isModulesExpanded = true; break;
      case 'attendance': _isAttendanceExpanded = true; break;
      case 'live_classes': _isLiveClassExpanded = true; break;
      case 'visitors': _isVisitorsExpanded = true; break;
      case 'inventory': _isInventoryExpanded = true; break;
      case 'campus': _isCampusExpanded = true; break;
      case 'exams': _isExamsExpanded = true; break;
      case 'announcements': _isAnnouncementsExpanded = true; break;
      case 'config': _isSystemConfigExpanded = true; break;
    }
  }

  void _toggleSection(String sectionKey) {
    setState(() {
      bool isCurrentlyOpen = false;
      switch (sectionKey) {
        case 'work': isCurrentlyOpen = _isWorkExpanded; break;
        case 'fleet': isCurrentlyOpen = _isFleetExpanded; break;
        case 'driver': isCurrentlyOpen = _isDriverExpanded; break;
        case 'route': isCurrentlyOpen = _isRouteExpanded; break;
        case 'hr': isCurrentlyOpen = _isHrExpanded; break;
        case 'classes': isCurrentlyOpen = _isClassesExpanded; break;
        case 'library': isCurrentlyOpen = _isLibraryExpanded; break;
        case 'hostel': isCurrentlyOpen = _isHostelExpanded; break;
        case 'roles': isCurrentlyOpen = _isRolesExpanded; break;
        case 'modules': isCurrentlyOpen = _isModulesExpanded; break;
        case 'attendance': isCurrentlyOpen = _isAttendanceExpanded; break;
        case 'live_classes': isCurrentlyOpen = _isLiveClassExpanded; break;
        case 'visitors': isCurrentlyOpen = _isVisitorsExpanded; break;
      case 'inventory': isCurrentlyOpen = _isInventoryExpanded; break;
      case 'campus': isCurrentlyOpen = _isCampusExpanded; break;
      case 'exams': isCurrentlyOpen = _isExamsExpanded; break;
        case 'announcements': isCurrentlyOpen = _isAnnouncementsExpanded; break;
        case 'config': isCurrentlyOpen = _isSystemConfigExpanded; break;
      }

      if (isCurrentlyOpen) {
        _collapseAllSections();
      } else {
        _expandOnlySection(sectionKey);
      }
    });
  }

  Widget _buildChevronTrailing({
    required bool isExpanded,
    required bool isRouteActive,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: AnimatedRotation(
            turns: isExpanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Icon(
              Icons.chevron_right_rounded,
              color: isRouteActive
                  ? const Color(0xFF4F46E5)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileFooter(bool isDark, Map<String, dynamic>? user, String userName, bool showLabels, bool isDrawer) {
    final role = user?['role']?.toString().toLowerCase() ?? 'super_admin';
    if (!showLabels) {
      return Tooltip(
        message: "$userName\n${_roleLabels[role] ?? role.toUpperCase().replaceAll('_', ' ')}",
        preferBelow: false,
        child: Center(
          child: InkWell(
            onTap: () {
              if (isDrawer) Navigator.of(context).pop();
              context.go('/admin/my-profile');
            },
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
              onTap: () {
                if (isDrawer) Navigator.of(context).pop();
                context.go('/admin/my-profile');
              },
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
                    const SizedBox(width: 10),
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

  Widget _buildExpandableFleetTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isFleetRoute = location.startsWith('/admin/fleet') || currentUrl.contains('/admin/fleet');
    final activeTab = int.tryParse(Uri.tryParse(currentUrl)?.queryParameters['tab'] ?? Uri.tryParse(location)?.queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.directions_bus_rounded,
            label: 'Fleet Management',
            route: '/admin/fleet',
            section: NavSection.transportFleet,
          ),
          isSelected: isFleetRoute && !_isFleetExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isFleetRoute) {
              _toggleSection('fleet');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('fleet');
              context.go('/admin/fleet');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isFleetExpanded,
                  isRouteActive: isFleetRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('fleet'),
                )
              : null,
        ),
        if (_isFleetExpanded && showLabels) ...[
          _buildSubTile('Overview', '/admin/fleet', 0, isFleetRoute && activeTab == 0, isDark, isDrawer, 'fleet'),
          _buildSubTile('Vehicles', '/admin/fleet', 1, isFleetRoute && activeTab == 1, isDark, isDrawer, 'fleet'),
          _buildSubTile('Vehicle Categories', '/admin/fleet', 2, isFleetRoute && activeTab == 2, isDark, isDrawer, 'fleet'),
          _buildSubTile('Vehicle Documents', '/admin/fleet', 3, isFleetRoute && activeTab == 3, isDark, isDrawer, 'fleet'),
        ],
      ],
    );
  }

  Widget _buildExpandableDriverTile(bool isDark, bool showLabels, String location, bool isDrawer) {
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
            section: NavSection.transportFleet,
          ),
          isSelected: isDriverRoute && !_isDriverExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isDriverRoute) {
              _toggleSection('driver');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('driver');
              context.go('/admin/driver-management');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isDriverExpanded,
                  isRouteActive: isDriverRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('driver'),
                )
              : null,
        ),
        if (_isDriverExpanded && showLabels) ...[
          _buildSubTile('Driver List', '/admin/driver-management', 0, isDriverRoute && activeTab == 0, isDark, isDrawer, 'driver'),
          _buildSubTile('License & Documents', '/admin/driver-management', 1, isDriverRoute && activeTab == 1, isDark, isDrawer, 'driver'),
          _buildSubTile('Performance', '/admin/driver-management', 2, isDriverRoute && activeTab == 2, isDark, isDrawer, 'driver'),
          _buildSubTile('Training', '/admin/driver-management', 3, isDriverRoute && activeTab == 3, isDark, isDrawer, 'driver'),
          _buildSubTile('Violations', '/admin/driver-management', 4, isDriverRoute && activeTab == 4, isDark, isDrawer, 'driver'),
        ],
      ],
    );
  }

  Widget _buildExpandableRouteTile(bool isDark, bool showLabels, String location, bool isDrawer) {
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
            section: NavSection.transportFleet,
          ),
          isSelected: isRouteRoute && !_isRouteExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isRouteRoute) {
              _toggleSection('route');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('route');
              context.go('/admin/route-management');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isRouteExpanded,
                  isRouteActive: isRouteRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('route'),
                )
              : null,
        ),
        if (_isRouteExpanded && showLabels) ...[
          _buildSubTile('Overview', '/admin/route-management', 0, isRouteRoute && activeTab == 0, isDark, isDrawer, 'route'),
          _buildSubTile('Route Management', '/admin/route-management', 1, isRouteRoute && activeTab == 1, isDark, isDrawer, 'route'),
          _buildSubTile('Live Tracking', '/admin/route-management', 2, isRouteRoute && activeTab == 2, isDark, isDrawer, 'route'),
          _buildSubTile('Route Reports', '/admin/route-management', 3, isRouteRoute && activeTab == 3, isDark, isDrawer, 'route'),
          _buildSubTile('Stops', '/admin/route-management', 4, isRouteRoute && activeTab == 4, isDark, isDrawer, 'route'),
          _buildSubTile('Passenger Assignment', '/admin/route-management', 5, isRouteRoute && activeTab == 5, isDark, isDrawer, 'route'),
        ],
      ],
    );
  }

  Widget _buildExpandableHrTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isHrRoute = location.startsWith('/admin/hr') || currentUrl.contains('/admin/hr') || location.startsWith('/hr') || currentUrl.contains('/hr');

    var cleanPath = Uri.tryParse(location)?.path ?? location;
    if ((cleanPath.isEmpty || cleanPath == '/') && kIsWeb) {
      final webPath = Uri.tryParse(html.window.location.href)?.path;
      if (webPath != null && webPath.isNotEmpty) cleanPath = webPath;
    }

    final String activeHrSub;
    if (cleanPath.startsWith('/admin/hr/recruitment') || cleanPath.startsWith('/hr/recruitment')) {
      activeHrSub = 'recruitment';
    } else if (cleanPath.startsWith('/admin/hr/onboarding') || cleanPath.startsWith('/hr/onboarding')) {
      activeHrSub = 'onboarding';
    } else if (cleanPath.startsWith('/admin/hr/training') || cleanPath.startsWith('/hr/training')) {
      activeHrSub = 'training';
    } else if (cleanPath.startsWith('/admin/hr/policies') || cleanPath.startsWith('/hr/policies')) {
      activeHrSub = 'policies';
    } else if (cleanPath.startsWith('/admin/hr') || cleanPath.startsWith('/hr')) {
      activeHrSub = 'overview';
    } else {
      activeHrSub = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.badge_outlined,
            label: 'HR Suite',
            route: '/admin/hr/overview',
            section: NavSection.humanResources,
          ),
          isSelected: isHrRoute && !_isHrExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isHrRoute) {
              _toggleSection('hr');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('hr');
              context.go('/admin/hr/overview');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isHrExpanded,
                  isRouteActive: isHrRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('hr'),
                )
              : null,
        ),
        if (_isHrExpanded && showLabels) ...[
          _buildHrRouteSubTile('Overview', '/admin/hr/overview', activeHrSub == 'overview', isDark, isDrawer),
          _buildHrRouteSubTile('Recruitment', '/admin/hr/recruitment', activeHrSub == 'recruitment', isDark, isDrawer),
          _buildHrRouteSubTile('Onboarding', '/admin/hr/onboarding', activeHrSub == 'onboarding', isDark, isDrawer),
          _buildHrRouteSubTile('Training & Learning', '/admin/hr/training', activeHrSub == 'training', isDark, isDrawer),
          _buildHrRouteSubTile('Policies & Documents', '/admin/hr/policies', activeHrSub == 'policies', isDark, isDrawer),
        ],
      ],
    );
  }

  Widget _buildExpandableClassesTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isClassesRoute = location.startsWith('/admin/classes') || currentUrl.contains('/admin/classes') || location.startsWith('/classes') || currentUrl.contains('/classes');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.meeting_room_outlined,
            label: 'Classes & Facilities',
            route: '/admin/classes',
            section: NavSection.academicsCampus,
          ),
          isSelected: isClassesRoute && !_isClassesExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isClassesRoute) {
              _toggleSection('classes');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('classes');
              context.go('/admin/classes');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isClassesExpanded,
                  isRouteActive: isClassesRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('classes'),
                )
              : null,
        ),
        if (_isClassesExpanded && showLabels) ...[
          _buildSubTile('Classes', '/admin/classes', 0, isClassesRoute && activeTab == 0, isDark, isDrawer, 'classes'),
          _buildSubTile('Sections', '/admin/classes', 1, isClassesRoute && activeTab == 1, isDark, isDrawer, 'classes'),
          _buildSubTile('Subjects', '/admin/classes', 2, isClassesRoute && activeTab == 2, isDark, isDrawer, 'classes'),
        ],
      ],
    );
  }

  Widget _buildExpandableWorkTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isWorkRoute = location.startsWith('/admin/work') || currentUrl.contains('/admin/work') || location.startsWith('/work') || currentUrl.contains('/work');
    int activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;
    if (location.startsWith('/admin/work/list') || currentUrl.contains('/admin/work/list')) activeTab = 1;
    if (location.startsWith('/admin/work/backlog') || currentUrl.contains('/admin/work/backlog')) activeTab = 2;
    if (location.startsWith('/admin/work/sprints') || currentUrl.contains('/admin/work/sprints')) activeTab = 3;
    if (location.startsWith('/admin/work/team') || currentUrl.contains('/admin/work/team')) activeTab = 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.layers_rounded,
            label: 'Work Management',
            route: '/admin/work',
            section: NavSection.executive,
          ),
          isSelected: isWorkRoute && !_isWorkExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isWorkRoute) {
              _toggleSection('work');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('work');
              context.go('/admin/work');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isWorkExpanded,
                  isRouteActive: isWorkRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('work'),
                )
              : null,
        ),
        if (_isWorkExpanded && showLabels) ...[
          _buildSubTile('Board', '/admin/work', 0, isWorkRoute && activeTab == 0, isDark, isDrawer, 'work'),
          _buildSubTile('List', '/admin/work', 1, isWorkRoute && activeTab == 1, isDark, isDrawer, 'work'),
          _buildSubTile('Backlog', '/admin/work', 2, isWorkRoute && activeTab == 2, isDark, isDrawer, 'work'),
          _buildSubTile('Sprints', '/admin/work', 3, isWorkRoute && activeTab == 3, isDark, isDrawer, 'work'),
          _buildSubTile('Team', '/admin/work', 4, isWorkRoute && activeTab == 4, isDark, isDrawer, 'work'),
        ],
      ],
    );
  }

  Widget _buildExpandableLibraryTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isLibraryRoute = location.startsWith('/admin/library') || currentUrl.contains('/admin/library') || location.startsWith('/library') || currentUrl.contains('/library');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.local_library_outlined,
            label: 'Library Management',
            route: '/admin/library',
            section: NavSection.academicsCampus,
          ),
          isSelected: isLibraryRoute && !_isLibraryExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isLibraryRoute) {
              _toggleSection('library');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('library');
              context.go('/admin/library');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isLibraryExpanded,
                  isRouteActive: isLibraryRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('library'),
                )
              : null,
        ),
        if (_isLibraryExpanded && showLabels) ...[
          _buildSubTile('Books', '/admin/library', 0, isLibraryRoute && activeTab == 0, isDark, isDrawer, 'library'),
          _buildSubTile('Members', '/admin/library', 1, isLibraryRoute && activeTab == 1, isDark, isDrawer, 'library'),
          _buildSubTile('Issue / Return', '/admin/library', 2, isLibraryRoute && activeTab == 2, isDark, isDrawer, 'library'),
          _buildSubTile('Requests', '/admin/library', 3, isLibraryRoute && activeTab == 3, isDark, isDrawer, 'library'),
        ],
      ],
    );
  }

  Widget _buildExpandableHostelTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isHostelRoute = location.startsWith('/admin/hostel') || currentUrl.contains('/admin/hostel') || location.startsWith('/hostel') || currentUrl.contains('/hostel');
    int activeTab = 0;
    try {
      final locUri = Uri.parse(location);
      final locTab = locUri.queryParameters['tab'];
      if (locTab != null) {
        activeTab = int.tryParse(locTab) ?? 0;
      } else if (kIsWeb) {
        final webUri = Uri.parse(currentUrl);
        final webTab = webUri.queryParameters['tab'];
        if (webTab != null) {
          activeTab = int.tryParse(webTab) ?? 0;
        }
      }
    } catch (_) {}
    if (location.endsWith('/rooms') || currentUrl.endsWith('/rooms')) {
      activeTab = 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.apartment_rounded,
            label: 'Hostel Management',
            route: '/admin/hostel',
            section: NavSection.academicsCampus,
          ),
          isSelected: isHostelRoute && !_isHostelExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isHostelRoute) {
              _toggleSection('hostel');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('hostel');
              context.go('/admin/hostel');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isHostelExpanded,
                  isRouteActive: isHostelRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('hostel'),
                )
              : null,
        ),
        if (_isHostelExpanded && showLabels) ...[
          _buildSubTile('Overview', '/admin/hostel', 0, isHostelRoute && activeTab == 0, isDark, isDrawer, 'hostel'),
          _buildSubTile('Rooms & Allocation', '/admin/hostel', 1, isHostelRoute && activeTab == 1, isDark, isDrawer, 'hostel'),
          _buildSubTile('Hostel Students', '/admin/hostel', 2, isHostelRoute && activeTab == 2, isDark, isDrawer, 'hostel'),
          _buildSubTile('Staff Management', '/admin/hostel', 3, isHostelRoute && activeTab == 3, isDark, isDrawer, 'hostel'),
          _buildSubTile('Fees & Billing', '/admin/hostel', 4, isHostelRoute && activeTab == 4, isDark, isDrawer, 'hostel'),
          _buildSubTile('Leave & Outing', '/admin/hostel', 5, isHostelRoute && activeTab == 5, isDark, isDrawer, 'hostel'),
          _buildSubTile('Complaints', '/admin/hostel', 6, isHostelRoute && activeTab == 6, isDark, isDrawer, 'hostel'),
          _buildSubTile('Reports', '/admin/hostel', 7, isHostelRoute && activeTab == 7, isDark, isDrawer, 'hostel'),
        ],
      ],
    );
  }

  Widget _buildExpandableRolesTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isRolesRoute = location.startsWith('/admin/roles') || currentUrl.contains('/admin/roles');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Roles & Permissions',
            route: '/admin/roles',
            section: NavSection.humanResources,
          ),
          isSelected: isRolesRoute && !_isRolesExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isRolesRoute) {
              _toggleSection('roles');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('roles');
              context.go('/admin/roles');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isRolesExpanded,
                  isRouteActive: isRolesRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('roles'),
                )
              : null,
        ),
        if (_isRolesExpanded && showLabels) ...[
          _buildSubTile('Roles', '/admin/roles', 0, isRolesRoute && activeTab == 0, isDark, isDrawer, 'roles'),
          _buildSubTile('Role Hierarchy', '/admin/roles', 1, isRolesRoute && activeTab == 1, isDark, isDrawer, 'roles'),
          _buildSubTile('Assign Permissions', '/admin/roles', 2, isRolesRoute && activeTab == 2, isDark, isDrawer, 'roles'),
          _buildSubTile('Drafted Permissions', '/admin/roles', 3, isRolesRoute && activeTab == 3, isDark, isDrawer, 'roles'),
        ],
      ],
    );
  }

  Widget _buildExpandableModulesTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isModulesRoute = location.startsWith('/admin/modules') || currentUrl.contains('/admin/modules');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.extension_outlined,
            label: 'Module Management',
            route: '/admin/modules',
            section: NavSection.systemDeveloper,
          ),
          isSelected: isModulesRoute && !_isModulesExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isModulesRoute) {
              _toggleSection('modules');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('modules');
              context.go('/admin/modules');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isModulesExpanded,
                  isRouteActive: isModulesRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('modules'),
                )
              : null,
        ),
        if (_isModulesExpanded && showLabels) ...[
          _buildSubTile('All Modules', '/admin/modules', 0, isModulesRoute && activeTab == 0, isDark, isDrawer, 'modules'),
          _buildSubTile('Module Categories', '/admin/modules', 1, isModulesRoute && activeTab == 1, isDark, isDrawer, 'modules'),
          _buildSubTile('Assign Modules', '/admin/modules', 2, isModulesRoute && activeTab == 2, isDark, isDrawer, 'modules'),
          _buildSubTile('Module Requests', '/admin/modules', 3, isModulesRoute && activeTab == 3, isDark, isDrawer, 'modules'),
        ],
      ],
    );
  }

  Widget _buildExpandableAttendanceTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isAttendanceRoute = location.startsWith('/admin/attendance') || currentUrl.contains('/admin/attendance') || location.startsWith('/attendance') || currentUrl.contains('/attendance');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.fact_check_outlined,
            label: 'Attendance Hub',
            route: '/admin/attendance',
            section: NavSection.academicsCampus,
          ),
          isSelected: isAttendanceRoute && !_isAttendanceExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isAttendanceRoute) {
              _toggleSection('attendance');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('attendance');
              context.go('/admin/attendance');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isAttendanceExpanded,
                  isRouteActive: isAttendanceRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('attendance'),
                )
              : null,
        ),
        if (_isAttendanceExpanded && showLabels) ...[
          _buildSubTile('Daily Attendance', '/admin/attendance', 0, isAttendanceRoute && activeTab == 0, isDark, isDrawer, 'attendance'),
          _buildSubTile('Staff Attendance', '/admin/attendance', 1, isAttendanceRoute && activeTab == 1, isDark, isDrawer, 'attendance'),
          _buildSubTile('Leave & Permissions', '/admin/attendance', 2, isAttendanceRoute && activeTab == 2, isDark, isDrawer, 'attendance'),
          _buildSubTile('Bulk Operations', '/admin/attendance', 3, isAttendanceRoute && activeTab == 3, isDark, isDrawer, 'attendance'),
          _buildSubTile('Attendance Insights', '/admin/attendance', 4, isAttendanceRoute && activeTab == 4, isDark, isDrawer, 'attendance'),
          _buildSubTile('Settings', '/admin/attendance', 5, isAttendanceRoute && activeTab == 5, isDark, isDrawer, 'attendance'),
        ],
      ],
    );
  }

  Widget _buildExpandableLiveClassTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isLiveClassRoute = location.startsWith('/admin/live-classes') || currentUrl.contains('/admin/live-classes') || location.startsWith('/live-classes') || currentUrl.contains('/live-classes');
    int activeTab = 0;
    try {
      final locUri = Uri.parse(location);
      final locTab = locUri.queryParameters['tab'];
      if (locTab != null) {
        activeTab = int.tryParse(locTab) ?? 0;
      } else if (kIsWeb) {
        final webUri = Uri.parse(currentUrl);
        final webTab = webUri.queryParameters['tab'];
        if (webTab != null) {
          activeTab = int.tryParse(webTab) ?? 0;
        }
      }
    } catch (_) {}
    if (location.endsWith('/white-board') ||
        currentUrl.endsWith('/white-board') ||
        location.endsWith('/whiteboard') ||
        currentUrl.endsWith('/whiteboard')) {
      activeTab = 2;
    } else if (location.endsWith('/recordings') || currentUrl.endsWith('/recordings')) {
      activeTab = 1;
    } else if (location.endsWith('/join') || currentUrl.endsWith('/join')) {
      activeTab = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.video_camera_front_rounded,
            label: 'Live Class Management',
            route: '/admin/live-classes',
            section: NavSection.academicsCampus,
          ),
          isSelected: isLiveClassRoute && !_isLiveClassExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isLiveClassRoute) {
              _toggleSection('live_classes');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('live_classes');
              context.go('/admin/live-classes');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isLiveClassExpanded,
                  isRouteActive: isLiveClassRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('live_classes'),
                )
              : null,
        ),
        if (_isLiveClassExpanded && showLabels) ...[
          _buildSubTile('Join & Conduct', '/admin/live-classes', 0, isLiveClassRoute && activeTab == 0, isDark, isDrawer, 'live_classes'),
          _buildSubTile('Recordings', '/admin/live-classes', 1, isLiveClassRoute && activeTab == 1, isDark, isDrawer, 'live_classes'),
          _buildSubTile('White Board', '/admin/live-classes', 2, isLiveClassRoute && activeTab == 2, isDark, isDrawer, 'live_classes'),
        ],
      ],
    );
  }

  
  Widget _buildExpandableExamsTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isExamsRoute = location.startsWith('/admin/exams') || currentUrl.contains('/admin/exams') || location.startsWith('/exams') || currentUrl.contains('/exams');

    final isQuestionBank = location.contains('/question-bank');
    final isPaperBuilder = location.contains('/paper-builder');
    final isScheduled = isExamsRoute && !isQuestionBank && !isPaperBuilder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.quiz_outlined,
            label: 'Exams Management',
            route: '/admin/exams',
            section: NavSection.academicsCampus,
          ),
          isSelected: isExamsRoute && !_isExamsExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isExamsRoute) {
              _toggleSection('exams');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('exams');
              context.go('/admin/exams');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isExamsExpanded,
                  isRouteActive: isExamsRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('exams'),
                )
              : null,
        ),
        if (_isExamsExpanded && showLabels) ...[
          _buildSubTileDirect('Scheduled Exams', '/admin/exams', isScheduled, isDark, isDrawer, 'exams'),
          _buildSubTileDirect('Question Bank', '/admin/exams/question-bank', isQuestionBank, isDark, isDrawer, 'exams'),
          _buildSubTileDirect('Paper Builder', '/admin/exams/paper-builder', isPaperBuilder, isDark, isDrawer, 'exams'),
        ],
      ],
    );
  }

  Widget _buildSubTileDirect(String label, String directRoute, bool isSelected, bool isDark, bool isDrawer, [String? sectionKey]) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            if (sectionKey != null) {
              setState(() => _expandOnlySection(sectionKey));
            }
            context.go(directRoute);
            setState(() {});
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? primaryColor.withValues(alpha: 0.15)
                      : primaryColor.withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
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


  Widget _buildExpandableCampusTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isCampusRoute = location.startsWith('/admin/campus') || currentUrl.contains('/admin/campus') || location.startsWith('/campus') || currentUrl.contains('/campus');
    final activeTab = int.tryParse(Uri.tryParse(currentUrl)?.queryParameters['tab'] ?? Uri.tryParse(location)?.queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.domain_rounded,
            label: 'Campus Management',
            route: '/admin/campus',
            section: NavSection.academicsCampus,
          ),
          isSelected: isCampusRoute && !_isCampusExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isCampusRoute) {
              _toggleSection('campus');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('campus');
              context.go('/admin/campus');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isCampusExpanded,
                  isRouteActive: isCampusRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('campus'),
                )
              : null,
        ),
        if (_isCampusExpanded && showLabels) ...[
          _buildSubTile('Buildings & Rooms', '/admin/campus', 0, isCampusRoute && activeTab == 0, isDark, isDrawer, 'campus'),
          _buildSubTile('Facilities', '/admin/campus', 1, isCampusRoute && activeTab == 1, isDark, isDrawer, 'campus'),
          _buildSubTile('Space Booking', '/admin/campus', 2, isCampusRoute && activeTab == 2, isDark, isDrawer, 'campus'),
          _buildSubTile('Maintenance', '/admin/campus', 3, isCampusRoute && activeTab == 3, isDark, isDrawer, 'campus'),
          _buildSubTile('Safety & Compliance', '/admin/campus', 4, isCampusRoute && activeTab == 4, isDark, isDrawer, 'campus'),
          _buildSubTile('Device Management & Control', '/admin/campus', 5, isCampusRoute && activeTab == 5, isDark, isDrawer, 'campus'),
          _buildSubTile('Utilities & Services', '/admin/campus', 6, isCampusRoute && activeTab == 6, isDark, isDrawer, 'campus'),
          _buildSubTile('Reports', '/admin/campus', 7, isCampusRoute && activeTab == 7, isDark, isDrawer, 'campus'),
        ],
      ],
    );
  }

  Widget _buildExpandableInventoryTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isInventoryRoute = location.startsWith('/admin/inventory') || currentUrl.contains('/admin/inventory') || location.startsWith('/inventory') || currentUrl.contains('/inventory');
    final activeTab = int.tryParse(Uri.tryParse(currentUrl)?.queryParameters['tab'] ?? Uri.tryParse(location)?.queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.inventory_2_rounded,
            label: 'Inventory Management',
            route: '/admin/inventory',
            section: NavSection.academicsCampus,
          ),
          isSelected: isInventoryRoute && !_isInventoryExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isInventoryRoute) {
              _toggleSection('inventory');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('inventory');
              context.go('/admin/inventory');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isInventoryExpanded,
                  isRouteActive: isInventoryRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('inventory'),
                )
              : null,
        ),
        if (_isInventoryExpanded && showLabels) ...[
          _buildSubTile('Stock Overview', '/admin/inventory', 0, isInventoryRoute && activeTab == 0, isDark, isDrawer, 'inventory'),
          _buildSubTile('Recent Transactions', '/admin/inventory', 1, isInventoryRoute && activeTab == 1, isDark, isDrawer, 'inventory'),
          _buildSubTile('Purchase Orders', '/admin/inventory', 2, isInventoryRoute && activeTab == 2, isDark, isDrawer, 'inventory'),
          _buildSubTile('Sales Orders', '/admin/inventory', 3, isInventoryRoute && activeTab == 3, isDark, isDrawer, 'inventory'),
        ],
      ],
    );
  }

  Widget _buildExpandableVisitorsTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isVisitorsRoute = location.startsWith('/admin/visitors') || currentUrl.contains('/admin/visitors') || location.startsWith('/visitors') || currentUrl.contains('/visitors');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.person_pin_circle_outlined,
            label: 'Visitors Management',
            route: '/admin/visitors',
            section: NavSection.academicsCampus,
          ),
          isSelected: isVisitorsRoute && !_isVisitorsExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isVisitorsRoute) {
              _toggleSection('visitors');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('visitors');
              context.go('/admin/visitors');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isVisitorsExpanded,
                  isRouteActive: isVisitorsRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('visitors'),
                )
              : null,
        ),
        if (_isVisitorsExpanded && showLabels) ...[
          _buildSubTile('All Visitors', '/admin/visitors', 0, isVisitorsRoute && activeTab == 0, isDark, isDrawer, 'visitors'),
          _buildSubTile('Scheduled Visitors', '/admin/visitors', 1, isVisitorsRoute && activeTab == 1, isDark, isDrawer, 'visitors'),
          _buildSubTile('Blacklisted Visitors', '/admin/visitors', 2, isVisitorsRoute && activeTab == 2, isDark, isDrawer, 'visitors'),
        ],
      ],
    );
  }

  Widget _buildExpandableAnnouncementsTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isAnnouncementsRoute = location.startsWith('/admin/announcements') || currentUrl.contains('/admin/announcements') || location.startsWith('/admin/notices') || currentUrl.contains('/admin/notices') || location.startsWith('/notices') || currentUrl.contains('/notices');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.campaign_outlined,
            label: 'Announcements',
            route: '/admin/announcements',
            section: NavSection.financeOperations,
          ),
          isSelected: isAnnouncementsRoute && !_isAnnouncementsExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isAnnouncementsRoute) {
              _toggleSection('announcements');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('announcements');
              context.go('/admin/announcements');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isAnnouncementsExpanded,
                  isRouteActive: isAnnouncementsRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('announcements'),
                )
              : null,
        ),
        if (_isAnnouncementsExpanded && showLabels) ...[
          _buildSubTile('All Notices', '/admin/announcements', 0, isAnnouncementsRoute && activeTab == 0, isDark, isDrawer, 'announcements'),
          _buildSubTile('My Notices', '/admin/announcements', 1, isAnnouncementsRoute && activeTab == 1, isDark, isDrawer, 'announcements'),
          _buildSubTile('School Notices', '/admin/announcements', 2, isAnnouncementsRoute && activeTab == 2, isDark, isDrawer, 'announcements'),
          _buildSubTile('Department Notices', '/admin/announcements', 3, isAnnouncementsRoute && activeTab == 3, isDark, isDrawer, 'announcements'),
          _buildSubTile('Drafts', '/admin/announcements', 4, isAnnouncementsRoute && activeTab == 4, isDark, isDrawer, 'announcements'),
          _buildSubTile('Scheduled', '/admin/announcements', 5, isAnnouncementsRoute && activeTab == 5, isDark, isDrawer, 'announcements'),
          _buildSubTile('Pending Approval', '/admin/announcements', 6, isAnnouncementsRoute && activeTab == 6, isDark, isDrawer, 'announcements'),
          _buildSubTile('Expired', '/admin/announcements', 7, isAnnouncementsRoute && activeTab == 7, isDark, isDrawer, 'announcements'),
          _buildSubTile('Archived', '/admin/announcements', 8, isAnnouncementsRoute && activeTab == 8, isDark, isDrawer, 'announcements'),
        ],
      ],
    );
  }

  Widget _buildExpandableSystemConfigTile(bool isDark, bool showLabels, String location, bool isDrawer) {
    final currentUrl = kIsWeb ? html.window.location.href : location;
    final isSystemConfigRoute = location.startsWith('/admin/config') || currentUrl.contains('/admin/config');
    final activeTab = int.tryParse(Uri.parse(currentUrl).queryParameters['tab'] ?? '0') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSidebarTile(
          item: const _NavItem(
            icon: Icons.settings_outlined,
            label: 'System Config',
            route: '/admin/config',
            section: NavSection.systemDeveloper,
          ),
          isSelected: isSystemConfigRoute && !_isSystemConfigExpanded,
          isDark: isDark,
          showLabels: showLabels,
          onTap: () {
            if (isSystemConfigRoute) {
              _toggleSection('config');
            } else {
              if (isDrawer) Navigator.of(context).pop();
              _expandOnlySection('config');
              context.go('/admin/config');
            }
          },
          trailing: showLabels
              ? _buildChevronTrailing(
                  isExpanded: _isSystemConfigExpanded,
                  isRouteActive: isSystemConfigRoute,
                  isDark: isDark,
                  onToggle: () => _toggleSection('config'),
                )
              : null,
        ),
        if (_isSystemConfigExpanded && showLabels) ...[
          _buildSubTile('General Settings', '/admin/config', 0, isSystemConfigRoute && activeTab == 0, isDark, isDrawer, 'config'),
          _buildSubTile('Security', '/admin/config', 1, isSystemConfigRoute && activeTab == 1, isDark, isDrawer, 'config'),
          _buildSubTile('Email & SMS', '/admin/config', 2, isSystemConfigRoute && activeTab == 2, isDark, isDrawer, 'config'),
          _buildSubTile('Modules', '/admin/config', 3, isSystemConfigRoute && activeTab == 3, isDark, isDrawer, 'config'),
          _buildSubTile('Appearance', '/admin/config', 4, isSystemConfigRoute && activeTab == 4, isDark, isDrawer, 'config'),
          _buildSubTile('Payments', '/admin/config', 5, isSystemConfigRoute && activeTab == 5, isDark, isDrawer, 'config'),
          _buildSubTile('Integrations', '/admin/config', 6, isSystemConfigRoute && activeTab == 6, isDark, isDrawer, 'config'),
          _buildSubTile('Backup & Restore', '/admin/config', 7, isSystemConfigRoute && activeTab == 7, isDark, isDrawer, 'config'),
          _buildSubTile('Advanced', '/admin/config', 8, isSystemConfigRoute && activeTab == 8, isDark, isDrawer, 'config'),
          _buildSubTile('Login Page', '/admin/config', 9, isSystemConfigRoute && activeTab == 9, isDark, isDrawer, 'config'),
          _buildSubTile('Footer Settings', '/admin/config', 10, isSystemConfigRoute && activeTab == 10, isDark, isDrawer, 'config'),
        ],
      ],
    );
  }

  Widget _buildHrRouteSubTile(String label, String route, bool isSelected, bool isDark, bool isDrawer) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            setState(() => _expandOnlySection('hr'));
            context.go(route);
            if (kIsWeb) {
              Future.microtask(() {
                try {
                  html.window.dispatchEvent(html.CustomEvent('tab_changed'));
                } catch (_) {}
              });
            }
            setState(() {});
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? primaryColor.withValues(alpha: 0.15)
                      : primaryColor.withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
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

  Widget _buildSubTile(String label, String baseRoute, int tabIndex, bool isSelected, bool isDark, bool isDrawer, [String? sectionKey]) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDrawer) Navigator.of(context).pop();
            if (sectionKey != null) {
              setState(() => _expandOnlySection(sectionKey));
            }
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
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? primaryColor.withValues(alpha: 0.15)
                      : primaryColor.withValues(alpha: 0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11.5,
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

// 7 Enterprise Pillars
enum NavSection {
  executive,
  academicsCampus,
  transportFleet,
  humanResources,
  financeOperations,
  securityAudit,
  systemDeveloper,
}

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
