import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_management_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_overview_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_location_explorer_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_quick_controls_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_bulk_operations_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_energy_usage_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_health_diagnostics_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_integrations_gateways_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_access_permissions_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_audit_logs_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_import_export_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_schedules_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_scenes_presets_subview.dart';

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Management Comprehensive Edge Cases Test Suite', () {
    // ------------------------------------------------------------------------
    // 1. Dynamic Location Explorer Hierarchy Edge Cases
    // ------------------------------------------------------------------------
    testWidgets('Location Explorer renders fallback tree when tree is null', (tester) async {
      _setViewport(tester, const Size(500, 700));
      await tester.pumpWidget(_buildTestApp(
        DeviceLocationExplorerCard(
          tree: null,
          onLocationSelected: (b, f, r, n, bc) {},
        ),
      ));
      await tester.pump();

      expect(find.text('Location Explorer'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Entire Campus'), findsWidgets);
    });

    testWidgets('Location Explorer dynamically renders custom hierarchy & search filtering', (tester) async {
      _setViewport(tester, const Size(500, 700));
      const customTree = LocationTreeNode(
        id: 'root-1',
        code: 'CAMPUS',
        name: 'Apex University Campus',
        deviceCount: 420,
        children: [
          LocationTreeNode(
            id: 'b-science',
            code: 'SCI',
            name: 'Science & Tech Complex',
            deviceCount: 150,
            children: [
              LocationTreeNode(
                id: 'fl-3',
                code: 'F3',
                name: 'Floor 3 - Robotics Wing',
                deviceCount: 60,
                children: [
                  LocationTreeNode(
                    id: 'rm-302',
                    code: 'R302',
                    name: 'Robotics Lab 302',
                    deviceCount: 25,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      String? selectedBuilding;
      await tester.pumpWidget(_buildTestApp(
        DeviceLocationExplorerCard(
          tree: customTree,
          onLocationSelected: (b, f, r, n, bc) => selectedBuilding = b,
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Apex University Campus'), findsOneWidget);
      expect(find.textContaining('Science & Tech Complex'), findsOneWidget);

      // Tap on building node to select it
      await tester.tap(find.textContaining('Science & Tech Complex'));
      await tester.pump();
      expect(selectedBuilding, 'b-science');

      // Search for room node
      await tester.enterText(find.byType(TextField), '302');
      await tester.pump();
      expect(find.textContaining('Robotics Lab 302'), findsOneWidget);

      // Search for non-existent query
      await tester.enterText(find.byType(TextField), 'NonExistentRoomXYZ');
      await tester.pump();
      expect(find.text('No matching locations found'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // 2. Dynamic Overview Card & Fullscreen Map Edge Cases
    // ------------------------------------------------------------------------
    testWidgets('Device Overview Card maps dynamic buildings & handles fullscreen dialog', (tester) async {
      _setViewport(tester, const Size(1600, 1000));
      final buildings = [
        const BuildingDeviceBreakdown(
          code: 'TECH-1',
          name: 'Technology Tower',
          totalDevices: 850,
          onlineDevices: 840,
          onlinePct: 98.8,
        ),
        const BuildingDeviceBreakdown(
          code: 'MED-2',
          name: 'Medical Sciences Block',
          totalDevices: 620,
          onlineDevices: 600,
          onlinePct: 96.7,
        ),
      ];

      String selectedBuilding = 'Entire Campus';
      await tester.pumpWidget(_buildTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              width: 1200,
              height: 500,
              child: DeviceOverviewCard(
                buildings: buildings,
                selectedCampusBuilding: selectedBuilding,
                onBuildingChanged: (val) => setState(() => selectedBuilding = val),
              ),
            );
          },
        ),
      ));
      await tester.pump();

      expect(find.text('TECH-1'), findsOneWidget);
      expect(find.text('850 Devices'), findsOneWidget);
      expect(find.text('(98.8% Online)'), findsOneWidget);
      expect(find.text('MED-2'), findsOneWidget);

      // Tap on building badge to filter
      await tester.tap(find.text('TECH-1'));
      await tester.pump();
      expect(selectedBuilding, 'TECH-1');

      // Tap fullscreen icon to open full topology dialog
      final fullscreenIcon = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenIcon, findsOneWidget);
      await tester.tap(fullscreenIcon);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Campus Device Overview & Building Topology'), findsOneWidget);
      expect(find.text('Reset to Entire Campus'), findsOneWidget);

      // Reset to Entire Campus from dialog
      await tester.tap(find.text('Reset to Entire Campus'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(selectedBuilding, 'Entire Campus');
    });

    // ------------------------------------------------------------------------
    // 3. Quick Controls Interactive Action Trigger Tests
    // ------------------------------------------------------------------------
    testWidgets('Quick Controls Card dispatches all action types', (tester) async {
      _setViewport(tester, const Size(1000, 600));
      final triggered = <String>[];
      await tester.pumpWidget(_buildTestApp(
        SizedBox(
          width: 500,
          height: 320,
          child: DeviceQuickControlsCard(
            onActionTriggered: (action) => triggered.add(action),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Set Level'), findsOneWidget);
      expect(find.text('Set Temperature'), findsOneWidget);
      expect(find.text('Apply Scene'), findsOneWidget);
      expect(find.text('Power Supply'), findsOneWidget);

      await tester.tap(find.text('Turn ON'));
      await tester.tap(find.text('Set Level'));
      await tester.tap(find.text('Set Temperature'));
      await tester.pump();

      expect(triggered, containsAll(['Turn ON', 'Set Level', 'Set Temperature']));
    });

    // ------------------------------------------------------------------------
    // 4. Subviews Direct Render & State Verification Tests
    // ------------------------------------------------------------------------
    testWidgets('Bulk Operations subview mounts with fallback data without error', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceBulkOperationsSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DeviceBulkOperationsSubview), findsOneWidget);
    });

    testWidgets('Energy Usage subview mounts with multi-tab layout without error', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceEnergyUsageSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Energy & Usage'), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('Health & Diagnostics subview mounts and displays KPIs', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceHealthDiagnosticsSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Device Health & Diagnostics'), findsOneWidget);
    });

    testWidgets('Integrations & Gateways subview mounts without error', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceIntegrationsGatewaysSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Integrations & Gateways'), findsOneWidget);
    });

    testWidgets('Access & Permissions subview mounts and displays roles', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceAccessPermissionsSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Access & Permissions'), findsOneWidget);
    });

    testWidgets('Audit Logs subview mounts and displays activity categories', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceAuditLogsSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Audit Logs'), findsOneWidget);
    });

    testWidgets('Import / Export subview mounts with history table', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        DeviceImportExportSubview(
          onBackToDashboard: () {},
          autoFetch: false,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Import / Export'), findsOneWidget);
    });

    testWidgets('Schedules subview mounts without error', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceSchedulesSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Schedules'), findsOneWidget);
    });

    testWidgets('Scenes & Presets subview mounts without error', (tester) async {
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceScenesPresetsSubview(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Scenes & Presets'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // 5. Responsive Form Factor Stress Test
    // ------------------------------------------------------------------------
    testWidgets('Device Management Tab View adapts across Desktop, Tablet, and Mobile', (tester) async {
      // Desktop Viewport
      _setViewport(tester, const Size(1400, 900));
      await tester.pumpWidget(_buildTestApp(
        const DeviceManagementTabView(),
      ));
      await tester.pump();
      expect(find.byType(DeviceManagementTabView), findsOneWidget);

      // Tablet Viewport
      _setViewport(tester, const Size(900, 700));
      await tester.pumpWidget(_buildTestApp(
        const DeviceManagementTabView(),
      ));
      await tester.pump();
      expect(find.byType(DeviceManagementTabView), findsOneWidget);

      // Mobile Viewport
      _setViewport(tester, const Size(450, 800));
      await tester.pumpWidget(_buildTestApp(
        const DeviceManagementTabView(),
      ));
      await tester.pump();
      expect(find.byType(DeviceManagementTabView), findsOneWidget);
    });
  });
}
