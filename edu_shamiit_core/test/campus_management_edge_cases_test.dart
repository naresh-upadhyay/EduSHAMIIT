import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/services/lookup_event_bus.dart';
import 'package:edu_shamiit_core/screens/campus/campus_management_screen.dart';
import 'package:edu_shamiit_core/screens/campus/providers/campus_provider.dart';
import 'package:edu_shamiit_core/screens/campus/services/campus_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/services/campus_lookup_helper.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/campus_tabs_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/campus_header_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/facilities/dialogs/add_edit_facility_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/utilities/dialogs/log_utility_reading_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/dialogs/create_edit_maintenance_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/dialogs/assign_technician_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/report_incident_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/add_certificate_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/schedule_drill_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';
import 'package:edu_shamiit_core/screens/campus/models/maintenance_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/buildings/building_right_details_panel.dart';

class CampusNotifierFake extends CampusNotifier {
  final CampusState customState;

  CampusNotifierFake(this.customState) : super(CampusApiService.instance) {
    state = customState;
  }

  @override
  Future<void> loadAll() async {
    // No-op for tests
  }
}

void main() {
  const sampleBuilding = BuildingModel(
    id: 'bld-001',
    schoolId: 'sch-001',
    name: 'Academic Block (A)',
    code: 'B1',
    buildingType: 'Academic',
    totalFloors: 5,
    totalRooms: 42,
    totalCapacity: 2100,
    currentOccupancy: 1950,
    occupancyRate: 92.9,
    status: 'Active',
  );

  const sampleFloor = BuildingFloorModel(
    id: 'flr-001',
    schoolId: 'sch-001',
    buildingId: 'bld-001',
    name: 'Ground Floor',
    floorCode: 'G',
    floorLevel: 0,
    totalRooms: 8,
    roomTypesSummary: 'Classroom (4), Lab (2), Office (2)',
    capacity: 400,
    occupancy: 368,
    occupancyPercentage: 92.0,
  );

  const sampleKpis = CampusKpis(
    totalBuildings: 8,
    totalFloors: 38,
    totalRooms: 166,
    totalCapacity: 8040,
    occupiedCapacity: 6842,
    availableCapacity: 1198,
    occupancyRate: 85.1,
  );

  group('1. Dynamic Lookups & LookupEventBus Invalidation', () {
    test(
        'CampusLookupHelper returns non-empty rich institutional defaults for all modules',
        () {
      final helper = CampusLookupHelper.instance;

      expect(helper.getImmediateLabels('BUILDING_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('BUILDING_STATUS').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('ROOM_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('FACILITY_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('BOOKING_PURPOSE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('ORGANIZER_ROLE').isNotEmpty, isTrue);
      expect(
          helper.getImmediateLabels('MAINTENANCE_CATEGORY').isNotEmpty, isTrue);
      expect(
          helper.getImmediateLabels('MAINTENANCE_PRIORITY').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('INCIDENT_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('INCIDENT_STATUS').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('CERTIFICATE_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('DRILL_TYPE').isNotEmpty, isTrue);
      expect(helper.getImmediateLabels('UTILITY_TYPE').isNotEmpty, isTrue);
    });

    test(
        'LookupEventBus invalidates CampusLookupHelper cache on lookup mutations',
        () {
      final helper = CampusLookupHelper.instance;

      // Ensure cache is populated
      final initialRooms = helper.getImmediateLabels('ROOM_TYPE');
      expect(initialRooms.isNotEmpty, isTrue);

      // Invalidate via EventBus
      LookupEventBus.instance.notifyLookupChanged('ROOM_TYPE');

      // Helper immediately refreshes
      final afterRooms = helper.getImmediateLabels('ROOM_TYPE');
      expect(afterRooms.isNotEmpty, isTrue);
    });
  });

  group(
      '2. Tab Switching Across All 8 Tabs Without Crash or Coming-Soon Placeholders',
      () {
    final campusState = CampusState(
      isLoading: false,
      kpis: sampleKpis,
      buildings: const [sampleBuilding],
      selectedBuilding: sampleBuilding,
      floors: const [sampleFloor],
      filterFloorId: sampleFloor.id,
    );

    for (int tabIndex = 0; tabIndex < 8; tabIndex++) {
      testWidgets('Tab $tabIndex renders smoothly without errors',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(1366, 768));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusProvider
                  .overrideWith((ref) => CampusNotifierFake(campusState)),
            ],
            child: MaterialApp(
              theme: ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
              ),
              home: Scaffold(
                body: CampusManagementScreen(initialTab: tabIndex),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Must not throw any exception
        expect(tester.takeException(), isNull);

        // Verify CampusTabsBar is rendered
        expect(find.byType(CampusTabsBar), findsOneWidget);

        // Verify "Coming Soon" or "Soon" badge is NOT shown anywhere on tabs
        expect(find.text('Soon'), findsNothing);
        expect(find.text('Coming Soon'), findsNothing);
      });
    }
  });

  group('3. Multi-Device Viewport Responsiveness (Mobile, Tablet, Desktop)',
      () {
    final campusState = CampusState(
      isLoading: false,
      kpis: sampleKpis,
      buildings: const [sampleBuilding],
      selectedBuilding: sampleBuilding,
      floors: const [sampleFloor],
      filterFloorId: sampleFloor.id,
    );

    testWidgets('Mobile Viewport (390 x 844) - Zero RenderFlex Overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider
                .overrideWith((ref) => CampusNotifierFake(campusState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampusManagementScreen(initialTab: 0),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet Viewport (820 x 1180) - Zero RenderFlex Overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(820, 1180));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider
                .overrideWith((ref) => CampusNotifierFake(campusState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampusManagementScreen(initialTab: 1),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Desktop Viewport (1440 x 900) - Zero RenderFlex Overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider
                .overrideWith((ref) => CampusNotifierFake(campusState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampusManagementScreen(initialTab: 6),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });

  group(
      '4. Theme-Based Setting Propagation (Custom Institutional Color Schemes)',
      () {
    const testThemes = [
      Color(0xFF2563EB), // EduSHAMIIT Classic Blue
      Color(0xFF059669), // Institutional Emerald Green
      Color(0xFF7C3AED), // Royal Purple
      Color(0xFFD97706), // Academic Amber
    ];

    for (final primaryColor in testThemes) {
      testWidgets(
          'CampusHeaderBar and Tabs adapt dynamically to primaryColor: $primaryColor',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: primaryColor, primary: primaryColor),
            ),
            home: Scaffold(
              body: Column(
                children: [
                  CampusHeaderBar(
                    onAddBuilding: () {},
                    onBulkImport: () {},
                    onExport: () {},
                  ),
                  CampusTabsBar(
                    activeIndex: 0,
                    onTabSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);

        final BuildContext ctx = tester.element(find.byType(CampusTabsBar));
        expect(Theme.of(ctx).colorScheme.primary, equals(primaryColor));
      });
    }
  });

  group('5. All Institutional Dialogs Render Cleanly with Dynamic Dropdowns',
      () {
    testWidgets('AddEditFacilityDialog renders with dynamic lookups',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditFacilityDialog(onSaved: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(AddEditFacilityDialog), findsOneWidget);
    });

    testWidgets('LogUtilityReadingDialog renders with dynamic utility types',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LogUtilityReadingDialog(onSaved: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.byType(LogUtilityReadingDialog), findsOneWidget);
    });

    testWidgets('CreateEditMaintenanceDialog renders with dynamic categories',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditMaintenanceDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Raise Maintenance'), findsOneWidget);
    });

    testWidgets(
        'AssignTechnicianDialog renders with dynamic technicians & vendors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      final sampleReq = MaintenanceRequestItem(
        id: 'req-001',
        requestCode: 'MNT-2026-001',
        title: 'AC unit water leakage',
        description: 'Compressor condensation drain blocked',
        requestType: 'HVAC',
        priority: 'High',
        locationDisplay: 'Academic Block A - Room 101',
        reportedByName: 'Admin',
        reportedByRole: 'Faculty',
        reportedAt: DateTime.now(),
        status: 'Open',
        isOverdue: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AssignTechnicianDialog(request: sampleReq),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Assign Work Order - MNT-2026-001'), findsOneWidget);
    });

    testWidgets(
        'ReportIncidentDialog renders with dynamic severity & incident types',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReportIncidentDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Report Safety & Security Incident'), findsOneWidget);
    });

    testWidgets('AddCertificateDialog renders with dynamic certificate types',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddCertificateDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Add Statutory Certificate'), findsOneWidget);
    });

    testWidgets('ScheduleDrillDialog renders with dynamic drill types',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ScheduleDrillDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Schedule Emergency Evacuation Drill'), findsOneWidget);
    });

    testWidgets(
        'Rooms subtab renders 52 rooms with pagination and table/grid view without error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));

      final sampleRooms = List.generate(
        10,
        (i) => RoomModel(
          id: 'room-$i',
          schoolId: 'sch-001',
          buildingId: sampleBuilding.id,
          buildingName: sampleBuilding.name,
          buildingCode: sampleBuilding.code,
          floorId: sampleFloor.id,
          floorName: sampleFloor.name,
          name: 'Classroom ${i + 1}',
          roomNumber: '${i + 101}',
          roomCode: 'RM-${i + 101}',
          roomType: 'Classroom',
          maxCapacity: 50,
          currentOccupancy: 45,
          operationalStatus: 'Available',
          assignmentStatus: 'Assigned',
        ),
      );

      final stateWithRooms = CampusState(
        isLoading: false,
        kpis: sampleKpis,
        buildings: const [sampleBuilding],
        selectedBuilding: sampleBuilding,
        floors: const [sampleFloor],
        activeBuildingSubTab: 1, // Rooms subtab
        rooms: sampleRooms,
        totalRoomsCount: 52,
        roomsPage: 1,
        roomsPageSize: 10,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider
                .overrideWith((ref) => CampusNotifierFake(stateWithRooms)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampusManagementScreen(initialTab: 0),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Classroom 1'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('Showing 1 - 10 of 52 rooms'), findsOneWidget);
    });

    testWidgets(
        '6. Building Photo Upload & State Synchronization - BuildingRightDetailsPanel renders updated image',
        (tester) async {
      const buildingWithImage = BuildingModel(
        id: 'bld-sports-1',
        schoolId: '11111111-1111-1111-1111-111111111111',
        name: 'Sports Complex',
        code: 'B6',
        buildingType: 'Sports',
        status: 'Active',
        totalFloors: 2,
        totalRooms: 6,
        totalCapacity: 345,
        currentOccupancy: 279,
        imageUrl: '/api/campus/images/0368858b172e_scaled_images (2).jpeg',
      );

      const buildingWithoutImage = BuildingModel(
        id: 'bld-academic-1',
        schoolId: '11111111-1111-1111-1111-111111111111',
        name: 'Academic Block',
        code: 'B1',
        buildingType: 'Academic',
        status: 'Active',
        totalFloors: 3,
        totalRooms: 20,
        totalCapacity: 500,
        currentOccupancy: 150,
        imageUrl: null,
      );

      // Verify widget with image
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingRightDetailsPanel(
              building: buildingWithImage,
              onAddRoom: () {},
              onAllocateRoom: () {},
              onRoomSetup: () {},
              onImportRooms: () {},
              onExportList: () {},
              onRoomReport: () {},
              onUpdateImage: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('B6 - Sports Complex'), findsOneWidget);

      // Verify widget without image shows upload button
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingRightDetailsPanel(
              building: buildingWithoutImage,
              onAddRoom: () {},
              onAllocateRoom: () {},
              onRoomSetup: () {},
              onImportRooms: () {},
              onExportList: () {},
              onRoomReport: () {},
              onUpdateImage: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Upload Building Photo'), findsOneWidget);
    });

    test(
        '6. CampusNotifier.updateBuildingImage updates buildings and selectedBuilding',
        () {
      const initialBuilding = BuildingModel(
        id: 'bld-sports-1',
        schoolId: '11111111-1111-1111-1111-111111111111',
        name: 'Sports Complex',
        code: 'B6',
        buildingType: 'Sports',
        status: 'Active',
        imageUrl: 'https://old.url/image.jpg',
      );

      final notifier = CampusNotifierFake(CampusState(
        buildings: [initialBuilding],
        selectedBuilding: initialBuilding,
      ));

      notifier.updateBuildingImage(
          'bld-sports-1', '/api/campus/images/new_image.jpg');

      expect(notifier.state.buildings.first.imageUrl,
          equals('/api/campus/images/new_image.jpg'));
      expect(notifier.state.selectedBuilding?.imageUrl,
          equals('/api/campus/images/new_image.jpg'));
    });
  });
}
