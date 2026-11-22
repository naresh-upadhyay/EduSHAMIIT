import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';
import 'package:edu_shamiit_core/screens/classes/providers/class_provider.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/rooms_tab_view.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/class_tabs_bar.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/class_header_bar.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/sections_tab_view.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/subjects_tab_view.dart';
import 'package:edu_shamiit_core/screens/classes/widgets/classes_tab_view.dart';

class MockClassNotifier extends StateNotifier<ClassState> implements ClassNotifier {
  MockClassNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fetchStats() async {}

  @override
  Future<void> fetchClasses() async {}

  @override
  Future<void> fetchAllClasses() async {}

  @override
  Future<void> fetchSections() async {}

  @override
  Future<void> fetchSectionsOverviewStats() async {}

  @override
  Future<void> fetchSubjects() async {}

  @override
  Future<void> fetchRooms() async {}

  @override
  Future<void> fetchBuildingsAndFloors() async {}

  @override
  void setRoomSearchQuery(String query) {
    state = state.copyWith(roomSearchQuery: query);
  }

  @override
  void setRoomTypeFilter(String type) {
    state = state.copyWith(roomTypeFilter: type);
  }

  @override
  void setRoomBuildingFilter(String b) {
    state = state.copyWith(roomBuildingFilter: b);
  }

  @override
  void setRoomFloorFilter(String f) {
    state = state.copyWith(roomFloorFilter: f);
  }

  @override
  void setRoomStatusFilter(String s) {
    state = state.copyWith(roomStatusFilter: s);
  }

  @override
  void setRoomViewMode(String mode) {
    state = state.copyWith(roomViewMode: mode);
  }

  @override
  Future<void> selectRoom(AcademicRoomModel room) async {
    state = state.copyWith(selectedRoom: room, selectedRoomDetail: room);
  }

  @override
  void clearSelectedRoom() {
    state = state.copyWith(clearSelectedRoom: true);
  }

  @override
  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index);
  }
}

void main() {
  final sampleRooms = [
    AcademicRoomModel(
      id: 'room-1',
      name: 'KING',
      code: 'K',
      type: 'Computer Lab',
      building: 'Academic Block A',
      floor: 'Ground Floor',
      capacity: 40,
      facilities: ['Whiteboard', 'Beds +1', 'Projector'],
      status: 'MAINTENANCE',
      description: 'Main campus computer laboratory under maintenance.',
      createdAt: DateTime.parse('2026-08-18T19:13:34Z'),
      updatedAt: DateTime.parse('2026-08-20T10:00:00Z'),
      assignedSections: [],
      assignedSectionsCount: 0,
      totalStudentsSeated: 0,
      capacityUtilization: 0.0,
    ),
    AcademicRoomModel(
      id: 'room-2',
      name: 'Physics Lab',
      code: 'PHY-01',
      type: 'Laboratory',
      building: 'Science Block',
      floor: '1st Floor',
      capacity: 35,
      facilities: ['Smart Board', 'Lab Equipment'],
      status: 'AVAILABLE',
      description: 'Fully equipped physics laboratory.',
      createdAt: DateTime.parse('2026-08-18T19:13:34Z'),
      updatedAt: DateTime.parse('2026-08-20T10:00:00Z'),
      assignedSections: [],
      assignedSectionsCount: 0,
      totalStudentsSeated: 0,
      capacityUtilization: 0.0,
    ),
  ];

  final sampleStats = AcademicStatsModel(
    totalClasses: 8,
    activeClasses: 8,
    totalSections: 12,
    activeSections: 12,
    totalSubjects: 7,
    coreSubjects: 5,
    electiveSubjects: 2,
    totalRooms: 1,
    availableRooms: 0,
    inUseRooms: 0,
    maintenanceRooms: 1,
    totalRoomCapacity: 40,
  );

  Widget createTestWidget(ClassState state, Widget child) {
    final mockNotifier = MockClassNotifier(state);
    return ProviderScope(
      overrides: [
        classProvider.overrideWith((ref) => mockNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Class Management Screen Responsiveness & Overflow Prevention', () {
    testWidgets('ClassTabsBar renders on mobile (360x780) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 0,
        stats: sampleStats,
      );

      await tester.pumpWidget(createTestWidget(state, const ClassTabsBar()));
      await tester.pumpAndSettle();

      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Sections'), findsOneWidget);
      expect(find.text('Subjects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RoomsTabView Filter Toolbar renders without overflow on Desktop 1140px (Previous Failing Width)', (tester) async {
      // 1140px was the exact width where the 24px overflow occurred previously!
      tester.view.physicalSize = const Size(1140, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 3,
        rooms: sampleRooms,
        stats: sampleStats,
        availableBuildings: ['Academic Block A', 'Science Block'],
        availableFloors: ['Ground Floor', '1st Floor'],
        roomTotalCount: 2,
        roomTotalPages: 1,
        roomPage: 1,
        roomPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const RoomsTabView()));
      await tester.pumpAndSettle();

      expect(find.text('KING'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
      expect(find.text('Floor Map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RoomsTabView renders on Mobile (375x812 iPhone) without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 3,
        rooms: sampleRooms,
        stats: sampleStats,
        availableBuildings: ['Academic Block A', 'Science Block'],
        availableFloors: ['Ground Floor', '1st Floor'],
        roomTotalCount: 2,
        roomTotalPages: 1,
        roomPage: 1,
        roomPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const RoomsTabView()));
      await tester.pumpAndSettle();

      expect(find.text('Total Rooms'), findsOneWidget);
      expect(find.text('Filters & View'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RoomsTabView renders on Tablet (768x1024 iPad) without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 3,
        rooms: sampleRooms,
        stats: sampleStats,
        availableBuildings: ['Academic Block A', 'Science Block'],
        availableFloors: ['Ground Floor', '1st Floor'],
        roomTotalCount: 2,
        roomTotalPages: 1,
        roomPage: 1,
        roomPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const RoomsTabView()));
      await tester.pumpAndSettle();

      expect(find.text('KING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RoomsTabView renders on Wide Desktop (1440x900) without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 3,
        rooms: sampleRooms,
        stats: sampleStats,
        availableBuildings: ['Academic Block A', 'Science Block'],
        availableFloors: ['Ground Floor', '1st Floor'],
        roomTotalCount: 2,
        roomTotalPages: 1,
        roomPage: 1,
        roomPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const RoomsTabView()));
      await tester.pumpAndSettle();

      expect(find.text('KING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SectionsTabView Filter Toolbar renders without overflow on 1050px', (tester) async {
      tester.view.physicalSize = const Size(1050, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 1,
        stats: sampleStats,
        availableBuildings: ['Academic Block A'],
        availableFloors: ['Ground Floor'],
      );

      await tester.pumpWidget(createTestWidget(state, const SectionsTabView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('SubjectsTabView Filter Toolbar renders without overflow on 950px', (tester) async {
      tester.view.physicalSize = const Size(950, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 2,
        stats: sampleStats,
      );

      await tester.pumpWidget(createTestWidget(state, const SubjectsTabView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('RoomsTabView renders on Extra-Small Mobile (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 3,
        rooms: sampleRooms,
        stats: sampleStats,
        availableBuildings: ['Academic Block A'],
        availableFloors: ['Ground Floor'],
        roomTotalCount: 2,
        roomTotalPages: 1,
        roomPage: 1,
        roomPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const RoomsTabView()));
      await tester.pumpAndSettle();

      expect(find.text('Total Rooms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SectionsTabView renders on Mobile (375x812) without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 1,
        stats: sampleStats,
        availableBuildings: ['Academic Block A'],
        availableFloors: ['Ground Floor'],
        sectionTotalCount: 12,
        sectionTotalPages: 2,
        sectionPage: 1,
        sectionPageSize: 10,
      );

      await tester.pumpWidget(createTestWidget(state, const SectionsTabView()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('ClassHeaderBar renders on Mobile (360x780) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final state = ClassState(
        activeTab: 0,
        stats: sampleStats,
      );

      await tester.pumpWidget(createTestWidget(state, const ClassHeaderBar()));
      await tester.pumpAndSettle();

      expect(find.text('Class Management'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ClassesTabView renders on Mobile (375x812) without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleClass = AcademicClassModel(
        id: 'cls-1',
        name: 'Class 10 - Secondary',
        code: '10-SEC',
        stage: 'Secondary',
        displayOrder: 10,
        academicYear: '2026-2027',
        status: 'ACTIVE',
        sectionsCount: 3,
        studentsCount: 110,
        subjectsCount: 8,
        sections: [],
      );

      final state = ClassState(
        activeTab: 0,
        stats: sampleStats,
        classes: [sampleClass],
        allClasses: [sampleClass],
        selectedClass: sampleClass,
      );

      await tester.pumpWidget(createTestWidget(state, const ClassesTabView()));
      await tester.pumpAndSettle();

      expect(find.text('Class 10 - Secondary'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
