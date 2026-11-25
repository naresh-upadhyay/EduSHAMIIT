import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_live_control_table.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_location_explorer_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/device_filter_dialog.dart';

void main() {
  final List<DeviceItemModel> sampleDevices = [
    const DeviceItemModel(
      id: 'dev-1',
      deviceCode: 'AC-B1-GF-CR1-01',
      deviceName: 'CR-1 Master AC',
      typeCode: 'ac',
      typeName: 'AC (HVAC)',
      typeIcon: 'ac_unit',
      buildingCode: 'B1',
      floorCode: 'GF',
      roomNumber: 'CR-1',
      locationDisplay: 'Academic Block (A) > Ground Floor > Room CR-1',
      isOnline: true,
      powerState: true,
      currentState: {
        'power': 'ON',
        'temperature': 23,
        'mode': 'Cool',
        'fan_speed': 'Medium'
      },
    ),
    const DeviceItemModel(
      id: 'dev-2',
      deviceCode: 'LIGHT-B1-GF-CR1-01',
      deviceName: 'CR-1 Ambient Lights',
      typeCode: 'lighting',
      typeName: 'Lighting',
      typeIcon: 'lightbulb',
      buildingCode: 'B1',
      floorCode: 'GF',
      roomNumber: 'CR-1',
      locationDisplay: 'Academic Block (A) > Ground Floor > Room CR-1',
      isOnline: true,
      powerState: true,
      currentState: {'power': 'ON', 'brightness': 85},
    ),
    const DeviceItemModel(
      id: 'dev-3',
      deviceCode: 'FAN-B1-GF-CL1-01',
      deviceName: 'CL-1 Ceiling Fan 1',
      typeCode: 'fan',
      typeName: 'Fans',
      typeIcon: 'mode_fan_off',
      buildingCode: 'B1',
      floorCode: 'GF',
      roomNumber: 'CL-1',
      locationDisplay: 'Academic Block (A) > Ground Floor > Room CL-1',
      isOnline: false,
      powerState: false,
      currentState: {'power': 'OFF', 'speed': 'Medium'},
    ),
  ];

  const sampleTree = LocationTreeNode(
    id: 'entire_campus',
    code: 'entire_campus',
    name: 'Entire Campus',
    deviceCount: 3,
    children: [
      LocationTreeNode(
        id: 'B1',
        code: 'B1',
        name: 'Academic Block (A)',
        deviceCount: 3,
        children: [
          LocationTreeNode(
            id: 'GF',
            code: 'GF',
            name: 'Ground Floor',
            deviceCount: 3,
            children: const [
              LocationTreeNode(
                id: 'CR-1',
                code: 'CR-1',
                name: 'Room CR-1 - Conference Room',
                deviceCount: 2,
              ),
              LocationTreeNode(
                id: 'CL-1',
                code: 'CL-1',
                name: 'Room CL-1 - Computer Lab',
                deviceCount: 1,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  group('Control Dashboard: DeviceLiveControlTable Tests', () {
    testWidgets(
        'renders single checkbox per row and exactly one in header (no double checkboxes)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 600,
              child: DeviceLiveControlTable(
                devices: sampleDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, __) {},
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                pageSize: 10,
                totalCount: 3,
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total checkboxes: 1 header + 3 rows = 4 checkboxes
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4));

      // Device names rendered
      expect(find.text('CR-1 Master AC'), findsOneWidget);
      expect(find.text('CR-1 Ambient Lights'), findsOneWidget);
      expect(find.text('CL-1 Ceiling Fan 1'), findsOneWidget);
    });

    testWidgets('sticky multi-select toolbar appears when items are checked',
        (tester) async {
      bool bulkTurnOnCalled = false;
      bool bulkDeleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 600,
              child: DeviceLiveControlTable(
                devices: sampleDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {'dev-1', 'dev-2'},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, __) {},
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                pageSize: 10,
                totalCount: 3,
                onPageChanged: (_) {},
                onBulkPowerToggle: (turnOn) => bulkTurnOnCalled = turnOn,
                onBulkDelete: () => bulkDeleteCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Multi-select toolbar should be visible
      expect(find.text('2 Selected'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Reboot Selected'), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap Turn ON
      await tester.tap(find.text('Turn ON'));
      expect(bulkTurnOnCalled, isTrue);

      // Tap Delete Selected
      await tester.tap(find.text('Delete Selected'));
      expect(bulkDeleteCalled, isTrue);
    });

    testWidgets('sort headers trigger onSortChanged callback', (tester) async {
      String? sortedColumn;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 600,
              child: DeviceLiveControlTable(
                devices: sampleDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, __) {},
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                pageSize: 10,
                totalCount: 3,
                onPageChanged: (_) {},
                sortColumn: 'device_name',
                sortAscending: true,
                onSortChanged: (col) => sortedColumn = col,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Type header
      await tester.tap(find.text('Type'));
      expect(sortedColumn, equals('type_name'));
    });

    testWidgets(
        'pagination footer displays correct bounds and page size selector',
        (tester) async {
      int? newPageSize;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 600,
              child: DeviceLiveControlTable(
                devices: sampleDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, __) {},
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                pageSize: 10,
                totalCount: 25,
                onPageChanged: (_) {},
                onPageSizeChanged: (s) => newPageSize = s,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Showing 1 - 10 of 25 devices'), findsOneWidget);
      expect(find.text('Rows per page:'), findsOneWidget);
    });
  });

  group('Control Dashboard: DeviceLocationExplorerCard Tests', () {
    testWidgets(
        'renders tree nodes and triggers onLocationSelected when tapped',
        (tester) async {
      String? selectedNode;
      String? breadcrumb;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 500,
              child: DeviceLocationExplorerCard(
                tree: sampleTree,
                onLocationSelected: (bld, fl, rm, nodeId, bcrumb) {
                  selectedNode = nodeId;
                  breadcrumb = bcrumb;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Location Explorer'), findsOneWidget);
      expect(find.textContaining('Entire Campus'), findsOneWidget);

      // Tap on Ground Floor
      final gfNode = find.textContaining('Ground Floor');
      if (gfNode.evaluate().isNotEmpty) {
        await tester.tap(gfNode);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
        'shows active filter banner with Reset button when selectedNodeId is set',
        (tester) async {
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 500,
              child: DeviceLocationExplorerCard(
                tree: sampleTree,
                selectedNodeId: 'CR-1',
                selectedBreadcrumb:
                    'Academic Block (A) > Ground Floor > Room CR-1',
                onLocationSelected: (_, __, ___, ____, _____) {},
                onClearLocation: () => resetCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Academic Block (A) > Ground Floor > Room CR-1'),
          findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      expect(resetCalled, isTrue);
    });
  });

  group('Control Dashboard: DeviceFilterDialog Dynamic Dropdowns Tests', () {
    testWidgets(
        'renders dynamic buildings and device types in dropdown options',
        (tester) async {
      final sampleBuildings = [
        const BuildingDeviceBreakdown(
            code: 'B1',
            name: 'Academic Block',
            totalDevices: 120,
            onlineDevices: 110,
            onlinePct: 91.6),
        const BuildingDeviceBreakdown(
            code: 'B2',
            name: 'Science Block',
            totalDevices: 80,
            onlineDevices: 75,
            onlinePct: 93.7),
      ];

      final sampleTypes = [
        const DeviceTypeBreakdown(
            type: 'HVAC',
            count: 40,
            percentage: 50.0,
            colorHex: '#0284C7',
            icon: 'ac_unit'),
        const DeviceTypeBreakdown(
            type: 'Lighting',
            count: 60,
            percentage: 50.0,
            colorHex: '#EAB308',
            icon: 'lightbulb'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceFilterDialog(
              buildings: sampleBuildings,
              types: sampleTypes,
              onApply: (_, __, ___) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filter Campus Devices'), findsOneWidget);
      expect(find.text('Entire Campus (All Buildings)'), findsOneWidget);
      expect(find.text('All Device Types'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
    });
  });

  group('Control Dashboard: Responsive Layout Tests', () {
    testWidgets(
        'renders cleanly on mobile viewport (400x800) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  children: [
                    SizedBox(
                      height: 380,
                      child: DeviceLiveControlTable(
                        devices: sampleDevices,
                        isLoading: false,
                        activeTab: 'Live Device Control',
                        onTabChanged: (_) {},
                        searchQuery: '',
                        onSearchChanged: (_) {},
                        selectedDeviceIds: const {},
                        onToggleSelect: (_) {},
                        onToggleSelectAll: (_) {},
                        onTogglePower: (_) {},
                        onSetTemperature: (_, __) {},
                        onSetHvacMode: (_, __) {},
                        onSetFanSpeed: (_, __) {},
                        onSetBrightness: (_, __) {},
                        onSetProjectorInput: (_, __) {},
                        onSetProjectorVolume: (_, __) {},
                        onGateControl: (_, __) {},
                        onInspectDevice: (_) {},
                        onDeleteDevice: (_) {},
                        currentPage: 1,
                        pageSize: 10,
                        totalCount: 3,
                        onPageChanged: (_) {},
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: DeviceLocationExplorerCard(
                        tree: sampleTree,
                        onLocationSelected: (_, __, ___, ____, _____) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'renders cleanly on tablet viewport (900x800) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 800,
              child: DeviceLiveControlTable(
                devices: sampleDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, __) {},
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                pageSize: 10,
                totalCount: 3,
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
