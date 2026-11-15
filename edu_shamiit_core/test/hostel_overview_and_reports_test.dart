import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/overview/hostel_overview_tab.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/reports/hostel_reports_tab.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';

void main() {
  group('Hostel Overview Tab Tests', () {
    testWidgets('Renders HostelOverviewTab with loading state gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HostelOverviewTab(),
            ),
          ),
        ),
      );

      // Verify that header or loading indicator appears
      expect(find.byType(HostelOverviewTab), findsOneWidget);
    });

    testWidgets('Renders HostelOverviewTab with populated data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final mockOverviewData = {
        'kpis': {
          'total_buildings': 4,
          'total_rooms': 15,
          'total_beds': 10,
          'occupied_beds': 10,
          'available_beds': 0,
          'maintenance_beds': 0,
          'occupancy_rate': 100.0,
          'active_residents': 10,
          'staff_count': 28,
          'staff_on_duty': 23,
          'pending_leaves': 8,
          'currently_out': 3,
          'open_complaints': 3,
          'urgent_complaints': 1,
          'total_billed': 420000.0,
          'total_paid': 304000.0,
          'total_dues': 116000.0,
          'recovery_rate': 72.4,
        },
        'building_occupancy': [
          {
            'building_id': 'b1',
            'building_name': 'Boys Hostel A',
            'code': 'BHA',
            'gender_policy': 'BOYS',
            'total_rooms': 11,
            'total_beds': 3,
            'occupied_beds': 3,
            'occupancy_rate': 100.0,
          },
        ],
        'room_types': [
          {'room_type': 'Standard', 'room_count': 8, 'bed_count': 4, 'occupied_beds': 4},
          {'room_type': 'Toilet/Washroom', 'room_count': 2, 'bed_count': 0, 'occupied_beds': 0},
        ],
        'recent_movements': [
          {
            'id': 'm1',
            'student_name': 'Rohan Joshi',
            'request_type': 'LEAVE',
            'request_subtype': 'Home Leave',
            'gate_pass_code': 'LOR-2024-0041',
            'departure_date': '2026-10-10 02:09:00',
            'expected_return': '2026-10-10 10:09:00',
            'status': 'PENDING',
          },
        ],
        'priority_complaints': [
          {
            'id': 'c1',
            'ticket_number': 'HC-2024-033',
            'title': 'Main drainage blockage',
            'category': 'Plumbing',
            'priority': 'HIGH',
            'status': 'ACTIVE',
            'room_number': 'G-102',
            'student_name': 'Karthik Reddy',
            'created_at': '2026-10-03 02:09:00',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                overviewData: mockOverviewData,
                isOverviewLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelOverviewTab(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Quick Operations'), findsOneWidget);
      expect(find.text('Boys Hostel A'), findsWidgets);
      expect(find.text('Main drainage blockage'), findsOneWidget);
      expect(find.text('Rohan Joshi'), findsOneWidget);
    });
  });

  group('Hostel Reports Tab Tests', () {
    testWidgets('Renders HostelReportsTab category cards and switches reports', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final mockReportsData = {
        'report_type': 'occupancy',
        'record_count': 2,
        'records': [
          {
            'building_name': 'Boys Hostel A',
            'floor_name': 'Ground Floor',
            'room_number': 'A-101',
            'room_type': 'Standard',
            'capacity': 2,
            'occupied_beds': 2,
            'vacant_beds': 0,
            'room_status': 'OPERATIONAL',
            'monthly_fee': 45000,
            'gender_restriction': 'BOYS',
          },
          {
            'building_name': 'Boys Hostel A',
            'floor_name': 'Ground Floor',
            'room_number': 'T-101',
            'room_type': 'Toilet/Washroom',
            'capacity': 0,
            'occupied_beds': 0,
            'vacant_beds': 0,
            'room_status': 'OPERATIONAL',
            'monthly_fee': 0,
            'gender_restriction': 'BOYS',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'occupancy',
                reportsData: mockReportsData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hostel Reports & Analytical Exports'), findsOneWidget);
      expect(find.text('Occupancy Master'), findsOneWidget);
      expect(find.text('Active Residents'), findsOneWidget);
      expect(find.text('Fee Defaulters'), findsOneWidget);
      expect(find.text('Leave & Movements'), findsOneWidget);
      expect(find.text('Complaints Ledger'), findsOneWidget);

      // Verify Table Records
      expect(find.text('A-101'), findsOneWidget);
      expect(find.text('T-101'), findsOneWidget);
      expect(find.text('Toilet/Washroom'), findsOneWidget);
    });

    testWidgets('Renders Fee Defaulters table accurately with currency and overdue badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final mockFeeData = {
        'report_type': 'fee_defaulters',
        'record_count': 1,
        'records': [
          {
            'roll_no': 'R-0101',
            'student_name': 'Rahul Sharma',
            'building_name': 'Boys Hostel A',
            'room_number': 'A-101',
            'invoice_number': 'INV-2024-001',
            'billed_amount': 45000,
            'paid_amount': 30000,
            'pending_due': 15000,
            'due_date': '2024-09-15',
            'overdue_days': 40,
            'payment_status': 'OVERDUE',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'fee_defaulters',
                reportsData: mockFeeData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('INV-2024-001'), findsOneWidget);
      expect(find.text('40 days'), findsOneWidget);
    });

    testWidgets('Renders reconciled 2026-2027 Fee Defaulters matching Fees & Billing pending accounts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final mockReconciledFeeData = {
        'report_type': 'fee_defaulters',
        'record_count': 1,
        'records': [
          {
            'roll_no': '201',
            'student_name': 'Deepak Chawla 101',
            'building_name': 'Boys Hostel A',
            'room_number': 'A-105',
            'invoice_number': 'HINV-20261104-8925',
            'billed_amount': 6000,
            'paid_amount': 0,
            'pending_due': 6000,
            'due_date': '2026-11-04',
            'overdue_days': 1,
            'payment_status': 'OVERDUE',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'fee_defaulters',
                reportsData: mockReconciledFeeData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      // Verify only genuine defaulter is present
      expect(find.text('Deepak Chawla 101'), findsOneWidget);
      expect(find.text('HINV-20261104-8925'), findsOneWidget);
      expect(find.text('1 days'), findsOneWidget);
      expect(find.text('OVERDUE'), findsOneWidget);

      // Verify overpaid students are NOT present
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Aman Khan'), findsNothing);
      expect(find.text('Aditi Rao'), findsNothing);
    });

    testWidgets('Reports Grid displays pagination controls and responds to sorting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1400));

      final mockOccupancyRecords = List.generate(25, (index) => {
        'building_name': 'Hostel Building ${index % 3}',
        'floor_name': 'Floor ${index % 4}',
        'room_number': 'R-${100 + index}',
        'room_type': index % 2 == 0 ? 'Standard' : 'Deluxe',
        'capacity': 2,
        'occupied_beds': 1,
        'vacant_beds': 1,
        'room_status': 'OPERATIONAL',
        'monthly_fee': 40000 + (index * 1000),
        'gender_restriction': 'ANY',
      });

      final mockData = {
        'report_type': 'occupancy',
        'record_count': 25,
        'records': mockOccupancyRecords,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'occupancy',
                reportsData: mockData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify pagination text & controls
      expect(find.text('Showing 1 to 10 of 25 records'), findsOneWidget);
      expect(find.text('Rows per page: '), findsOneWidget);

      // Verify column header is present
      expect(find.text('Room No'), findsOneWidget);

      // Tap on column header 'Room No' to trigger sort
      await tester.tap(find.text('Room No'));
      await tester.pumpAndSettle();

      // Verify sort badge appears
      expect(find.textContaining('Sorted by: room_number'), findsOneWidget);

      // Navigate to page 2 via Next Page button
      final nextBtn = find.byTooltip('Next Page');
      await tester.ensureVisible(nextBtn);
      await tester.pumpAndSettle();
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Showing 11 to 20 of 25 records'), findsOneWidget);
    });

    testWidgets('Renders Active Residents, Movements, and Complaints tables', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final mockResidentsData = {
        'report_type': 'residents',
        'record_count': 1,
        'records': [
          {
            'roll_no': '2026-101',
            'student_name': 'Aarav Sharma',
            'class_name': 'Class 10 A',
            'building_name': 'Boys Hostel A',
            'room_number': 'A-101',
            'bed_label': 'Bed 1',
            'admission_date': '2026-06-01',
            'fee_status': 'PAID',
            'resident_status': 'CHECKED_IN',
            'guardian_phone': '+91 98765 43210',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'residents',
                reportsData: mockResidentsData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('2026-101'), findsOneWidget);
      expect(find.text('Class 10 A'), findsOneWidget);
      expect(find.text('Bed 1'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
    });

    testWidgets('Live search filter filters rows dynamically and clear button resets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final mockData = {
        'report_type': 'movement',
        'record_count': 2,
        'records': [
          {
            'gate_pass_code': 'GP-2026-001',
            'student_name': 'Vikram Singh',
            'building_name': 'Boys Hostel A',
            'room_number': 'A-102',
            'request_type': 'OUTING',
            'request_subtype': 'Day Outing',
            'purpose': 'Medical Checkup',
            'destination': 'Apollo Hospital',
            'departure_date': '2026-10-15 10:00',
            'expected_return': '2026-10-15 17:00',
            'status': 'APPROVED',
          },
          {
            'gate_pass_code': 'GP-2026-002',
            'student_name': 'Riya Nair',
            'building_name': 'Girls Hostel B',
            'room_number': 'G-201',
            'request_type': 'LEAVE',
            'request_subtype': 'Weekend Leave',
            'purpose': 'Family Function',
            'destination': 'Home',
            'departure_date': '2026-10-18 09:00',
            'expected_return': '2026-10-20 18:00',
            'status': 'APPROVED',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'movement',
                reportsData: mockData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Riya Nair'), findsOneWidget);

      // Search for Vikram
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Vikram');
      await tester.pumpAndSettle();

      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Riya Nair'), findsNothing);

      // Tap clear icon
      final clearBtn = find.byIcon(Icons.clear);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Riya Nair'), findsOneWidget);
    });

    testWidgets('Opens Print Preview dialog and shows mapped data cells', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final mockComplaintsData = {
        'report_type': 'complaints',
        'record_count': 1,
        'records': [
          {
            'ticket_number': 'HC-2026-088',
            'title': 'Ceiling fan regulator damaged',
            'category': 'Electrical',
            'priority': 'HIGH',
            'status': 'OPEN',
            'room_number': 'A-105',
            'student_name': 'Manish Agarwal',
            'assigned_staff': 'Electrician Ramesh',
            'lodged_date': '2026-10-20 11:30',
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                selectedReportType: 'complaints',
                reportsData: mockComplaintsData,
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Print Preview button
      final printPreviewBtn = find.text('Print Preview');
      expect(printPreviewBtn, findsOneWidget);
      await tester.tap(printPreviewBtn);
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.textContaining('Print Preview — Complaints Ledger'), findsOneWidget);
      expect(find.text('EduSHAMIIT INSTITUTION OF TECHNOLOGY'), findsOneWidget);
      expect(find.text('Ceiling fan regulator damaged'), findsWidgets);
      expect(find.text('Electrician Ramesh'), findsWidgets);

      // Tap Print / Save PDF
      final printBtn = find.text('Print / Save PDF');
      expect(printBtn, findsOneWidget);
      await tester.tap(printBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar appears
      expect(find.textContaining('Opened Complaints Ledger print window'), findsOneWidget);
    });

    testWidgets('Session Turnover & Capacity Forecasting card expands and responds to slider', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostelProvider.overrideWith((ref) {
              final notifier = HostelNotifier();
              notifier.state = notifier.state.copyWith(
                kpis: HostelKPIs(
                  totalBeds: 400,
                  occupiedBeds: 300,
                  availableBeds: 100,
                ),
                reportsData: {'records': [], 'record_count': 0, 'report_type': 'occupancy'},
                isReportsLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HostelReportsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Forecast card should be collapsed initially
      expect(find.text('Session Turnover & Capacity Forecasting'), findsOneWidget);
      expect(find.text('AI FORECAST'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Session Turnover & Capacity Forecasting'));
      await tester.pumpAndSettle();

      // Now slider and projection metrics should be visible
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Available for New Admissions'), findsOneWidget);
      expect(find.text('Deposit Liquidity Needed'), findsOneWidget);
      expect(find.text('Projected New Intake Revenue'), findsOneWidget);
      expect(find.textContaining('Residents Leaving'), findsOneWidget);
    });

    testWidgets('HostelReportsTab renders cleanly without overflow on Mobile, Tablet, and Desktop', (tester) async {
      final dummyRecords = [
        {
          'building_name': 'Boys Hostel A',
          'floor_name': '1st Floor',
          'room_number': 'A-101',
          'room_type': 'Standard',
          'capacity': 3,
          'occupied': 3,
          'vacant': 0,
          'status': 'OCCUPIED',
          'monthly_fee': 6000,
          'gender_restriction': 'BOYS',
        },
      ];

      final screenSizes = [
        const Size(390, 844),   // Mobile phone
        const Size(768, 1024),  // Tablet / iPad
        const Size(1280, 720),  // Standard laptop
        const Size(1440, 900),  // Desktop monitor
      ];

      for (final size in screenSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hostelProvider.overrideWith((ref) {
                final notifier = HostelNotifier();
                notifier.state = notifier.state.copyWith(
                  selectedReportType: 'occupancy',
                  reportsData: {'records': dummyRecords, 'record_count': 1, 'report_type': 'occupancy'},
                  isReportsLoading: false,
                );
                return notifier;
              }),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: HostelReportsTab(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(HostelReportsTab), findsOneWidget);
        final ex = tester.takeException();
        if (ex != null) {
          debugPrint('DEBUG OVERFLOW ON $size: $ex');
          if (ex is FlutterError) {
            debugPrint('ERROR_DEEP: ${ex.toStringDeep()}');
          }
        }
        expect(ex, isNull, reason: 'Must render with zero overflow on $size');
      }
    });
  });
}
