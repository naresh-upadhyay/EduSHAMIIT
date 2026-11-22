import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/maintenance_models.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/maintenance_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/campus_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/facilities_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/widgets/location_multi_selector.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/dialogs/add_edit_vendor_contract_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/dialogs/maintenance_plan_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/subviews/vendor_contracts_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/subviews/maintenance_plans_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/maintenance_center_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Maintenance Vendor, Contract & Plan Models Serialization Tests', () {
    test('MaintenanceVendorItem parses complete contract and document attachment details', () {
      final json = {
        'id': 'v-001',
        'vendor_name': 'CoolAir Solutions Pvt Ltd',
        'contact_person': 'Rajesh Sharma',
        'phone': '+91 98801 23456',
        'email': 'support@coolair.com',
        'service_category': 'HVAC',
        'contract_type': 'AMC',
        'contract_ref_no': 'AMC-HVAC-2026-08',
        'contract_value': 145000.0,
        'contract_start': '2026-04-01',
        'contract_end': '2027-03-31',
        'sla_response_hours': 4.0,
        'sla_resolution_hours': 24.0,
        'agreement_url': 'https://assets.edushamiit.org/contracts/CoolAir_HVAC_Annual_Contract_2026.pdf',
        'contract_document_name': 'CoolAir_HVAC_Annual_Contract_2026.pdf',
        'notes': 'Bi-annual AC condenser servicing, quarterly air filter replacement.',
        'address': 'Plot 45, Industrial Area, Phase 2',
        'is_active': true,
      };

      final vendor = MaintenanceVendorItem.fromJson(json);

      expect(vendor.id, 'v-001');
      expect(vendor.vendorName, 'CoolAir Solutions Pvt Ltd');
      expect(vendor.contactPerson, 'Rajesh Sharma');
      expect(vendor.phone, '+91 98801 23456');
      expect(vendor.email, 'support@coolair.com');
      expect(vendor.serviceCategory, 'HVAC');
      expect(vendor.contractType, 'AMC');
      expect(vendor.contractRefNo, 'AMC-HVAC-2026-08');
      expect(vendor.contractValue, 145000.0);
      expect(vendor.contractStart, DateTime(2026, 4, 1));
      expect(vendor.contractEnd, DateTime(2027, 3, 31));
      expect(vendor.slaResponseHours, 4.0);
      expect(vendor.slaResolutionHours, 24.0);
      expect(vendor.agreementUrl, 'https://assets.edushamiit.org/contracts/CoolAir_HVAC_Annual_Contract_2026.pdf');
      expect(vendor.contractDocumentName, 'CoolAir_HVAC_Annual_Contract_2026.pdf');
      expect(vendor.notes, contains('Bi-annual AC condenser'));
      expect(vendor.isActive, true);
    });

    test('MaintenancePlanItem parses multi-location targets, recurrence intervals and vendor automation', () {
      final json = {
        'id': 'p-001',
        'plan_code': 'MP-001',
        'title': 'Bi-Annual AC Servicing & Filter Replacement',
        'category': 'HVAC',
        'frequency': 'Every 6 Months',
        'recurrence_interval_months': 6,
        'vendor_id': 'v-001',
        'vendor_name': 'CoolAir Solutions Pvt Ltd',
        'vendor_phone': '+91 98801 23456',
        'vendor_email': 'support@coolair.com',
        'send_vendor_email': true,
        'estimated_duration_hours': 3.5,
        'estimated_cost': 18000.0,
        'is_active': true,
        'next_due_date': '2026-11-22T00:00:00.000',
        'target_locations': [
          {'building_id': 'b-1', 'room_id': 'r-101', 'location_name': 'B1 / Room 101'},
          {'building_id': 'b-1', 'room_id': 'r-102', 'location_name': 'B1 / Room 102'},
          {'facility_id': 'fac-aud', 'location_name': 'Auditorium Central AC'},
        ],
        'checklist_items': [
          {'task': 'Clean air filters', 'status': 'Pending'},
          {'task': 'Check refrigerant pressure', 'status': 'Pending'},
        ],
      };

      final plan = MaintenancePlanItem.fromJson(json);

      expect(plan.id, 'p-001');
      expect(plan.planCode, 'MP-001');
      expect(plan.frequency, 'Every 6 Months');
      expect(plan.recurrenceIntervalMonths, 6);
      expect(plan.vendorName, 'CoolAir Solutions Pvt Ltd');
      expect(plan.vendorPhone, '+91 98801 23456');
      expect(plan.vendorEmail, 'support@coolair.com');
      expect(plan.sendVendorEmail, true);
      expect(plan.targetLocations.length, 3);
      expect(plan.checklistItems.length, 2);
    });

    test('MaintenanceRequestItem parses multi-location and vendor contact attributes', () {
      final json = {
        'id': 'req-001',
        'request_code': 'MT-0568',
        'title': 'AC Servicing & Coil Cleaning',
        'request_type': 'HVAC',
        'priority': 'High',
        'status': 'Scheduled',
        'location_display': 'Academic Block (A) > Second Floor > Room 203',
        'building_id': 'b-1',
        'building_name': 'Academic Block (A)',
        'floor_id': 'f-2',
        'room_id': 'r-203',
        'room_number': '203',
        'facility_id': 'fac-aud',
        'facility_name': 'Auditorium',
        'reported_by_name': 'Admin',
        'reported_at': '2026-11-22T10:00:00.000',
        'assigned_vendor_name': 'CoolAir Solutions Pvt Ltd',
        'vendor_phone': '+91 98801 23456',
        'vendor_email': 'support@coolair.com',
      };

      final req = MaintenanceRequestItem.fromJson(json);

      expect(req.id, 'req-001');
      expect(req.requestCode, 'MT-0568');
      expect(req.buildingName, 'Academic Block (A)');
      expect(req.roomNumber, '203');
      expect(req.facilityId, 'fac-aud');
      expect(req.facilityName, 'Auditorium');
      expect(req.assignedVendorName, 'CoolAir Solutions Pvt Ltd');
      expect(req.vendorPhone, '+91 98801 23456');
      expect(req.vendorEmail, 'support@coolair.com');
    });
  });

  group('2. LocationMultiSelector Component Tests', () {
    testWidgets('Renders Buildings & Rooms and Campus Facilities tabs and handles selection', (tester) async {
      List<SelectedLocationItem> selected = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider.overrideWith((ref) => CampusNotifierFake()),
            facilitiesProvider.overrideWith((ref) => FacilitiesNotifierFake()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: LocationMultiSelector(
                  allowMultiple: true,
                  onSelectionChanged: (locs) => selected = locs,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buildings & Rooms'), findsOneWidget);
      expect(find.text('Campus Facilities'), findsOneWidget);

      // Tap on Campus Facilities tab
      await tester.tap(find.text('Campus Facilities'));
      await tester.pumpAndSettle();

      // Check facility listed from mock
      expect(find.text('Main Auditorium'), findsOneWidget);
      expect(find.text('Indoor Sports Complex'), findsOneWidget);

      // Select Auditorium checkbox
      await tester.tap(find.text('Main Auditorium'));
      await tester.pumpAndSettle();

      expect(selected.length, 1);
      expect(selected.first.displayName, 'Main Auditorium');
      expect(selected.first.locationType, 'facility');
    });
  });

  group('3. AddEditVendorContractDialog Component Tests', () {
    testWidgets('Renders all vendor contact fields, agreement document URL and validation', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEditVendorContractDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Register Service Vendor & Agreement'), findsOneWidget);
      expect(find.text('1. Vendor Organization & Direct Contact'), findsOneWidget);
      expect(find.text('2. Service Scope & Agreement Terms'), findsOneWidget);
      expect(find.text('3. SLA Guarantees & Turnaround Times'), findsOneWidget);
      expect(find.text('4. Contract / Agreement Document Attachment'), findsOneWidget);
      expect(find.text('Save & Register Contract'), findsOneWidget);

      // Verify fields exist
      expect(find.text('Vendor Company / Agency Name *'), findsOneWidget);
      expect(find.text('Mobile / Phone Number *'), findsOneWidget);
      expect(find.text('Official Email ID *'), findsOneWidget);
      expect(find.text('Attached Document File Name'), findsOneWidget);
      expect(find.text('Document Storage URL / Secure Access Link'), findsOneWidget);
    });
  });

  group('4. MaintenancePlanDialog Component Tests', () {
    testWidgets('Renders recurrence dropdown with Every 6 Months and vendor automation section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider.overrideWith((ref) => CampusNotifierFake()),
            facilitiesProvider.overrideWith((ref) => FacilitiesNotifierFake()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MaintenancePlanDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create Preventive Maintenance Plan'), findsOneWidget);
      expect(find.text('1. Plan Title & Service Scope'), findsOneWidget);
      expect(find.text('2. Target Campus Locations (Single or Bulk Multi-Location)'), findsOneWidget);
      expect(find.text('3. Service Vendor Assignment & Automated Contact'), findsOneWidget);
      expect(find.text('4. Maintenance Procedure Checklist Tasks'), findsOneWidget);

      expect(find.text('Recurrence Frequency *'), findsOneWidget);
      expect(find.text('Automated Email Dispatch to Vendor'), findsOneWidget);
      expect(find.text('Vendor Mobile Number'), findsOneWidget);
      expect(find.text('Vendor Dispatch Email ID'), findsOneWidget);
    });
  });

  group('5. VendorContractsSubview & MaintenancePlansSubview Tests', () {
    testWidgets('VendorContractsSubview renders metrics tiles, filters and data grid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maintenanceProvider.overrideWith((ref) => MaintenanceNotifierFake(initialView: 'vendors')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VendorContractsSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Total Vendors'), findsOneWidget);
      expect(find.text('Active AMC Contracts'), findsOneWidget);
      expect(find.text('Annual Contract Value'), findsOneWidget);
      expect(find.text('Avg Response SLA'), findsOneWidget);
      expect(find.text('Add Vendor / Contract'), findsOneWidget);

      // Verify vendor row from fake
      expect(find.text('CoolAir Solutions Pvt Ltd'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('+91 98801 23456'), findsOneWidget);
    });

    testWidgets('MaintenancePlansSubview renders preventive plans with frequency and trigger button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maintenanceProvider.overrideWith((ref) => MaintenanceNotifierFake(initialView: 'plans')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MaintenancePlansSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Preventive Maintenance Plans (1)'), findsOneWidget);
      expect(find.text('Create Plan'), findsOneWidget);
      expect(find.text('Generate Due Work Orders'), findsOneWidget);
      expect(find.text('AC Annual Servicing & Filter Replacement'), findsOneWidget);
      expect(find.text('Every 6 Months'), findsOneWidget);
    });

    testWidgets('MaintenanceCenterPanel renders VendorContractsSubview when activeView is vendors', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            maintenanceProvider.overrideWith((ref) => MaintenanceNotifierFake(initialView: 'vendors')),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MaintenanceCenterPanel(onOpenNewRequest: () {}),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirms dedicated Vendor Contracts Grid is displayed in Center Panel!
      expect(find.text('Add Vendor / Contract'), findsOneWidget);
      expect(find.text('CoolAir Solutions Pvt Ltd'), findsOneWidget);
    });
  });
}

// ============================================================================
// FAKES & TEST DOUBLES FOR ISOLATED TESTING
// ============================================================================

class MaintenanceNotifierFake extends StateNotifier<MaintenanceState> implements MaintenanceNotifier {
  MaintenanceNotifierFake({String initialView = 'all'})
      : super(MaintenanceState(
          activeView: initialView,
          vendors: [
            const MaintenanceVendorItem(
              id: 'v-001',
              vendorName: 'CoolAir Solutions Pvt Ltd',
              contactPerson: 'Rajesh Sharma',
              phone: '+91 98801 23456',
              email: 'support@coolair.com',
              serviceCategory: 'HVAC',
              contractType: 'AMC',
              contractRefNo: 'AMC-HVAC-2026-08',
              contractValue: 145000.0,
              slaResponseHours: 4.0,
              slaResolutionHours: 24.0,
              agreementUrl: 'https://assets.edushamiit.org/contracts/CoolAir_Contract.pdf',
              contractDocumentName: 'CoolAir_Contract.pdf',
              isActive: true,
            ),
          ],
          plans: [
            MaintenancePlanItem(
              id: 'p-001',
              planCode: 'MP-001',
              title: 'AC Annual Servicing & Filter Replacement',
              category: 'HVAC',
              frequency: 'Every 6 Months',
              recurrenceIntervalMonths: 6,
              vendorName: 'CoolAir Solutions Pvt Ltd',
              vendorPhone: '+91 98801 23456',
              vendorEmail: 'support@coolair.com',
              sendVendorEmail: true,
              estimatedDurationHours: 2.0,
              estimatedCost: 15000.0,
              nextDueDate: DateTime(2026, 12, 1),
            ),
          ],
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CampusNotifierFake extends StateNotifier<CampusState> implements CampusNotifier {
  CampusNotifierFake()
      : super(const CampusState(
          buildings: [
            BuildingModel(
              id: 'b-1',
              schoolId: 's-1',
              name: 'Academic Block (A)',
              code: 'B1',
            ),
          ],
          floors: [
            BuildingFloorModel(
              id: 'f-1',
              buildingId: 'b-1',
              name: 'Ground Floor',
              floorCode: 'GF',
            ),
          ],
          rooms: [
            RoomModel(
              id: 'r-101',
              schoolId: 's-1',
              buildingId: 'b-1',
              floorId: 'f-1',
              name: 'Classroom 101',
              roomNumber: '101',
              roomCode: 'B1-101',
              maxCapacity: 45,
              seatingCapacity: 40,
              operationalStatus: 'Available',
            ),
          ],
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FacilitiesNotifierFake extends StateNotifier<FacilitiesState> implements FacilitiesNotifier {
  FacilitiesNotifierFake()
      : super(const FacilitiesState(
          facilities: [
            {
              'id': 'fac-1',
              'name': 'Main Auditorium',
              'code': 'AUD-01',
              'category': 'Auditorium',
              'capacity': 1200,
            },
            {
              'id': 'fac-2',
              'name': 'Indoor Sports Complex',
              'code': 'SPT-01',
              'category': 'Sports',
              'capacity': 400,
            },
          ],
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
