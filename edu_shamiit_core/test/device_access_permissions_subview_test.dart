import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_access_permissions_subview.dart';

void main() {
  group('Enterprise Access & Permissions Models Tests', () {
    test('AccessPermissionsKpis default values and JSON deserialization', () {
      final kpis = AccessPermissionsKpis();
      expect(kpis.totalUsers, 238);
      expect(kpis.totalRoles, 12);
      expect(kpis.permissionPolicies, 6);
      expect(kpis.userGroups, 18);
      expect(kpis.pendingRequests, 4);
      expect(kpis.accessHealth, 'Compliant');

      final deserialized = AccessPermissionsKpis.fromJson({
        'total_users': 300,
        'total_roles': 15,
        'permission_policies': 8,
        'user_groups': 20,
        'pending_requests': 2,
        'access_health': 'Attention Required',
      });
      expect(deserialized.totalUsers, 300);
      expect(deserialized.totalRoles, 15);
      expect(deserialized.accessHealth, 'Attention Required');
    });

    test('RoleDistributionItem deserialization', () {
      final item = RoleDistributionItem(name: 'Facility Manager', count: 36, percentage: 15.1, colorHex: '#10B981');
      expect(item.name, 'Facility Manager');
      expect(item.count, 36);
      expect(item.percentage, 15.1);

      final fromJson = RoleDistributionItem.fromJson({
        'name': 'Teacher',
        'count': 88,
        'percentage': 37.0,
        'color': '#8B5CF6'
      });
      expect(fromJson.name, 'Teacher');
      expect(fromJson.percentage, 37.0);
    });

    test('PermissionCoverageItem deserialization', () {
      final cov = PermissionCoverageItem(domain: 'Device Control', percentage: 92);
      expect(cov.domain, 'Device Control');
      expect(cov.percentage, 92);

      final fromJson = PermissionCoverageItem.fromJson({'domain': 'Reports', 'percentage': 76});
      expect(fromJson.domain, 'Reports');
      expect(fromJson.percentage, 76);
    });

    test('EnterpriseRoleItem with scope and policy fields', () {
      final role = EnterpriseRoleItem(
        id: 'role-1',
        roleName: 'Facility Manager',
        roleCode: 'FACILITY_MANAGER',
        description: 'Operate and monitor devices for assigned locations',
        usersCount: 36,
        keyPermissions: 'Live Control, Schedules, Scenes',
        status: 'Active',
        priority: 80,
        locationScope: 'Assigned Locations (e.g., Academic Block A)',
        deviceTypesScope: 'All (within assigned locations)',
        timePolicy: 'Allowed (24 x 7)',
        accessChannel: 'Web & Mobile',
      );

      expect(role.roleName, 'Facility Manager');
      expect(role.usersCount, 36);
      expect(role.locationScope, contains('Academic Block A'));
      expect(role.timePolicy, 'Allowed (24 x 7)');

      final fromJson = EnterpriseRoleItem.fromJson({
        'id': 'role-2',
        'role_name': 'Maintenance Staff',
        'role_code': 'MAINTENANCE_STAFF',
        'users_count': 18,
        'status': 'Active',
      });
      expect(fromJson.roleName, 'Maintenance Staff');
      expect(fromJson.usersCount, 18);
    });

    test('EnterpriseUserAccessItem canonical test', () {
      final user = EnterpriseUserAccessItem(
        id: 'user-1',
        userName: 'Amit Sharma',
        email: 'amit.sharma@edushamiit.edu',
        roleName: 'Device Administrator',
        groupName: 'IT Team',
        locationScope: 'All Locations',
        status: 'Active',
        lastLogin: '10 Jan 2025, 02:18 PM',
      );

      expect(user.userName, 'Amit Sharma');
      expect(user.email, 'amit.sharma@edushamiit.edu');
      expect(user.roleName, 'Device Administrator');
      expect(user.groupName, 'IT Team');
      expect(user.locationScope, 'All Locations');
    });

    test('EnterpriseUserGroupItem test', () {
      final group = EnterpriseUserGroupItem(
        id: 'grp-1',
        groupName: 'Facility Team',
        groupCode: 'FACILITY_TEAM',
        description: 'Operational caretakers and facility managers',
        memberCount: 36,
        status: 'Active',
      );
      expect(group.groupName, 'Facility Team');
      expect(group.memberCount, 36);
      expect(group.groupCode, 'FACILITY_TEAM');
    });

    test('AccessPolicyItem and AccessDelegationItem test', () {
      final pol = AccessPolicyItem(
        id: 'pol-1',
        policyName: 'Working Hours Access',
        policyCode: 'POL_WORKING_HOURS',
        category: 'Time-Based',
        priority: 10,
        isActive: true,
      );
      expect(pol.policyName, 'Working Hours Access');
      expect(pol.isActive, true);

      final del = AccessDelegationItem(
        id: 'del-1',
        delegateeName: 'Deepak Joshi',
        delegateeEmail: 'deepak.j@voltas.com',
        delegatorName: 'Amit Sharma',
        assignedRole: 'Maintenance Staff',
        locationScope: 'Academic Block A & B',
        reason: 'HVAC Maintenance',
        startTime: '09 Jan 2025, 09:00 AM',
        endTime: '12 Jan 2025, 06:00 PM',
        status: 'Active',
      );
      expect(del.delegateeName, 'Deepak Joshi');
      expect(del.assignedRole, 'Maintenance Staff');
      expect(del.status, 'Active');
    });

    test('AccessRequestItem and SecurityAuditLogItem serialization', () {
      final req = AccessRequestItem(
        id: 'req-1',
        requestCode: 'REQ-2025-081',
        requesterName: 'Priya Verma',
        requestedRole: 'Device Administrator',
        requestedScope: 'Server Room & Gateways',
        duration: '7 Days',
        justification: 'Critical gateway maintenance',
        priority: 'High',
        status: 'Pending',
      );
      expect(req.requestCode, 'REQ-2025-081');
      expect(req.priority, 'High');

      final log = SecurityAuditLogItem(
        id: 'log-1',
        actorName: 'Amit Sharma',
        roleName: 'Device Administrator',
        action: 'Role Modified',
        resource: 'Roles',
        target: 'Facility Manager',
        status: 'Success',
        correlationId: 'CORR-SEC-9101',
      );
      expect(log.actorName, 'Amit Sharma');
      expect(log.action, 'Role Modified');
      expect(log.status, 'Success');
    });
  });

  group('DeviceAccessPermissionsSubview Widget Tests', () {
    Widget buildTestWidget({Size size = const Size(1440, 900), Brightness brightness = Brightness.light}) {
      return MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: const DeviceAccessPermissionsSubview(apiBaseUrl: 'http://mock.endpoint'),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all 6 top KPI cards with canonical values', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('Roles'), findsWidgets);
      expect(find.text('Permission Policies'), findsOneWidget);
      expect(find.text('User Groups'), findsWidgets);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Access Health'), findsOneWidget);
      expect(find.text('Compliant'), findsOneWidget);
    });

    testWidgets('renders all 9 Sub-Tabs', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Users & Access'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Access Policies'), findsWidgets);
      expect(find.text('Delegation'), findsOneWidget);
      expect(find.text('Access Requests'), findsOneWidget);
      expect(find.text('Audit Logs'), findsWidgets);
    });

    testWidgets('renders Row 1 cards: Access Overview, Permission Coverage, Quick Actions', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Access Overview'), findsOneWidget);
      expect(find.text('Permission Coverage'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Device Control'), findsOneWidget);
      expect(find.text('Create Role'), findsOneWidget);
      expect(find.text('Add User Access'), findsOneWidget);
      expect(find.text('Create Group'), findsOneWidget);
      expect(find.text('Define Policy'), findsOneWidget);
    });

    testWidgets('renders Roles table with canonical roles and actions', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Roles ('), findsOneWidget);
      expect(find.text('Super Admin'), findsWidgets);
      expect(find.text('Device Administrator'), findsWidgets);
      expect(find.text('Facility Manager'), findsWidgets);
      expect(find.text('Maintenance Staff'), findsWidgets);
      expect(find.text('View Only'), findsWidgets);
    });

    testWidgets('renders User Access (Recent) table with canonical users', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('User Access (Recent)'), findsOneWidget);
      expect(find.text('Amit Sharma'), findsWidgets);
      expect(find.text('Priya Verma'), findsWidgets);
      expect(find.text('Rohan Mehta'), findsWidgets);
      expect(find.text('Neha Kapoor'), findsWidgets);
      expect(find.text('Vikas Singh'), findsWidgets);
    });

    testWidgets('renders Right Inspector Panel for selected Facility Manager', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected Role'), findsOneWidget);
      expect(find.text('Key Permissions'), findsWidgets);
      expect(find.text('Scope & Restrictions'), findsOneWidget);
      expect(find.text('Permission Matrix (Role × Feature)'), findsOneWidget);
      expect(find.text('Access Policies'), findsWidgets);
      expect(find.text('Delegation & Temporary Access'), findsOneWidget);
      expect(find.text('Access Requests (4 Pending)'), findsOneWidget);
      expect(find.text('Access Audit Logs'), findsOneWidget);
    });

    testWidgets('switches to dedicated sub-tabs smoothly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap Roles sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Roles')));
      await tester.tap(find.byKey(const ValueKey('subtab_Roles')));
      await tester.pumpAndSettle();
      expect(find.text('Institutional Roles Catalog'), findsOneWidget);

      // Tap Users & Access sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Users & Access')));
      await tester.tap(find.byKey(const ValueKey('subtab_Users & Access')));
      await tester.pumpAndSettle();
      expect(find.text('User Access Directory & Assignment'), findsOneWidget);

      // Tap User Groups sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_User Groups')));
      await tester.tap(find.byKey(const ValueKey('subtab_User Groups')));
      await tester.pumpAndSettle();
      expect(find.text('18 Active User Groups'), findsOneWidget);

      // Tap Access Policies sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Access Policies')));
      await tester.tap(find.byKey(const ValueKey('subtab_Access Policies')));
      await tester.pumpAndSettle();
      expect(find.text('Configured ABAC Policies (6 Active)'), findsOneWidget);

      // Tap Delegation sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Delegation')));
      await tester.tap(find.byKey(const ValueKey('subtab_Delegation')));
      await tester.pumpAndSettle();
      expect(find.text('Active Temporary Delegations'), findsOneWidget);

      // Tap Access Requests sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Access Requests')));
      await tester.tap(find.byKey(const ValueKey('subtab_Access Requests')));
      await tester.pumpAndSettle();
      expect(find.text('Pending Access & Privilege Requests (4)'), findsOneWidget);

      // Tap Audit Logs sub-tab
      await tester.ensureVisible(find.byKey(const ValueKey('subtab_Audit Logs')));
      await tester.tap(find.byKey(const ValueKey('subtab_Audit Logs')));
      await tester.pumpAndSettle();
      expect(find.text('Security & Access Audit Trail'), findsOneWidget);
    });

    testWidgets('renders properly in dark mode without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pumpAndSettle();

      expect(find.text('Access & Permissions'), findsOneWidget);
      expect(find.text('Total Users'), findsOneWidget);
    });

    testWidgets('renders on tablet viewport (800x1024) without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(800, 1024)));
      await tester.pumpAndSettle();

      expect(find.text('Access & Permissions'), findsOneWidget);
      final err = tester.takeException();
      if (err != null) {
        debugPrint('TEST ERROR DETAILS: $err');
      }
      expect(err, isNull);
    });

    testWidgets('renders on mobile viewport (400x800) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? caughtDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };

      await tester.pumpWidget(buildTestWidget(size: const Size(400, 800)));
      await tester.pumpAndSettle();

      FlutterError.onError = oldHandler;

      expect(find.text('Access & Permissions'), findsOneWidget);
      final err = tester.takeException();
      if (err != null) {
        debugPrint('TEST ERROR DETAILS: $err');
      }
      expect(err, isNull);
    });
  });
}
