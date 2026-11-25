import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/providers/facilities_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/utilities_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/campus_reports_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/facilities/facilities_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/utilities/utilities_services_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/reports/campus_reports_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/buildings/rooms_subtab_view.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/create_edit_booking_dialog.dart';

import 'package:edu_shamiit_core/screens/campus/services/campus_api_service.dart';

class FakeUtilitiesNotifier extends UtilitiesNotifier {
  FakeUtilitiesNotifier(UtilitiesState initialState)
      : super(CampusApiService.instance) {
    state = initialState;
  }
  @override
  Future<void> loadData() async {}
}

void main() {
  group('Campus Management Advanced Architecture & Riverpod State Verification',
      () {
    test(
        'FacilitiesState and FacilitiesNotifier filtering and pagination operations',
        () {
      const state = FacilitiesState(
        facilities: [
          {
            'id': 'fac-1',
            'name': 'Robotics Lab',
            'category': 'Specialized Laboratory',
            'status': 'Operational',
            'capacity': 40,
          },
          {
            'id': 'fac-2',
            'name': 'Central Auditorium',
            'category': 'Auditorium & Amphitheater',
            'status': 'Reserved / In-Use',
            'capacity': 500,
          },
          {
            'id': 'fac-3',
            'name': 'Olympic Swimming Pool',
            'category': 'Sports Complex / Ground',
            'status': 'Under Maintenance',
            'capacity': 100,
          },
        ],
      );

      expect(state.facilities.length, 3);
      final filtered =
          state.facilities.where((f) => f['status'] == 'Operational').toList();
      expect(filtered.length, 1);
      expect(filtered.first['name'], 'Robotics Lab');

      final updated = state.copyWith(
        selectedCategory: 'Sports Complex / Ground',
        currentPage: 2,
        viewMode: 1,
      );
      expect(updated.selectedCategory, 'Sports Complex / Ground');
      expect(updated.currentPage, 2);
      expect(updated.viewMode, 1);
    });

    test('UtilitiesState tariff calculation and anomaly presentation', () {
      const state = UtilitiesState(
        tariffKwh: 9.50,
        tariffDiesel: 89.00,
        latestAnomaly: {
          'is_anomaly': true,
          'ticket_code': 'MT-UTL-2611-0012',
          'auto_ticket_created': true,
        },
      );

      // Verify commercial tariff calculations
      const monthlyKwh = 45210.0;
      final estMonthlyCost = monthlyKwh * state.tariffKwh;
      expect(estMonthlyCost, 429495.0);

      // Verify anomaly details
      expect(state.latestAnomaly != null, isTrue);
      expect(state.latestAnomaly!['is_anomaly'], isTrue);
      expect(state.latestAnomaly!['ticket_code'], 'MT-UTL-2611-0012');
    });

    test('CampusReportsState and dossier formatting logic', () {
      const state = CampusReportsState(
        selectedReportType: 0,
        timeRange: 'Current Semester',
      );

      expect(state.selectedReportType, 0);
      expect(state.timeRange, 'Current Semester');

      final updated = state.copyWith(
        selectedReportType: 3,
        timeRange: 'Last 7 Days',
      );
      expect(updated.selectedReportType, 3);
      expect(updated.timeRange, 'Last 7 Days');
    });

    testWidgets(
        'CreateEditBookingDialog honors preselectedRoomId from Facilities bridge',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(
                preselectedRoomId: 'room-b1-101',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Book a Campus Space'), findsOneWidget);
    });

    testWidgets(
        'RoomsSubtabView renders 2D Spatial Floorplan Blueprint (viewMode 2)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      final dummyRooms = [
        const RoomModel(
          id: 'r-1',
          schoolId: 's-1',
          buildingId: 'b-1',
          floorId: 'fl-1',
          name: 'Physics Lab',
          roomNumber: 'G-101',
          roomCode: 'PHY-101',
          roomType: 'Laboratory',
          maxCapacity: 45,
          operationalStatus: 'Available',
          responsibleDepartment: 'Science Department',
        ),
        const RoomModel(
          id: 'r-2',
          schoolId: 's-1',
          buildingId: 'b-1',
          floorId: 'fl-1',
          name: 'Chemistry Lab',
          roomNumber: 'G-102',
          roomCode: 'CHM-102',
          roomType: 'Laboratory',
          maxCapacity: 40,
          operationalStatus: 'Occupied',
          responsibleDepartment: 'Science Department',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoomsSubtabView(
                building: const BuildingModel(
                  id: 'b-1',
                  schoolId: 's-1',
                  name: 'Main Academic Block',
                  code: 'B1',
                ),
                rooms: dummyRooms,
                floors: const [],
                isLoading: false,
                viewMode: 2, // 2D Spatial Floorplan Grid
                onViewModeChanged: (_) {},
                searchQuery: '',
                onSearch: (_) {},
                filterFloorId: null,
                onFilterFloor: (_) {},
                filterRoomType: null,
                onFilterRoomType: (_) {},
                filterStatus: null,
                onFilterStatus: (_) {},
                onClearFilters: () {},
                onAddRoom: () {},
                onBulkCreate: () {},
                onInspectRoom: (_) {},
                onEditRoom: (_) {},
                onManageEquipment: (_) {},
                onDeleteRoom: (_) {},
                totalRoomsCount: 2,
                currentPage: 1,
                pageSize: 10,
                onPageChanged: (_) {},
                onPageSizeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('2D Spatial Floorplan Blueprint'), findsOneWidget);
      expect(find.text('G-101'), findsOneWidget);
      expect(find.text('G-102'), findsOneWidget);
      expect(find.text('45 Cap'), findsOneWidget);
      expect(find.text('40 Cap'), findsOneWidget);
    });

    testWidgets(
        'FacilitiesTabView renders without throwing and displays KPI cards',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FacilitiesTabView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Total Facilities'), findsOneWidget);
      expect(find.text('Operational'), findsWidgets);
    });

    testWidgets(
        'UtilitiesServicesTabView renders with tariff projections and anomaly banner when present',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            utilitiesProvider.overrideWith((ref) => FakeUtilitiesNotifier(
                  const UtilitiesState(
                    tariffKwh: 9.50,
                    tariffDiesel: 89.00,
                    latestAnomaly: {
                      'is_anomaly': true,
                      'ticket_code': 'MT-UTL-0089',
                    },
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UtilitiesServicesTabView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Automated Utility Surge Detected (>1.5x Baseline)'),
          findsOneWidget);
      expect(find.text('View Work Order'), findsOneWidget);
      expect(find.text('Grid Power Load'), findsOneWidget);
      expect(find.text('Solar Generation'), findsOneWidget);
    });

    testWidgets(
        'CampusReportsTabView renders with dual export options: CSV and Executive PDF Dossier',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CampusReportsTabView(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Export CSV'), findsOneWidget);
      expect(find.text('Executive PDF Dossier'), findsOneWidget);
      expect(find.text('Space & Room Utilization'), findsOneWidget);
      expect(find.text('Asset & Equipment Health'), findsOneWidget);
    });
  });
}
