// ignore_for_file: prefer_const_constructors, prefer_const_declarations
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/visitors_header_bar.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/visitors_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/scheduled_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/blacklisted_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/appointment_reschedule_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/appointment_reject_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/restriction_lift_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/restriction_update_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_registration_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/utils/visitor_avatar_helper.dart';

void main() {
  group('Visitors Management - Models & Serialization', () {
    test('VisitorKPIs parses backend JSON with 6 cards data', () {
      final json = {
        'total_visitors': 256,
        'total_trend': '↑ 12%',
        'total_subtitle': 'This Month',
        'currently_inside': 38,
        'currently_inside_subtitle': 'On campus now',
        'checked_in_today': 62,
        'checked_in_today_subtitle': 'Till now',
        'checked_out_today': 58,
        'checked_out_today_subtitle': 'Completed visits',
        'overstay': 4,
        'overstay_subtitle': 'Exceeding allowed time',
        'scheduled_today': 12,
        'scheduled_today_subtitle': 'Upcoming visitors',
      };

      final kpis = VisitorKPIs.fromJson(json);
      expect(kpis.totalVisitors, equals(256));
      expect(kpis.totalTrend, equals('↑ 12%'));
      expect(kpis.currentlyInside, equals(38));
      expect(kpis.checkedInToday, equals(62));
      expect(kpis.checkedOutToday, equals(58));
      expect(kpis.overstay, equals(4));
      expect(kpis.scheduledToday, equals(12));
    });

    test('ScheduledKPIs parses exact 5 cards matching Screenshot 1', () {
      final json = {
        'total_scheduled': 12,
        'total_scheduled_subtitle': 'Upcoming visitors',
        'today': 4,
        'today_subtitle': 'Scheduled for today',
        'this_week': 8,
        'this_week_subtitle': 'Next 7 days',
        'expected_visitors': 26,
        'expected_visitors_subtitle': 'This week',
        'pending_approval': 3,
        'pending_approval_subtitle': 'Awaiting approval',
      };

      final kpis = ScheduledKPIs.fromJson(json);
      expect(kpis.totalScheduled, equals(12));
      expect(kpis.today, equals(4));
      expect(kpis.thisWeek, equals(8));
      expect(kpis.expectedVisitors, equals(26));
      expect(kpis.pendingApproval, equals(3));
    });

    test('BlacklistKPIs parses exact 4 cards matching Screenshot 2', () {
      final json = {
        'total_blacklisted': 18,
        'total_blacklisted_subtitle': 'Restricted from entry',
        'active_blocks': 15,
        'active_blocks_subtitle': 'Currently restricted',
        'expired_blocks': 3,
        'expired_blocks_subtitle': 'Restriction ended',
        'attempted_entries': 5,
        'attempted_entries_subtitle': 'Blocked at gate',
      };

      final kpis = BlacklistKPIs.fromJson(json);
      expect(kpis.totalBlacklisted, equals(18));
      expect(kpis.activeBlocks, equals(15));
      expect(kpis.expiredBlocks, equals(3));
      expect(kpis.attemptedEntries, equals(5));
    });

    test('ScheduledAppointmentItem parses all fields from Screenshot 1', () {
      final json = {
        'id': 'a1000001-0000-0000-0000-000000000001',
        'appointment_number': 'APT-001',
        'visitor_id': 'v1',
        'visitor_name': 'Mr. Rajesh Kumar',
        'phone': '+91 98765 43210',
        'email': 'rajesh@gmail.com',
        'visitor_type': 'Parent',
        'host_name': 'Rahul Sharma',
        'host_subtitle': 'Class 10 A',
        'purpose': 'PTM Meeting',
        'location': 'Main Gate',
        'destination': 'Main Gate',
        'scheduled_date': '12 May 2024',
        'scheduled_start_at': '10:00 AM',
        'scheduled_end_at': '11:00 AM',
        'date_time_text': '12 May 2024\n10:00 AM - 11:00 AM',
        'status': 'Confirmed',
        'expected_count': 2,
        'expected_visitors_text': '2 (Self + Spouse)',
        'vehicle_number': 'UP16 AB 1234',
        'id_type': 'Aadhaar Card',
        'id_number_masked': 'XXXX-XXXX-1234',
        'remarks': 'Discussion about academic progress and future plan.',
      };

      final appt = ScheduledAppointmentItem.fromJson(json);
      expect(appt.visitorName, equals('Mr. Rajesh Kumar'));
      expect(appt.purpose, equals('PTM Meeting'));
      expect(appt.status, equals('Confirmed'));
      expect(appt.expectedVisitorsText, equals('2 (Self + Spouse)'));
      expect(appt.vehicleNumber, equals('UP16 AB 1234'));
      expect(appt.idNumberMasked, equals('XXXX-XXXX-1234'));
    });

    test('BlacklistedVisitorItem parses all fields from Screenshot 2', () {
      final json = {
        'id': 'r1000001-0000-0000-0000-000000000001',
        'visitor_name': 'Rohit Malhotra',
        'visitor_phone': '+91 98765 43210',
        'id_type': 'Aadhaar Card',
        'id_number_masked': 'XXXX-XXXX-1234',
        'scope_name': 'Main Gate',
        'reason_category': 'Theft',
        'status': 'Active',
        'blocked_on': '12 May 2024, 10:30 AM',
        'valid_till': 'Permanent',
        'is_permanent': true,
        'blocked_by_name': 'Rahul Sharma (Security)',
        'remarks': 'Attempted to steal student belongings. Caught on CCTV.',
      };

      final item = BlacklistedVisitorItem.fromJson(json);
      expect(item.visitorName, equals('Rohit Malhotra'));
      expect(item.reasonCategory, equals('Theft'));
      expect(item.scopeName, equals('Main Gate'));
      expect(item.validTillText, equals('Permanent'));
      expect(item.status, equals('Active'));
      expect(item.blockedByName, equals('Rahul Sharma (Security)'));
    });

    test('HostSearchResultItem parses student with active outing and hostel room', () {
      final json = {
        'id': 's101',
        'full_name': 'Aarav Patel',
        'role': 'student',
        'class_section': '10-A',
        'roll_number': '101',
        'hostel_room': 'Boys Hostel 204',
        'has_active_outing': true,
        'outing_details': 'Medical Outing till 6:00 PM',
      };

      final host = HostSearchResultItem.fromJson(json);
      expect(host.isStudent, isTrue);
      expect(host.fullName, equals('Aarav Patel'));
      expect(host.displayName, contains('Aarav Patel (Class 10-A)'));
      expect(host.classSection, equals('10-A'));
      expect(host.rollNumber, equals('101'));
      expect(host.hostelRoom, equals('Boys Hostel 204'));
      expect(host.hasActiveOuting, isTrue);
      expect(host.outingDetails, equals('Medical Outing till 6:00 PM'));
    });

    test('HostSearchResultItem parses staff member with department correctly', () {
      final json = {
        'id': 'st201',
        'full_name': 'Dr. Meenakshi Sundaram',
        'role': 'staff',
        'department': 'Science Lab',
        'designation': 'HOD Chemistry',
        'has_active_outing': false,
      };

      final host = HostSearchResultItem.fromJson(json);
      expect(host.isStudent, isFalse);
      expect(host.fullName, equals('Dr. Meenakshi Sundaram'));
      expect(host.displayName, contains('Dr. Meenakshi Sundaram (HOD Chemistry)'));
      expect(host.department, equals('Science Lab'));
      expect(host.hasActiveOuting, isFalse);
    });

    test('InstantRestrictionResult parses active blacklist with supervisor override rationale', () {
      final json = {
        'is_restricted': true,
        'restriction_type': 'security_block',
        'restriction_reason': 'Attempted unauthorized entry at rear perimeter',
        'scope': 'All Campus Locations',
      };

      final result = InstantRestrictionResult.fromJson(json);
      expect(result.isRestricted, isTrue);
      expect(result.restrictionType, equals('security_block'));
      expect(result.restrictionReason, equals('Attempted unauthorized entry at rear perimeter'));
      expect(result.profile, isNull);
    });

    test('InstantRestrictionResult parses clear record with returning visitor profile', () {
      final json = {
        'is_restricted': false,
        'profile': {
          'id': 'v-ret-001',
          'full_name': 'Kavita Verma',
          'phone': '+91 98765 00000',
          'visitor_type': 'Parent',
          'id_type': 'Aadhaar Card',
          'id_number_masked': 'XXXX-XXXX-4567',
        },
      };

      final result = InstantRestrictionResult.fromJson(json);
      expect(result.isRestricted, isFalse);
      expect(result.profile, isNotNull);
      expect(result.profile!.fullName, equals('Kavita Verma'));
      expect(result.profile!.visitorType, equals('Parent'));
      expect(result.profile!.idNumberMasked, equals('XXXX-XXXX-4567'));
    });
  });

  group('Visitors Management - State & Provider', () {
    test('VisitorsState default initializes with 3 primary tabs and empty selections', () {
      const state = VisitorsState();
      expect(state.activeTab, equals(0));
      expect(state.isDrawerOpen, isFalse);
      expect(state.selectedVisit, isNull);
      expect(state.selectedAppointment, isNull);
      expect(state.selectedRestriction, isNull);
      expect(state.selectedLocation, equals('All Locations'));
      expect(state.selectedCategory, equals('All Visitor Types'));
    });

    test('VisitorsState copyWith updates active tab correctly', () {
      const state = VisitorsState();
      final updated = state.copyWith(activeTab: 1);
      expect(updated.activeTab, equals(1));
    });

    test('VisitorsState copyWith updates filter criteria', () {
      const state = VisitorsState();
      final updated = state.copyWith(
        searchQuery: 'Rajesh',
        selectedLocation: 'Library',
        selectedStatus: 'Inside',
      );
      expect(updated.searchQuery, equals('Rajesh'));
      expect(updated.selectedLocation, equals('Library'));
      expect(updated.selectedStatus, equals('Inside'));
    });

    test('VisitorsNotifier searchHosts returns matching host list', () async {
      final notifier = MockVisitorsNotifier(const VisitorsState());
      final results = await notifier.searchHosts('Aarav');
      expect(results.length, equals(1));
      expect(results.first.fullName, equals('Aarav Patel'));
      expect(results.first.isStudent, isTrue);
      expect(results.first.hasActiveOuting, isTrue);
    });

    test('VisitorsNotifier checkInstantRestriction identifies restricted vs clear visitors', () async {
      final notifier = MockVisitorsNotifier(const VisitorsState());
      final blocked = await notifier.checkInstantRestriction(phone: '+91 99999 99999');
      expect(blocked.isRestricted, isTrue);
      expect(blocked.restrictionType, equals('security_block'));

      final clear = await notifier.checkInstantRestriction(phone: '+91 98765 00000');
      expect(clear.isRestricted, isFalse);
      expect(clear.profile, isNotNull);
      expect(clear.profile!.fullName, equals('Returning Parent'));
    });

    test('VisitorsNotifier checkInAppointment returns issued gate pass and updates status', () async {
      final notifier = MockVisitorsNotifier(const VisitorsState());
      final pass = await notifier.checkInAppointment('appt-100');
      expect(pass, isNotNull);
      expect(pass!['pass_number'], equals('GP-2024-TEST'));
      expect(pass['visitor_name'], equals('Test Visitor'));
    });

    test('VisitorsNotifier getExecutiveSummaryReport returns aggregated report map', () async {
      final notifier = MockVisitorsNotifier(const VisitorsState());
      final report = await notifier.getExecutiveSummaryReport();
      expect(report['total_visits'], equals(120));
      expect(report['inside_now'], equals(15));
      expect(report['active_restrictions'], equals(4));
    });
  });

  group('Visitors Management - Widgets & UI Integrity', () {
    testWidgets('VisitorsHeaderBar renders exactly 3 primary tabs + action button', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorsHeaderBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & subtitle
      expect(find.text('Visitors Management'), findsOneWidget);
      expect(find.textContaining('Manage visitors across all institute locations'), findsOneWidget);

      // Verify EXACTLY THREE PRIMARY TABS
      expect(find.text('All Visitors'), findsOneWidget);
      expect(find.text('Scheduled Visitors'), findsOneWidget);
      expect(find.text('Blacklisted Visitors'), findsOneWidget);

      // Ensure forbidden extra tabs are NOT present
      expect(find.text('Check-In'), findsNothing);
      expect(find.text('Currently Inside'), findsNothing);
      expect(find.text('Past Visitors'), findsNothing);
      expect(find.text('Visitor Categories'), findsNothing);
      expect(find.text('Gate Passes'), findsNothing);

      // On Tab 0, Register Visitor lives in the table toolbar (as per design mockup)
      expect(find.text('Schedule Visitor'), findsNothing);
      expect(find.text('Add to Blocklist'), findsNothing);
    });

    testWidgets('VisitorsHeaderBar renders Schedule Visitor button on Tab 1', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final stateTab1 = const VisitorsState(activeTab: 1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => MockVisitorsNotifier(stateTab1)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisitorsHeaderBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Schedule Visitor'), findsOneWidget);
    });

    testWidgets('VisitorsHeaderBar renders Add to Blocklist button on Tab 2', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final stateTab2 = const VisitorsState(activeTab: 2);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => MockVisitorsNotifier(stateTab2)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisitorsHeaderBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add to Blocklist'), findsOneWidget);
    });

    testWidgets('VisitorsKPICards renders all 6 dashboard metric cards', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final state = VisitorsState(
        kpis: const VisitorKPIs(
          totalVisitors: 256,
          currentlyInside: 38,
          checkedInToday: 62,
          checkedOutToday: 58,
          overstay: 4,
          scheduledToday: 12,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => MockVisitorsNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisitorsKPICards(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 6 KPI Card Labels
      expect(find.text('Total Visitors'), findsOneWidget);
      expect(find.text('Currently Inside'), findsOneWidget);
      expect(find.text('Checked In Today'), findsOneWidget);
      expect(find.text('Checked Out Today'), findsOneWidget);
      expect(find.text('Overstay'), findsOneWidget);
      expect(find.text('Scheduled Today'), findsOneWidget);

      // Verify Values
      expect(find.text('256'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('62'), findsOneWidget);
      expect(find.text('58'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('ScheduledVisitorsTab renders 5 KPI cards, table toolbar and inspector', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final appt = ScheduledAppointmentItem(
        id: 'a1',
        appointmentNumber: 'APT-001',
        visitorId: 'v1',
        visitorName: 'Mr. Rajesh Kumar',
        phone: '+91 98765 43210',
        email: 'rajesh@gmail.com',
        visitorType: 'Parent',
        hostName: 'Rahul Sharma',
        hostSubtitle: 'Class 10 A',
        purpose: 'PTM Meeting',
        destination: 'Main Gate',
        location: 'Main Gate',
        scheduledDate: '12 May 2024',
        scheduledStartAt: '10:00 AM',
        scheduledEndAt: '11:00 AM',
        dateTimeText: '12 May 2024\n10:00 AM - 11:00 AM',
        status: 'Confirmed',
        expectedCount: 2,
        expectedVisitorsText: '2 (Self + Spouse)',
        vehicleNumber: 'UP16 AB 1234',
        remarks: 'Discussion about academic progress and future plan.',
      );

      final state = VisitorsState(
        activeTab: 1,
        scheduledKpis: const ScheduledKPIs(
          totalScheduled: 12,
          today: 4,
          thisWeek: 8,
          expectedVisitors: 26,
          pendingApproval: 3,
        ),
        appointments: [appt],
        selectedAppointment: appt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => MockVisitorsNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScheduledVisitorsTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 5 KPI cards
      expect(find.text('Total Scheduled'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Expected Visitors'), findsWidgets);
      expect(find.text('26'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify Table Toolbar
      expect(find.text('Calendar View'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Bulk Actions'), findsOneWidget);

      // Verify Visitor Details Right Drawer
      expect(find.text('Visitor Details'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Reschedule'), findsWidgets);
      expect(find.text('Cancel Visit'), findsOneWidget);
    });

    testWidgets('BlacklistedVisitorsTab renders 4 KPI cards, table toolbar and inspector', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final rest = BlacklistedVisitorItem(
        id: 'r1',
        visitorId: 'v1',
        visitorName: 'Rohit Malhotra',
        visitorPhone: '+91 98765 43210',
        idType: 'Aadhaar Card',
        idNumberMasked: 'XXXX-XXXX-1234',
        scopeType: 'INSTITUTION',
        scopeName: 'Main Gate',
        reasonCategory: 'Theft',
        confidentialNotes: 'Attempted to steal student belongings. Caught on CCTV.',
        status: 'Active',
        effectiveFrom: '12 May 2024',
        blockedOnText: '12 May 2024, 10:30 AM',
        validTillText: 'Permanent',
        isPermanent: true,
        blockedByName: 'Rahul Sharma (Security)',
        remarks: 'Attempted to steal student belongings. Caught on CCTV.',
      );

      final state = VisitorsState(
        activeTab: 2,
        blacklistKpis: const BlacklistKPIs(
          totalBlacklisted: 18,
          activeBlocks: 15,
          expiredBlocks: 3,
          attemptedEntries: 5,
        ),
        restrictions: [rest],
        selectedRestriction: rest,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => MockVisitorsNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BlacklistedVisitorsTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 4 KPI cards
      expect(find.text('Total Blacklisted'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Active Blocks'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Expired Blocks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Attempted Entries'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify Table Toolbar
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Bulk Actions'), findsOneWidget);

      // Verify Inspector Drawer with Buttons
      expect(find.text('Visitor Details'), findsOneWidget);
      expect(find.text('Remove from Blocklist'), findsOneWidget);
      expect(find.text('Update Details'), findsWidgets);
    });

    testWidgets('AppointmentRescheduleDialog renders with date and time pickers', (WidgetTester tester) async {
      final appt = ScheduledAppointmentItem(
        id: 'a1',
        appointmentNumber: 'APT-001',
        visitorId: 'v1',
        visitorName: 'Mr. Rajesh Kumar',
        phone: '+91 98765 43210',
        visitorType: 'Parent',
        hostName: 'Rahul Sharma',
        purpose: 'PTM Meeting',
        destination: 'Main Gate',
        scheduledDate: '12 May 2024',
        scheduledStartAt: '10:00 AM',
        scheduledEndAt: '11:00 AM',
        status: 'Confirmed',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentRescheduleDialog(appointment: appt),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reschedule Appointment'), findsOneWidget);
      expect(find.text('Confirm Reschedule'), findsOneWidget);
    });

    testWidgets('AppointmentRejectDialog renders with rejection reason', (WidgetTester tester) async {
      final appt = ScheduledAppointmentItem(
        id: 'a1',
        appointmentNumber: 'APT-001',
        visitorId: 'v1',
        visitorName: 'Mr. Rajesh Kumar',
        phone: '+91 98765 43210',
        visitorType: 'Parent',
        hostName: 'Rahul Sharma',
        purpose: 'PTM Meeting',
        destination: 'Main Gate',
        scheduledDate: '12 May 2024',
        scheduledStartAt: '10:00 AM',
        scheduledEndAt: '11:00 AM',
        status: 'Confirmed',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentRejectDialog(appointment: appt),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reject Appointment'), findsOneWidget);
      expect(find.text('Confirm Rejection'), findsOneWidget);
    });

    testWidgets('RestrictionLiftDialog renders with lifting justification', (WidgetTester tester) async {
      final rest = BlacklistedVisitorItem(
        id: 'r1',
        visitorId: 'v1',
        visitorName: 'Rohit Malhotra',
        visitorPhone: '+91 98765 43210',
        scopeType: 'INSTITUTION',
        scopeName: 'Main Gate',
        reasonCategory: 'Theft',
        confidentialNotes: 'Notes',
        status: 'Active',
        effectiveFrom: '12 May 2024',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RestrictionLiftDialog(restriction: rest),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove from Blocklist'), findsOneWidget);
      expect(find.text('Confirm Lift'), findsOneWidget);
    });

    testWidgets('RestrictionUpdateDialog renders with editable fields', (WidgetTester tester) async {
      final rest = BlacklistedVisitorItem(
        id: 'r1',
        visitorId: 'v1',
        visitorName: 'Rohit Malhotra',
        visitorPhone: '+91 98765 43210',
        scopeType: 'INSTITUTION',
        scopeName: 'Main Gate',
        reasonCategory: 'Theft',
        confidentialNotes: 'Notes',
        status: 'Active',
        effectiveFrom: '12 May 2024',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RestrictionUpdateDialog(restriction: rest),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Restriction Details'), findsOneWidget);
      expect(find.text('Save Details'), findsOneWidget);
    });

    // =========================================================================
    // RESPONSIVE TESTS ACROSS DEVICE FORM FACTORS (MOBILE, TABLET, DESKTOP)
    // =========================================================================
    testWidgets('VisitorsHeaderBar adapts seamlessly on Mobile (360x640), Tablet (768x1024), and Desktop (1440x900)', (WidgetTester tester) async {
      final testSizes = [
        const Size(360, 640),  // Mobile phone
        const Size(768, 1024), // Tablet
        const Size(1440, 900), // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: VisitorsHeaderBar(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Visitors Management'), findsOneWidget);
        expect(find.text('All Visitors'), findsOneWidget);
        expect(find.text('Scheduled Visitors'), findsOneWidget);
        expect(find.text('Blacklisted Visitors'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('VisitorsKPICards adapts to all screen sizes without overflow', (WidgetTester tester) async {
      final testSizes = [
        const Size(360, 640),  // Mobile
        const Size(768, 1024), // Tablet
        const Size(1280, 800), // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: VisitorsKPICards(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Visitors'), findsOneWidget);
        expect(find.text('Currently Inside'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ScheduledVisitorsTab renders without overflow on mobile, tablet, and desktop', (WidgetTester tester) async {
      final testSizes = [
        const Size(360, 640),  // Mobile
        const Size(768, 1024), // Tablet
        const Size(1440, 900), // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ScheduledVisitorsTab(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Scheduled'), findsOneWidget);
        expect(find.text('Expected Visitors'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('BlacklistedVisitorsTab renders without overflow on mobile, tablet, and desktop', (WidgetTester tester) async {
      final testSizes = [
        const Size(360, 640),  // Mobile
        const Size(768, 1024), // Tablet
        const Size(1440, 900), // Desktop
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: BlacklistedVisitorsTab(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Blacklisted'), findsOneWidget);
        expect(find.text('Active Blocks'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('VisitorAvatar renders safely with Base64 Data URI and fallback initial', (tester) async {
      // 1. With fallback initial
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisitorAvatar(photoUrl: null, name: 'Lifecycle Visitor'),
          ),
        ),
      );
      expect(find.text('L'), findsOneWidget);

      // 2. With base64 Data URI (1x1 transparent PNG)
      const base64Pixel = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VisitorAvatar(photoUrl: base64Pixel, name: 'Lifecycle Visitor'),
          ),
        ),
      );
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('VisitorRegistrationDialog populates existing visitor details and Save Changes button in edit mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      const existing = VisitorItem(
        id: 'visit-123',
        visitNumber: 'VIS-2024-001',
        visitorId: 'vis-456',
        visitorName: 'Lifecycle Visitor',
        phone: '+91 9888b3f924',
        visitorType: 'Parent',
        category: 'Parent',
        purpose: 'Official Audit',
        location: 'Admin Office',
        destination: 'Admin Office',
        hostName: 'Finance Head',
        checkInAt: '15 Oct 2026, 10:51 PM',
        status: 'Checked Out',
        photoUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorRegistrationDialog(existingVisit: existing),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Visitor'), findsOneWidget);
      expect(find.text('Lifecycle Visitor'), findsOneWidget);
      expect(find.text('+91 9888b3f924'), findsOneWidget);
      expect(find.text('Official Audit'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class MockVisitorsNotifier extends VisitorsNotifier {
  MockVisitorsNotifier(VisitorsState initialState) : super(FakeVisitorsApiService()) {
    state = initialState;
  }

  @override
  Future<void> init() async {}
}

class FakeVisitorsApiService extends VisitorsApiService {
  @override
  Future<Map<String, dynamic>> checkInAppointment(
    String appointmentId, {
    String entryLocation = 'Main Gate',
    String? remarks,
  }) async {
    return {
      'success': true,
      'message': 'Appointment checked in successfully',
      'data': {
        'visit_id': 'visit-test-001',
        'pass_number': 'GP-2024-TEST',
        'visitor_name': 'Test Visitor',
      },
    };
  }

  @override
  Future<List<HostSearchResultItem>> searchHosts(String query) async {
    return [
      HostSearchResultItem.fromJson({
        'id': 'h1',
        'full_name': 'Aarav Patel',
        'role': 'student',
        'class_section': '10-A',
        'roll_number': '101',
        'hostel_room': 'Boys Hostel 204',
        'has_active_outing': true,
        'outing_details': 'Medical Leave till 6 PM',
      }),
    ];
  }

  @override
  Future<InstantRestrictionResult> checkInstantRestriction({String? phone, String? idNumber}) async {
    if (phone == '+91 99999 99999') {
      return InstantRestrictionResult.fromJson({
        'is_restricted': true,
        'restriction_type': 'security_block',
        'restriction_reason': 'Attempted unauthorized campus access',
      });
    }
    return InstantRestrictionResult.fromJson({
      'is_restricted': false,
      'profile': {
        'id': 'p1',
        'full_name': 'Returning Parent',
        'visitor_type': 'Parent',
        'id_type': 'Aadhaar Card',
        'id_number_masked': 'XXXX-XXXX-9999',
      },
    });
  }

  @override
  Future<Map<String, dynamic>> getExecutiveSummaryReport({String? dateFrom, String? dateTo}) async {
    return {
      'generated_at': '2026-10-25 22:00:00',
      'total_visits': 120,
      'inside_now': 15,
      'active_restrictions': 4,
    };
  }

  @override
  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
    String? search,
  }) async {
    return const VisitorKPIs();
  }

  @override
  Future<ScheduledKPIs> getScheduledKPIs({
    String? dateFrom,
    String? dateTo,
    String? location,
    String? category,
    String? search,
  }) async {
    return const ScheduledKPIs();
  }

  @override
  Future<Map<String, dynamic>> getAppointments({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    return {
      'records': <ScheduledAppointmentItem>[],
      'pagination': const VisitorPagination(),
    };
  }

  @override
  Future<Map<String, dynamic>> getVisits({
    String search = '',
    String location = 'All Locations',
    String category = 'All Visitor Types',
    String status = 'All Status',
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    return {
      'records': <VisitorItem>[],
      'pagination': const VisitorPagination(),
    };
  }
}
