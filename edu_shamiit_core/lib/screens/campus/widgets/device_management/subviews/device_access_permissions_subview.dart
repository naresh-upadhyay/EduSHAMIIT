import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Complete Enterprise-Grade Access & Permissions Subview matching the canonical design.
///
/// Features:
/// - 6 Top KPI Summary Cards (Total Users 238, Roles 12, Permission Policies 6, User Groups 18, Pending Requests 4, Access Health Compliant)
/// - 9 Functional Sub-Tabs (Overview, Roles, Users & Access, User Groups, Permissions, Access Policies, Delegation, Access Requests, Audit Logs)
/// - Row 1: Access Overview Donut Chart, Permission Coverage Progress Bars, 6 Quick Action Buttons
/// - Row 2: Roles (12) Data Table, User Access (Recent) Data Table with filters, Selected Role Inspector Panel (Facility Manager) with 5 Accordions
/// - Interactive Modals: Create Role, Assign User Access, Create Group, Define Policy, Access Request, Delegation Grant
class DeviceAccessPermissionsSubview extends StatefulWidget {
  final String? initialRole;
  final VoidCallback? onBackToDashboard;
  final String? apiBaseUrl;

  const DeviceAccessPermissionsSubview({
    super.key,
    this.initialRole,
    this.onBackToDashboard,
    this.apiBaseUrl,
  });

  @override
  State<DeviceAccessPermissionsSubview> createState() =>
      _DeviceAccessPermissionsSubviewState();
}

class _DeviceAccessPermissionsSubviewState
    extends State<DeviceAccessPermissionsSubview> {
  // Navigation & Sub-Tabs
  int _selectedSubTab = 0;
  final List<String> _subTabs = [
    'Overview',
    'Roles',
    'Users & Access',
    'User Groups',
    'Permissions',
    'Access Policies',
    'Delegation',
    'Access Requests',
    'Audit Logs',
  ];

  // State
  bool _isLoading = false;
  AccessPermissionsKpis _kpis = AccessPermissionsKpis();
  List<RoleDistributionItem> _roleDistribution = [];
  List<PermissionCoverageItem> _permissionCoverage = [];
  List<EnterpriseRoleItem> _roles = [];
  List<EnterpriseUserAccessItem> _recentUsers = [];
  final List<EnterpriseUserGroupItem> _groups = [];
  List<AccessPolicyItem> _policies = [];
  List<AccessDelegationItem> _delegations = [];
  List<AccessRequestItem> _accessRequests = [];
  List<SecurityAuditLogItem> _auditLogs = [];

  // Canonical dropdown options from backend
  List<Map<String, dynamic>> _dropdownRoles = [];
  List<Map<String, dynamic>> _dropdownUsers = [];
  List<Map<String, dynamic>> _dropdownLocations = [];

  // Multi-selection state
  Set<String> _selectedRoleIds = {};
  Set<String> _selectedUserIds = {};

  // Selected Role for Right Inspector Panel
  EnterpriseRoleItem? _selectedRole;

  // Roles Table sorting & pagination
  String _roleSortColumn = 'priority';
  bool _roleSortAsc = false;
  int _rolesCurrentPage = 1;
  int _rolesPageSize = 10;

  // Filters for User Access Table
  String _selectedRoleFilter = 'All Roles';
  String _selectedStatusFilter = 'All Status';
  String _userSearchQuery = '';
  String _userSortColumn = 'user_name';
  bool _userSortAsc = true;
  int _userCurrentPage = 1;
  int _userTotalCount = 238;
  int _userPageSize = 10;

  // Accordion Expand/Collapse States (Inspector Panel)
  bool _accPermissionMatrixExpanded = false;
  bool _accPoliciesExpanded = false;
  bool _accDelegationExpanded = false;
  bool _accRequestsExpanded = false;
  bool _accAuditLogsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialFallbackData();
    _fetchDashboardData();
  }

  void _loadInitialFallbackData() {
    _kpis = AccessPermissionsKpis();

    _roleDistribution = [
      RoleDistributionItem(name: 'Administrator', count: 12, percentage: 5.0, colorHex: '#1677F2'),
      RoleDistributionItem(name: 'Facility Manager', count: 36, percentage: 15.1, colorHex: '#10B981'),
      RoleDistributionItem(name: 'Teacher', count: 88, percentage: 37.0, colorHex: '#8B5CF6'),
      RoleDistributionItem(name: 'Staff', count: 72, percentage: 30.3, colorHex: '#06B6D4'),
      RoleDistributionItem(name: 'Others', count: 30, percentage: 12.6, colorHex: '#F59E0B'),
    ];

    _permissionCoverage = [
      PermissionCoverageItem(domain: 'Device Control', percentage: 92),
      PermissionCoverageItem(domain: 'Configuration & Setup', percentage: 85),
      PermissionCoverageItem(domain: 'Scheduling & Automation', percentage: 80),
      PermissionCoverageItem(domain: 'Reports & Analytics', percentage: 76),
      PermissionCoverageItem(domain: 'System & Integration', percentage: 68),
    ];

    _dropdownRoles = [
      {'id': 'c1000000-0000-0000-0000-000000000001', 'name': 'super_admin', 'display_name': 'Super Admin', 'code': 'SUPER_ADMIN'},
      {'id': 'c1000000-0000-0000-0000-000000000002', 'name': 'device_administrator', 'display_name': 'Device Administrator', 'code': 'DEVICE_ADMIN'},
      {'id': 'c1000000-0000-0000-0000-000000000003', 'name': 'facility_manager', 'display_name': 'Facility Manager', 'code': 'FACILITY_MANAGER'},
      {'id': 'c1000000-0000-0000-0000-000000000004', 'name': 'maintenance_staff', 'display_name': 'Maintenance Staff', 'code': 'MAINTENANCE_STAFF'},
      {'id': 'c1000000-0000-0000-0000-000000000005', 'name': 'teacher', 'display_name': 'Teacher', 'code': 'TEACHER'},
      {'id': 'c1000000-0000-0000-0000-000000000006', 'name': 'view_only', 'display_name': 'View Only', 'code': 'VIEW_ONLY'},
      {'id': 'c1000000-0000-0000-0000-000000000007', 'name': 'it_iot_admin', 'display_name': 'IT/IoT Administrator', 'code': 'IT_IOT_ADMIN'},
      {'id': 'c1000000-0000-0000-0000-000000000008', 'name': 'security', 'display_name': 'Security Head', 'code': 'SECURITY'},
      {'id': 'c1000000-0000-0000-0000-000000000009', 'name': 'campus_administrator', 'display_name': 'Campus Administrator', 'code': 'CAMPUS_ADMIN'},
    ];

    _dropdownUsers = [
      {'id': 'u1', 'full_name': 'King Doe', 'email': 'admin@edushamiit.com', 'role': 'Super Admin', 'department': 'Administration'},
      {'id': 'u2', 'full_name': 'Amit Sharma', 'email': 'amit.sharma@edushamiit.edu', 'role': 'Device Administrator', 'department': 'IT Team'},
      {'id': 'u3', 'full_name': 'Priya Verma', 'email': 'priya.verma@edushamiit.edu', 'role': 'Facility Manager', 'department': 'Facility Team'},
      {'id': 'u4', 'full_name': 'Rohan Mehta', 'email': 'rohan.mehta@edushamiit.edu', 'role': 'Teacher', 'department': 'Science Department'},
      {'id': 'u5', 'full_name': 'Aarav Sharma', 'email': 'aarav.sharma@edushamiit.com', 'role': 'Student', 'department': 'Grade 10'},
      {'id': 'u6', 'full_name': 'Amit Chauhan', 'email': 'amit.chauhan@school.edu', 'role': 'Hostel Warden', 'department': 'Hostel Operations'},
      {'id': 'u7', 'full_name': 'Teacher One School A', 'email': 'teacher1@school-a.edu', 'role': 'Teacher', 'department': 'Mathematics'},
      {'id': 'u8', 'full_name': 'Dr. Universal Tester', 'email': 'universal.tester@edushamiit.edu', 'role': 'Teacher', 'department': 'R&D'},
    ];

    _dropdownLocations = [
      {'name': 'All Locations'},
      {'name': 'Academic Block (A)'},
      {'name': 'Academic Block (B)'},
      {'name': 'Admin Block'},
      {'name': 'Library Block'},
      {'name': 'Laboratories Block'},
      {'name': 'Auditorium Block'},
      {'name': 'Sports Complex'},
      {'name': 'Hostel Block A'},
    ];

    _roles = [
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000001',
        roleName: 'Super Admin',
        roleCode: 'SUPER_ADMIN',
        description: 'Full access to all device modules and settings',
        usersCount: 4,
        keyPermissions: 'All permissions',
        status: 'Active',
        priority: 100,
        locationScope: 'Entire Institution',
        deviceTypesScope: 'All Devices',
        timePolicy: '24x7 Unrestricted',
      ),
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000002',
        roleName: 'Device Administrator',
        roleCode: 'DEVICE_ADMIN',
        description: 'Manage devices, groups, locations and integrations',
        usersCount: 8,
        keyPermissions: 'Device, Config, Integration',
        status: 'Active',
        priority: 90,
        locationScope: 'All Campus Locations',
        deviceTypesScope: 'All Device Profiles',
        timePolicy: '24x7 Operations',
      ),
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000003',
        roleName: 'Facility Manager',
        roleCode: 'FACILITY_MANAGER',
        description:
            'Operate and monitor devices for assigned locations (e.g., blocks, floors, rooms) and manage daily operations such as live control, scenes, schedules and basic automation.',
        usersCount: 36,
        keyPermissions: 'Live Control, Schedules, Scenes',
        status: 'Active',
        priority: 80,
        locationScope: 'Assigned Locations (e.g., Academic Block A)',
        deviceTypesScope: 'All (within assigned locations)',
        timePolicy: 'Allowed (24 x 7)',
        accessChannel: 'Web & Mobile',
      ),
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000004',
        roleName: 'Maintenance Staff',
        roleCode: 'MAINTENANCE_STAFF',
        description: 'Diagnostics and maintenance operations',
        usersCount: 18,
        keyPermissions: 'Health, Diagnostics, Firmware',
        status: 'Active',
        priority: 70,
        locationScope: 'Assigned Blocks & Utility Areas',
        deviceTypesScope: 'HVAC, Power, Gateways',
        timePolicy: 'Working Hours (07:00 - 19:00)',
      ),
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000005',
        roleName: 'Teacher',
        roleCode: 'TEACHER',
        description: 'Basic control for classroom devices',
        usersCount: 88,
        keyPermissions: 'Live Control (Limited), Scenes',
        status: 'Active',
        priority: 50,
        locationScope: 'Assigned Classrooms & Labs',
        deviceTypesScope: 'Lighting, AC, Projectors, Audio',
        timePolicy: 'Teaching Hours Only (07:30 - 17:30)',
      ),
      EnterpriseRoleItem(
        id: 'c1000000-0000-0000-0000-000000000006',
        roleName: 'View Only',
        roleCode: 'VIEW_ONLY',
        description: 'Read-only access to monitoring and reports',
        usersCount: 42,
        keyPermissions: 'View, Reports',
        status: 'Active',
        priority: 30,
        locationScope: 'All Locations (Read Only)',
        deviceTypesScope: 'All Devices (Telemetry Only)',
        timePolicy: 'Allowed (24 x 7)',
      ),
    ];

    _selectedRole = _roles.firstWhere(
      (r) => r.roleName == 'Facility Manager',
      orElse: () => _roles[2],
    );

    _recentUsers = [
      EnterpriseUserAccessItem(
        id: 'e1000000-0000-0000-0000-000000000001',
        userName: 'Amit Sharma',
        email: 'amit.sharma@edushamiit.edu',
        roleName: 'Device Administrator',
        groupName: 'IT Team',
        locationScope: 'All Locations',
        status: 'Active',
        lastLogin: '10 Jan 2025, 02:18 PM',
      ),
      EnterpriseUserAccessItem(
        id: 'e1000000-0000-0000-0000-000000000002',
        userName: 'Priya Verma',
        email: 'priya.verma@edushamiit.edu',
        roleName: 'Facility Manager',
        groupName: 'Facility Team',
        locationScope: 'Academic Block (A)',
        status: 'Active',
        lastLogin: '10 Jan 2025, 01:56 PM',
      ),
      EnterpriseUserAccessItem(
        id: 'e1000000-0000-0000-0000-000000000003',
        userName: 'Rohan Mehta',
        email: 'rohan.mehta@edushamiit.edu',
        roleName: 'Teacher',
        groupName: 'Teachers',
        locationScope: 'A-101, A-102, A-103',
        status: 'Active',
        lastLogin: '10 Jan 2025, 01:40 PM',
      ),
      EnterpriseUserAccessItem(
        id: 'e1000000-0000-0000-0000-000000000004',
        userName: 'Neha Kapoor',
        email: 'neha.kapoor@edushamiit.edu',
        roleName: 'Maintenance Staff',
        groupName: 'Maintenance',
        locationScope: 'Entire Campus',
        status: 'Active',
        lastLogin: '10 Jan 2025, 12:10 PM',
      ),
      EnterpriseUserAccessItem(
        id: 'e1000000-0000-0000-0000-000000000005',
        userName: 'Vikas Singh',
        email: 'vikas.singh@edushamiit.edu',
        roleName: 'View Only',
        groupName: 'Management',
        locationScope: 'All Locations',
        status: 'Active',
        lastLogin: '10 Jan 2025, 11:32 AM',
      ),
    ];

    _policies = [
      AccessPolicyItem(
        id: 'p1',
        policyName: 'Working Hours Access',
        policyCode: 'POL_WORKING_HOURS',
        description: 'Restricts teacher device operation to instructional hours (07:30 - 17:30)',
        category: 'Time-Based',
        targetScope: 'Teaching Staff',
        priority: 10,
        isActive: true,
      ),
      AccessPolicyItem(
        id: 'p2',
        policyName: 'Location-Based Access',
        policyCode: 'POL_LOCATION_BOUND',
        description: 'Limits facility staff and teachers strictly to assigned rooms/blocks',
        category: 'Location-Based',
        targetScope: 'All Operational Roles',
        priority: 20,
        isActive: true,
      ),
      AccessPolicyItem(
        id: 'p3',
        policyName: 'Restricted Device Access',
        policyCode: 'POL_RESTRICTED_DEV',
        description: 'Enforces high-privilege access for main power distribution and server racks',
        category: 'Critical Device',
        targetScope: 'Engineering & Utility',
        priority: 30,
        isActive: true,
        approvalRequired: true,
      ),
      AccessPolicyItem(
        id: 'p4',
        policyName: 'Bulk Operation Approval',
        policyCode: 'POL_BULK_APPROVAL',
        description: 'Mandates multi-level approval for any mass operation affecting > 50 devices',
        category: 'Approval Workflow',
        targetScope: 'Campus Wide',
        priority: 40,
        isActive: true,
        approvalRequired: true,
      ),
      AccessPolicyItem(
        id: 'p5',
        policyName: 'Firmware Update Authorization',
        policyCode: 'POL_OTA_FIRMWARE',
        description: 'Restricts OTA firmware uploads exclusively to Device & IT Administrators',
        category: 'Device Security',
        targetScope: 'Fleet Gateways & Meters',
        priority: 50,
        isActive: true,
      ),
      AccessPolicyItem(
        id: 'p6',
        policyName: 'Gateway Restart Protection',
        policyCode: 'POL_GW_RESTART',
        description: 'Requires confirmation challenge and audit logging before physical gateway reboots',
        category: 'Gateway Operations',
        targetScope: 'Campus Gateways',
        priority: 60,
        isActive: true,
      ),
    ];

    _accessRequests = [
      AccessRequestItem(
        id: 'req1',
        requestCode: 'REQ-2025-081',
        requesterName: 'Dr. Ramesh Nair',
        requestedRole: 'Facility Manager',
        requestedScope: 'Laboratories Block (Floors 1-3)',
        duration: '7 Days',
        justification: 'Conducting annual physics laboratory electrical safety audit',
        priority: 'High',
        status: 'Pending',
      ),
      AccessRequestItem(
        id: 'req2',
        requestCode: 'REQ-2025-082',
        requesterName: 'Sneha Patil',
        requestedRole: 'IoT Operator',
        requestedScope: 'Auditorium Block',
        duration: '24 Hours',
        justification: 'Configuring stage projection and mood lighting for Annual Cultural Festival',
        priority: 'Medium',
        status: 'Pending',
      ),
      AccessRequestItem(
        id: 'req3',
        requestCode: 'REQ-2025-083',
        requesterName: 'Farhan Akhtar',
        requestedRole: 'Maintenance Staff',
        requestedScope: 'Hostel Block A (HVAC)',
        duration: '3 Days',
        justification: 'Servicing rooftop chiller unit and room thermostats',
        priority: 'Urgent',
        status: 'Pending',
      ),
      AccessRequestItem(
        id: 'req4',
        requestCode: 'REQ-2025-084',
        requesterName: 'Kavita Menon',
        requestedRole: 'Teacher',
        requestedScope: 'Smart Class A1-107',
        duration: '1 Semester',
        justification: 'Assigned additional robotics elective class needing display and power control',
        priority: 'Low',
        status: 'Pending',
      ),
    ];

    _delegations = [
      AccessDelegationItem(
        id: 'del1',
        delegateeName: 'Deepak Joshi',
        delegateeEmail: 'deepak.j@voltas.com',
        delegatorName: 'Amit Sharma',
        assignedRole: 'Maintenance Staff',
        locationScope: 'Academic Block A & B',
        reason: 'Quarterly HVAC Comprehensive Preventive Maintenance',
        startTime: '09 Jan 2025, 09:00 AM',
        endTime: '12 Jan 2025, 06:00 PM',
        status: 'Active',
      ),
      AccessDelegationItem(
        id: 'del2',
        delegateeName: 'Alok Chandra',
        delegateeEmail: 'alok.c@edushamiit.edu',
        delegatorName: 'Priya Verma',
        assignedRole: 'Facility Manager',
        locationScope: 'Main Block Ground Floor',
        reason: 'Acting Facility Head during medical leave',
        startTime: '08 Jan 2025, 08:00 AM',
        endTime: '15 Jan 2025, 08:00 PM',
        status: 'Active',
      ),
    ];

    _auditLogs = [
      SecurityAuditLogItem(
        id: 'l1',
        actorName: 'Amit Sharma',
        roleName: 'Device Administrator',
        action: 'Role Modified',
        resource: 'Roles',
        target: 'Facility Manager (Permissions Updated)',
        status: 'Success',
        ipAddress: '192.168.10.21',
        correlationId: 'CORR-SEC-9101',
        timestamp: '10 Jan 2025, 02:15 PM',
      ),
      SecurityAuditLogItem(
        id: 'l2',
        actorName: 'Priya Verma',
        roleName: 'Facility Manager',
        action: 'Live Control Executed',
        resource: 'Device A1-103',
        target: 'AC Unit Turned ON (24°C Cool)',
        status: 'Success',
        ipAddress: '192.168.10.45',
        correlationId: 'CORR-SEC-9102',
        timestamp: '10 Jan 2025, 01:58 PM',
      ),
      SecurityAuditLogItem(
        id: 'l3',
        actorName: 'Dr. Arvind Swaminathan',
        roleName: 'Super Admin',
        action: 'Policy Enforced',
        resource: 'Policies',
        target: 'Working Hours Policy Re-calibrated',
        status: 'Success',
        ipAddress: '192.168.1.1',
        correlationId: 'CORR-SEC-9103',
        timestamp: '10 Jan 2025, 01:30 PM',
      ),
      SecurityAuditLogItem(
        id: 'l4',
        actorName: 'Unauthorized Agent',
        roleName: 'Unknown',
        action: 'Command Rejected',
        resource: 'Main Gate Lock',
        target: 'Door Unlock without Elevate-MFA Blocked',
        status: 'Denied',
        ipAddress: '192.168.100.89',
        correlationId: 'CORR-SEC-9104',
        timestamp: '10 Jan 2025, 12:45 PM',
      ),
    ];
  }

  // --- API CALLS ---
  String get _apiBase => widget.apiBaseUrl != null && widget.apiBaseUrl!.isNotEmpty
      ? '${widget.apiBaseUrl}/v1/devices/access-permissions'
      : '${AppConfig.apiBaseUrl}/v1/devices/access-permissions';

  Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
  }

  Future<void> _fetchDashboardData() async {
    if (widget.apiBaseUrl != null && widget.apiBaseUrl!.contains('mock')) {
      _loadInitialFallbackData();
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    final headers = await _getHeaders();
    try {
      final res = await http
          .get(Uri.parse('$_apiBase/dashboard'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          if (data['kpis'] != null) {
            _kpis = AccessPermissionsKpis.fromJson(data['kpis']);
          }
          if (data['role_distribution'] != null) {
            _roleDistribution = (data['role_distribution'] as List)
                .map((e) => RoleDistributionItem.fromJson(e))
                .toList();
          }
          if (data['permission_coverage'] != null) {
            _permissionCoverage = (data['permission_coverage'] as List)
                .map((e) => PermissionCoverageItem.fromJson(e))
                .toList();
          }
        }
      }
    } catch (_) {
      // Fallback kept
    }

    try {
      final rolesRes = await http
          .get(Uri.parse('$_apiBase/roles'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (rolesRes.statusCode == 200) {
        final data = jsonDecode(rolesRes.body);
        if (data['success'] == true && data['roles'] != null) {
          _roles = (data['roles'] as List)
              .map((e) => EnterpriseRoleItem.fromJson(e))
              .toList();
          if (_roles.isNotEmpty && _selectedRole == null) {
            _selectedRole = _roles.firstWhere(
              (r) => r.roleName == 'Facility Manager',
              orElse: () => _roles.first,
            );
          }
        }
      }
    } catch (_) {}

    try {
      final usersRes = await http
          .get(Uri.parse(
              '$_apiBase/users?page=$_userCurrentPage&page_size=$_userPageSize'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (usersRes.statusCode == 200) {
        final data = jsonDecode(usersRes.body);
        if (data['success'] == true && data['users'] != null) {
          _recentUsers = (data['users'] as List)
              .map((e) => EnterpriseUserAccessItem.fromJson(e))
              .toList();
          _userTotalCount = data['total'] ?? data['total_count'] ?? 238;
        }
      }
    } catch (_) {}

    try {
      final dropRes = await http
          .get(Uri.parse('$_apiBase/dropdown-options'), headers: headers)
          .timeout(const Duration(seconds: 4));
      if (dropRes.statusCode == 200) {
        final data = jsonDecode(dropRes.body);
        if (data['success'] == true) {
          if (data['roles'] != null) {
            _dropdownRoles = List<Map<String, dynamic>>.from(data['roles']);
          }
          if (data['users'] != null) {
            _dropdownUsers = List<Map<String, dynamic>>.from(data['users']);
          }
          if (data['locations'] != null) {
            _dropdownLocations = List<Map<String, dynamic>>.from(data['locations']);
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _filterUsersFromBackend() async {
    if (widget.apiBaseUrl != null && widget.apiBaseUrl!.contains('mock')) return;
    final headers = await _getHeaders();
    try {
      final queryParams = <String, String>{
        'page': '$_userCurrentPage',
        'page_size': '$_userPageSize',
        'sort_by': _userSortColumn,
        'sort_asc': '$_userSortAsc',
      };
      if (_selectedRoleFilter != 'All Roles') {
        queryParams['role'] = _selectedRoleFilter;
      }
      if (_selectedStatusFilter != 'All Status') {
        queryParams['status'] = _selectedStatusFilter;
      }
      if (_userSearchQuery.trim().isNotEmpty) {
        queryParams['search'] = _userSearchQuery.trim();
      }

      final uri = Uri.parse('$_apiBase/users').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['users'] != null) {
          setState(() {
            _recentUsers = (data['users'] as List)
                .map((e) => EnterpriseUserAccessItem.fromJson(e))
                .toList();
            _userTotalCount = data['total'] ?? data['total_count'] ?? _recentUsers.length;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _executeBulkUserAction(String action) async {
    if (_selectedUserIds.isEmpty) return;
    final headers = await _getHeaders();
    final count = _selectedUserIds.length;
    try {
      if (widget.apiBaseUrl != null && !widget.apiBaseUrl!.contains('mock')) {
        await http.post(
          Uri.parse('$_apiBase/users/bulk-action'),
          headers: headers,
          body: jsonEncode({
            'action': action,
            'user_ids': _selectedUserIds.toList(),
          }),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    setState(() {
      for (final uid in _selectedUserIds) {
        final idx = _recentUsers.indexWhere((u) => u.id == uid);
        if (idx >= 0) {
          if (action == 'activate') {
            _recentUsers[idx] = _recentUsers[idx].copyWith(status: 'Active');
          } else if (action == 'deactivate') {
            _recentUsers[idx] = _recentUsers[idx].copyWith(status: 'Suspended');
          } else if (action == 'revoke') {
            _recentUsers.removeAt(idx);
          }
        }
      }
      _selectedUserIds.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulk $action completed for $count user${count > 1 ? "s" : ""}!'),
        backgroundColor: action == 'revoke' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _revokeSingleUser(EnterpriseUserAccessItem user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Revoke User Access'),
          ],
        ),
        content: Text('Are you sure you want to revoke campus device access for "${user.userName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (widget.apiBaseUrl != null && !widget.apiBaseUrl!.contains('mock')) {
      try {
        final headers = await _getHeaders();
        await http.delete(Uri.parse('$_apiBase/users/${user.id}'), headers: headers).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    setState(() {
      _recentUsers.removeWhere((u) => u.id == user.id);
      _selectedUserIds.remove(user.id);
      if (_userTotalCount > 0) _userTotalCount--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access revoked for "${user.userName}"'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  // --- ACTIONS & MODALS ---
  void _openCreateRoleWizard([EnterpriseRoleItem? roleToEdit]) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateRoleDialog(
        roleToEdit: roleToEdit,
        onRoleSaved: (newRole) {
          setState(() {
            final idx = _roles.indexWhere((r) => r.id == newRole.id);
            if (idx >= 0) {
              _roles[idx] = newRole;
            } else {
              _roles.insert(0, newRole);
            }
            _selectedRole = newRole;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Role "${newRole.roleName}" saved successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _duplicateRole(EnterpriseRoleItem role) {
    final cloned = role.copyWith(
      roleName: '${role.roleName} (Copy)',
      usersCount: 0,
    );
    setState(() {
      _roles.insert(_roles.indexOf(role) + 1, cloned);
      _selectedRole = cloned;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Role "${role.roleName}" duplicated successfully!'),
        backgroundColor: const Color(0xFF1677F2),
      ),
    );
  }

  void _openAssignUserAccessModal([EnterpriseUserAccessItem? user]) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignUserAccessDialog(
        user: user,
        roles: _roles,
        dropdownUsers: _dropdownUsers,
        dropdownRoles: _dropdownRoles,
        dropdownLocations: _dropdownLocations,
        apiBaseUrl: widget.apiBaseUrl,
        onUserAssigned: (updatedUser) {
          setState(() {
            final idx = _recentUsers.indexWhere((u) => u.id == updatedUser.id);
            if (idx >= 0) {
              _recentUsers[idx] = updatedUser;
            } else {
              _recentUsers.insert(0, updatedUser);
              _userTotalCount++;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Access assigned for "${updatedUser.userName}"!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _openCreateGroupModal() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateGroupDialog(
        onGroupCreated: (grp) {
          setState(() => _groups.insert(0, grp));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User Group "${grp.groupName}" created!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _openDefinePolicyModal() {
    showDialog(
      context: context,
      builder: (ctx) => _DefinePolicyDialog(
        onPolicyCreated: (pol) {
          setState(() => _policies.insert(0, pol));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Access Policy "${pol.policyName}" registered!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _openAccessRequestModal() {
    showDialog(
      context: context,
      builder: (ctx) => _AccessRequestDialog(
        roles: _roles,
        onRequestSubmitted: (req) {
          setState(() => _accessRequests.insert(0, req));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Access Request "${req.requestCode}" submitted!'),
              backgroundColor: const Color(0xFF1677F2),
            ),
          );
        },
      ),
    );
  }

  void _openCreateDelegationModal() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateDelegationDialog(
        roles: _roles,
        onDelegationCreated: (del) {
          setState(() => _delegations.insert(0, del));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Temporary access granted to "${del.delegateeName}"!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _approveRequest(AccessRequestItem req) {
    setState(() {
      final idx = _accessRequests.indexWhere((r) => r.id == req.id);
      if (idx >= 0) {
        _accessRequests[idx] = AccessRequestItem(
          id: req.id,
          requestCode: req.requestCode,
          requesterName: req.requesterName,
          requestedRole: req.requestedRole,
          requestedScope: req.requestedScope,
          duration: req.duration,
          justification: req.justification,
          priority: req.priority,
          status: 'Approved',
          approverName: 'Admin Swaminathan',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access Request ${req.requestCode} has been Approved!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _rejectRequest(AccessRequestItem req) {
    setState(() {
      final idx = _accessRequests.indexWhere((r) => r.id == req.id);
      if (idx >= 0) {
        _accessRequests[idx] = AccessRequestItem(
          id: req.id,
          requestCode: req.requestCode,
          requesterName: req.requesterName,
          requestedRole: req.requestedRole,
          requestedScope: req.requestedScope,
          duration: req.duration,
          justification: req.justification,
          priority: req.priority,
          status: 'Rejected',
          approverName: 'Admin Swaminathan',
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Access Request ${req.requestCode} has been Rejected.'),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Banner
          _buildHeaderBanner(isDark, screenWidth),
          const SizedBox(height: 14),

          // 2. Top 6 KPI Summary Cards
          _buildTopKpiCards(isDark, screenWidth),
          const SizedBox(height: 16),

          // 3. Sub-Tabs Bar (9 Sub-Tabs)
          _buildSubTabsBar(isDark),
          const SizedBox(height: 16),

          // 4. View switched dynamically by sub-tab index
          _buildActiveSubTabView(isDark, screenWidth),
        ],
      ),
    );
  }

  // ============================================================================
  // 1. HEADER BANNER
  // ============================================================================
  Widget _buildHeaderBanner(bool isDark, double width) {
    final isCompact = width < 900;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildHeaderShieldIcon(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Access & Permissions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Define who can access what, and what actions they can perform on campus devices, groups, locations and features.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRefreshButton(isDark),
                    _buildAddActionSplitButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _buildHeaderShieldIcon(),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access & Permissions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Define who can access what, and what actions they can perform on campus devices, groups, locations and features.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildRefreshButton(isDark),
                const SizedBox(width: 10),
                _buildAddActionSplitButton(),
              ],
            ),
    );
  }

  Widget _buildHeaderShieldIcon() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF1677F2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1677F2).withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Icon(Icons.verified_user_rounded, color: Color(0xFF1677F2), size: 24),
      ),
    );
  }

  Widget _buildRefreshButton(bool isDark) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _isLoading ? null : _fetchDashboardData,
      icon: _isLoading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAddActionSplitButton() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'role') {
          _openCreateRoleWizard();
        } else if (val == 'user') {
          _openAssignUserAccessModal();
        } else if (val == 'group') {
          _openCreateGroupModal();
        } else if (val == 'policy') {
          _openDefinePolicyModal();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'role',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF1677F2)),
              SizedBox(width: 10),
              Text('Create Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'user',
          child: Row(
            children: [
              Icon(Icons.person_add_outlined, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Add User Access', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'group',
          child: Row(
            children: [
              Icon(Icons.group_add_outlined, size: 18, color: Color(0xFF8B5CF6)),
              SizedBox(width: 10),
              Text('Create Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'policy',
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Define Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1677F2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1677F2).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Add User / Role',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 2. TOP 6 KPI SUMMARY CARDS
  // ============================================================================
  Widget _buildTopKpiCards(bool isDark, double width) {
    final cards = [
      _buildKpiCard('Total Users', '${_kpis.totalUsers}', '', Icons.people_outline_rounded, const Color(0xFF1677F2), isDark),
      _buildKpiCard('Roles', '${_kpis.totalRoles}', '', Icons.badge_outlined, const Color(0xFF1677F2), isDark),
      _buildKpiCard('Permission Policies', '${_kpis.permissionPolicies}', '', Icons.shield_outlined, const Color(0xFFEF4444), isDark),
      _buildKpiCard('User Groups', '${_kpis.userGroups}', '', Icons.groups_outlined, const Color(0xFF1677F2), isDark),
      _buildKpiCard('Pending Requests', '${_kpis.pendingRequests}', '', Icons.pending_actions_rounded, const Color(0xFFF59E0B), isDark),
      _buildKpiCard('Access Health', _kpis.accessHealth, '', Icons.check_circle_outline_rounded, const Color(0xFF10B981), isDark),
    ];

    if (width < 750) {
      final cardWidth = (width - 40) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    } else if (width < 1200) {
      final cardWidth = (width - 56) / 3;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard(String title, String mainValue, String subValue, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      mainValue,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    ),
                    if (subValue.isNotEmpty)
                      Text(
                        subValue,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
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

  // ============================================================================
  // 3. SUB-TABS BAR (9 SUB-TABS)
  // ============================================================================
  Widget _buildSubTabsBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_subTabs.length, (i) {
            final isSelected = _selectedSubTab == i;
            final title = _subTabs[i];
            return InkWell(
              key: ValueKey('subtab_$title'),
              onTap: () => setState(() => _selectedSubTab = i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1677F2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================================
  // 4. ACTIVE SUB-TAB ROUTER
  // ============================================================================
  Widget _buildActiveSubTabView(bool isDark, double width) {
    switch (_selectedSubTab) {
      case 1:
        return _buildRolesTabView(isDark, width);
      case 2:
        return _buildUsersTabView(isDark, width);
      case 3:
        return _buildGroupsTabView(isDark, width);
      case 4:
        return _buildPermissionsTabView(isDark, width);
      case 5:
        return _buildPoliciesTabView(isDark, width);
      case 6:
        return _buildDelegationTabView(isDark, width);
      case 7:
        return _buildRequestsTabView(isDark, width);
      case 8:
        return _buildAuditLogsTabView(isDark, width);
      case 0:
      default:
        return _buildOverviewTabView(isDark, width);
    }
  }

  // ============================================================================
  // TAB 0: OVERVIEW TAB VIEW
  // ============================================================================
  Widget _buildOverviewTabView(bool isDark, double width) {
    final isCompact = width < 1080;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: 3 Visual Analytics Cards
        _buildOverviewRow1(isDark, width),
        const SizedBox(height: 16),

        // Row 2: Dual Central Tables (Left) + Selected Role Inspector (Right)
        if (!isCompact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left 68%: Roles (12) Table + User Access (Recent) Table
              Expanded(
                flex: 68,
                child: Column(
                  children: [
                    _buildRolesTableCard(isDark),
                    const SizedBox(height: 16),
                    _buildUserAccessTableCard(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right 32%: Selected Role Inspector Panel (Facility Manager)
              Expanded(
                flex: 32,
                child: _buildRightInspectorPanel(isDark),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildRolesTableCard(isDark),
              const SizedBox(height: 16),
              _buildUserAccessTableCard(isDark),
              const SizedBox(height: 16),
              _buildRightInspectorPanel(isDark),
            ],
          ),
      ],
    );
  }

  // --- ROW 1: 3 OVERVIEW CARDS ---
  Widget _buildOverviewRow1(bool isDark, double width) {
    final isCompact = width < 1000;

    final card1 = _buildDonutAccessOverviewCard(isDark);
    final card2 = _buildPermissionCoverageCard(isDark);
    final card3 = _buildQuickActionsCard(isDark);

    if (isCompact) {
      return Column(
        children: [
          card1,
          const SizedBox(height: 12),
          card2,
          const SizedBox(height: 12),
          card3,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card1),
        const SizedBox(width: 14),
        Expanded(child: card2),
        const SizedBox(width: 14),
        Expanded(child: card3),
      ],
    );
  }

  // CARD 1: Access Overview (Donut Chart)
  Widget _buildDonutAccessOverviewCard(bool isDark) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF1677F2), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Access Overview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                // Custom Donut Painter
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(120, 120),
                            painter: _RoleDonutPainter(items: _roleDistribution),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_kpis.totalUsers}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                              ),
                              const Text('Users', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Legend
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _roleDistribution.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: _hexToColor(item.colorHex), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(item.name, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                            const Spacer(),
                            Text('${item.count} (${item.percentage}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CARD 2: Permission Coverage (Progress Bars)
  Widget _buildPermissionCoverageCard(bool isDark) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF1677F2), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Permission Coverage',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _permissionCoverage.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = _permissionCoverage[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            item.domain,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.percentage}%',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1677F2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.percentage / 100.0,
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1677F2)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // CARD 3: Quick Actions (3x2 Grid)
  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      {'title': 'Create Role', 'icon': Icons.person_add_alt_1_outlined, 'fn': () => _openCreateRoleWizard()},
      {'title': 'Add User Access', 'icon': Icons.person_add_outlined, 'fn': () => _openAssignUserAccessModal()},
      {'title': 'Create Group', 'icon': Icons.group_add_outlined, 'fn': () => _openCreateGroupModal()},
      {'title': 'Define Policy', 'icon': Icons.shield_outlined, 'fn': () => _openDefinePolicyModal()},
      {'title': 'Access Request', 'icon': Icons.assignment_outlined, 'fn': () => _openAccessRequestModal()},
      {'title': 'View Audit Logs', 'icon': Icons.fact_check_outlined, 'fn': () => setState(() => _selectedSubTab = 8)},
    ];

    return Container(
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF1677F2), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.25,
              physics: const NeverScrollableScrollPhysics(),
              children: actions.map((act) {
                return InkWell(
                  onTap: act['fn'] as VoidCallback,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(act['icon'] as IconData, color: const Color(0xFF1677F2), size: 20),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            act['title'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CENTRAL TABLE 1: ROLES CATALOG
  // ============================================================================
  Widget _buildRolesTableCard(bool isDark) {
    // Sort roles
    final sortedRoles = List<EnterpriseRoleItem>.from(_roles);
    sortedRoles.sort((a, b) {
      int cmp = 0;
      if (_roleSortColumn == 'role_name') {
        cmp = a.roleName.compareTo(b.roleName);
      } else if (_roleSortColumn == 'users_count') {
        cmp = a.usersCount.compareTo(b.usersCount);
      } else if (_roleSortColumn == 'status') {
        cmp = a.status.compareTo(b.status);
      } else {
        cmp = a.priority.compareTo(b.priority);
      }
      return _roleSortAsc ? cmp : -cmp;
    });

    final totalRoles = sortedRoles.length;
    final totalRolePages = (totalRoles / _rolesPageSize).ceil().clamp(1, 9999);
    final currentRolePage = _rolesCurrentPage.clamp(1, totalRolePages);
    final startRoleIdx = (currentRolePage - 1) * _rolesPageSize;
    final endRoleIdx = (startRoleIdx + _rolesPageSize).clamp(0, totalRoles);
    final pagedRoles = totalRoles > 0 ? sortedRoles.sublist(startRoleIdx, endRoleIdx) : <EnterpriseRoleItem>[];

    final isAllSelected = pagedRoles.isNotEmpty && pagedRoles.every((r) => _selectedRoleIds.contains(r.id));
    final isSomeSelected = pagedRoles.any((r) => _selectedRoleIds.contains(r.id)) && !isAllSelected;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Color(0xFF1677F2), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Roles ($totalRoles)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedSubTab = 1),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All', style: TextStyle(color: Color(0xFF1677F2), fontSize: 12, fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward_rounded, color: Color(0xFF1677F2), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-Selection Action Toolbar
          if (_selectedRoleIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1677F2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1677F2).withValues(alpha: 0.3)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1677F2), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedRoleIds.length} of $totalRoles roles selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1677F2)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1677F2),
                          side: const BorderSide(color: Color(0xFF1677F2)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Assigning policies to ${_selectedRoleIds.length} roles...')),
                          );
                        },
                        icon: const Icon(Icons.shield_outlined, size: 14),
                        label: const Text('Assign Policy', style: TextStyle(fontSize: 11.5)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1677F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Exported ${_selectedRoleIds.length} roles.')),
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 14),
                        label: const Text('Export Selected', style: TextStyle(fontSize: 11.5)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedRoleIds.clear()),
                        child: const Text('Deselect All', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: isAllSelected ? true : (isSomeSelected ? null : false),
                    tristate: true,
                    activeColor: const Color(0xFF1677F2),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedRoleIds.addAll(pagedRoles.map((r) => r.id));
                        } else {
                          for (final r in pagedRoles) {
                            _selectedRoleIds.remove(r.id);
                          }
                        }
                      });
                    },
                  ),
                ),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_roleSortColumn == 'role_name') {
                          _roleSortAsc = !_roleSortAsc;
                        } else {
                          _roleSortColumn = 'role_name';
                          _roleSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Role Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _roleSortColumn == 'role_name'
                              ? (_roleSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _roleSortColumn == 'role_name' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_roleSortColumn == 'users_count') {
                          _roleSortAsc = !_roleSortAsc;
                        } else {
                          _roleSortColumn = 'users_count';
                          _roleSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _roleSortColumn == 'users_count'
                              ? (_roleSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _roleSortColumn == 'users_count' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(label: Text('Key Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_roleSortColumn == 'status') {
                          _roleSortAsc = !_roleSortAsc;
                        } else {
                          _roleSortColumn = 'status';
                          _roleSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _roleSortColumn == 'status'
                              ? (_roleSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _roleSortColumn == 'status' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: pagedRoles.map((r) {
                final isSelected = _selectedRole?.id == r.id;
                final isChecked = _selectedRoleIds.contains(r.id);
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => setState(() => _selectedRole = r),
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFF1677F2),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedRoleIds.add(r.id);
                            } else {
                              _selectedRoleIds.remove(r.id);
                            }
                            _selectedRole = r;
                          });
                        },
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            r.roleName == 'Super Admin'
                                ? Icons.security_rounded
                                : (r.roleName == 'Facility Manager'
                                    ? Icons.business_rounded
                                    : (r.roleName == 'Teacher' ? Icons.school_rounded : Icons.person_outline_rounded)),
                            color: const Color(0xFF1677F2),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(r.roleName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          r.description,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${r.usersCount}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1677F2).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.keyPermissions,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1677F2)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              r.status,
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1677F2)),
                            onPressed: () => _openCreateRoleWizard(r),
                            tooltip: 'Edit Role',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (action) {
                              if (action == 'duplicate') {
                                _duplicateRole(r);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Role')),
                              const PopupMenuItem(value: 'export', child: Text('Export JSON')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Showing ${totalRoles == 0 ? 0 : startRoleIdx + 1} - $endRoleIdx of $totalRoles roles',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Rows per page:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _rolesPageSize,
                        isDense: true,
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _rolesPageSize = v;
                              _rolesCurrentPage = 1;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: _rolesCurrentPage > 1 ? () => setState(() => _rolesCurrentPage--) : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$_rolesCurrentPage', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text('of $totalRolePages', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _rolesCurrentPage < totalRolePages ? () => setState(() => _rolesCurrentPage++) : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  // ============================================================================
  // CENTRAL TABLE 2: USER ACCESS (RECENT)
  // ============================================================================
  Widget _buildUserAccessTableCard(bool isDark) {
    // Filter users locally or against current fetch
    final filteredUsers = _recentUsers.where((u) {
      if (_selectedRoleFilter != 'All Roles') {
        if (!u.roleName.toLowerCase().contains(_selectedRoleFilter.toLowerCase())) {
          return false;
        }
      }
      if (_selectedStatusFilter != 'All Status') {
        if (u.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
          return false;
        }
      }
      if (_userSearchQuery.trim().isNotEmpty) {
        final q = _userSearchQuery.toLowerCase();
        if (!u.userName.toLowerCase().contains(q) && !u.email.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort users
    filteredUsers.sort((a, b) {
      int cmp = 0;
      if (_userSortColumn == 'role_name') {
        cmp = a.roleName.compareTo(b.roleName);
      } else if (_userSortColumn == 'group_name') {
        cmp = a.groupName.compareTo(b.groupName);
      } else if (_userSortColumn == 'location_scope') {
        cmp = a.locationScope.compareTo(b.locationScope);
      } else if (_userSortColumn == 'status') {
        cmp = a.status.compareTo(b.status);
      } else if (_userSortColumn == 'last_login') {
        cmp = a.lastLogin.compareTo(b.lastLogin);
      } else {
        cmp = a.userName.compareTo(b.userName);
      }
      return _userSortAsc ? cmp : -cmp;
    });

    final totalUsers = filteredUsers.length;
    final totalUserPages = (totalUsers / _userPageSize).ceil().clamp(1, 9999);
    final currentUserPage = _userCurrentPage.clamp(1, totalUserPages);
    final startUserIdx = (currentUserPage - 1) * _userPageSize;
    final endUserIdx = (startUserIdx + _userPageSize).clamp(0, totalUsers);
    final pagedUsers = totalUsers > 0 ? filteredUsers.sublist(startUserIdx, endUserIdx) : <EnterpriseUserAccessItem>[];

    final isAllSelected = pagedUsers.isNotEmpty && pagedUsers.every((u) => _selectedUserIds.contains(u.id));
    final isSomeSelected = pagedUsers.any((u) => _selectedUserIds.contains(u.id)) && !isAllSelected;

    // Available roles for filter dropdown
    final filterRoleNames = <String>{'All Roles'};
    if (_dropdownRoles.isNotEmpty) {
      for (final r in _dropdownRoles) {
        final dname = r['display_name'] ?? r['name'];
        if (dname != null) filterRoleNames.add(dname.toString());
      }
    } else {
      filterRoleNames.addAll(['Super Admin', 'Device Administrator', 'Facility Manager', 'Teacher', 'Maintenance Staff', 'Security Officer']);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + Filters
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF1677F2), size: 18),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'User Access (Recent)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($totalUsers)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Roles Dropdown (Canonical from app_roles)
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: filterRoleNames.contains(_selectedRoleFilter) ? _selectedRoleFilter : 'All Roles',
                          isDense: true,
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                          items: filterRoleNames.map((r) {
                            return DropdownMenuItem<String>(value: r, child: Text(r));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedRoleFilter = v;
                                _userCurrentPage = 1;
                              });
                              _filterUsersFromBackend();
                            }
                          },
                        ),
                      ),
                    ),
                    // Status Dropdown
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatusFilter,
                          isDense: true,
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                          items: const [
                            DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _selectedStatusFilter = v;
                                _userCurrentPage = 1;
                              });
                              _filterUsersFromBackend();
                            }
                          },
                        ),
                      ),
                    ),
                    // Search Bar
                    SizedBox(
                      width: 180,
                      height: 32,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by user name or email...',
                          hintStyle: const TextStyle(fontSize: 10.5),
                          prefixIcon: const Icon(Icons.search_rounded, size: 14),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _userSearchQuery = v;
                            _userCurrentPage = 1;
                          });
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openAssignUserAccessModal(),
                      icon: const Icon(Icons.person_add_rounded, size: 14),
                      label: const Text('Assign User Access', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Multi-Selection Action Toolbar
          if (_selectedUserIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1677F2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1677F2).withValues(alpha: 0.3)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1677F2), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedUserIds.length} of $totalUsers users selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1677F2)),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _executeBulkUserAction('activate'),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                        label: const Text('Activate Selected', style: TextStyle(fontSize: 11.5)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _executeBulkUserAction('deactivate'),
                        icon: const Icon(Icons.pause_circle_outline_rounded, size: 14),
                        label: const Text('Deactivate Selected', style: TextStyle(fontSize: 11.5)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _executeBulkUserAction('revoke'),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text('Revoke Selected', style: TextStyle(fontSize: 11.5)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedUserIds.clear()),
                        child: const Text('Deselect All', style: TextStyle(fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Users Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 48,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: isAllSelected ? true : (isSomeSelected ? null : false),
                    tristate: true,
                    activeColor: const Color(0xFF1677F2),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedUserIds.addAll(pagedUsers.map((u) => u.id));
                        } else {
                          for (final u in pagedUsers) {
                            _selectedUserIds.remove(u.id);
                          }
                        }
                      });
                    },
                  ),
                ),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_userSortColumn == 'user_name') {
                          _userSortAsc = !_userSortAsc;
                        } else {
                          _userSortColumn = 'user_name';
                          _userSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('User Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _userSortColumn == 'user_name'
                              ? (_userSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _userSortColumn == 'user_name' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_userSortColumn == 'role_name') {
                          _userSortAsc = !_userSortAsc;
                        } else {
                          _userSortColumn = 'role_name';
                          _userSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _userSortColumn == 'role_name'
                              ? (_userSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _userSortColumn == 'role_name' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(label: Text('User Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_userSortColumn == 'location_scope') {
                          _userSortAsc = !_userSortAsc;
                        } else {
                          _userSortColumn = 'location_scope';
                          _userSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Location Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _userSortColumn == 'location_scope'
                              ? (_userSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _userSortColumn == 'location_scope' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_userSortColumn == 'status') {
                          _userSortAsc = !_userSortAsc;
                        } else {
                          _userSortColumn = 'status';
                          _userSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _userSortColumn == 'status'
                              ? (_userSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _userSortColumn == 'status' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: InkWell(
                    onTap: () {
                      setState(() {
                        if (_userSortColumn == 'last_login') {
                          _userSortAsc = !_userSortAsc;
                        } else {
                          _userSortColumn = 'last_login';
                          _userSortAsc = true;
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Last Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 4),
                        Icon(
                          _userSortColumn == 'last_login'
                              ? (_userSortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: _userSortColumn == 'last_login' ? const Color(0xFF1677F2) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: pagedUsers.map((u) {
                final isChecked = _selectedUserIds.contains(u.id);
                return DataRow(
                  cells: [
                    DataCell(
                      Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFF1677F2),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(u.id);
                            } else {
                              _selectedUserIds.remove(u.id);
                            }
                          });
                        },
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF1677F2).withValues(alpha: 0.1),
                            child: Text(
                              u.userName.isNotEmpty ? u.userName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1677F2)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(u.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              if (u.email.isNotEmpty)
                                Text(u.email, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1677F2).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          u.roleName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1677F2)),
                        ),
                      ),
                    ),
                    DataCell(Text(u.groupName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(u.locationScope, style: const TextStyle(fontSize: 11.5)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: u.status == 'Active'
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              u.status == 'Active' ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                              color: u.status == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              u.status,
                              style: TextStyle(
                                color: u.status == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(u.lastLogin, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1677F2)),
                            onPressed: () => _openAssignUserAccessModal(u),
                            tooltip: 'Edit Access',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                            onPressed: () => _revokeSingleUser(u),
                            tooltip: 'Revoke Access',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Pagination Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Showing ${totalUsers == 0 ? 0 : startUserIdx + 1} - $endUserIdx of $totalUsers users',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Rows per page:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _userPageSize,
                        isDense: true,
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : Colors.black87),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _userPageSize = v;
                              _userCurrentPage = 1;
                            });
                            _filterUsersFromBackend();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: _userCurrentPage > 1
                          ? () {
                              setState(() => _userCurrentPage--);
                              _filterUsersFromBackend();
                            }
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677F2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$_userCurrentPage', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text('of $totalUserPages', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: _userCurrentPage < totalUserPages
                          ? () {
                              setState(() => _userCurrentPage++);
                              _filterUsersFromBackend();
                            }
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  // ============================================================================
  // RIGHT INSPECTOR PANEL: SELECTED ROLE (FACILITY MANAGER)
  // ============================================================================
  Widget _buildRightInspectorPanel(bool isDark) {
    final role = _selectedRole ??
        EnterpriseRoleItem(
          id: 'def',
          roleName: 'Facility Manager',
          roleCode: 'FACILITY_MANAGER',
          description:
              'Operate and monitor devices for assigned locations (e.g., blocks, floors, rooms) and manage daily operations such as live control, scenes, schedules and basic automation.',
        );

    final keyPermissions = [
      'View Devices & Groups',
      'Live Control (ON/OFF, Parameters)',
      'Run Scenes & Presets',
      'View Schedules',
      'View Energy & Usage',
      'View Device Health',
      'Create Limited Schedules',
      'Run Approved Automations',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: Color(0xFF1677F2), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Selected Role – ${role.roleName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1677F2)),
                onPressed: () => _openCreateRoleWizard(role),
                tooltip: 'Edit Role Settings',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(height: 18),

          // Role Avatar & Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1677F2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, color: Color(0xFF1677F2), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  role.roleName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 10),
                                    SizedBox(width: 3),
                                    Text('Active', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Priority: ${role.priority} • ${role.roleCategory}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  role.description,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Key Permissions Checklist
          const Text('Key Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 8),
          ...keyPermissions.map((perm) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perm,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),

          // Scope & Restrictions
          const Text('Scope & Restrictions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 8),
          _buildScopeRow(Icons.location_on_outlined, 'Location Scope:', role.locationScope),
          _buildScopeRow(Icons.devices_other_rounded, 'Device Types:', role.deviceTypesScope),
          _buildScopeRow(Icons.access_time_rounded, 'Time Policy:', role.timePolicy),
          _buildScopeRow(Icons.language_rounded, 'Access Channel:', role.accessChannel),
          const SizedBox(height: 16),

          // 5 Accordions
          _buildAccordionItem(
            title: 'Permission Matrix (Role × Feature)',
            icon: Icons.grid_view_rounded,
            isExpanded: _accPermissionMatrixExpanded,
            onToggle: () => setState(() => _accPermissionMatrixExpanded = !_accPermissionMatrixExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Full resource capabilities configured for this role:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                _buildMiniMatrixRow('Device Registry', 'View, Edit, Export'),
                _buildMiniMatrixRow('Live Control', 'ON/OFF, Parameters, Scene'),
                _buildMiniMatrixRow('Bulk Operations', 'Restricted (Approval Req.)'),
                _buildMiniMatrixRow('Schedules', 'Create, Edit, Pause'),
              ],
            ),
          ),
          _buildAccordionItem(
            title: 'Access Policies',
            icon: Icons.shield_outlined,
            isExpanded: _accPoliciesExpanded,
            onToggle: () => setState(() => _accPoliciesExpanded = !_accPoliciesExpanded),
            content: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• POL_LOCATION_BOUND: Enforced on Block A', style: TextStyle(fontSize: 11.5)),
                SizedBox(height: 4),
                Text('• POL_WORKING_HOURS: Allowed 24x7', style: TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
          _buildAccordionItem(
            title: 'Delegation & Temporary Access',
            icon: Icons.transfer_within_a_station_rounded,
            isExpanded: _accDelegationExpanded,
            onToggle: () => setState(() => _accDelegationExpanded = !_accDelegationExpanded),
            content: const Text('1 Active Delegation: Alok Chandra (Ends in 5 days)', style: TextStyle(fontSize: 11.5)),
          ),
          _buildAccordionItem(
            title: 'Access Requests (4 Pending)',
            icon: Icons.pending_actions_rounded,
            isExpanded: _accRequestsExpanded,
            badgeCount: 4,
            onToggle: () => setState(() => _accRequestsExpanded = !_accRequestsExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('4 requests awaiting administrator review.', style: TextStyle(fontSize: 11.5)),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => setState(() => _selectedSubTab = 7),
                  child: const Text('Review Requests', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          _buildAccordionItem(
            title: 'Access Audit Logs',
            icon: Icons.fact_check_outlined,
            isExpanded: _accAuditLogsExpanded,
            onToggle: () => setState(() => _accAuditLogsExpanded = !_accAuditLogsExpanded),
            content: const Text('Recent role modification recorded at 10 Jan 2025, 02:15 PM by Amit Sharma.', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMatrixRow(String resource, String perms) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(resource, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(perms, style: const TextStyle(fontSize: 10.5, color: Color(0xFF1677F2))),
        ],
      ),
    );
  }

  Widget _buildAccordionItem({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
    int? badgeCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF1677F2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeCount != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: content,
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: ROLES FULL VIEW
  // ============================================================================
  Widget _buildRolesTabView(bool isDark, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text('Institutional Roles Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
              onPressed: () => _openCreateRoleWizard(),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Role'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRolesTableCard(isDark),
      ],
    );
  }

  // ============================================================================
  // TAB 2: USERS & ACCESS FULL VIEW
  // ============================================================================
  Widget _buildUsersTabView(bool isDark, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text('User Access Directory & Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () => _openAssignUserAccessModal(),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Assign User Access'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildUserAccessTableCard(isDark),
      ],
    );
  }

  // ============================================================================
  // TAB 3: USER GROUPS FULL VIEW
  // ============================================================================
  Widget _buildGroupsTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text('18 Active User Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
                onPressed: _openCreateGroupModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Group'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _groups.isNotEmpty
                ? _groups.map((g) => _buildGroupCard(g, isDark)).toList()
                : [
                    _buildFallbackGroupCard('IT Team', 'GRP_IT', 14, isDark),
                    _buildFallbackGroupCard('Facility Team', 'GRP_FACILITY', 36, isDark),
                    _buildFallbackGroupCard('Teachers', 'GRP_TEACHERS', 88, isDark),
                    _buildFallbackGroupCard('Maintenance', 'GRP_MAINTENANCE', 18, isDark),
                    _buildFallbackGroupCard('Management', 'GRP_MANAGEMENT', 12, isDark),
                    _buildFallbackGroupCard('Security Team', 'GRP_SECURITY', 12, isDark),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(EnterpriseUserGroupItem g, bool isDark) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(g.groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('${g.memberCount} users', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(g.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildFallbackGroupCard(String name, String code, int members, bool isDark) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('$members users', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Code: $code', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: PERMISSIONS MATRIX FULL VIEW
  // ============================================================================
  Widget _buildPermissionsTabView(bool isDark, double width) {
    final resources = [
      'Device Registry',
      'Live Control',
      'Bulk Operations',
      'Schedules',
      'Scenes & Presets',
      'Energy & Usage',
      'Health & Diagnostics',
      'Integrations & Gateways',
      'Access & Permissions',
      'Audit Logs',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dynamic Permission Matrix – Role: ${_selectedRole?.roleName ?? "Facility Manager"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Configure resource-level actions (RBAC & ABAC Enforcement)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permission Matrix saved successfully!'), backgroundColor: Color(0xFF10B981)),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Matrix'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('Resource / Module', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Create', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Execute', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Control', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(label: Text('Export', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: resources.map((res) {
                return DataRow(
                  cells: [
                    DataCell(Text(res, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(Checkbox(value: true, onChanged: (_) {}, activeColor: const Color(0xFF10B981))),
                    DataCell(Checkbox(value: res.contains('Schedule'), onChanged: (_) {}, activeColor: const Color(0xFF1677F2))),
                    DataCell(Checkbox(value: res.contains('Control') || res.contains('Schedule'), onChanged: (_) {}, activeColor: const Color(0xFF1677F2))),
                    DataCell(Checkbox(value: false, onChanged: (_) {}, activeColor: const Color(0xFFEF4444))),
                    DataCell(Checkbox(value: res.contains('Control') || res.contains('Scene'), onChanged: (_) {}, activeColor: const Color(0xFF10B981))),
                    DataCell(Checkbox(value: res.contains('Control'), onChanged: (_) {}, activeColor: const Color(0xFF10B981))),
                    DataCell(Checkbox(value: res.contains('Schedule'), onChanged: (_) {}, activeColor: const Color(0xFFF59E0B))),
                    DataCell(Checkbox(value: res.contains('Usage') || res.contains('Audit'), onChanged: (_) {}, activeColor: const Color(0xFF1677F2))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 5: ACCESS POLICIES FULL VIEW
  // ============================================================================
  Widget _buildPoliciesTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text('Configured ABAC Policies (6 Active)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
                onPressed: _openDefinePolicyModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Define Policy'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._policies.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF1677F2), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(p.policyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF1677F2).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(p.category, style: const TextStyle(fontSize: 10, color: Color(0xFF1677F2), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(p.description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Switch(
                    value: p.isActive,
                    onChanged: (val) {
                      setState(() {
                        final idx = _policies.indexOf(p);
                        _policies[idx] = AccessPolicyItem(
                          id: p.id,
                          policyName: p.policyName,
                          policyCode: p.policyCode,
                          description: p.description,
                          category: p.category,
                          targetScope: p.targetScope,
                          priority: p.priority,
                          isActive: val,
                          approvalRequired: p.approvalRequired,
                        );
                      });
                    },
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 6: DELEGATION FULL VIEW
  // ============================================================================
  Widget _buildDelegationTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text('Active Temporary Delegations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
                onPressed: _openCreateDelegationModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Grant Temporary Access'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._delegations.map((d) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.transfer_within_a_station_rounded, color: Color(0xFF1677F2), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delegatee: ${d.delegateeName} (${d.assignedRole})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Scope: ${d.locationScope} • Delegated by: ${d.delegatorName}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('Reason: ${d.reason}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(d.status, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 7: ACCESS REQUESTS FULL VIEW
  // ============================================================================
  Widget _buildRequestsTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              const Text('Pending Access & Privilege Requests (4)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
                onPressed: _openAccessRequestModal,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Submit Request'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._accessRequests.map((req) {
            final isPending = req.status == 'Pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(req.requestCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1677F2))),
                            const SizedBox(width: 8),
                            Text('Requester: ${req.requesterName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Role: ${req.requestedRole} • Scope: ${req.requestedScope} • Duration: ${req.duration}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Text('Justification: "${req.justification}"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  if (isPending) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () => _approveRequest(req),
                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      onPressed: () => _rejectRequest(req),
                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: req.status == 'Approved'
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        req.status,
                        style: TextStyle(
                          color: req.status == 'Approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 8: AUDIT LOGS FULL VIEW
  // ============================================================================
  Widget _buildAuditLogsTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Security & Access Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Immutable, tamper-evident chronological log of authorization decisions and role alterations.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 14),
          ..._auditLogs.map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    log.status == 'Success' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    color: log.status == 'Success' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${log.action} – ${log.target}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text('Actor: ${log.actorName} (${log.roleName}) • IP: ${log.ipAddress} • Correlation: ${log.correlationId}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text(log.timestamp, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

// ============================================================================
// CUSTOM DONUT PAINTER FOR ACCESS OVERVIEW
// ============================================================================
class _RoleDonutPainter extends CustomPainter {
  final List<RoleDistributionItem> items;

  _RoleDonutPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -1.5708; // -90 deg

    if (items.isEmpty) {
      paint.color = const Color(0xFF1677F2);
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    for (var it in items) {
      final sweepAngle = (it.percentage / 100.0) * 6.283185;
      paint.color = _hexToColor(it.colorHex);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  bool shouldRepaint(covariant _RoleDonutPainter oldDelegate) => true;
}

// ============================================================================
// MODALS & DIALOGS
// ============================================================================

// 1. Create/Edit Role Dialog
class _CreateRoleDialog extends StatefulWidget {
  final EnterpriseRoleItem? roleToEdit;
  final ValueChanged<EnterpriseRoleItem> onRoleSaved;

  const _CreateRoleDialog({this.roleToEdit, required this.onRoleSaved});

  @override
  State<_CreateRoleDialog> createState() => _CreateRoleDialogState();
}

class _CreateRoleDialogState extends State<_CreateRoleDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _descCtrl;
  String _location = 'Assigned Locations';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.roleToEdit?.roleName ?? 'Campus Energy Specialist');
    _codeCtrl = TextEditingController(text: widget.roleToEdit?.roleCode ?? 'CAMPUS_ENERGY_SPEC');
    _descCtrl = TextEditingController(text: widget.roleToEdit?.description ?? 'Supervises smart meter schedules and telemetry.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1677F2)),
          SizedBox(width: 8),
          Text('Enterprise Role Configuration'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Role Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Role Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _codeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Location Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _location,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Assigned Locations', child: Text('Assigned Locations')),
                DropdownMenuItem(value: 'Entire Institution', child: Text('Entire Institution')),
                DropdownMenuItem(value: 'Academic Block A', child: Text('Academic Block A')),
              ],
              onChanged: (v) => setState(() => _location = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
          onPressed: () {
            final role = EnterpriseRoleItem(
              id: widget.roleToEdit?.id ?? 'c1000000-${DateTime.now().millisecondsSinceEpoch}',
              roleName: _nameCtrl.text.trim(),
              roleCode: _codeCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              usersCount: widget.roleToEdit?.usersCount ?? 0,
              keyPermissions: 'View, Control, Schedules',
              locationScope: _location,
            );
            widget.onRoleSaved(role);
            Navigator.pop(context);
          },
          child: const Text('Save Role'),
        ),
      ],
    );
  }
}

// 2. Assign User Access Dialog (Canonical Dropdowns for Users, Roles, Locations & Permissions)
class _AssignUserAccessDialog extends StatefulWidget {
  final EnterpriseUserAccessItem? user;
  final List<EnterpriseRoleItem> roles;
  final List<Map<String, dynamic>> dropdownUsers;
  final List<Map<String, dynamic>> dropdownRoles;
  final List<Map<String, dynamic>> dropdownLocations;
  final String? apiBaseUrl;
  final ValueChanged<EnterpriseUserAccessItem> onUserAssigned;

  const _AssignUserAccessDialog({
    this.user,
    required this.roles,
    this.dropdownUsers = const [],
    this.dropdownRoles = const [],
    this.dropdownLocations = const [],
    this.apiBaseUrl,
    required this.onUserAssigned,
  });

  @override
  State<_AssignUserAccessDialog> createState() => _AssignUserAccessDialogState();
}

class _AssignUserAccessDialogState extends State<_AssignUserAccessDialog> {
  String? _selectedUserId;
  Map<String, dynamic>? _selectedUser;
  String _userSearch = '';

  String? _selectedRoleId;
  String _selectedRoleName = 'Facility Manager';

  String _selectedScope = 'All Locations';
  String _selectedAccessLevel = 'Full Control';
  final Set<String> _selectedFeatures = {
    'Devices & Groups',
    'Live Control',
    'Scenes & Presets',
    'Schedules & Timers',
    'Energy & Analytics',
    'Device Health & Diagnostics',
  };
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _selectedUserId = widget.user!.id;
      _selectedRoleName = widget.user!.roleName;
      _selectedScope = widget.user!.locationScope;
      _selectedUser = {
        'id': widget.user!.id,
        'full_name': widget.user!.userName,
        'email': widget.user!.email,
        'role': widget.user!.roleName,
        'department': widget.user!.groupName,
      };
      for (final r in widget.dropdownRoles) {
        if ((r['display_name'] != null && r['display_name'].toString().toLowerCase() == _selectedRoleName.toLowerCase()) ||
            (r['name'] != null && r['name'].toString().toLowerCase() == _selectedRoleName.toLowerCase())) {
          _selectedRoleId = r['id']?.toString();
          break;
        }
      }
    } else {
      if (widget.dropdownUsers.isNotEmpty) {
        _selectedUser = widget.dropdownUsers.first;
        _selectedUserId = _selectedUser!['id']?.toString();
      }
      if (widget.dropdownRoles.isNotEmpty) {
        final r = widget.dropdownRoles.first;
        _selectedRoleId = r['id']?.toString();
        _selectedRoleName = r['display_name'] ?? r['name'] ?? 'Facility Manager';
      }
    }
  }

  Future<void> _submitAssignment() async {
    final userId = _selectedUserId ?? widget.user?.id ?? 'u-${DateTime.now().millisecondsSinceEpoch}';
    final userName = _selectedUser?['full_name']?.toString() ?? widget.user?.userName ?? 'User';
    final userEmail = _selectedUser?['email']?.toString() ?? widget.user?.email ?? '';
    final groupName = _selectedUser?['department']?.toString() ?? widget.user?.groupName ?? 'General';
    final roleId = _selectedRoleId ?? (widget.roles.isNotEmpty ? widget.roles.first.id : 'role-1');

    setState(() => _isSaving = true);

    if (widget.apiBaseUrl != null && !widget.apiBaseUrl!.contains('mock')) {
      try {
        final token = (await SharedPreferences.getInstance()).getString('auth_token');
        final targetUrl = '${widget.apiBaseUrl}/access-permissions/users/assign';
        await http.post(
          Uri.parse(targetUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'user_id': userId,
            'role_id': roleId,
            'role_name': _selectedRoleName,
            'location_scope': _selectedScope,
            'access_level': _selectedAccessLevel,
            'department': groupName,
            'feature_permissions': _selectedFeatures.toList(),
            'status': 'Active',
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    final updated = EnterpriseUserAccessItem(
      id: userId,
      userName: userName,
      email: userEmail,
      roleName: _selectedRoleName,
      groupName: groupName,
      locationScope: _selectedScope,
      status: 'Active',
      lastLogin: 'Just now',
    );

    widget.onUserAssigned(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredUsers = widget.dropdownUsers.where((u) {
      if (_userSearch.trim().isEmpty) return true;
      final q = _userSearch.toLowerCase();
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.person_add_outlined, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 10),
          Text(widget.user != null ? 'Edit User Device Access' : 'Assign Device Access Permissions'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Selection
              const Text('1. Institutional User (from User Management)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (widget.user != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF1677F2),
                        child: Text(
                          widget.user!.userName.isNotEmpty ? widget.user!.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.user!.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(widget.user!.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    hintStyle: const TextStyle(fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onChanged: (v) => setState(() => _userSearch = v),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: filteredUsers.isEmpty
                      ? const Center(child: Text('No users found', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))))
                      : ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final u = filteredUsers[idx];
                            final isSel = _selectedUserId == u['id']?.toString();
                            return ListTile(
                              dense: true,
                              selected: isSel,
                              selectedTileColor: const Color(0xFF1677F2).withValues(alpha: 0.1),
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF1677F2).withValues(alpha: 0.1),
                                child: Text(
                                  (u['full_name'] != null && u['full_name'].toString().isNotEmpty)
                                      ? u['full_name'].toString()[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1677F2)),
                                ),
                              ),
                              title: Text(u['full_name']?.toString() ?? 'User', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text(u['email']?.toString() ?? '', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1677F2).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(u['role']?.toString() ?? 'Role', style: const TextStyle(fontSize: 9.5, color: Color(0xFF1677F2), fontWeight: FontWeight.w500)),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedUserId = u['id']?.toString();
                                  _selectedUser = u;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: 14),

              // Role Selection
              const Text('2. Assign Institutional Role (from Roles Management)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedRoleId ?? (widget.dropdownRoles.isNotEmpty ? widget.dropdownRoles.first['id']?.toString() : null),
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: widget.dropdownRoles.map((r) {
                  final dname = r['display_name'] ?? r['name'] ?? 'Role';
                  return DropdownMenuItem<String>(
                    value: r['id']?.toString(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF1677F2)),
                        const SizedBox(width: 8),
                        Text(dname, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedRoleId = v;
                      final match = widget.dropdownRoles.firstWhere((r) => r['id']?.toString() == v, orElse: () => {});
                      _selectedRoleName = match['display_name'] ?? match['name'] ?? 'Facility Manager';
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Location Scope Selection
              const Text('3. Location Scope (from Buildings)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedScope,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: (widget.dropdownLocations.isNotEmpty
                        ? widget.dropdownLocations.map((l) => l['name']?.toString() ?? 'All Locations').toSet().toList()
                        : ['All Locations', 'Academic Block (A)', 'Academic Block (B)', 'Admin Block', 'Library Block', 'Laboratories Block', 'Auditorium Block', 'Sports Complex', 'Hostel Block A'])
                    .map((loc) {
                  return DropdownMenuItem<String>(
                    value: loc,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(loc, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedScope = v);
                },
              ),
              const SizedBox(height: 14),

              // Access Level
              const Text('4. Access Level', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedAccessLevel,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'Full Control', child: Text('Full Control (Read, Write, Execute, Admin)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Operator', child: Text('Operator (Read, Live Control, Schedules)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Monitor Only', child: Text('Monitor Only (Telemetry, Read Only)', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Restricted', child: Text('Restricted (Single Room or Emergency)', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedAccessLevel = v);
                },
              ),
              const SizedBox(height: 14),

              // Granular Features
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('5. Feature Permissions', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedFeatures.length == 8) {
                          _selectedFeatures.clear();
                        } else {
                          _selectedFeatures.addAll([
                            'Devices & Groups',
                            'Live Control',
                            'Scenes & Presets',
                            'Schedules & Timers',
                            'Energy & Analytics',
                            'Device Health & Diagnostics',
                            'Integrations & Gateways',
                            'Security Audit',
                          ]);
                        }
                      });
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    child: Text(_selectedFeatures.length == 8 ? 'Clear All' : 'Select All', style: const TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Devices & Groups',
                  'Live Control',
                  'Scenes & Presets',
                  'Schedules & Timers',
                  'Energy & Analytics',
                  'Device Health & Diagnostics',
                  'Integrations & Gateways',
                  'Security Audit',
                ].map((feat) {
                  final isChecked = _selectedFeatures.contains(feat);
                  return FilterChip(
                    label: Text(feat, style: TextStyle(fontSize: 11, color: isChecked ? Colors.white : null)),
                    selected: isChecked,
                    selectedColor: const Color(0xFF10B981),
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedFeatures.add(feat);
                        } else {
                          _selectedFeatures.remove(feat);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _submitAssignment,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Assignment'),
        ),
      ],
    );
  }
}

// 3. Create Group Dialog
class _CreateGroupDialog extends StatefulWidget {
  final ValueChanged<EnterpriseUserGroupItem> onGroupCreated;

  const _CreateGroupDialog({required this.onGroupCreated});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController(text: 'Science Laboratory Supervisors');
  final _codeCtrl = TextEditingController(text: 'GRP_SCIENCE_LAB');
  final _descCtrl = TextEditingController(text: 'Staff in charge of physics and chemistry safety switches');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.group_add_outlined, color: Color(0xFF8B5CF6)),
          SizedBox(width: 8),
          Text('Create User Group'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Group Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _codeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
          onPressed: () {
            final grp = EnterpriseUserGroupItem(
              id: 'd1000000-${DateTime.now().millisecondsSinceEpoch}',
              groupName: _nameCtrl.text.trim(),
              groupCode: _codeCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              memberCount: 1,
            );
            widget.onGroupCreated(grp);
            Navigator.pop(context);
          },
          child: const Text('Create Group'),
        ),
      ],
    );
  }
}

// 4. Define Policy Dialog
class _DefinePolicyDialog extends StatefulWidget {
  final ValueChanged<AccessPolicyItem> onPolicyCreated;

  const _DefinePolicyDialog({required this.onPolicyCreated});

  @override
  State<_DefinePolicyDialog> createState() => _DefinePolicyDialogState();
}

class _DefinePolicyDialogState extends State<_DefinePolicyDialog> {
  final _nameCtrl = TextEditingController(text: 'Elevated Emergency Gate Lockdown');
  final _codeCtrl = TextEditingController(text: 'POL_EMERGENCY_LOCK');
  final _descCtrl = TextEditingController(text: 'Permits campus security chief to issue global gate lock during alert');
  String _category = 'Emergency Access';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Text('Define Access Policy (ABAC)'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Policy Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Policy Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Emergency Access', child: Text('Emergency Access')),
                DropdownMenuItem(value: 'Time-Based', child: Text('Time-Based')),
                DropdownMenuItem(value: 'Location-Based', child: Text('Location-Based')),
                DropdownMenuItem(value: 'Critical Device', child: Text('Critical Device')),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 10),
            const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _descCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
          onPressed: () {
            final pol = AccessPolicyItem(
              id: 'f1000000-${DateTime.now().millisecondsSinceEpoch}',
              policyName: _nameCtrl.text.trim(),
              policyCode: _codeCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              category: _category,
              priority: 70,
              isActive: true,
            );
            widget.onPolicyCreated(pol);
            Navigator.pop(context);
          },
          child: const Text('Register Policy'),
        ),
      ],
    );
  }
}

// 5. Access Request Dialog
class _AccessRequestDialog extends StatefulWidget {
  final List<EnterpriseRoleItem> roles;
  final ValueChanged<AccessRequestItem> onRequestSubmitted;

  const _AccessRequestDialog({required this.roles, required this.onRequestSubmitted});

  @override
  State<_AccessRequestDialog> createState() => _AccessRequestDialogState();
}

class _AccessRequestDialogState extends State<_AccessRequestDialog> {
  final _requesterCtrl = TextEditingController(text: 'Ananya Deshmukh');
  final _scopeCtrl = TextEditingController(text: 'Laboratories Block Floor 2');
  final _justCtrl = TextEditingController(text: 'Conducting robotics workshop requiring power switches');
  String _role = 'Facility Manager';
  final String _duration = '3 Days';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assignment_outlined, color: Color(0xFF1677F2)),
          SizedBox(width: 8),
          Text('Submit Access Request'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Requester Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _requesterCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Requested Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _role,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Facility Manager', child: Text('Facility Manager')),
                DropdownMenuItem(value: 'IoT Operator', child: Text('IoT Operator')),
                DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 10),
            const Text('Location Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _scopeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Justification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _justCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
          onPressed: () {
            final req = AccessRequestItem(
              id: 'a1000000-${DateTime.now().millisecondsSinceEpoch}',
              requestCode: 'REQ-2025-${DateTime.now().millisecond}',
              requesterName: _requesterCtrl.text.trim(),
              requestedRole: _role,
              requestedScope: _scopeCtrl.text.trim(),
              duration: _duration,
              justification: _justCtrl.text.trim(),
              status: 'Pending',
            );
            widget.onRequestSubmitted(req);
            Navigator.pop(context);
          },
          child: const Text('Submit Request'),
        ),
      ],
    );
  }
}

// 6. Create Delegation Dialog
class _CreateDelegationDialog extends StatefulWidget {
  final List<EnterpriseRoleItem> roles;
  final ValueChanged<AccessDelegationItem> onDelegationCreated;

  const _CreateDelegationDialog({required this.roles, required this.onDelegationCreated});

  @override
  State<_CreateDelegationDialog> createState() => _CreateDelegationDialogState();
}

class _CreateDelegationDialogState extends State<_CreateDelegationDialog> {
  final _delCtrl = TextEditingController(text: 'Suresh Raina');
  final _emailCtrl = TextEditingController(text: 'suresh.r@schneider.com');
  final _scopeCtrl = TextEditingController(text: 'Sports Complex Floodlights');
  final _reasonCtrl = TextEditingController(text: 'Inter-college cricket tournament lighting setup');
  String _role = 'Maintenance Staff';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.transfer_within_a_station_rounded, color: Color(0xFF1677F2)),
          SizedBox(width: 8),
          Text('Grant Temporary Delegation'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delegatee Name (Vendor / Contractor)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _delCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Assigned Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _role,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Maintenance Staff', child: Text('Maintenance Staff')),
                DropdownMenuItem(value: 'Facility Manager', child: Text('Facility Manager')),
                DropdownMenuItem(value: 'IoT Operator', child: Text('IoT Operator')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 10),
            const Text('Location Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _scopeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            const Text('Business Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(controller: _reasonCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1677F2), foregroundColor: Colors.white),
          onPressed: () {
            final del = AccessDelegationItem(
              id: 'b2000000-${DateTime.now().millisecondsSinceEpoch}',
              delegateeName: _delCtrl.text.trim(),
              delegateeEmail: _emailCtrl.text.trim(),
              delegatorName: 'Admin',
              assignedRole: _role,
              locationScope: _scopeCtrl.text.trim(),
              reason: _reasonCtrl.text.trim(),
              startTime: 'Today, 09:00 AM',
              endTime: 'In 3 Days, 06:00 PM',
              status: 'Active',
            );
            widget.onDelegationCreated(del);
            Navigator.pop(context);
          },
          child: const Text('Confirm Delegation'),
        ),
      ],
    );
  }
}
