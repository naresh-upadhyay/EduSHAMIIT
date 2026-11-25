import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/campus_management_screen.dart';
import 'package:edu_shamiit_core/screens/campus/providers/campus_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_center_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';

void main() {
  group('Campus Management Screen Tabs & Loading Fix Verification', () {
    testWidgets(
        'CampusManagementScreen displays loading indicator without throwing null operator error when building is null',
        (tester) async {
      // Simulate screen loading state before buildings are fetched
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider.overrideWith((ref) => CampusNotifierFake(
                  const CampusState(isLoading: true, selectedBuilding: null),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CampusManagementScreen(initialTab: 0),
            ),
          ),
        ),
      );

      // Verify no exceptions were thrown
      expect(tester.takeException(), isNull);

      // Verify loading indicator and message are shown
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Loading campus buildings and facilities...'),
          findsOneWidget);
    });

    testWidgets(
        'SpaceBookingCenterPanel renders without flex: 0 assertion crash on desktop and compact widths',
        (tester) async {
      // 1. Desktop width (constraints.maxWidth >= 650)
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpaceBookingCenterPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Space Availability & Booking'), findsOneWidget);

      // 2. Compact width (constraints.maxWidth < 650)
      await tester.binding.setSurfaceSize(const Size(500, 800));
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpaceBookingCenterPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Space Availability & Booking'), findsOneWidget);
    });

    testWidgets(
        'SpaceBookingTabView renders inside tab view without crashing or freezing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SpaceBookingTabView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Space Availability & Booking'), findsOneWidget);
      expect(find.text('Booking Requests'), findsWidgets);
    });

    testWidgets(
        'Switching through all campus tabs (0 to 7) renders gracefully without freeze or error',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      const sampleBuilding = BuildingModel(
        id: 'bld-test-01',
        schoolId: 'sch-01',
        name: 'Science Block',
        code: 'SB-01',
        buildingType: 'Academic',
        totalFloors: 3,
        totalRooms: 12,
        totalCapacity: 600,
        currentOccupancy: 450,
        occupancyRate: 75.0,
      );

      const stateWithBuilding = CampusState(
        isLoading: false,
        selectedBuilding: sampleBuilding,
        buildings: [sampleBuilding],
        kpis: CampusKpis(totalBuildings: 1, totalFloors: 3, totalRooms: 12),
      );

      for (int tabIdx = 0; tabIdx <= 7; tabIdx++) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              campusProvider.overrideWith((ref) => CampusNotifierFake(
                    stateWithBuilding.copyWith(activeCampusTab: tabIdx),
                  )),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CampusManagementScreen(initialTab: tabIdx),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final err = tester.takeException();
        expect(err, isNull,
            reason: 'Tab $tabIdx should render without exception');
      }
    });
  });
}

class CampusNotifierFake extends StateNotifier<CampusState>
    implements CampusNotifier {
  CampusNotifierFake(super.state);

  @override
  Future<void> loadAll() async {}

  @override
  Future<void> loadBuildingDetails(String buildingId) async {}

  @override
  void selectBuilding(BuildingModel building) {}

  @override
  void setActiveCampusTab(int tabIndex) {
    state = state.copyWith(activeCampusTab: tabIndex);
  }

  @override
  void setActiveBuildingSubTab(int subTabIndex) {}

  @override
  void setBuildingSearchQuery(String query) {}

  @override
  Future<void> setFloorsPage(int page) async {}

  @override
  Future<void> setRoomsPage(int page) async {}

  @override
  void setRoomsViewMode(int mode) {}

  @override
  void setRoomSearch(String search) {}

  @override
  void setFilterFloor(String? floorId) {}

  @override
  void setFilterRoomType(String? roomType) {}

  @override
  void setFilterRoomStatus(String? status) {}

  void setFilterAssignmentStatus(String? assignment) {}

  @override
  void clearFilters() {}

  @override
  void inspectRoom(RoomModel? room) {}

  void clearInspectedRoom() {}

  @override
  Future<void> reloadRooms({int? page}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
