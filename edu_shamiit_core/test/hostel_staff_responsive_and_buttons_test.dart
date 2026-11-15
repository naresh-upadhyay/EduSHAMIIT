import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/staff/hostel_staff_tab.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/staff/hostel_staff_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/staff/hostel_staff_table.dart';

void main() {
  final sampleKPIs = HostelStaffKPIs(
    totalStaff: 28,
    wardensCount: 4,
    wardensBoys: 2,
    wardensGirls: 2,
    caretakersCount: 12,
    supportCount: 10,
    onLeaveCount: 3,
    pendingAssignmentsCount: 2,
  );

  final sampleRoster = [
    HostelStaffRosterItem(
      assignmentId: 'assign-1',
      profileId: 'profile-1',
      rowNum: 21,
      name: 'Balram Yadav',
      employeeId: 'HS021',
      role: 'Security',
      hostelId: 'h-1',
      hostelName: 'Boys Hostel B',
      assignedArea: 'Main Gate',
      contact: '+91 98765 43230',
      email: 'balram@school.edu',
      status: 'Active',
      shiftTimings: 'Day Shift (8 AM - 4 PM)',
      joiningDate: '01 Jun 2023',
    ),
    HostelStaffRosterItem(
      assignmentId: 'assign-2',
      profileId: 'profile-2',
      rowNum: 22,
      name: 'Kamla Bai',
      employeeId: 'HS022',
      role: 'Housekeeping',
      hostelId: 'h-2',
      hostelName: 'Girls Hostel B',
      assignedArea: 'All Floors',
      contact: '+91 98765 43231',
      email: 'kamla@school.edu',
      status: 'On Leave',
      shiftTimings: 'Morning Shift (6 AM - 2 PM)',
      joiningDate: '15 Jul 2023',
    ),
  ];

  final sampleDetail = HostelStaffDetail360(
    assignmentId: 'assign-1',
    profileId: 'profile-1',
    fullName: 'Balram Yadav',
    employeeId: 'HS021',
    role: 'Security',
    hostelId: 'h-1',
    hostelName: 'Boys Hostel B',
    contact: '+91 98765 43230',
    email: 'balram@school.edu',
    address: 'Noida, UP',
    emergencyContact: '+91 98765 00000',
    shiftTimings: 'Day Shift (8 AM - 4 PM)',
    reportingTo: 'Chief Security Officer',
    status: 'Active',
    joiningDate: '01 Jun 2023',
    assignedAreas: [
      HostelStaffArea(id: 'a1', areaName: 'Main Gate', badgeLabel: 'Primary', isPrimary: true),
    ],
    activities: [
      HostelStaffActivity(
        id: 'act1',
        activityType: 'Assigned',
        title: 'Assigned to Main Gate',
        description: 'Duty started',
        performedByName: 'Admin',
        createdAt: '01 Jun 2023',
      ),
    ],
  );

  Widget createTestWidget({
    required Size surfaceSize,
    bool openDrawer = false,
  }) {
    return ProviderScope(
      overrides: [
        hostelProvider.overrideWith((ref) {
          final notifier = HostelNotifier();
          notifier.state = notifier.state.copyWith(
            staffKPIs: sampleKPIs,
            staffRoster: sampleRoster,
            isStaffDrawerOpen: openDrawer,
            selectedStaffDetail: openDrawer ? sampleDetail : null,
          );
          return notifier;
        }),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(size: surfaceSize),
            child: SizedBox(
              width: surfaceSize.width,
              height: surfaceSize.height,
              child: const HostelStaffTab(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpFrames(WidgetTester tester, [int count = 5]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('Hostel Staff Responsive Screen Sizes - Zero Overflow Tests', () {
    testWidgets('Renders cleanly on Laptop (1024 x 768) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(1024, 768)));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'Must have zero RenderFlex overflow on laptop screens');
      expect(find.text('Total Staff'), findsOneWidget);
      expect(find.byType(HostelStaffTable), findsOneWidget);
    });

    testWidgets('Renders cleanly on Desktop (1280 x 800) with Drawer open', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(1280, 800), openDrawer: true));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'Zero overflow on 1280px desktop with open drawer');
      expect(find.text('Staff Details'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('Renders cleanly on Tablet (768 x 1024)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(768, 1024)));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'Zero overflow on tablet');
    });

    testWidgets('Renders cleanly on Mobile (390 x 844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(390, 844)));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'Zero overflow on mobile');
    });

    testWidgets('Renders cleanly on Wide 1080p Desktop (1920 x 1080)', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(1920, 1080), openDrawer: true));
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: 'Zero overflow on 1080p full HD desktop');
    });
  });

  group('Hostel Staff Interactive Buttons Tests', () {
    testWidgets('List View and Grid View toggle buttons switch display modes', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(1400, 900)));
      await pumpFrames(tester);

      // Find Grid View button and click it
      final gridIcon = find.byIcon(Icons.grid_view_rounded);
      expect(gridIcon, findsOneWidget);
      await tester.tap(gridIcon);
      await pumpFrames(tester);

      // Card view elements should be displayed
      expect(find.byIcon(Icons.badge_outlined), findsWidgets);

      // Find List View button and click it back
      final listIcon = find.byIcon(Icons.format_list_bulleted_rounded);
      expect(listIcon, findsOneWidget);
      await tester.tap(listIcon);
      await pumpFrames(tester);

      // Table headers should be displayed
      expect(find.text('#'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets('Bulk Actions button renders and can be tapped', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(surfaceSize: const Size(1400, 900)));
      await pumpFrames(tester);

      final bulkActionsBtn = find.text('Bulk Actions');
      expect(bulkActionsBtn, findsOneWidget);
      await tester.tap(bulkActionsBtn);
      await pumpFrames(tester, 3);

      expect(tester.takeException(), isNull);
    });

    testWidgets('KPI Cards click filters update staff filters', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(hostelProvider.notifier).state = container.read(hostelProvider.notifier).state.copyWith(
        staffKPIs: sampleKPIs,
        staffRoster: sampleRoster,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: HostelStaffKPICards(),
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      // Tap Wardens card
      final wardensCard = find.text('Wardens');
      expect(wardensCard, findsOneWidget);
      await tester.tap(wardensCard);
      await pumpFrames(tester);

      expect(container.read(hostelProvider).staffRoleFilter, 'Warden');

      // Tap On Leave card
      final onLeaveCard = find.text('On Leave');
      expect(onLeaveCard, findsOneWidget);
      await tester.tap(onLeaveCard);
      await pumpFrames(tester);

      expect(container.read(hostelProvider).staffStatusFilter, 'On Leave');
    });
  });
}
