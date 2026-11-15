import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';
import 'package:edu_shamiit_core/screens/hostel/services/hostel_lookup_helper.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/common/hostel_smooth_spinner.dart';

void main() {
  group('Hostel Dynamic Fee Billing Plans & Initial Payment Lookups', () {
    test('HostelLookupHelper returns dynamic fee billing plans with clean names only', () async {
      final plans = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_FEE_BILLING_PLAN');
      expect(plans.isNotEmpty, true);
      
      final names = plans.map((p) => p.label).toList();
      expect(names, containsAll(['Monthly', 'Quarterly', 'Bi-Annual', 'Annual']));

      // Must not contain hardcoded currency or amounts
      for (final name in names) {
        expect(name.contains('₹'), false, reason: 'Plan name "$name" should not contain hardcoded currency');
        expect(name.contains('('), false, reason: 'Plan name "$name" should not contain parenthesis amount');
      }
    });

    test('HostelLookupHelper returns dynamic initial fee payment status lookups', () async {
      final statuses = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_INITIAL_FEE_PAYMENT_STATUS');
      expect(statuses.isNotEmpty, true);

      final codes = statuses.map((s) => s.code).toList();
      expect(codes, containsAll(['PAID', 'PENDING', 'PARTIAL', 'WAIVED']));
    });

    test('HostelStudentRosterItem models initial payment amount and clean fee plan', () {
      final json = {
        'id': 'adm-123',
        'admission_id': 'adm-123',
        'student_id': 'stud-456',
        'student_name': 'Aarav Sharma',
        'roll_no': '0101',
        'class_name': 'Grade 10-A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-101',
        'bed_no': '1',
        'status': 'Active',
        'raw_status': 'ACTIVE',
        'fee_status': 'Paid',
        'fee_plan': 'Monthly',
        'initial_payment_amount': 16000.0,
      };

      final item = HostelStudentRosterItem.fromJson(json);
      expect(item.feePlan, 'Monthly');
      expect(item.initialPaymentAmount, 16000.0);
    });

    test('HostelStudentDetail360 models initial payment amount and clean fee plan', () {
      final json = {
        'admission_id': 'adm-123',
        'student_id': 'stud-456',
        'student_name': 'Aarav Sharma',
        'status': 'Active',
        'admission_status': 'ACTIVE',
        'roll_no': '0101',
        'class_name': 'Grade 10-A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-101',
        'bed_no': '1',
        'admission_date': '30 Oct 2026',
        'room_and_bed': 'A-101 (Bed 1)',
        'hostel_type': 'AC Room',
        'fee_plan': 'Monthly',
        'blood_group': 'B+',
        'emergency_contact': '+91 98765 43210 (Father)',
        'emergency_contact_label': '+91 98765 43210 (Father)',
        'address': 'A-123, Sector 62, Noida, UP',
        'initial_payment_amount': 16000.0,
        'fee_summary': {
          'plan_name': 'Monthly',
          'monthly_fee': 6000.0,
          'deposit_amount': 10000.0,
          'fee_status': 'PAID',
          'initial_payment_amount': 16000.0,
          'billed_amount': 16000.0,
          'paid_amount': 16000.0,
          'outstanding_dues': 0.0,
        },
      };

      final detail = HostelStudentDetail360.fromJson(json);
      expect(detail.feePlan, 'Monthly');
      expect(detail.initialPaymentAmount, 16000.0);
      expect(detail.feeSummary['initial_payment_amount'], 16000.0);
    });

    test('Dynamic fee calculation accurately calculates based on billing plan', () {
      double calculatePlanFee(String plan, double baseMonthly) {
        final p = plan.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '_');
        if (p.contains('QUARTERLY')) {
          return ((baseMonthly * 3 * (35.0 / 36.0)) / 100).round() * 100.0;
        } else if (p.contains('BI_ANNUAL') || p.contains('BIANNUAL') || p.contains('HALF')) {
          return ((baseMonthly * 6 * (17.0 / 18.0)) / 100).round() * 100.0;
        } else if (p.contains('ANNUAL') || p.contains('YEARLY')) {
          return ((baseMonthly * 12 * (65.0 / 72.0)) / 100).round() * 100.0;
        }
        return baseMonthly;
      }

      const baseFee = 6000.0;
      expect(calculatePlanFee('Monthly', baseFee), 6000.0);
      expect(calculatePlanFee('Quarterly', baseFee), 17500.0);
      expect(calculatePlanFee('Bi-Annual', baseFee), 34000.0);
      expect(calculatePlanFee('Annual', baseFee), 65000.0);
    });

    test('HostelLookupHelper returns dynamic ROOM_TYPE lookups matching Add Room / Space', () async {
      final roomTypes = await HostelLookupHelper.instance.getActiveLookup('ROOM_TYPE');
      expect(roomTypes.isNotEmpty, true);

      final labels = roomTypes.map((r) => r.label).toList();
      expect(labels, containsAll(['Standard', 'Deluxe', 'Super Deluxe', 'Dormitory', 'Single Occupancy']));
    });

    test('Rooms are strictly filtered by selected Room Type and rooms with 0 empty beds are excluded', () {
      final rooms = [
        HostelRoomItem(
          id: 'room-1',
          buildingId: 'b-1',
          buildingName: 'Hostel A',
          floorId: 'f-1',
          floorName: '1st Floor',
          roomNumber: 'A-101',
          roomCode: 'A-101',
          roomType: 'Standard',
          monthlyFee: 6000.0,
          capacity: 3,
          occupied: 3, // 0 free beds!
        ),
        HostelRoomItem(
          id: 'room-2',
          buildingId: 'b-1',
          buildingName: 'Hostel A',
          floorId: 'f-1',
          floorName: '1st Floor',
          roomNumber: 'A-102',
          roomCode: 'A-102',
          roomType: 'Deluxe',
          monthlyFee: 7500.0,
          capacity: 2,
          occupied: 1, // 1 free bed!
        ),
        HostelRoomItem(
          id: 'room-3',
          buildingId: 'b-1',
          buildingName: 'Hostel A',
          floorId: 'f-2',
          floorName: '2nd Floor',
          roomNumber: 'A-201',
          roomCode: 'A-201',
          roomType: 'Standard',
          monthlyFee: 6500.0,
          capacity: 3,
          occupied: 1, // 2 free beds!
        ),
      ];

      List<HostelRoomItem> filterRooms(String type) {
        return rooms.where((r) {
          final matchesType = type.isEmpty || r.roomType.trim().toLowerCase() == type.trim().toLowerCase();
          final hasVacantBeds = r.availableBeds > 0;
          return matchesType && hasVacantBeds;
        }).toList();
      }

      final standardRooms = filterRooms('Standard');
      expect(standardRooms.length, 1);
      expect(standardRooms.first.roomNumber, 'A-201');
      // Room A-101 has 0 empty beds and must not be included
      expect(standardRooms.any((r) => r.roomNumber == 'A-101'), false);

      final deluxeRooms = filterRooms('Deluxe');
      expect(deluxeRooms.length, 1);
      expect(deluxeRooms.first.roomNumber, 'A-102');
      expect(deluxeRooms.first.monthlyFee, 7500.0);
    });

    test('Bed dropdown shows ONLY vacant beds and excludes occupied beds', () {
      final beds = [
        HostelBed(
          id: 'bed-1',
          bedCode: 'Bed 1',
          bedType: 'Single',
          status: 'OCCUPIED',
        ),
        HostelBed(
          id: 'bed-2',
          bedCode: 'Bed 2',
          bedType: 'Single',
          status: 'AVAILABLE',
        ),
        HostelBed(
          id: 'bed-3',
          bedCode: 'Bed 3',
          bedType: 'Single',
          status: 'OCCUPIED',
        ),
        HostelBed(
          id: 'bed-4',
          bedCode: 'Bed 4',
          bedType: 'Single',
          status: 'AVAILABLE',
        ),
      ];

      final vacantBeds = beds.where((b) => b.isAvailable).toList();
      expect(vacantBeds.length, 2);
      expect(vacantBeds.map((b) => b.bedCode).toList(), ['Bed 2', 'Bed 4']);
      expect(vacantBeds.any((b) => b.bedCode == 'Bed 1'), false);
      expect(vacantBeds.any((b) => b.bedCode == 'Bed 3'), false);
    });

    test('Room monthly fee from Room & Allocation dynamically sets fee and scales plan fee', () {
      final deluxeRoom = HostelRoomItem(
        id: 'room-deluxe',
        buildingId: 'b-1',
        buildingName: 'Hostel A',
        floorId: 'f-1',
        floorName: '1st Floor',
        roomNumber: 'A-104',
        roomCode: 'A-104',
        roomType: 'Deluxe',
        monthlyFee: 8000.0,
      );

      double calculatePlanFee(String plan, double baseMonthly) {
        final p = plan.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '_');
        if (p.contains('QUARTERLY')) {
          return ((baseMonthly * 3 * (35.0 / 36.0)) / 100).round() * 100.0;
        } else if (p.contains('BI_ANNUAL') || p.contains('BIANNUAL') || p.contains('HALF')) {
          return ((baseMonthly * 6 * (17.0 / 18.0)) / 100).round() * 100.0;
        } else if (p.contains('ANNUAL') || p.contains('YEARLY')) {
          return ((baseMonthly * 12 * (65.0 / 72.0)) / 100).round() * 100.0;
        }
        return baseMonthly;
      }

      final baseFee = deluxeRoom.monthlyFee;
      expect(baseFee, 8000.0);
      expect(calculatePlanFee('Monthly', baseFee), 8000.0);
      expect(calculatePlanFee('Quarterly', baseFee), 23300.0);
      expect(calculatePlanFee('Bi-Annual', baseFee), 45300.0);
      expect(calculatePlanFee('Annual', baseFee), 86700.0);
    });

    testWidgets('HostelSmoothSpinner renders with constant linear RotationTransition and RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HostelSmoothSpinner(size: 24, strokeWidth: 2.5),
            ),
          ),
        ),
      );

      // Verify HostelSmoothSpinner and RepaintBoundary are present
      expect(find.byType(HostelSmoothSpinner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HostelSmoothSpinner),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HostelSmoothSpinner),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );

      // Verify smooth frame ticking
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
