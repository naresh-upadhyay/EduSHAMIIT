import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_complaint_models.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/hostel_complaints_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/hostel_complaints_filter_bar.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/hostel_complaints_table.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/hostel_complaint_detail_drawer.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/hostel_complaints_tab.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/dialogs/assign_complaint_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/dialogs/update_status_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/dialogs/raise_complaint_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/complaints/dialogs/complaint_feedback_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';

void main() {
  group('Hostel Complaints - Models & Serialization', () {
    test('ComplaintKpiData parses backend JSON matching screenshot', () {
      final json = {
        'total_complaints': 36,
        'total_trend': '↑ 12%',
        'total_subtitle': 'This Month',
        'resolved': 24,
        'resolution_rate': '67% resolution rate',
        'pending': 8,
        'pending_percentage': '22% of total',
        'overdue': 4,
        'overdue_percentage': '11% of total',
        'high_priority': 6,
        'high_priority_subtitle': 'Requires urgent attention',
        'maintenance_related': 14,
        'maintenance_percentage': '39% of total',
        'avg_resolution_hours': 18.5,
      };

      final kpis = ComplaintKpiData.fromJson(json);
      expect(kpis.totalComplaints, equals(36));
      expect(kpis.resolved, equals(24));
      expect(kpis.pending, equals(8));
      expect(kpis.overdue, equals(4));
      expect(kpis.highPriority, equals(6));
      expect(kpis.maintenanceRelated, equals(14));
      expect(kpis.avgResolutionHours, equals(18.5));
    });

    test('HostelComplaintItem parses complete backend record', () {
      final json = {
        'id': 'c1000001-0000-0000-0000-000000000001',
        'complaint_number': 'HC-2024-001',
        'display_index': 1,
        'title': 'Water leakage in bathroom',
        'description': 'Continuous water dripping from the washbasin tap.',
        'category': 'Plumbing',
        'priority': 'High',
        'status': 'Open',
        'hostel_name': 'Boys Hostel A',
        'building_name': 'Block A',
        'floor_name': '1st Floor',
        'room_number': 'A-101',
        'reported_by_name': 'Rahul Sharma',
        'reported_by_class': 'Class 10 A',
        'primary_assignee_name': 'Mr. Ramesh (Maintenance Staff)',
        'sla_due_text': '2h remaining',
        'is_overdue': false,
        'created_at': '2024-05-12T10:30:00',
        'expected_resolution': '14 May 2024',
        'last_updated': '12 May 2024, 11:00 AM',
        'attachments': ['tap_photo.jpg'],
        'version': 1,
      };

      final item = HostelComplaintItem.fromJson(json);
      expect(item.complaintNumber, equals('HC-2024-001'));
      expect(item.title, equals('Water leakage in bathroom'));
      expect(item.category, equals('Plumbing'));
      expect(item.priority, equals('HIGH'));
      expect(item.status, equals('OPEN'));
      expect(item.hostelName, equals('Boys Hostel A'));
      expect(item.roomNumber, equals('A-101'));
      expect(item.reportedByName, equals('Rahul Sharma'));
      expect(item.reportedByClass, equals('Class 10 A'));
      expect(item.primaryAssigneeName, equals('Mr. Ramesh (Maintenance Staff)'));
      expect(item.raisedOnFormatted, equals('12 May 2024\n10:30 AM'));
      expect(item.attachments.length, equals(1));
    });

    test('ComplaintPagination calculates limits and flags', () {
      const p = ComplaintPagination(
        page: 2,
        pageSize: 10,
        totalRecords: 36,
        totalPages: 4,
        hasPrev: true,
        hasNext: true,
      );

      expect(p.hasPrev, isTrue);
      expect(p.hasNext, isTrue);
      expect(p.page, equals(2));
      expect(p.pageSize, equals(10));
      expect(p.totalRecords, equals(36));
      expect(p.totalPages, equals(4));
    });

    test('HostelComplaintDetail360 parses full audit and discussion history', () {
      final cJson = {
        'id': 'c1000001-0000-0000-0000-000000000001',
        'complaint_number': 'HC-2024-001',
        'display_index': 1,
        'title': 'Water leakage in bathroom',
        'category': 'Plumbing',
        'priority': 'High',
        'status': 'Open',
        'raised_on': '12 May 2024, 10:30 AM',
      };

      final commentJson = {
        'id': 'cm-001',
        'author_name': 'Ramesh Technician',
        'author_role': 'Maintenance Staff',
        'message': 'Spare parts ordered, will fix by tomorrow.',
        'comment_type': 'PUBLIC_UPDATE',
        'created_at': '12 May 2024, 02:15 PM',
      };

      final historyJson = {
        'id': 'h-001',
        'event_title': 'Complaint raised',
        'actor_name': 'Rahul Sharma',
        'created_at': '12 May 2024, 10:30 AM',
      };

      final detail = HostelComplaintDetail360.fromJson({
        'complaint': cJson,
        'comments': [commentJson],
        'history': [historyJson],
        'assignments': [],
      });

      expect(detail.complaint.complaintNumber, equals('HC-2024-001'));
      expect(detail.comments.length, equals(1));
      expect(detail.comments.first.message, contains('Spare parts ordered'));
      expect(detail.history.length, equals(1));
      expect(detail.history.first.eventTitle, equals('Complaint raised'));
    });
  });

  group('Hostel Complaints - Widget Tests', () {
    testWidgets('HostelComplaintsKPICards renders 6 KPI cards with correct metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              complaintKpis: const ComplaintKpiData(
                totalComplaints: 36,
                totalTrend: '↑ 12%',
                totalSubtitle: 'This Month',
                resolved: 24,
                resolutionRate: '67% resolution rate',
                pending: 8,
                pendingPercentage: '22% of total',
                overdue: 4,
                overduePercentage: '11% of total',
                highPriority: 6,
                highPrioritySubtitle: 'Requires urgent attention',
                maintenanceRelated: 14,
                maintenancePercentage: '39% of total',
              ),
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintsKPICards(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 6 KPI cards exist
      expect(find.text('Total Complaints'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('High Priority'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Maintenance Related'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('HostelComplaintsFilterBar renders subtabs, search, and action button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final container = ProviderContainer();
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintsFilterBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify subtabs
      expect(find.text('All Complaints'), findsOneWidget);
      expect(find.text('My Complaints'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);

      // Verify Raise Complaint button
      expect(find.text('Raise Complaint'), findsOneWidget);
    });

    testWidgets('HostelComplaintsTable renders headers, rows, and pagination', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final testComplaint = HostelComplaintItem(
        id: 'c1000001-0000-0000-0000-000000000001',
        complaintNumber: 'HC-2024-001',
        displayIndex: 1,
        title: 'Water leakage in bathroom',
        description: 'Leak in washbasin',
        category: 'Plumbing',
        priority: 'High',
        status: 'Open',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-101',
        reportedByName: 'Rahul Sharma',
        reportedByClass: 'Class 10 A',
        raisedOnFormatted: '12 May 2024, 10:30 AM',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              complaintsList: [testComplaint],
              complaintsPagination: const ComplaintPagination(
                page: 1,
                pageSize: 10,
                totalRecords: 1,
                totalPages: 1,
              ),
              isComplaintsLoading: false,
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HostelComplaintsTable(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Table Elements
      expect(find.text('Water leakage in bathroom'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Boys Hostel A'), findsOneWidget);
      expect(find.text('A-101'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('HostelComplaintDetailDrawer displays hero, tabs, and action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final testDetail = HostelComplaintDetail360(
        complaint: HostelComplaintItem(
          id: 'c1000001-0000-0000-0000-000000000001',
          complaintNumber: 'HC-2024-001',
          displayIndex: 1,
          title: 'Water leakage in bathroom',
          description: 'Continuous water leakage from tap in room A-101.',
          category: 'Plumbing',
          priority: 'High',
          status: 'Open',
          hostelName: 'Boys Hostel A',
          roomNumber: 'A-101',
          reportedByName: 'Rahul Sharma',
          reportedByClass: 'Class 10 A',
          primaryAssigneeName: 'Mr. Ramesh (Maintenance Staff)',
          raisedOnFormatted: '12 May 2024, 10:30 AM',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          resolutionDueAt: DateTime.now().add(const Duration(days: 2)),
        ),
        comments: [
          ComplaintCommentItem(
            id: 'cm-01',
            authorName: 'Ramesh',
            message: 'Spare parts ordered',
            commentType: 'PUBLIC_UPDATE',
            createdAt: DateTime.now(),
            timeFormatted: '12 May 2024, 02:15 PM',
          ),
        ],
        assignments: [],
        history: [
          ComplaintHistoryItem(
            id: 'h-01',
            actorName: 'Rahul Sharma',
            eventTitle: 'Complaint raised',
            actionNote: 'Reported by Rahul Sharma',
            createdAt: DateTime.now(),
            timeFormatted: '12 May 2024, 10:30 AM',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              selectedComplaintId: testDetail.complaint.id,
              selectedComplaintDetail: testDetail,
              isComplaintDrawerOpen: true,
              isComplaintDetailLoading: false,
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 440,
                child: HostelComplaintDetailDrawer(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Hero
      expect(find.text('Complaint Details'), findsOneWidget);
      expect(find.textContaining('HC-2024-001'), findsWidgets);
      expect(find.text('Water leakage in bathroom'), findsWidgets);

      // Verify 4 Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Updates (1)'), findsOneWidget);
      expect(find.text('Assign & Resolve'), findsOneWidget);
      expect(find.text('Attachments (0)'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Update Status'), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
    });

    testWidgets('HostelComplaintsTab renders complete desktop view without unbounded height crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final testDetail = HostelComplaintDetail360(
        complaint: HostelComplaintItem(
          id: 'c1000001-0000-0000-0000-000000000001',
          complaintNumber: 'HC-2024-001',
          displayIndex: 1,
          title: 'Water leakage in bathroom',
          description: 'Continuous water leakage from tap in room A-101.',
          category: 'Plumbing',
          priority: 'High',
          status: 'Open',
          hostelName: 'Boys Hostel A',
          roomNumber: 'A-101',
          reportedByName: 'Rahul Sharma',
          reportedByClass: 'Class 10 A',
          raisedOnFormatted: '12 May 2024, 10:30 AM',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              selectedComplaintId: testDetail.complaint.id,
              selectedComplaintDetail: testDetail,
              isComplaintDrawerOpen: true,
              isComplaintsLoading: false,
              complaintsList: [testDetail.complaint],
              complaintsPagination: const ComplaintPagination(
                page: 1,
                pageSize: 10,
                totalRecords: 1,
                totalPages: 1,
              ),
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Complaints (1)'), findsOneWidget);
      expect(find.text('Water leakage in bathroom'), findsWidgets);
      expect(find.text('Complaint Details'), findsOneWidget);
    });

    testWidgets('AssignComplaintDialog renders cleanly on Desktop, Tablet, and Mobile with zero overflow', (tester) async {
      final container = ProviderContainer();

      for (final size in [
        const Size(1280, 800), // Desktop
        const Size(768, 1024), // Tablet
        const Size(375, 667),  // Mobile
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: AssignComplaintDialog(
                  complaintId: 'c1000001-0000-0000-0000-000000000001',
                  currentAssignee: 'Mr. Suresh Kumar',
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Reassign Complaint'), findsOneWidget);
        expect(find.text('Select Staff / Technician *'), findsOneWidget);
        expect(find.text('Assignment Type'), findsOneWidget);
        expect(find.text('Assign Staff'), findsOneWidget);
        // Verify no RenderFlex overflow
        expect(tester.takeException(), isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('UpdateStatusDialog renders cleanly on Mobile and Desktop with zero overflow', (tester) async {
      final container = ProviderContainer();
      final complaint = HostelComplaintItem.fromJson({
        'id': 'c1000001-0000-0000-0000-000000000001',
        'complaint_number': 'HC-2024-001',
        'display_index': 1,
        'title': 'Water leakage in bathroom',
        'description': 'Tap broken in room 101',
        'category': 'Plumbing',
        'priority': 'High',
        'status': 'IN_PROGRESS',
        'reported_by_name': 'Aarav Sharma',
        'room_number': 'A-101',
        'hostel_name': 'Boys Hostel A',
        'primary_assignee_name': 'Ramesh Babu',
        'created_at': '2026-11-01T10:00:00Z',
        'updated_at': '2026-11-01T10:00:00Z',
      });

      for (final size in [
        const Size(1280, 800), // Desktop
        const Size(375, 667),  // Mobile
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: UpdateComplaintStatusDialog(complaint: complaint),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Update Status: HC-2024-001'), findsOneWidget);
        expect(find.text('Select Target Status *'), findsOneWidget);
        // Verify no RenderFlex overflow
        expect(tester.takeException(), isNull);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('HostelComplaintsFilterBar shows Filter Dates when null and formats when set', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final container = ProviderContainer();
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintsFilterBar(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // By default with complaintsDateRange == null, button must display 'Filter Dates'
      expect(find.text('Filter Dates'), findsOneWidget);

      // Now set a date range
      final testRange = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 11, 4),
      );
      container.read(hostelProvider.notifier).setComplaintsDateRange(testRange);
      await tester.pumpAndSettle();

      // Should now display formatted date range and close icon
      expect(find.text('01 Oct - 04 Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close icon to clear date filter back to null
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Filter Dates'), findsOneWidget);
    });

    testWidgets('HostelComplaintsKPICards tap on High Priority card triggers setComplaintsSubtab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              complaintKpis: const ComplaintKpiData(
                totalComplaints: 40,
                resolved: 26,
                pending: 14,
                overdue: 14,
                highPriority: 7,
                maintenanceRelated: 25,
              ),
            );
            return notifier;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintsKPICards(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the High Priority card and tap it
      final highPriorityCard = find.text('High Priority');
      expect(highPriorityCard, findsOneWidget);
      await tester.tap(highPriorityCard);
      await tester.pumpAndSettle();

      // Verify complaintsSubtab changed to 'High Priority'
      expect(container.read(hostelProvider).complaintsSubtab, equals('High Priority'));
    });

    testWidgets('HostelComplaintDetailDrawer renders zero overflow across Mobile, Laptop, and Desktop with extensive timeline', (tester) async {
      final mockComplaint = HostelComplaintItem(
        id: 'c1',
        complaintNumber: 'HC-2026-076',
        displayIndex: 1,
        title: 'Study Room AC Leaking Heavily onto Desks and Floor',
        description: 'AC unit is dripping water constantly causing disruption.',
        category: 'Electrical & Wiring',
        priority: 'HIGH',
        status: 'OPEN',
        hostelName: 'Boys Hostel A',
        buildingName: 'Block A',
        floorName: '1st Floor',
        roomNumber: 'A-101',
        reportedByName: 'King Doe',
        reportedByClass: 'Class 10 A',
        primaryAssigneeName: 'Karthik Reddy',
        primaryAssigneeRole: 'Senior Technician',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        raisedOnFormatted: '04 Nov 2026\n02:23 PM',
        attachments: ['photo1.jpg', 'photo2.jpg'],
        version: 2,
      );

      final mockDetail = HostelComplaintDetail360(
        complaint: mockComplaint,
        history: [
          ComplaintHistoryItem(
            id: 'h0',
            eventTitle: 'Complaint raised',
            actorName: 'Resident Student',
            actorRole: 'Student',
            actionNote: null,
            createdAt: DateTime.now().subtract(const Duration(hours: 10)),
            timeFormatted: '04 Nov 2026, 02:23 PM',
          ),
          ComplaintHistoryItem(
            id: 'h1',
            eventTitle: 'Assigned to Karthik Reddy',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'Staff assigned for complaint resolution.',
            createdAt: DateTime.now().subtract(const Duration(hours: 8)),
            timeFormatted: '04 Nov 2026, 05:19 PM',
          ),
          ComplaintHistoryItem(
            id: 'h2',
            eventTitle: 'Complaint marked resolved',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'LOPLLP',
            createdAt: DateTime.now().subtract(const Duration(hours: 7)),
            timeFormatted: '04 Nov 2026, 05:20 PM',
          ),
          ComplaintHistoryItem(
            id: 'h3',
            eventTitle: 'Resolution verified & completed',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'ESZX',
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            timeFormatted: '05 Nov 2026, 02:35 AM',
          ),
          ComplaintHistoryItem(
            id: 'h4',
            eventTitle: 'Assigned to Sunita Devi',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'XZSA',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            timeFormatted: '05 Nov 2026, 02:36 AM',
          ),
          ComplaintHistoryItem(
            id: 'h5',
            eventTitle: 'Work in progress',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'Issue reported unresolved',
            createdAt: DateTime.now().subtract(const Duration(hours: 4)),
            timeFormatted: '05 Nov 2026, 02:37 AM',
          ),
          ComplaintHistoryItem(
            id: 'h6',
            eventTitle: 'Requester submitted feedback (5★)',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'TPE',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            timeFormatted: '05 Nov 2026, 02:39 AM',
          ),
          ComplaintHistoryItem(
            id: 'h7',
            eventTitle: 'Resolution verified & completed',
            actorName: 'King Doe',
            actorRole: 'Admin',
            actionNote: 'Status changed to COMPLETED',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            timeFormatted: '05 Nov 2026, 02:41 AM',
          ),
        ],
        comments: [
          ComplaintCommentItem(
            id: 'cm1',
            authorName: 'Technician Karthik',
            authorRole: 'Maintenance',
            commentType: 'INTERNAL_NOTE',
            message: 'Checked compressor unit. Ordering replacement capacitor.',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            timeFormatted: '04 Nov 2026, 06:15 PM',
          ),
          ComplaintCommentItem(
            id: 'cm2',
            authorName: 'Warden Ramesh',
            authorRole: 'Warden',
            commentType: 'PUBLIC_UPDATE',
            message: 'Student notified that repair will complete today by 5 PM.',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            timeFormatted: '04 Nov 2026, 07:00 PM',
          ),
        ],
      );

      final screenSizes = [
        const Size(390, 844),   // Mobile phone
        const Size(768, 1024),  // Tablet / iPad
        const Size(1280, 640),  // Compact laptop with small browser viewport
        const Size(1440, 900),  // Full desktop
      ];

      for (final size in screenSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostelProvider.overrideWith((ref) {
                final notifier = HostelNotifier();
                notifier.state = notifier.state.copyWith(
                  selectedComplaintId: 'c1',
                  selectedComplaintDetail: mockDetail,
                  isComplaintDrawerOpen: true,
                  complaintDrawerTab: 0, // Overview tab with extensive timeline
                );
                return notifier;
              }),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: HostelComplaintsTab(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(HostelComplaintDetailDrawer), findsOneWidget);
        expect(find.text('Complaint Details'), findsOneWidget);
        final ex = tester.takeException();
        if (ex != null) {
          debugPrint('DEBUG OVERFLOW ON $size: $ex');
          if (ex is FlutterError) {
            debugPrint('ERROR_DEEP: ${ex.toStringDeep()}');
          }
        }
        expect(ex, isNull, reason: 'Must not overflow on $size');
      }
    });

    testWidgets('RaiseComplaintDialog links dynamically with Rooms & Allocation structure and dynamic preferred visit time', (tester) async {
      final mockTree = [
        HostelBuilding(
          id: 'b1',
          code: 'Block A',
          name: 'Boys Hostel A',
          hostelName: 'Boys Hostel A',
          floors: [
            HostelFloor(
              id: 'f1',
              floorNumber: 1,
              floorCode: '1F',
              floorName: '1st Floor',
              roomsCount: 2,
              rooms: [
                HostelTreeRoom(
                  id: 'r1',
                  roomNumber: 'A-101',
                  roomCode: 'BHA-1-101',
                  roomType: 'Standard',
                  status: 'OCCUPIED',
                ),
                HostelTreeRoom(
                  id: 'r2',
                  roomNumber: 'A-102',
                  roomCode: 'BHA-1-102',
                  roomType: 'Standard',
                  status: 'AVAILABLE',
                ),
              ],
            ),
            HostelFloor(
              id: 'f2',
              floorNumber: 2,
              floorCode: '2F',
              floorName: '2nd Floor',
              roomsCount: 1,
              rooms: [
                HostelTreeRoom(
                  id: 'r3',
                  roomNumber: 'A-201',
                  roomCode: 'BHA-2-201',
                  roomType: 'Deluxe',
                  status: 'AVAILABLE',
                ),
              ],
            ),
          ],
        ),
        HostelBuilding(
          id: 'b2',
          code: 'Block G',
          name: 'Girls Hostel A',
          hostelName: 'Girls Hostel A',
          floors: [
            HostelFloor(
              id: 'f3',
              floorNumber: 0,
              floorCode: 'GF',
              floorName: 'Ground Floor',
              roomsCount: 1,
              rooms: [
                HostelTreeRoom(
                  id: 'r4',
                  roomNumber: 'G-101',
                  roomCode: 'GHA-0-101',
                  roomType: 'Standard',
                  status: 'AVAILABLE',
                ),
              ],
            ),
          ],
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                structureTree: mockTree,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RaiseComplaintDialog(
                initialHostelName: 'Boys Hostel A',
                initialRoomNumber: 'A-101',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Dialog Header and Badges
      expect(find.text('Raise New Complaint'), findsOneWidget);
      expect(find.text('Hostel Location & Asset Linkage'), findsOneWidget);
      expect(find.text('Rooms & Allocation Sync'), findsOneWidget);

      // 2. Verify Dynamic Values from Rooms & Allocation without manual typing
      expect(find.text('Boys Hostel A'), findsOneWidget);
      expect(find.text('1st Floor (2 rooms)'), findsOneWidget);
      expect(find.text('A-101 (Standard • Occupied)'), findsOneWidget);

      // 3. Verify Preferred Visit Time has dynamic time slots
      expect(find.byIcon(Icons.edit_calendar_rounded), findsOneWidget);
      expect(find.textContaining('Morning (09:00 AM - 12:00 PM)'), findsWidgets);

      final ex = tester.takeException();
      if (ex != null) {
        debugPrint('RAISE_COMPLAINT_TEST_ERROR: $ex');
      }
      expect(ex, isNull, reason: 'RaiseComplaintDialog must render cleanly without errors');
    });

    testWidgets('RaiseComplaintDialog renders cleanly on Mobile without overflow', (tester) async {
      final mockTree = [
        HostelBuilding(
          id: 'b1',
          code: 'Block A',
          name: 'Boys Hostel A',
          hostelName: 'Boys Hostel A',
          floors: [
            HostelFloor(
              id: 'f1',
              floorNumber: 1,
              floorCode: '1F',
              floorName: '1st Floor',
              roomsCount: 1,
              rooms: [
                HostelTreeRoom(
                  id: 'r1',
                  roomNumber: 'A-101',
                  roomCode: 'BHA-1-101',
                  roomType: 'Standard',
                  status: 'AVAILABLE',
                ),
              ],
            ),
          ],
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                structureTree: mockTree,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RaiseComplaintDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RaiseComplaintDialog), findsOneWidget);
      final ex = tester.takeException();
      expect(ex, isNull, reason: 'Must render with zero overflow on Mobile 390x844');
    });

    testWidgets('ComplaintFeedbackItem serializes and parses complete feedback record', (tester) async {
      final json = {
        'id': 'fdbk-1001',
        'submitted_by_name': 'King Doe',
        'rating': 5,
        'resolution_quality': 4,
        'response_time_rating': 5,
        'staff_behavior_rating': 5,
        'comment': 'Prompt repair and polite staff',
        'is_satisfied': true,
        'created_at': '2026-11-05T05:38:53.414126Z',
      };

      final item = ComplaintFeedbackItem.fromJson(json);
      expect(item.id, 'fdbk-1001');
      expect(item.submittedByName, 'King Doe');
      expect(item.rating, 5);
      expect(item.resolutionQuality, 4);
      expect(item.responseTimeRating, 5);
      expect(item.staffBehaviorRating, 5);
      expect(item.comment, 'Prompt repair and polite staff');
      expect(item.isSatisfied, isTrue);
      expect(item.createdAt, isNotNull);
    });

    testWidgets('ComplaintFeedbackDialog pre-populates existing feedback correctly', (tester) async {
      final container = ProviderContainer();
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ComplaintFeedbackDialog(
                complaintId: 'c1000001-0000-0000-0000-000000000001',
                complaintTitle: 'IOP',
                initialRating: 5,
                initialQuality: 4,
                initialResponseTime: 3,
                initialStaffBehavior: 5,
                initialComment: 'NEW RESOLUTION COMMENT',
                initialIsSatisfied: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Resolution Feedback'), findsOneWidget);
      expect(find.text('NEW RESOLUTION COMMENT'), findsOneWidget);
      expect(find.text('Update Feedback'), findsOneWidget);
      expect(find.text('Satisfied with resolution'), findsOneWidget);
      expect(find.text('Resolution Quality'), findsOneWidget);
      expect(find.text('Response Time'), findsOneWidget);
      expect(find.text('Staff Courtesy & Behavior'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HostelComplaintDetailDrawer displays Resident Resolution Feedback card when feedback exists', (tester) async {
      final mockFeedback = ComplaintFeedbackItem(
        id: 'f1',
        submittedByName: 'King Doe',
        rating: 5,
        resolutionQuality: 4,
        responseTimeRating: 5,
        staffBehaviorRating: 5,
        comment: 'Technician fixed the AC quickly and cleaned up afterwards.',
        isSatisfied: true,
        createdAt: DateTime.now(),
      );

      final mockComplaint = HostelComplaintItem(
        id: 'c-001',
        complaintNumber: 'HC-2026-076',
        title: 'IOP',
        description: 'Water leaking from pipe',
        category: 'Plumbing & Water Supply',
        priority: 'MEDIUM',
        status: 'COMPLETED',
        reportedByName: 'King Doe',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-101',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        raisedOnFormatted: '04 Nov 2026, 02:23 PM',
      );

      final mockDetail = HostelComplaintDetail360(
        complaint: mockComplaint,
        feedback: mockFeedback,
        comments: [],
        assignments: [],
        history: [
          ComplaintHistoryItem(
            id: 'h1',
            actorName: 'King Doe',
            eventTitle: 'Requester submitted feedback (5★)',
            actionNote: 'Technician fixed the AC quickly and cleaned up afterwards.',
            createdAt: DateTime.now(),
            timeFormatted: '05 Nov 2026, 05:38 AM',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              isComplaintDrawerOpen: true,
              selectedComplaintId: 'c-001',
              selectedComplaintDetail: mockDetail,
            );
            return notifier;
          }),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintDetailDrawer(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Resident Resolution Feedback Card is displayed
      expect(find.text('Resident Resolution Feedback'), findsOneWidget);
      expect(find.text('Resident Resolution Feedback'), findsOneWidget);
      // Average rating computed from (4 + 5 + 5) / 3.0 = 4.7 ★
      expect(find.text('4.7 ★'), findsWidgets);
      expect(find.text('Requester submitted feedback (4.7 ★)'), findsOneWidget);
      expect(find.text('Resident Satisfied'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Technician fixed the AC quickly and cleaned up afterwards.'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('HostelComplaintDetailDrawer computes dynamic 3.7 rating from aspect ratings (2, 4, 5)', (tester) async {
      final mockFeedback = ComplaintFeedbackItem(
        rating: 5,
        resolutionQuality: 2,
        responseTimeRating: 4,
        staffBehaviorRating: 5,
        comment: 'Fair resolution with 3.7 average rating.',
        isSatisfied: true,
        createdAt: DateTime.now(),
      );

      // Verify model getter computes 3.7
      expect(mockFeedback.averageRating, equals(3.7));
      expect(mockFeedback.ratingLabel, equals('Very Good'));

      final mockComplaint = HostelComplaintItem(
        id: 'c-002',
        complaintNumber: 'HC-2026-076',
        title: 'IOP',
        description: 'Test water leak',
        category: 'Plumbing & Water Supply',
        priority: 'MEDIUM',
        status: 'COMPLETED',
        reportedByName: 'King Doe',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-101',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        raisedOnFormatted: '04 Nov 2026, 02:23 PM',
      );

      final mockDetail = HostelComplaintDetail360(
        complaint: mockComplaint,
        feedback: mockFeedback,
        comments: [],
        assignments: [],
        history: [
          ComplaintHistoryItem(
            id: 'h1',
            actorName: 'King Doe',
            eventTitle: 'Requester submitted feedback (5???)', // tests legacy ??? sanitization
            actionNote: 'Fair resolution with 3.7 average rating.',
            createdAt: DateTime.now(),
            timeFormatted: '05 Nov 2026, 12:19 PM',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              isComplaintDrawerOpen: true,
              selectedComplaintId: 'c-002',
              selectedComplaintDetail: mockDetail,
            );
            return notifier;
          }),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HostelComplaintDetailDrawer(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top hero badge displays 3.7
      expect(find.text('3.7'), findsOneWidget);

      // Feedback card displays 3.7 ★
      expect(find.text('3.7 ★'), findsOneWidget);

      // Timeline sanitizes ??? and dynamically formats Requester submitted feedback (3.7 ★)
      expect(find.text('Requester submitted feedback (3.7 ★)'), findsOneWidget);
      expect(find.textContaining('???'), findsNothing);

      expect(tester.takeException(), isNull);
    });

  });
}