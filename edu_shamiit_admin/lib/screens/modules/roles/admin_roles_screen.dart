import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html;

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg => _isDark ? const Color(0xFF070913) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF0E1326) : Colors.white;
  Color get _dialogBg => _isDark ? const Color(0xFF11172E) : Colors.white;
  Color get _borderColor => _isDark ? const Color(0xFF1E2846) : Colors.black.withValues(alpha: 0.08);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  final ScrollController _horizScrollController = ScrollController();
  final ScrollController _hierarchyScrollController = ScrollController();
  final ScrollController _tableHorizController = ScrollController();
  final ScrollController _tableVertController = ScrollController();
  final ScrollController _rightSidebarScrollController = ScrollController();

  bool _isLoading = true;
  List<dynamic> _roles = [];
  List<dynamic> _hierarchyTree = [];
  Map<String, dynamic>? _selectedRole;

  // Active Tab: "Roles", "Role Hierarchy", "Assign Permissions", "Drafted Permissions"
  String _activeTab = "Role Hierarchy";

  // Modules data
  List<dynamic> _modules = [];
  bool _isLoadingModules = true;
  Map<String, dynamic>? _selectedModule;
  String _moduleSearchQuery = "";

  // Search & Filter state for Roles tab
  String _searchQuery = "";
  String _statusFilter = "All Status"; // "All Status", "Active", "Inactive"
  String _roleTypeFilter = "ALL"; // "ALL", "SYSTEM", "CUSTOM"

  // Pagination for Roles Tab
  int _currentPage = 1;
  int _pageSize = 10;

  // Search & Pagination for Role Hierarchy Tab
  String _hierarchySearchQuery = "";
  int _hierarchyCurrentPage = 1;
  int _hierarchyPageSize = 10;

  // Tree interactive state
  final Set<String> _collapsedNodeIds = {};

  // In-memory permissions map for selected role in Assign Permissions tab
  // Key: "module_id:action" -> Value: "allow" / "deny" / "not_set"
  final Map<String, String> _rolePermissionsMap = {};

  // Standard CRUD & System actions for each module
  final List<Map<String, String>> _permissionActions = [
    {'action': 'create', 'label': 'Create', 'desc': 'Add new items or records'},
    {'action': 'read', 'label': 'Read', 'desc': 'View list and details records'},
    {'action': 'update', 'label': 'Update', 'desc': 'Modify existing records'},
    {'action': 'delete', 'label': 'Delete', 'desc': 'Permanently delete records'},
    {'action': 'export', 'label': 'Export', 'desc': 'Export module data to CSV/Excel'},
    {'action': 'import', 'label': 'Import', 'desc': 'Import records from files'},
    {'action': 'approve', 'label': 'Approve', 'desc': 'Approve or verify transactions'},
    {'action': 'activate_deactivate', 'label': 'Activate / Deactivate', 'desc': 'Activate or deactivate records'},
    {'action': 'view_audit', 'label': 'View Audit Logs', 'desc': 'View activity log for this module'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRoles();
    _fetchModules();
  }

  @override
  void dispose() {
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _horizScrollController.dispose();
    _hierarchyScrollController.dispose();
    _tableHorizController.dispose();
    _tableVertController.dispose();
    _rightSidebarScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoles() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/schools/roles', useCache: false);
      if (res['success'] == true) {
        final rolesData = res['data'] as List<dynamic>? ?? [];
        final hierarchyRes = await ApiService().get('/admin/schools/roles/hierarchy', useCache: false);
        final treeData = hierarchyRes['success'] == true
            ? ((hierarchyRes['data'] ?? hierarchyRes['tree']) as List<dynamic>? ?? [])
            : [];

        setState(() {
          _roles = rolesData;
          _hierarchyTree = treeData;

          if (_roles.isNotEmpty) {
            final storedRoleId = CacheService().get<String>('selected_role_id');
            if (storedRoleId != null) {
              final stillExists = _roles.firstWhere(
                (r) => r['id'].toString() == storedRoleId,
                orElse: () => null,
              );
              _selectedRole = stillExists ?? _roles.first;
            } else {
              _selectedRole ??= _roles.first;
            }
            _loadRolePermissions();
          } else {
            _selectedRole = null;
          }
        });
      } else {
        _showErrorSnackBar(res['message'] ?? 'Failed to fetch roles');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchModules() async {
    setState(() {
      _isLoadingModules = true;
    });
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
          if (_modules.isNotEmpty && _selectedModule == null) {
            _selectedModule = _modules.first;
          }
        });
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModules = false;
        });
      }
    }
  }

  void _loadRolePermissions() {
    _rolePermissionsMap.clear();
    if (_selectedRole != null) {
      final List<dynamic> draftPerms = _selectedRole!['draft_permissions'] ?? [];
      final List<dynamic> activePerms = _selectedRole!['permissions'] ?? [];
      final bool hasDraftModulePerms = draftPerms.any((p) => p.toString().contains(':'));
      final List<dynamic> perms = hasDraftModulePerms ? draftPerms : activePerms;

      for (final p in perms) {
        final str = p.toString();
        final parts = str.split(':');
        if (parts.length == 3) {
          _rolePermissionsMap['${parts[0]}:${parts[1]}'] = parts[2];
        } else {
          _rolePermissionsMap[str] = 'allow';
        }
      }
    }
  }

  List<String> _buildPermissionsList() {
    final List<String> list = [];
    _rolePermissionsMap.forEach((key, effect) {
      if (effect == 'allow' || effect == 'deny') {
        if (key.contains(':')) {
          list.add('$key:$effect');
        } else {
          if (effect == 'allow') {
            list.add(key);
          }
        }
      }
    });
    return list;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _hasPendingPublish(Map<String, dynamic> role) {
    return role['has_pending_publish'] ?? false;
  }

  bool _hasModuleDraftChanges(String modId) {
    if (_selectedRole == null) return false;
    final List<dynamic> activePerms = _selectedRole!['permissions'] ?? [];
    final List<dynamic> draftPerms = _selectedRole!['draft_permissions'] ?? [];

    for (final actionMap in _permissionActions) {
      final action = actionMap['action']!;
      final activeEffect = _getPermissionEffect(activePerms, modId, action);
      final draftEffect = _getPermissionEffect(draftPerms, modId, action);
      if (activeEffect != draftEffect) return true;
    }
    return false;
  }

  String _getPermissionEffect(List<dynamic> perms, String modId, String action) {
    final prefix = '$modId:$action:';
    for (final p in perms) {
      final str = p.toString();
      if (str.startsWith(prefix)) {
        return str.substring(prefix.length);
      }
    }
    return 'not_set';
  }

  Widget _buildEffectBadge(String effect, {bool isDraft = false}) {
    Color bg;
    Color fg;
    String label;

    switch (effect) {
      case 'allow':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        label = 'ALLOW';
        break;
      case 'deny':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        label = 'DENY';
        break;
      default:
        bg = isDraft ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05);
        fg = isDraft ? const Color(0xFFF59E0B) : _textMuted;
        label = 'NOT SET';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header matching the SaaS screenshot layout
                  _buildHeader(screenWidth, isMobile),

                  // Metrics summary row (for Roles tab)
                  if (_activeTab == "Roles") ...[
                    _buildMetricsRow(screenWidth),
                    const SizedBox(height: 12),
                  ],

                  // Dynamic Tabs Bar: Roles | Role Hierarchy | Assign Permissions | Drafted Permissions
                  _buildTabsRow(),

                  // Main View Content Container
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      child: _buildActiveTabContent(isMobile),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // =========================================================================
  // TOP HEADER (Search, Institution Picker, Notifications, Create New Role)
  // =========================================================================
  Widget _buildHeader(double screenWidth, bool isMobile) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              'Roles Management',
              style: TextStyle(
                color: _textPrimary,
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Text(
                '${_roles.length} ROLES',
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Manage user roles, tree hierarchy and granular system permissions',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );

    final actionsRow = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // Institution Picker Dropdown
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apartment_rounded, size: 14, color: _textSecondary),
              const SizedBox(width: 6),
              Text(
                'All Institutions',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 14, color: _textSecondary),
            ],
          ),
        ),

        // Global Search bar
        Container(
          width: isMobile ? 180 : 220,
          height: 36,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: TextField(
            style: TextStyle(color: _textPrimary, fontSize: 12),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
            },
            decoration: const InputDecoration(
              hintText: 'Search roles...',
              hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              prefixIcon: Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 14),
            ),
          ),
        ),

        // Notifications Bell
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Icon(Icons.notifications_none_rounded, size: 16, color: _textSecondary),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: const Text('12', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),

        // Create New Role Button (Purple Glow CTA)
        ElevatedButton.icon(
          onPressed: () => _openRoleFormModal(),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text(
            'Create New Role',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleColumn,
                const SizedBox(height: 12),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: actionsRow),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleColumn),
                const SizedBox(width: 16),
                actionsRow,
              ],
            ),
    );
  }

  // =========================================================================
  // METRICS ROW (Roles Tab)
  // =========================================================================
  Widget _buildMetricsRow(double screenWidth) {
    final systemRoles = _roles.where((r) => r['is_custom'] != true && (r['role_type'] ?? '').toString().toUpperCase() != 'CUSTOM').length;
    final customRoles = _roles.where((r) => r['is_custom'] == true || (r['role_type'] ?? '').toString().toUpperCase() == 'CUSTOM').length;
    final usersCount = _roles.fold<int>(0, (sum, r) => sum + ((r['user_count'] as num?)?.toInt() ?? 0));
    final totalPermissionsAssigned = _roles.fold<int>(0, (sum, r) {
      final List<dynamic> perms = r['permissions'] ?? [];
      return sum + perms.length;
    });

    double cardWidth = (screenWidth - 96) / 5;
    if (cardWidth < 180) cardWidth = 180;

    return Padding(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricCardItem('Total Roles', '${systemRoles + customRoles}', 'Active roles in system', Icons.shield_outlined, const Color(0xFF818CF8), cardWidth),
            const SizedBox(width: 10),
            _buildMetricCardItem('System Roles', '$systemRoles', 'Default system roles', Icons.security_outlined, const Color(0xFF38BDF8), cardWidth),
            const SizedBox(width: 10),
            _buildMetricCardItem('Custom Roles', '$customRoles', 'Custom created roles', Icons.group_outlined, const Color(0xFF60A5FA), cardWidth),
            const SizedBox(width: 10),
            _buildMetricCardItem('Users Assigned', '$usersCount', 'Users with roles', Icons.people_outline, const Color(0xFF34D399), cardWidth),
            const SizedBox(width: 10),
            _buildMetricCardItem('Permissions', '$totalPermissionsAssigned', 'Total assigned permissions', Icons.key_outlined, const Color(0xFFFBBF24), cardWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCardItem(String title, String value, String subtitle, IconData icon, Color accentColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DYNAMIC TABS BAR (Roles | Role Hierarchy | Assign Permissions | Drafted Permissions)
  // =========================================================================
  Widget _buildTabsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          _buildTabItem("Roles"),
          _buildTabItem("Role Hierarchy"),
          if (_selectedRole != null) ...[
            _buildTabItem("Assign Permissions"),
            _buildTabItem("Drafted Permissions"),
          ],
          const Spacer(),
          if (_activeTab == "Role Hierarchy")
            InkWell(
              onTap: _showHowHierarchyWorksDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 14, color: _textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'How Role Hierarchy Works?',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String tabName) {
    final isActive = _activeTab == tabName;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isActive ? (_isDark ? Colors.white : const Color(0xFF6366F1)) : _textSecondary,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ACTIVE TAB CONTENT SWITCHER
  // =========================================================================
  Widget _buildActiveTabContent(bool isMobile) {
    switch (_activeTab) {
      case "Roles":
        return _buildRolesTabContent(isMobile);
      case "Role Hierarchy":
        return _buildHierarchyTabContent(isMobile);
      case "Assign Permissions":
        return _buildAssignPermissionsView();
      case "Drafted Permissions":
        return _buildDraftedPermissionsView();
      default:
        return _buildHierarchyTabContent(isMobile);
    }
  }

  // =========================================================================
  // TAB 1: ROLES MANAGEMENT VIEW (Table + Sidebar)
  // =========================================================================
  Widget _buildRolesTabContent(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
              ),
              child: Column(
                children: [
                  _buildFilterSection(),
                  Expanded(child: _buildRolesTable()),
                ],
              ),
            ),
          ),
          if (_selectedRole != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 380,
              child: _buildRolesRightSidebarSection(),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (70%): Roles Table with Filter
        Expanded(
          flex: 7,
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                _buildFilterSection(),
                Expanded(child: _buildRolesTable()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right Column (30%): Selected Role Details
        Expanded(
          flex: 3,
          child: _buildRolesRightSidebarSection(),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 220,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _scaffoldBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: TextField(
                  style: TextStyle(color: _textPrimary, fontSize: 12),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search roles...',
                    hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 11),
                    prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF475569)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _scaffoldBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textPrimary, fontSize: 11.5),
                    items: const [
                      DropdownMenuItem(value: "All Status", child: Text("All Status")),
                      DropdownMenuItem(value: "Active", child: Text("Active")),
                      DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _scaffoldBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _roleTypeFilter,
                    dropdownColor: _cardBg,
                    style: TextStyle(color: _textPrimary, fontSize: 11.5),
                    items: const [
                      DropdownMenuItem(value: "ALL", child: Text("All Types")),
                      DropdownMenuItem(value: "SYSTEM", child: Text("System Roles")),
                      DropdownMenuItem(value: "CUSTOM", child: Text("Custom Roles")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _roleTypeFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _exportHierarchyPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF818CF8)),
            label: const Text('Export PDF', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF818CF8),
              side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTable() {
    final filteredRoles = _roles.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final displayName = (r['display_name'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? 'Active').toString().toLowerCase();
      final roleType = (r['role_type'] ?? (r['is_custom'] == true ? 'CUSTOM' : 'SYSTEM')).toString().toUpperCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          displayName.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase()) ||
          code.contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == "All Status" || status == _statusFilter.toLowerCase();
      final matchesType = _roleTypeFilter == "ALL" || roleType == _roleTypeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();

    final totalRolesCount = filteredRoles.length;
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRolesCount);
    final pageRoles = startIndex < totalRolesCount ? filteredRoles.sublist(startIndex, endIndex) : [];

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _scaffoldBg.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: _borderColor)),
          ),
          child: Row(
            children: [
              Expanded(flex: 4, child: Text('ROLE NAME', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 3, child: Text('ROLE CODE', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 2, child: Text('TYPE', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 2, child: Text('USERS', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 2, child: Text('STATUS', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              SizedBox(width: 80, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: pageRoles.isEmpty
              ? Center(child: Text('No roles match your search filters.', style: TextStyle(color: _textSecondary, fontSize: 12)))
              : ListView.builder(
                  controller: _leftScrollController,
                  itemCount: pageRoles.length,
                  itemBuilder: (context, idx) {
                    final role = pageRoles[idx] as Map<String, dynamic>;
                    final isSelected = _selectedRole != null && _selectedRole!['id'] == role['id'];
                    final isCustom = role['is_custom'] == true || (role['role_type'] ?? '').toString().toUpperCase() == 'CUSTOM';
                    final status = role['status'] ?? 'Active';
                    final isActive = status.toString().toLowerCase() == 'active';
                    final userCount = role['user_count'] ?? 0;
                    final displayName = (role['display_name'] ?? role['name']?.toString().replaceAll('_', ' ').toUpperCase()).toString();
                    final code = role['code'] ?? '';

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRole = role;
                          _loadRolePermissions();
                          CacheService().set('selected_role_id', role['id'].toString());
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.08) : null,
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                              width: 3,
                            ),
                            bottom: BorderSide(color: _borderColor.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Role Name
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      isCustom ? Icons.badge_outlined : Icons.shield_outlined,
                                      size: 14,
                                      color: isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            color: isSelected ? const Color(0xFF818CF8) : _textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                        if (role['description'] != null)
                                          Text(
                                            role['description'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: _textMuted, fontSize: 10.5),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Role Code
                            Expanded(
                              flex: 3,
                              child: Text(
                                code,
                                style: TextStyle(color: _textSecondary, fontSize: 11.5, fontFamily: 'monospace'),
                              ),
                            ),

                            // Role Type
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: (isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: 0.3), width: 0.5),
                                  ),
                                  child: Text(
                                    isCustom ? 'CUSTOM' : 'SYSTEM',
                                    style: TextStyle(
                                      color: isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Users Assigned
                            Expanded(
                              flex: 2,
                              child: Text(
                                '$userCount users',
                                style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),

                            // Status
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'INACTIVE',
                                    style: TextStyle(
                                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () => _openRoleFormModal(role: role),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(Icons.edit_outlined, size: 14, color: _textSecondary),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    color: _dialogBg,
                                    icon: Icon(Icons.more_horiz_rounded, size: 16, color: _textSecondary),
                                    onSelected: (action) => _handleRoleRowAction(action, role),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view_users',
                                        child: Row(
                                          children: [
                                            Icon(Icons.people_outline_rounded, size: 14),
                                            SizedBox(width: 8),
                                            Text('View Users', style: TextStyle(fontSize: 11.5)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'manage_perms',
                                        child: Row(
                                          children: [
                                            Icon(Icons.vpn_key_outlined, size: 14),
                                            SizedBox(width: 8),
                                            Text('Manage Permissions', style: TextStyle(fontSize: 11.5)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'add_child',
                                        child: Row(
                                          children: [
                                            Icon(Icons.account_tree_outlined, size: 14),
                                            SizedBox(width: 8),
                                            Text('Add Sub Role', style: TextStyle(fontSize: 11.5)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'audit_logs',
                                        child: Row(
                                          children: [
                                            Icon(Icons.history_rounded, size: 14),
                                            SizedBox(width: 8),
                                            Text('Audit Logs', style: TextStyle(fontSize: 11.5)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle_status',
                                        child: Row(
                                          children: [
                                            Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline, size: 14),
                                            const SizedBox(width: 8),
                                            Text(isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 11.5)),
                                          ],
                                        ),
                                      ),
                                      if (isCustom)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                                              SizedBox(width: 8),
                                              Text('Delete Role', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Reusable Pagination Footer with Rows Per Page Selection
        _buildPaginationFooter(
          totalCount: totalRolesCount,
          currentPage: _currentPage,
          pageSize: _pageSize,
          onPageChanged: (p) => setState(() => _currentPage = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _currentPage = 1;
          }),
        ),
      ],
    );
  }

  // =========================================================================
  // REUSABLE PAGINATION FOOTER WITH ROWS PER PAGE SELECTION & PAGE PILLS
  // =========================================================================
  Widget _buildPaginationFooter({
    required int totalCount,
    required int currentPage,
    required int pageSize,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onPageSizeChanged,
  }) {
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 9999);
    final startIndex = totalCount == 0 ? 0 : (currentPage - 1) * pageSize + 1;
    final endIndex = (currentPage * pageSize).clamp(0, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalCount == 0
                ? 'No roles found'
                : 'Showing $startIndex to $endIndex of $totalCount roles',
            style: TextStyle(color: _textMuted, fontSize: 11.5),
          ),
          Row(
            children: [
              // Previous Page Button
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: currentPage > 1 ? _textPrimary : _textMuted.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              const SizedBox(width: 2),

              // Numbered Page Pills (e.g. [1], [2], [3])
              ...List.generate(totalPages > 5 ? 5 : totalPages, (i) {
                final pageNum = i + 1;
                final isCurrent = pageNum == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => onPageChanged(pageNum),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF6366F1)
                            : _borderColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : _textSecondary,
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 2),
              // Next Page Button
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: currentPage < totalPages ? _textPrimary : _textMuted.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),

              const SizedBox(width: 14),

              // Rows per page dropdown selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rows per page:',
                    style: TextStyle(color: _textMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _scaffoldBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: pageSize,
                        dropdownColor: _dialogBg,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _textSecondary),
                        style: TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                        items: [5, 10, 25, 50, 100].map((v) {
                          return DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            onPageSizeChanged(v);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Right sidebar details for Roles Tab
  Widget _buildRolesRightSidebarSection() {
    if (_selectedRole == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Center(
          child: Text('Select a role to view details', style: TextStyle(color: _textSecondary, fontSize: 12)),
        ),
      );
    }

    final role = _selectedRole!;
    final name = (role['display_name'] ?? role['name']).toString();
    final code = (role['code'] ?? '').toString();
    final desc = (role['description'] ?? 'No description provided.').toString();
    final userCount = role['user_count'] ?? 0;
    final isCustom = role['is_custom'] == true;
    final permsCount = role['permissions_count'] ?? (role['permissions'] as List<dynamic>?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFF818CF8), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Text(code, style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(desc, style: TextStyle(color: _textSecondary, fontSize: 11.5, height: 1.4)),
          Divider(height: 24, color: _borderColor),

          _buildSidebarDetailRow('Users Assigned', '$userCount'),
          _buildSidebarDetailRow('Direct Permissions', '$permsCount'),
          _buildSidebarDetailRow('Type', isCustom ? 'Custom Role' : 'System Role'),
          _buildSidebarDetailRow('Status', role['status'] ?? 'Active'),

          if (_hasPendingPublish(role)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pending draft changes',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRoleFormModal(role: role),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Role', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showUsersAssignedModal(role),
                  icon: const Icon(Icons.people_outline_rounded, size: 14),
                  label: Text('View Users ($userCount)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _activeTab = "Assign Permissions";
                });
              },
              icon: const Icon(Icons.settings_outlined, size: 14),
              label: const Text('Manage Permissions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: BorderSide(color: _borderColor),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: ROLE HIERARCHY VIEW (Tree Visualizer + Hierarchy List + Sidebar)
  // =========================================================================
  Widget _buildHierarchyTabContent(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildHierarchyTreeCard(),
            const SizedBox(height: 16),
            _buildHierarchyTableCard(),
            const SizedBox(height: 16),
            _buildHierarchySidebar(),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (70%): Visual Tree + Hierarchy List
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            controller: _tableVertController,
            child: Column(
              children: [
                _buildHierarchyTreeCard(),
                const SizedBox(height: 16),
                _buildHierarchyTableCard(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right Column (30%): Selected Role Details & Legend & Actions
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            controller: _rightSidebarScrollController,
            child: _buildHierarchySidebar(),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // CARD 1: ROLE HIERARCHY VISUALIZATION TREE
  // =========================================================================
  Widget _buildHierarchyTreeCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Role Hierarchy Visualization',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interactive hierarchical tree showing organizational reporting lines and permission inheritance',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Expand All
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _collapsedNodeIds.clear();
                        });
                      },
                      icon: const Icon(Icons.unfold_more_rounded, size: 13),
                      label: const Text('Expand All', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Collapse All
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (final r in _roles) {
                            _collapsedNodeIds.add(r['id'].toString());
                          }
                        });
                      },
                      icon: const Icon(Icons.unfold_less_rounded, size: 13),
                      label: const Text('Collapse All', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Export Hierarchy PDF
                    IconButton(
                      onPressed: _exportHierarchyPdf,
                      tooltip: 'Download Role Hierarchy (PDF)',
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF818CF8)),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _borderColor),

          // Interactive Visual Tree Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Scrollbar(
              controller: _hierarchyScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _hierarchyScrollController,
                scrollDirection: Axis.horizontal,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildDynamicHierarchyTreeNodes(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicHierarchyTreeNodes() {
    if (_hierarchyTree.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.account_tree_outlined, size: 40, color: _textMuted),
              const SizedBox(height: 8),
              Text('No hierarchy configured yet.', style: TextStyle(color: _textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final rootNodes = _hierarchyTree.where((r) => r['name'] != 'owner').toList();
    final displayRoots = rootNodes.isNotEmpty ? rootNodes : _hierarchyTree;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: displayRoots.map((root) => _buildTreeNodeWidget(root as Map<String, dynamic>)).toList(),
    );
  }

  Widget _buildTreeNodeWidget(Map<String, dynamic> node) {
    final String nodeId = node['id'].toString();
    final List<dynamic> children = (node['children'] as List<dynamic>?) ?? [];
    final bool hasChildren = children.isNotEmpty;
    final bool isCollapsed = _collapsedNodeIds.contains(nodeId);

    final bool matchesSearch = _searchQuery.isNotEmpty &&
        ((node['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (node['display_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (node['code'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Current Node Card
        _buildRoleNodeCard(node, isHighlighted: matchesSearch),

        if (hasChildren && !isCollapsed) ...[
          // Vertical Connector down from bottom center of parent
          Container(
            width: 1.5,
            height: 20.0,
            color: const Color(0xFF475569),
          ),

          // Subtree with children connected by geometric branches
          _buildChildrenWithBranches(children),
        ],
      ],
    );
  }

  Widget _buildChildrenWithBranches(List<dynamic> children) {
    if (children.isEmpty) return const SizedBox();

    if (children.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 1.5,
            height: 20.0,
            color: const Color(0xFF475569),
          ),
          _buildTreeNodeWidget(children.first as Map<String, dynamic>),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.asMap().entries.map((entry) {
        final idx = entry.key;
        final child = entry.value as Map<String, dynamic>;
        final isFirst = idx == 0;
        final isLast = idx == children.length - 1;

        return IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top horizontal and vertical connector junction
              _buildChildBranchConnector(isFirst: isFirst, isLast: isLast),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildTreeNodeWidget(child),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChildBranchConnector({required bool isFirst, required bool isLast}) {
    return SizedBox(
      height: 20.0,
      child: Row(
        children: [
          // Left half of the horizontal connector line
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: isFirst
                  ? const SizedBox()
                  : Container(height: 1.5, color: const Color(0xFF475569)),
            ),
          ),
          // Vertical drop stem into the child card
          Container(
            width: 1.5,
            height: 20.0,
            color: const Color(0xFF475569),
          ),
          // Right half of the horizontal connector line
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: isLast
                  ? const SizedBox()
                  : Container(height: 1.5, color: const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleNodeCard(Map<String, dynamic> role, {bool isHighlighted = false}) {
    final id = role['id'].toString();
    final name = (role['name'] ?? '').toString();
    final displayName = (role['display_name'] ?? name.replaceFirst('ROLE_', '').replaceAll('_', ' ').toUpperCase()).toString();
    final isCustom = role['is_custom'] == true || (role['role_type'] ?? '').toString().toUpperCase() == 'CUSTOM';
    final userCount = (role['user_count'] as num?)?.toInt() ?? 0;
    final level = (role['level'] as num?)?.toInt() ?? 1;
    final isSelected = _selectedRole != null && _selectedRole!['id'].toString() == id;

    final formattedUserCount = NumberFormat('#,###').format(userCount);

    Color cardBgColor;
    Color borderColor;
    Widget leadingIcon;
    Color badgeBg;
    Color badgeFg;

    if (level == 1) {
      // Level 1: Super Admin (Royal Purple)
      cardBgColor = const Color(0xFF2E1B5B);
      borderColor = const Color(0xFF8B5CF6);
      leadingIcon = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle),
      );
      badgeBg = const Color(0xFF4338CA).withValues(alpha: 0.7);
      badgeFg = const Color(0xFFC7D2FE);
    } else if (level == 2) {
      // Level 2: Institution Admin & Academic Admin (Emerald Green)
      cardBgColor = const Color(0xFF044332);
      borderColor = const Color(0xFF10B981);
      leadingIcon = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
      );
      badgeBg = const Color(0xFF065F46).withValues(alpha: 0.8);
      badgeFg = const Color(0xFFA7F3D0);
    } else if (level == 3) {
      // Level 3: Teacher, Accountant, Librarian, Student, Front Office (Navy/Slate)
      cardBgColor = const Color(0xFF0F1E36);
      borderColor = const Color(0xFF2563EB).withValues(alpha: 0.6);
      leadingIcon = const Icon(Icons.person, size: 12, color: Color(0xFF60A5FA));
      badgeBg = isCustom ? const Color(0xFF0369A1).withValues(alpha: 0.7) : const Color(0xFF1E3A8A).withValues(alpha: 0.7);
      badgeFg = isCustom ? const Color(0xFF7DD3FC) : const Color(0xFF93C5FD);
    } else {
      // Level 4
      if (name.contains('student') || name.contains('parent')) {
        // Students (Plum / Maroon)
        cardBgColor = const Color(0xFF4A0E2E);
        borderColor = const Color(0xFFBE185D);
        leadingIcon = const Icon(Icons.person, size: 12, color: Color(0xFFF472B6));
        badgeBg = const Color(0xFF831843).withValues(alpha: 0.8);
        badgeFg = const Color(0xFFFBCFE8);
      } else {
        // Teachers (Warm Amber)
        cardBgColor = const Color(0xFF451A03);
        borderColor = const Color(0xFFD97706);
        leadingIcon = const Icon(Icons.badge_outlined, size: 12, color: Color(0xFFFBBF24));
        badgeBg = const Color(0xFF78350F).withValues(alpha: 0.8);
        badgeFg = const Color(0xFFFDE68A);
      }
    }

    final hasChildren = (role['children'] as List<dynamic>?)?.isNotEmpty ?? false;
    final isCollapsed = _collapsedNodeIds.contains(id);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _loadRolePermissions();
          CacheService().set('selected_role_id', id);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isHighlighted ? const Color(0xFFF59E0B) : borderColor),
            width: isSelected ? 2.0 : (isHighlighted ? 2.0 : 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? 2 : 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row 1: Icon + Title + Badge + Collapse Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                leadingIcon,
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCustom ? 'Custom' : 'System',
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasChildren) ...[
                  const SizedBox(width: 3),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isCollapsed) {
                          _collapsedNodeIds.remove(id);
                        } else {
                          _collapsedNodeIds.add(id);
                        }
                      });
                    },
                    child: Icon(
                      isCollapsed ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Centered User Count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 11, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(width: 3.5),
                Text(
                  formattedUserCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CARD 2: ROLES HIERARCHY LIST TABLE (Hierarchy Tab)
  // =========================================================================
  Widget _buildHierarchyTableCard() {
    final filteredRoles = _roles.where((r) {
      final status = (r['status'] ?? 'Active').toString().toLowerCase();
      if (status != 'active') return false;

      final name = (r['name'] ?? '').toString().toLowerCase();
      final displayName = (r['display_name'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();

      return name.contains(_hierarchySearchQuery.toLowerCase()) ||
          displayName.contains(_hierarchySearchQuery.toLowerCase()) ||
          desc.contains(_hierarchySearchQuery.toLowerCase()) ||
          code.contains(_hierarchySearchQuery.toLowerCase());
    }).toList();

    final totalRolesCount = filteredRoles.length;
    final startIndex = (_hierarchyCurrentPage - 1) * _hierarchyPageSize;
    final endIndex = (startIndex + _hierarchyPageSize).clamp(0, totalRolesCount);
    final pageRoles = startIndex < totalRolesCount ? filteredRoles.sublist(startIndex, endIndex) : [];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Roles Hierarchy List',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                Container(
                  width: 200,
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _scaffoldBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    style: TextStyle(color: _textPrimary, fontSize: 11.5),
                    onChanged: (val) {
                      setState(() {
                        _hierarchySearchQuery = val;
                        _hierarchyCurrentPage = 1;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Filter hierarchy...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      prefixIcon: Icon(Icons.search, size: 13, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _borderColor),

          // Horizontal Scrollbar Container for Grid Content
          Scrollbar(
            controller: _tableHorizController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _tableHorizController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1080,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _scaffoldBg.withValues(alpha: 0.5),
                        border: Border(bottom: BorderSide(color: _borderColor)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 190, child: Text('ROLE NAME', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 140, child: Text('ROLE CODE', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 95, child: Text('TYPE', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 70, child: Text('LEVEL', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 150, child: Text('PARENT ROLE', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 80, child: Text('USERS', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 110, child: Text('PERMISSIONS', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 95, child: Text('STATUS', style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                          SizedBox(width: 80, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(color: _textMuted, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                        ],
                      ),
                    ),

                    // Table Rows
                    if (pageRoles.isEmpty)
                      Container(
                        width: 1080,
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        child: Text(
                          'No active roles found matching the hierarchy filter.',
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pageRoles.length,
                        itemBuilder: (context, idx) {
                          final role = pageRoles[idx] as Map<String, dynamic>;
                          final isSelected = _selectedRole != null && _selectedRole!['id'] == role['id'];
                          final isCustom = role['is_custom'] == true || (role['role_type'] ?? '').toString().toUpperCase() == 'CUSTOM';
                          final status = role['status'] ?? 'Active';
                          final isActive = status.toString().toLowerCase() == 'active';
                          final userCount = role['user_count'] ?? 0;
                          final permsCount = role['permissions_count'] ?? (role['permissions'] as List<dynamic>?)?.length ?? 0;
                          final level = role['level'] ?? 1;
                          final parentName = role['parent_role_display_name'] ?? '—';
                          final displayName = (role['display_name'] ?? role['name']?.toString().replaceAll('_', ' ').toUpperCase()).toString();
                          final code = role['code'] ?? '';

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedRole = role;
                                _loadRolePermissions();
                                CacheService().set('selected_role_id', role['id'].toString());
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.08) : null,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                                    width: 3,
                                  ),
                                  bottom: BorderSide(color: _borderColor.withValues(alpha: 0.5)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Role Name
                                  SizedBox(
                                    width: 190,
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFF818CF8) : _textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Code
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      code,
                                      style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Type
                                  SizedBox(
                                    width: 95,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: (isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isCustom ? 'Custom' : 'System',
                                          style: TextStyle(
                                            color: isCustom ? const Color(0xFF38BDF8) : const Color(0xFF818CF8),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Level
                                  SizedBox(
                                    width: 70,
                                    child: Text('L$level', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),

                                  // Parent Role
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      parentName,
                                      style: TextStyle(color: _textSecondary, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Users
                                  SizedBox(
                                    width: 80,
                                    child: Text('$userCount', style: TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),

                                  // Permissions
                                  SizedBox(
                                    width: 110,
                                    child: Text('$permsCount', style: TextStyle(color: _textSecondary, fontSize: 11)),
                                  ),

                                  // Status
                                  SizedBox(
                                    width: 95,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isActive ? 'ACTIVE' : 'INACTIVE',
                                          style: TextStyle(
                                            color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Actions
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        InkWell(
                                          onTap: () => _openRoleFormModal(role: role),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(Icons.edit_outlined, size: 14, color: _textSecondary),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            color: _dialogBg,
                                            icon: Icon(Icons.more_horiz_rounded, size: 16, color: _textSecondary),
                                            onSelected: (action) => _handleRoleRowAction(action, role),
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'view_users',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.people_outline_rounded, size: 14),
                                                    SizedBox(width: 8),
                                                    Text('View Users', style: TextStyle(fontSize: 11.5)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'manage_perms',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.vpn_key_outlined, size: 14),
                                                    SizedBox(width: 8),
                                                    Text('Manage Permissions', style: TextStyle(fontSize: 11.5)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'add_child',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.account_tree_outlined, size: 14),
                                                    SizedBox(width: 8),
                                                    Text('Add Sub Role', style: TextStyle(fontSize: 11.5)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'audit_logs',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.history_rounded, size: 14),
                                                    SizedBox(width: 8),
                                                    Text('Audit Logs', style: TextStyle(fontSize: 11.5)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Pagination Footer with Rows Per Page Selection
          _buildPaginationFooter(
            totalCount: totalRolesCount,
            currentPage: _hierarchyCurrentPage,
            pageSize: _hierarchyPageSize,
            onPageChanged: (p) => setState(() => _hierarchyCurrentPage = p),
            onPageSizeChanged: (s) => setState(() {
              _hierarchyPageSize = s;
              _hierarchyCurrentPage = 1;
            }),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT SIDEBAR (Hierarchy Tab)
  // =========================================================================
  Widget _buildHierarchySidebar() {
    if (_selectedRole == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Center(
          child: Text('Select a role to view details', style: TextStyle(color: _textSecondary, fontSize: 12)),
        ),
      );
    }

    final role = _selectedRole!;
    final name = (role['display_name'] ?? role['name']).toString();
    final code = (role['code'] ?? '').toString();
    final desc = (role['description'] ?? 'No description provided.').toString();
    final userCount = role['user_count'] ?? 0;
    final permsCount = role['permissions_count'] ?? (role['permissions'] as List<dynamic>?)?.length ?? 0;
    final childCount = role['child_roles_count'] ?? (role['children'] as List<dynamic>?)?.length ?? 0;

    final createdAtStr = role['created_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(role['created_at'].toString()))
        : 'N/A';
    final updatedAtStr = role['updated_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(role['updated_at'].toString()))
        : 'N/A';

    return Column(
      children: [
        // CARD 1: Selected Role Details
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF818CF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Text(code, style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(desc, style: TextStyle(color: _textSecondary, fontSize: 11.5, height: 1.4)),
              Divider(height: 24, color: _borderColor),

              _buildSidebarDetailRow('Role Code', code),
              _buildSidebarDetailRow('Users Assigned', '$userCount'),
              _buildSidebarDetailRow('Permissions', '$permsCount'),
              _buildSidebarDetailRow('Child Roles', '$childCount'),
              _buildSidebarDetailRow('Created On', createdAtStr),
              _buildSidebarDetailRow('Last Updated', updatedAtStr),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openRoleFormModal(role: role),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit Role', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUsersAssignedModal(role),
                      icon: const Icon(Icons.people_outline_rounded, size: 14),
                      label: Text('View Users ($userCount)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 2: Hierarchy Legend
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hierarchy Legend',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 14),
              _buildLegendItem('System Role', const Color(0xFF818CF8)),
              _buildLegendItem('Custom Role', const Color(0xFF38BDF8)),
              _buildLegendItem('Default Role', const Color(0xFFF59E0B)),
              _buildLegendItem('Inherited Role', const Color(0xFFEC4899)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 3: Information Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Information',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoBullet(
                Icons.verified_user_outlined,
                'Roles inherit permissions from their parent roles automatically.',
              ),
              const SizedBox(height: 8),
              _buildInfoBullet(
                Icons.people_alt_outlined,
                'Users assigned to a role will automatically inherit permissions from all parent roles.',
              ),
              const SizedBox(height: 8),
              _buildInfoBullet(
                Icons.warning_amber_rounded,
                'Changes to a parent role will affect all dependent child roles.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 4: Quick Actions
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openRoleFormModal(parentRole: role),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Add Sub Role', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeTab = "Assign Permissions";
                        });
                      },
                      icon: const Icon(Icons.settings_outlined, size: 14),
                      label: const Text('Manage Permissions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAuditLogsModal(role),
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: const Text('View Audit Logs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: BorderSide(color: _borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarDetailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(color: _textSecondary, fontSize: 11.5)),
          Text(
            value,
            style: TextStyle(color: _textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF818CF8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: _textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: ASSIGN PERMISSIONS VIEW
  // =========================================================================
  Widget _buildAssignPermissionsView() {
    if (_selectedRole == null) {
      return Center(child: Text("Please select a role first", style: TextStyle(color: _textSecondary)));
    }

    final isMobile = Responsive.isMobile(context);
    final roleName = (_selectedRole!['display_name'] ?? _selectedRole!['name']).toString();
    final roleCode = (_selectedRole!['code'] ?? '').toString();

    final filteredModules = _modules.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final desc = (m['description'] ?? '').toString().toLowerCase();
      return name.contains(_moduleSearchQuery.toLowerCase()) || desc.contains(_moduleSearchQuery.toLowerCase());
    }).toList();

    final totalSystemPerms = _modules.length * 9;
    final totalAllowed = _rolePermissionsMap.entries.where((e) => e.key.contains(':') && e.value == 'allow').length;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vpn_key_outlined, size: 16, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text('Configuring Permissions for: ', style: TextStyle(color: _textSecondary, fontSize: 12)),
                Text(roleName, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                Text(' ($roleCode)', style: TextStyle(color: _textMuted, fontSize: 11)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 0.5),
                  ),
                  child: Text(
                    '$totalAllowed / $totalSystemPerms Configured',
                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeTab = "Roles";
                    });
                  },
                  icon: const Icon(Icons.arrow_back, size: 13),
                  label: const Text('Back', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),

          // Modules Tree & Actions Matrix
          Expanded(
            child: Row(
              children: [
                // Modules list sidebar
                Container(
                  width: isMobile ? 180 : 250,
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: _borderColor))),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _scaffoldBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _borderColor),
                          ),
                          child: TextField(
                            style: TextStyle(color: _textPrimary, fontSize: 12),
                            onChanged: (val) {
                              setState(() {
                                _moduleSearchQuery = val;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search modules...',
                              hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 11),
                              prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF475569)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(bottom: 14),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: _borderColor),
                      Expanded(
                        child: _isLoadingModules
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                            : ListView.builder(
                                itemCount: filteredModules.length,
                                itemBuilder: (context, idx) {
                                  final m = filteredModules[idx];
                                  final isSel = _selectedModule != null && _selectedModule!['id'] == m['id'];
                                  final modId = m['id'].toString();
                                  final allowedCount = _permissionActions.where((act) => _rolePermissionsMap['$modId:${act['action']}'] == 'allow').length;

                                  return ListTile(
                                    dense: true,
                                    selected: isSel,
                                    selectedTileColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                    title: Text(m['name'] ?? '', style: TextStyle(color: isSel ? const Color(0xFF818CF8) : _textPrimary, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                    trailing: allowedCount > 0
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('$allowedCount', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 8.5, fontWeight: FontWeight.bold)),
                                          )
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedModule = m;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // Permissions Action Table
                Expanded(
                  child: _selectedModule == null
                      ? Center(child: Text('Select a module', style: TextStyle(color: _textSecondary)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _scaffoldBg.withValues(alpha: 0.3),
                                border: Border(bottom: BorderSide(color: _borderColor)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Permission', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 5, child: Text('Description', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Allow', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Deny', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Not Set', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _permissionActions.length,
                                itemBuilder: (context, idx) {
                                  final act = _permissionActions[idx];
                                  final actionKey = act['action']!;
                                  final modId = _selectedModule!['id'].toString();
                                  final currVal = _rolePermissionsMap['$modId:$actionKey'] ?? 'not_set';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(act['label']!, style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: Text(act['desc']!, style: TextStyle(color: _textSecondary, fontSize: 11)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _rolePermissionsMap['$modId:$actionKey'] = 'allow';
                                                });
                                              },
                                              child: CircleAvatar(
                                                radius: 7,
                                                backgroundColor: currVal == 'allow' ? const Color(0xFF10B981) : Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: currVal == 'allow' ? const Color(0xFF10B981) : _textMuted, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _rolePermissionsMap['$modId:$actionKey'] = 'deny';
                                                });
                                              },
                                              child: CircleAvatar(
                                                radius: 7,
                                                backgroundColor: currVal == 'deny' ? const Color(0xFFEF4444) : Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: currVal == 'deny' ? const Color(0xFFEF4444) : _textMuted, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _rolePermissionsMap.remove('$modId:$actionKey');
                                                });
                                              },
                                              child: CircleAvatar(
                                                radius: 7,
                                                backgroundColor: currVal == 'not_set' ? const Color(0xFFF59E0B) : Colors.transparent,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: currVal == 'not_set' ? const Color(0xFFF59E0B) : _textMuted, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _borderColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _savePermissions(publish: false),
                  child: const Text('Save as Draft', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _savePermissions(publish: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Review & Publish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: DRAFTED PERMISSIONS COMPARISON VIEW
  // =========================================================================
  Widget _buildDraftedPermissionsView() {
    if (_selectedRole == null) {
      return Center(child: Text("Please select a role first", style: TextStyle(color: _textSecondary)));
    }

    final isMobile = Responsive.isMobile(context);
    final roleName = (_selectedRole!['display_name'] ?? _selectedRole!['name']).toString();
    final code = (_selectedRole!['code'] ?? '').toString();

    final filteredModules = _modules.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final desc = (m['description'] ?? '').toString().toLowerCase();
      return name.contains(_moduleSearchQuery.toLowerCase()) || desc.contains(_moduleSearchQuery.toLowerCase());
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 8),
                Text('Drafted Permissions Comparison: ', style: TextStyle(color: _textSecondary, fontSize: 12)),
                Text(roleName, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                Text(' ($code)', style: TextStyle(color: _textMuted, fontSize: 11)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeTab = "Role Hierarchy";
                    });
                  },
                  icon: const Icon(Icons.arrow_back, size: 13),
                  label: const Text('Back', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),

          // Comparison Table
          Expanded(
            child: Row(
              children: [
                // Modules sidebar
                Container(
                  width: isMobile ? 180 : 240,
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: _borderColor))),
                  child: ListView.builder(
                    itemCount: filteredModules.length,
                    itemBuilder: (context, idx) {
                      final m = filteredModules[idx];
                      final isSel = _selectedModule != null && _selectedModule!['id'] == m['id'];
                      final hasDraftChange = _hasModuleDraftChanges(m['id'].toString());

                      return ListTile(
                        dense: true,
                        selected: isSel,
                        selectedTileColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        title: Text(m['name'] ?? '', style: TextStyle(color: isSel ? const Color(0xFFF59E0B) : _textPrimary, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        trailing: hasDraftChange
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('PENDING', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8, fontWeight: FontWeight.bold)),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedModule = m;
                          });
                        },
                      );
                    },
                  ),
                ),

                // Table
                Expanded(
                  child: _selectedModule == null
                      ? Center(child: Text('Select a module to view differences', style: TextStyle(color: _textSecondary)))
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _scaffoldBg.withValues(alpha: 0.3),
                                border: Border(bottom: BorderSide(color: _borderColor)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Permission', style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Active (Published)', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 3, child: Text('Draft (Unpublished)', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _permissionActions.length,
                                itemBuilder: (context, idx) {
                                  final act = _permissionActions[idx];
                                  final action = act['action']!;
                                  final modId = _selectedModule!['id'].toString();

                                  final activeEffect = _getPermissionEffect(_selectedRole!['permissions'] ?? [], modId, action);
                                  final draftEffect = _getPermissionEffect(_selectedRole!['draft_permissions'] ?? [], modId, action);
                                  final isDifferent = activeEffect != draftEffect;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _borderColor))),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(act['label']!, style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                                        Expanded(flex: 3, child: Center(child: _buildEffectBadge(activeEffect))),
                                        Expanded(flex: 3, child: Center(child: _buildEffectBadge(draftEffect, isDraft: true))),
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDifferent ? const Color(0xFFF59E0B).withValues(alpha: 0.12) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isDifferent ? 'CHANGED' : 'SAME',
                                                style: TextStyle(
                                                  color: isDifferent ? const Color(0xFFF59E0B) : _textMuted,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _borderColor))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final res = await ApiService().put('/admin/schools/roles/${_selectedRole!['id']}', {
                        'draft_permissions': _selectedRole!['permissions'] ?? [],
                      });
                      if (res['success'] == true) {
                        _showSuccessSnackBar('Draft permissions discarded.');
                        _fetchRoles();
                      } else {
                        _showErrorSnackBar(res['message'] ?? 'Failed to discard draft');
                      }
                    } catch (e) {
                      _showErrorSnackBar('Network error: $e');
                    }
                  },
                  child: const Text('Discard Draft', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final res = await ApiService().post('/admin/schools/roles/${_selectedRole!['id']}/publish', {});
                      if (res['success'] == true) {
                        _showSuccessSnackBar('Permissions published successfully!');
                        _fetchRoles();
                        setState(() {
                          _activeTab = "Roles";
                        });
                      } else {
                        _showErrorSnackBar(res['message'] ?? 'Failed to publish permissions');
                      }
                    } catch (e) {
                      _showErrorSnackBar('Network error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Publish Draft Changes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePermissions({required bool publish}) async {
    if (_selectedRole == null) return;
    final permsList = _buildPermissionsList();
    try {
      final body = {
        'draft_permissions': permsList,
        if (publish) 'permissions': permsList,
      };
      final res = await ApiService().put('/admin/schools/roles/${_selectedRole!['id']}', body);
      if (res['success'] == true) {
        _showSuccessSnackBar(publish ? 'Permissions published successfully!' : 'Draft permissions saved.');
        _fetchRoles();
        if (publish) {
          setState(() {
            _activeTab = "Roles";
          });
        }
      } else {
        _showErrorSnackBar(res['message'] ?? 'Failed to save permissions');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    }
  }

  // =========================================================================
  // CREATE / EDIT ROLE MODAL
  // =========================================================================
  void _openRoleFormModal({Map<String, dynamic>? role, Map<String, dynamic>? parentRole}) {
    final isEdit = role != null;
    final nameController = TextEditingController(text: role?['display_name'] ?? role?['name'] ?? '');
    final codeController = TextEditingController(text: role?['code'] ?? '');
    final descController = TextEditingController(text: role?['description'] ?? '');
    String status = role?['status'] ?? 'Active';
    String roleType = role?['role_type'] ?? 'CUSTOM';
    bool inheritPermissions = role?['inherit_permissions'] ?? true;
    String? selectedParentId = role?['parent_role_id']?.toString() ?? parentRole?['id']?.toString();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isBuiltIn = isEdit && !(role['is_custom'] ?? true) && (role['level'] == 1);

            int calculatedLevel = 1;
            if (selectedParentId != null && selectedParentId!.isNotEmpty) {
              final parent = _roles.firstWhere(
                (r) => r['id'].toString() == selectedParentId,
                orElse: () => null,
              );
              if (parent != null) {
                calculatedLevel = (parent['level'] ?? 1) + 1;
              }
            }

            final eligibleParents = _roles.where((r) {
              if ((r['status'] ?? 'Active').toString().toLowerCase() != 'active') return false;
              if (isEdit && r['id'].toString() == role['id'].toString()) return false;
              return true;
            }).toList();

            return Dialog(
              backgroundColor: _dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_rounded : Icons.add_moderator_rounded,
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Edit Role: ${role['display_name'] ?? role['name']}' : 'Create New Role',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              Text(
                                isEdit ? 'Update hierarchy position and role metadata' : 'Define new role hierarchy node and permissions',
                                style: TextStyle(color: _textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: _textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: _borderColor),

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Role Name & Code
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Role Display Name *', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: nameController,
                                        enabled: !isBuiltIn,
                                        style: TextStyle(color: _textPrimary, fontSize: 12.5),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. Assistant Teacher',
                                          hintStyle: TextStyle(color: _textMuted, fontSize: 12),
                                          filled: true,
                                          fillColor: _scaffoldBg,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                                        ),
                                        onChanged: (val) {
                                          if (!isEdit && codeController.text.isEmpty) {
                                            codeController.text = 'ROLE_${val.trim().toUpperCase().replaceAll(' ', '_')}';
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Role Code (Unique Identifier) *', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: codeController,
                                        enabled: !isBuiltIn,
                                        style: TextStyle(color: _textPrimary, fontSize: 12.5, fontFamily: 'monospace'),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. ASST_TEACHER',
                                          hintStyle: TextStyle(color: _textMuted, fontSize: 12),
                                          filled: true,
                                          fillColor: _scaffoldBg,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Parent Role Selection
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Parent Role (Reports To)', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Derived Level: L$calculatedLevel',
                                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _scaffoldBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: selectedParentId,
                                      isExpanded: true,
                                      dropdownColor: _dialogBg,
                                      style: TextStyle(color: _textPrimary, fontSize: 12.5),
                                      hint: Text('None (Root Level 1 Role)', style: TextStyle(color: _textMuted, fontSize: 12)),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('None (Top Root Role - Level 1)', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                                        ),
                                        ...eligibleParents.map((p) {
                                          final pName = (p['display_name'] ?? p['name']).toString();
                                          final pLevel = p['level'] ?? 1;
                                          return DropdownMenuItem<String?>(
                                            value: p['id'].toString(),
                                            child: Text('$pName (Level $pLevel)'),
                                          );
                                        }),
                                      ],
                                      onChanged: isBuiltIn
                                          ? null
                                          : (val) {
                                              setModalState(() {
                                                selectedParentId = val;
                                              });
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Role Type & Status
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Role Type', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _scaffoldBg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: roleType,
                                            isExpanded: true,
                                            dropdownColor: _dialogBg,
                                            style: TextStyle(color: _textPrimary, fontSize: 12),
                                            items: const [
                                              DropdownMenuItem(value: 'CUSTOM', child: Text('Custom Role')),
                                              DropdownMenuItem(value: 'SYSTEM', child: Text('System Role')),
                                              DropdownMenuItem(value: 'DEFAULT', child: Text('Default Role')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() {
                                                  roleType = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Status', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _scaffoldBg,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _borderColor),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: status,
                                            isExpanded: true,
                                            dropdownColor: _dialogBg,
                                            style: TextStyle(color: _textPrimary, fontSize: 12),
                                            items: const [
                                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() {
                                                  status = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Inherit Permissions Toggle
                            SwitchListTile(
                              value: inheritPermissions,
                              title: Text('Inherit Parent Permissions', style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('Child role automatically gains all permissions granted to parent role', style: TextStyle(color: _textSecondary, fontSize: 10.5)),
                              activeTrackColor: const Color(0xFF6366F1),
                              activeThumbColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setModalState(() {
                                  inheritPermissions = val;
                                });
                              },
                            ),
                            const SizedBox(height: 10),

                            // Description
                            Text('Description', style: TextStyle(color: _textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 3,
                              style: TextStyle(color: _textPrimary, fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Enter role details and responsibilities...',
                                hintStyle: TextStyle(color: _textMuted, fontSize: 12),
                                filled: true,
                                fillColor: _scaffoldBg,
                                contentPadding: const EdgeInsets.all(12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(height: 24, color: _borderColor),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel', style: TextStyle(color: _textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final rawName = nameController.text.trim();
                            final code = codeController.text.trim().toUpperCase();
                            final desc = descController.text.trim();

                            if (rawName.isEmpty || code.isEmpty) {
                              _showErrorSnackBar('Role name and code are required');
                              return;
                            }

                            final body = {
                              'name': rawName.toLowerCase().replaceAll(' ', '_'),
                              'display_name': rawName,
                              'code': code,
                              'description': desc,
                              'status': status,
                              'role_type': roleType,
                              'is_custom': roleType != 'SYSTEM',
                              'parent_role_id': selectedParentId,
                              'level': calculatedLevel,
                              'inherit_permissions': inheritPermissions,
                            };

                            Navigator.of(context).pop();

                            try {
                              dynamic res;
                              if (isEdit) {
                                res = await ApiService().put('/admin/schools/roles/${role['id']}', body);
                              } else {
                                res = await ApiService().post('/admin/schools/roles', body);
                              }

                              if (res['success'] == true) {
                                _showSuccessSnackBar(isEdit ? 'Role updated successfully' : 'Role created successfully');
                                _fetchRoles();
                              } else {
                                _showErrorSnackBar(res['message'] ?? 'Operation failed');
                              }
                            } catch (e) {
                              _showErrorSnackBar('Error saving role: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEdit ? 'Save Changes' : 'Create Role', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // VIEW USERS ASSIGNED MODAL
  // =========================================================================
  void _showUsersAssignedModal(Map<String, dynamic> role) {
    final roleId = role['id'].toString();
    final roleName = (role['display_name'] ?? role['name']).toString();
    String userQuery = "";
    int userPage = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: _dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Container(
                width: 600,
                height: 520,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Users with Role: $roleName',
                                style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                              ),
                              Text('Active users and personnel assigned to this position', style: TextStyle(color: _textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: _textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: _borderColor),

                    // Search input
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _scaffoldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: TextField(
                        style: TextStyle(color: _textPrimary, fontSize: 12),
                        onChanged: (val) {
                          setModalState(() {
                            userQuery = val;
                            userPage = 1;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search assigned users by name, email or ID...',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Async Users List
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: ApiService().get(
                          '/admin/schools/roles/$roleId/users?q=$userQuery&page=$userPage&limit=10',
                          useCache: false,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                          }
                          if (snapshot.hasError || snapshot.data?['success'] != true) {
                            return Center(child: Text('Failed to load users: ${snapshot.error ?? snapshot.data?['message']}', style: TextStyle(color: _textSecondary)));
                          }

                          final users = (snapshot.data!['data'] as List<dynamic>?) ?? [];

                          if (users.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_search_rounded, size: 36, color: _textMuted),
                                  const SizedBox(height: 8),
                                  Text('No assigned users found for this role.', style: TextStyle(color: _textSecondary, fontSize: 12.5)),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, idx) {
                              final u = users[idx];
                              final uName = (u['full_name'] ?? 'User').toString();
                              final uEmail = (u['email'] ?? 'No email').toString();
                              final uStatus = (u['status'] ?? 'Active').toString();
                              final uId = (u['employee_id'] ?? u['admission_number'] ?? 'ID: —').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _scaffoldBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                      child: Text(
                                        uName.isNotEmpty ? uName[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(uName, style: TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                          Text(uEmail, style: TextStyle(color: _textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(uId, style: TextStyle(color: _textMuted, fontSize: 10.5, fontFamily: 'monospace')),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: (uStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            uStatus.toUpperCase(),
                                            style: TextStyle(
                                              color: uStatus == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ROLE AUDIT LOGS MODAL
  // =========================================================================
  void _showAuditLogsModal(Map<String, dynamic> role) {
    final roleId = role['id'].toString();
    final roleName = (role['display_name'] ?? role['name']).toString();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: _dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            width: 600,
            height: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.history_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Audit Trail: $roleName', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                          Text('Immutable log of changes, permission updates and assignment events', style: TextStyle(color: _textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: _textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Divider(height: 24, color: _borderColor),

                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ApiService().get('/admin/schools/roles/$roleId/audit-logs', useCache: false),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                      }
                      if (snapshot.hasError || snapshot.data?['success'] != true) {
                        return Center(child: Text('Failed to load audit logs: ${snapshot.error ?? snapshot.data?['message']}', style: TextStyle(color: _textSecondary)));
                      }

                      final logs = (snapshot.data!['data'] as List<dynamic>?) ?? [];
                      if (logs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 36, color: _textMuted),
                              const SizedBox(height: 8),
                              Text('No audit entries recorded for this role yet.', style: TextStyle(color: _textSecondary, fontSize: 12.5)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, idx) {
                          final l = logs[idx];
                          final action = (l['action'] ?? 'MODIFIED').toString();
                          final details = (l['details'] ?? 'Configuration updated').toString();
                          final createdStr = l['created_at'] != null
                              ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(l['created_at'].toString()))
                              : 'Recent';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _scaffoldBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(action, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(details, style: TextStyle(color: _textPrimary, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(createdStr, style: TextStyle(color: _textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // HOW ROLE HIERARCHY WORKS MODAL
  // =========================================================================
  void _showHowHierarchyWorksDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: _dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'How Role Hierarchy Works in EduSHAMIIT ERP',
                        style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: _textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Divider(height: 24, color: _borderColor),

                _buildHowItWorksItem(
                  '1. Tree Hierarchy & Depth Levels',
                  'Roles exist in a directed tree structure. Level 1 represents root management (e.g. Super Admin), Level 2 covers institutional heads, Level 3 operational roles, and Level 4 specialized functions.',
                ),
                const SizedBox(height: 12),
                _buildHowItWorksItem(
                  '2. Automatic Permission Inheritance',
                  'Child roles automatically inherit all functional permissions granted to their ancestor roles. Direct grants supplement inherited privileges.',
                ),
                const SizedBox(height: 12),
                _buildHowItWorksItem(
                  '3. Graph Integrity & Cycle Prevention',
                  'The hierarchy engine prevents circular references (e.g. A -> B -> A) and self-parenting to guarantee reliable authorization trees.',
                ),
                const SizedBox(height: 12),
                _buildHowItWorksItem(
                  '4. Cascading Level Recalculation',
                  'When a parent role is moved or re-anchored, all subordinate children and grandchildren have their hierarchy depth levels automatically updated.',
                ),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Got It'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHowItWorksItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(desc, style: TextStyle(color: _textSecondary, fontSize: 11.5, height: 1.4)),
      ],
    );
  }

  // =========================================================================
  // ROW ACTIONS HANDLER
  // =========================================================================
  void _handleRoleRowAction(String action, Map<String, dynamic> role) {
    final id = role['id'].toString();
    final name = (role['display_name'] ?? role['name']).toString();
    final status = (role['status'] ?? 'Active').toString();

    if (action == 'view_users') {
      _showUsersAssignedModal(role);
    } else if (action == 'manage_perms') {
      setState(() {
        _selectedRole = role;
        _loadRolePermissions();
        _activeTab = "Assign Permissions";
      });
    } else if (action == 'add_child') {
      _openRoleFormModal(parentRole: role);
    } else if (action == 'audit_logs') {
      _showAuditLogsModal(role);
    } else if (action == 'toggle_status') {
      final newStatus = status == 'Active' ? 'Inactive' : 'Active';
      ApiService().put('/admin/schools/roles/$id', {'status': newStatus}).then((res) {
        if (res['success'] == true) {
          _showSuccessSnackBar('Role "$name" status set to $newStatus');
          _fetchRoles();
        } else {
          _showErrorSnackBar(res['message'] ?? 'Failed to update status');
        }
      });
    } else if (action == 'delete') {
      final userCount = role['user_count'] ?? 0;
      final childCount = role['child_roles_count'] ?? 0;

      if (userCount > 0 || childCount > 0) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Deletion Restricted', style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            content: Text(
              'Cannot delete "$name" because it has $userCount active users and $childCount dependent child roles. Reassign users and children first.',
              style: TextStyle(color: _textSecondary, fontSize: 12.5),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Acknowledge')),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Delete Role?', style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to permanently delete custom role "$name"?', style: TextStyle(color: _textSecondary, fontSize: 12.5)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final res = await ApiService().delete('/admin/schools/roles/$id');
                  if (res['success'] == true) {
                    _showSuccessSnackBar('Role deleted successfully');
                    _fetchRoles();
                  } else {
                    _showErrorSnackBar(res['message'] ?? 'Failed to delete role');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  // =========================================================================
  // EXPORT ROLE HIERARCHY & MATRIX TO PDF
  // =========================================================================
  Future<void> _exportHierarchyPdf() async {
    try {
      _showSuccessSnackBar('Generating official Role Hierarchy PDF report...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/schools/roles/hierarchy/pdf');

      final res = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final blob = html.Blob([res.bodyBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = 'EduSHAMIIT_Role_Hierarchy_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackBar('Downloaded "$fileName" successfully!');
      } else {
        _showErrorSnackBar('Failed to generate PDF. Server returned ${res.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading PDF: $e');
    }
  }
}

// =========================================================================
// CUSTOM PAINTER FOR TREE CONNECTOR BRANCHES
// =========================================================================
class BranchJunctionPainter extends CustomPainter {
  final bool isFirst;
  final bool isLast;
  final Color color;

  BranchJunctionPainter({
    required this.isFirst,
    required this.isLast,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final midX = size.width / 2;
    const topY = 0.0;
    final bottomY = size.height;

    // Horizontal line connecting with adjacent sibling padding
    if (isFirst) {
      canvas.drawLine(Offset(midX, topY), Offset(size.width + 8.0, topY), paint);
    } else if (isLast) {
      canvas.drawLine(const Offset(-8.0, topY), Offset(midX, topY), paint);
    } else {
      canvas.drawLine(const Offset(-8.0, topY), Offset(size.width + 8.0, topY), paint);
    }

    // Vertical drop stem into child card
    canvas.drawLine(Offset(midX, topY), Offset(midX, bottomY), paint);
  }

  @override
  bool shouldRepaint(covariant BranchJunctionPainter oldDelegate) {
    return oldDelegate.isFirst != isFirst || oldDelegate.isLast != isLast || oldDelegate.color != color;
  }
}
