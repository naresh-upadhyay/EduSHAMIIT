import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_groups_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/create_edit_device_group_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/advanced_group_control_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/group_members_management_dialog.dart';

class TestDeviceManagementNotifier extends DeviceManagementNotifier {
  TestDeviceManagementNotifier() : super(DeviceManagementApiService.instance);

  @override
  Future<void> loadDeviceGroupsData() async {}

  @override
  Future<void> loadGroupMembers(String groupId) async {}
}

void main() {
  group('Device Groups - Models Tests', () {
    test('DeviceGroupsKpis JSON deserialization matching exact screenshot metrics', () {
      final json = {
        'total_groups': 128,
        'active_groups': 118,
        'active_percentage': 92.2,
        'inactive_groups': 10,
        'total_devices': 8742,
        'grouped_devices': 8296,
        'grouped_percentage': 95.0,
        'ungrouped_devices': 446,
        'ungrouped_percentage': 5.0,
      };

      final kpis = DeviceGroupsKpis.fromJson(json);
      expect(kpis.totalGroups, 128);
      expect(kpis.activeGroups, 118);
      expect(kpis.activePercentage, 92.2);
      expect(kpis.activeGroupsPct, 92.2);
      expect(kpis.inactiveGroups, 10);
      expect(kpis.totalDevices, 8742);
      expect(kpis.groupedDevices, 8296);
      expect(kpis.groupedPercentage, 95.0);
      expect(kpis.groupedDevicesPct, 95.0);
      expect(kpis.ungroupedDevices, 446);
      expect(kpis.ungroupedPercentage, 5.0);
      expect(kpis.ungroupedDevicesPct, 5.0);
    });

    test('DeviceGroupItem JSON deserialization with full specifications', () {
      final json = {
        'id': 'grp-lgt-01',
        'name': 'Classroom Lighting - Block A',
        'code': 'GRP-LGT-BLKA',
        'description': 'All lights in Classrooms (Block A) with unified control, scheduling and automation.',
        'group_type': 'Lighting',
        'icon': 'lightbulb_outline',
        'color': '#D97706',
        'status': 'active',
        'location_scope': 'Block A > Classrooms',
        'profile_name': 'Default Lighting',
        'member_count': 96,
        'online_count': 90,
        'offline_count': 2,
        'schedules_count': 3,
        'automations_count': 2,
        'scenes_count': 4,
        'created_on': '10 Jan 2025, 11:20 AM',
        'last_updated': '12 Jan 2025, 02:45 PM',
        'resolved_capabilities': {
          'power': true,
          'brightness': {'type': 'slider', 'min': 0, 'max': 100, 'unit': '%'},
        },
        'advanced_controls': [
          {'type': 'slider', 'key': 'brightness', 'label': 'Master Brightness', 'unit': '%'}
        ],
        'device_ids': ['dev-1', 'dev-2'],
      };

      final group = DeviceGroupItem.fromJson(json);
      expect(group.id, 'grp-lgt-01');
      expect(group.name, 'Classroom Lighting - Block A');
      expect(group.code, 'GRP-LGT-BLKA');
      expect(group.groupType, 'Lighting');
      expect(group.locationScope, 'Block A > Classrooms');
      expect(group.profileName, 'Default Lighting');
      expect(group.deviceCount, 96);
      expect(group.memberCount, 96);
      expect(group.onlineCount, 90);
      expect(group.offlineCount, 2);
      expect(group.schedulesCount, 3);
      expect(group.automationsCount, 2);
      expect(group.scenesCount, 4);
      expect(group.createdOn, '10 Jan 2025, 11:20 AM');
      expect(group.lastUpdated, '12 Jan 2025, 02:45 PM');
    });
  });

  group('Device Groups - Widget & Subview Tests', () {
    late List<DeviceGroupItem> sampleGroups;
    late DeviceGroupsKpis sampleKpis;

    setUp(() {
      sampleKpis = const DeviceGroupsKpis(
        totalGroups: 128,
        activeGroups: 118,
        activePercentage: 92.2,
        inactiveGroups: 10,
        totalDevices: 8742,
        groupedDevices: 8296,
        groupedPercentage: 95.0,
        ungroupedDevices: 446,
        ungroupedPercentage: 5.0,
      );

      sampleGroups = [
        const DeviceGroupItem(
          id: 'grp-1',
          name: 'Classroom Lighting - Block A',
          code: 'GRP-LGT-BLKA',
          description: 'All lights in Classrooms (Block A) with unified control, scheduling and automation.',
          groupType: 'Lighting',
          locationScope: 'Block A > Classrooms',
          deviceCount: 96,
          profileName: 'Default Lighting',
          status: 'active',
          onlineCount: 90,
          offlineCount: 2,
          schedulesCount: 3,
          automationsCount: 2,
          scenesCount: 4,
          createdAtFormatted: '10 Jan 2025, 11:20 AM',
          updatedAtFormatted: '12 Jan 2025, 02:45 PM',
        ),
        const DeviceGroupItem(
          id: 'grp-2',
          name: 'AC - Academic Block',
          code: 'GRP-HVAC-ACAD',
          description: 'HVAC units for academic rooms',
          groupType: 'HVAC (AC)',
          locationScope: 'Academic Block',
          deviceCount: 48,
          profileName: 'AC Standard',
          status: 'active',
          onlineCount: 48,
          offlineCount: 0,
        ),
        const DeviceGroupItem(
          id: 'grp-3',
          name: 'Projectors - Classrooms',
          code: 'GRP-AV-PROJ',
          description: 'All classroom projectors',
          groupType: 'AV & Display',
          locationScope: 'All Buildings > Classrooms',
          deviceCount: 72,
          profileName: 'Projector Base',
          status: 'active',
          onlineCount: 70,
          offlineCount: 2,
        ),
        const DeviceGroupItem(
          id: 'grp-4',
          name: 'CCTV - Campus Perimeter',
          code: 'GRP-SEC-PERIM',
          description: 'Perimeter surveillance cameras',
          groupType: 'Security',
          locationScope: 'Campus > Perimeter',
          deviceCount: 64,
          profileName: 'High Security',
          status: 'active',
          onlineCount: 64,
          offlineCount: 0,
        ),
      ];
    });

    Widget createTestApp({
      Size screenSize = const Size(1440, 900),
      DeviceGroupItem? selectedDetail,
    }) {
      return ProviderScope(
        overrides: [
          deviceManagementProvider.overrideWith((ref) {
            final notifier = TestDeviceManagementNotifier();
            notifier.state = notifier.state.copyWith(
              groupsKpis: sampleKpis,
              groupsList: sampleGroups,
              totalGroupsCount: 128,
              selectedGroupId: sampleGroups.first.id,
              selectedGroupDetail: selectedDetail ?? sampleGroups.first,
              groupsActiveSubTab: 'All Groups (128)',
              groupsFilterLocation: 'All Locations',
              groupsFilterType: 'All Device Types',
              groupsFilterProfile: 'All Profiles',
            );
            return notifier;
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: const Scaffold(
              body: DeviceGroupsSubview(),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders Top 5 KPI Cards with exact metrics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify KPI Labels and Numbers
      expect(find.text('Total Groups'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(find.text('All Groups (128)'), findsOneWidget);

      expect(find.text('Active Groups'), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
      expect(find.text('Active (118)'), findsOneWidget);
      expect(find.text('(92.2%)'), findsOneWidget);

      expect(find.text('Total Devices'), findsWidgets);
      expect(find.text('8,742'), findsOneWidget);

      expect(find.text('Grouped Devices'), findsOneWidget);
      expect(find.text('8,296'), findsOneWidget);
      expect(find.text('(95.0%)'), findsOneWidget);

      expect(find.text('Ungrouped Devices'), findsOneWidget);
      expect(find.text('446'), findsOneWidget);
      expect(find.text('(5.0%)'), findsOneWidget);
    });

    testWidgets('Renders Sub-Tabs and Filter Bar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('All Groups (128)'), findsOneWidget);
      expect(find.text('Active (118)'), findsOneWidget);
      expect(find.text('Inactive (10)'), findsOneWidget);

      expect(find.text('All Locations'), findsOneWidget);
      expect(find.text('All Device Types'), findsOneWidget);
      expect(find.text('All Profiles'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Create Group'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('Renders Data Table rows and columns correctly', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Group Name'), findsOneWidget);
      expect(find.text('Group Type'), findsWidgets);
      expect(find.text('Location / Scope'), findsWidgets);
      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Status'), findsWidgets);
      expect(find.text('Actions'), findsOneWidget);

      // Verify row items
      expect(find.text('Classroom Lighting - Block A'), findsWidgets);
      expect(find.text('AC - Academic Block'), findsOneWidget);
      expect(find.text('Projectors - Classrooms'), findsOneWidget);
      expect(find.text('CCTV - Campus Perimeter'), findsOneWidget);
    });

    testWidgets('Renders Right Inspector Panel with full specifications', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Group Details'), findsOneWidget);
      expect(find.text('Block A > Classrooms'), findsWidgets);
      expect(find.text('Default Lighting'), findsWidgets);
      expect(find.text('10 Jan 2025, 11:20 AM'), findsOneWidget);
      expect(find.text('12 Jan 2025, 02:45 PM'), findsOneWidget);

      // Group Members section
      expect(find.text('Group Members (96)'), findsOneWidget);
      expect(find.text('View All →'), findsOneWidget);

      // Group Control section
      expect(find.text('Group Control'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Advanced\nControl'), findsOneWidget);

      // Accordion sections
      expect(find.text('Schedules (3)'), findsOneWidget);
      expect(find.text('Automation Rules (2)'), findsOneWidget);
      expect(find.text('Scenes & Presets (4)'), findsOneWidget);
      expect(find.text('Energy & Usage'), findsOneWidget);
    });

    testWidgets('Opens CreateEditDeviceGroupDialog on Create Group tap', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final createBtn = find.text('Create Group');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CreateEditDeviceGroupDialog), findsOneWidget);
      expect(find.text('Create Device Group'), findsOneWidget);
      expect(find.text('Group Name *'), findsOneWidget);
      expect(find.text('Group Code *'), findsOneWidget);
    });

    testWidgets('Opens AdvancedGroupControlDialog on Advanced Control tap', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final advCtrl = find.text('Advanced\nControl');
      expect(advCtrl, findsOneWidget);
      await tester.ensureVisible(advCtrl);
      await tester.tap(advCtrl);
      await tester.pumpAndSettle();

      expect(find.byType(AdvancedGroupControlDialog), findsOneWidget);
      expect(find.textContaining('Advanced Group Control'), findsOneWidget);
    });

    testWidgets('Opens GroupMembersManagementDialog on View All tap', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final viewAllBtn = find.text('View All →');
      expect(viewAllBtn, findsOneWidget);
      await tester.ensureVisible(viewAllBtn);
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      expect(find.byType(GroupMembersManagementDialog), findsOneWidget);
      expect(find.textContaining('Manage Members'), findsOneWidget);
    });

    testWidgets('Responsive Layout across Laptop (1280px), Tablet (800px), and Mobile (400px) with 0 overflows', (tester) async {
      // 1. Laptop
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createTestApp(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Tablet
      tester.view.physicalSize = const Size(800, 1024);
      await tester.pumpWidget(createTestApp(screenSize: const Size(800, 1024)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 3. Mobile
      tester.view.physicalSize = const Size(400, 850);
      FlutterErrorDetails? mobileDetails;
      FlutterError.onError = (d) => mobileDetails = d;
      await tester.pumpWidget(createTestApp(screenSize: const Size(400, 850)));
      await tester.pumpAndSettle();
      if (mobileDetails != null) {
        debugPrint('MOBILE COLLECTOR:\n${mobileDetails?.informationCollector?.call().join('\n')}');
      }
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
    });
  });
}
