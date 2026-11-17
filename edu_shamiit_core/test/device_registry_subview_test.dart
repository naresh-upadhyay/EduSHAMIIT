import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_registry_subview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      currentState: {'power': 'ON', 'temperature': 23},
      ratedPowerWatts: 1500,
      ipAddress: '192.168.1.101',
      macAddress: '00:1B:44:11:3A:B7',
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
      ratedPowerWatts: 120,
      ipAddress: '192.168.1.102',
      macAddress: '00:1B:44:11:3A:B8',
    ),
    const DeviceItemModel(
      id: 'dev-3',
      deviceCode: 'CAM-B2-F1-01',
      deviceName: 'Library Corridor Camera',
      typeCode: 'cctv',
      typeName: 'CCTV Camera',
      typeIcon: 'videocam',
      buildingCode: 'B2',
      floorCode: 'F1',
      roomNumber: 'COR-1',
      locationDisplay: 'Library Block > First Floor',
      isOnline: false,
      powerState: false,
      currentState: {'status': 'disconnected'},
      ratedPowerWatts: 35,
      ipAddress: '192.168.2.55',
      macAddress: '00:1B:44:11:3A:C9',
    ),
  ];

  const sampleKpis = DeviceManagementKpis(
    totalDevices: 222,
    online: 215,
    offline: 7,
    onlinePercentage: 96.8,
    deviceTypes: 12,
    buildingsCount: 5,
    floorsCount: 5,
    roomsCount: 5,
    locationsSummary: '5 Buildings • 5 Floors',
  );

  Widget buildTestWidget({
    Size surfaceSize = const Size(1200, 800),
    Brightness brightness = Brightness.dark,
    VoidCallback? onBackToDashboard,
    List<DeviceItemModel>? devices,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: DeviceRegistrySubview(
              onBackToDashboard: onBackToDashboard,
              initialDevices: devices ?? sampleDevices,
              initialKpis: sampleKpis,
              initialBuildings: const ['All Buildings', 'Academic Block (A)', 'Library Block'],
              initialTypes: const ['All Device Types', 'AC (HVAC)', 'Lighting', 'CCTV Camera'],
            ),
          ),
        ),
      ),
    );
  }

  group('Device Registry Subview Comprehensive Tests', () {
    testWidgets('renders Header with Back button, Title, Refresh and Add Device button (Zero double ++)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      bool backTapped = false;

      await tester.pumpWidget(buildTestWidget(
        onBackToDashboard: () => backTapped = true,
      ));
      await tester.pump();

      // Check title & subtitle
      expect(find.text('Campus Device Registry & Fleet Control'), findsOneWidget);
      expect(find.byTooltip('Back to Dashboard'), findsOneWidget);
      expect(find.byTooltip('Refresh Registry'), findsOneWidget);

      // Verify Add Device button has exactly one label "Add Device" and no double "++"
      expect(find.text('Add Device'), findsOneWidget);
      expect(find.text('++'), findsNothing);
      expect(find.text('+ +'), findsNothing);
      expect(find.text('+ Create'), findsNothing);

      // Test back button
      await tester.tap(find.byTooltip('Back to Dashboard'));
      expect(backTapped, isTrue);
    });

    testWidgets('renders Real-Time Fleet KPI Cards with live metric labels', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Verify KPI cards rendered
      expect(find.text('Total Devices'), findsOneWidget);
      expect(find.text('222'), findsOneWidget);
      expect(find.text('Online Fleet'), findsOneWidget);
      expect(find.text('215'), findsOneWidget);
      expect(find.text('Offline / Attention'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Device Types'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Campus Coverage'), findsOneWidget);
      expect(find.text('5 Blocks'), findsOneWidget);
    });

    testWidgets('renders Filter Bar with Search, Dynamic Dropdowns and Clear button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search device (name, code, IP, MAC, room)...'), findsOneWidget);

      // Dropdown initial values
      expect(find.text('All Buildings'), findsOneWidget);
      expect(find.text('All Device Types'), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('active filters badges appear when search is entered and can be reset', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Camera');
      await tester.pump();

      // Active filters badge should appear
      expect(find.text('Active Filters:'), findsOneWidget);
      expect(find.text('Search: "Camera"'), findsOneWidget);
      expect(find.text('Reset All'), findsOneWidget);

      // Tap Reset All
      await tester.tap(find.text('Reset All'));
      await tester.pump();

      // Badge should disappear and text cleared
      expect(find.text('Active Filters:'), findsNothing);
    });

    testWidgets('table renders single checkbox per row and single in header (Zero double checkboxes)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Header has 1 checkbox + 3 rows each have 1 checkbox = 4 total checkboxes
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(4));

      // Verify row data rendered
      expect(find.text('CR-1 Master AC'), findsOneWidget);
      expect(find.text('CR-1 Ambient Lights'), findsOneWidget);
      expect(find.text('Library Corridor Camera'), findsOneWidget);
      expect(find.text('AC-B1-GF-CR1-01'), findsOneWidget);
      expect(find.text('192.168.1.101'), findsOneWidget);
    });

    testWidgets('sticky batch selection toolbar appears when row checkbox is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Initially no batch toolbar
      expect(find.text('1 Selected'), findsNothing);

      // Tap the first row checkbox (index 1 because index 0 is header)
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(1));
      await tester.pump();

      // Batch action toolbar should appear
      expect(find.text('1 Selected'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Reboot'), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);
      expect(find.text('Deselect'), findsOneWidget);

      // Tap Deselect
      await tester.tap(find.text('Deselect'));
      await tester.pump();

      expect(find.text('1 Selected'), findsNothing);
    });

    testWidgets('database sort headers exist and are clickable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Find sortable headers
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Device Code'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('IP / MAC'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);

      // Tap Device Name header to sort
      await tester.tap(find.text('Device Name'));
      await tester.pump();

      // Tap Device Code header to sort
      await tester.tap(find.text('Device Code'));
      await tester.pump();
    });

    testWidgets('pagination footer displays bounds, page size dropdown and stepper', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Showing 1 - 3 of 3 devices
      expect(find.text('Showing 1 - 3 of 3 devices'), findsOneWidget);
      expect(find.text('Rows per page:'), findsOneWidget);

      // Stepper icons
      expect(find.byTooltip('First Page'), findsOneWidget);
      expect(find.byTooltip('Previous Page'), findsOneWidget);
      expect(find.byTooltip('Next Page'), findsOneWidget);
      expect(find.byTooltip('Last Page'), findsOneWidget);
    });

    testWidgets('responsive layout on mobile viewport (400x800) with zero overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(400, 800)));
      await tester.pump();

      // Verify no exceptions or overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Campus Device Registry & Fleet Control'), findsOneWidget);
      expect(find.text('Add Device'), findsOneWidget);
    });

    testWidgets('responsive layout on tablet viewport (900x800) with zero overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(900, 800)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Campus Device Registry & Fleet Control'), findsOneWidget);
      expect(find.text('Add Device'), findsOneWidget);
    });

    testWidgets('light theme compatibility without errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.light));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Campus Device Registry & Fleet Control'), findsOneWidget);
    });
  });
}
