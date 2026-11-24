import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/create_edit_booking_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/dialogs/create_edit_maintenance_dialog.dart';

void main() {
  group('Campus Facility Booking & Maintenance Pre-Population Tests', () {
    testWidgets('CreateEditBookingDialog initializes with pre-selected campus facility', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(
                initialFacilityId: 'fac-999',
                initialFacilityName: 'Olympic Standard Swimming Pool',
                initialFacilityCategory: 'Sports Complex / Ground',
                initialFacilityCapacity: 300,
                initialPurpose: 'Sports & Athletic Training',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog header is present
      expect(find.text('Book a Campus Space'), findsOneWidget);

      // Verify that Campus Facilities mode is active and shows the facility name
      expect(find.textContaining('Olympic Standard Swimming Pool'), findsWidgets);

      // Verify purpose is pre-selected
      expect(find.textContaining('Sports & Athletic Training'), findsWidgets);

      // Verify facility toggle tab is displayed
      expect(find.text('Campus Facilities & Grounds'), findsOneWidget);
    });

    testWidgets('CreateEditMaintenanceDialog initializes with pre-selected campus facility location', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditMaintenanceDialog(
                initialFacilityId: 'fac-888',
                initialFacilityName: 'Central Advanced Physics & AI Lab',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify dialog title
      expect(find.text('Raise Maintenance Work Order'), findsOneWidget);

      // Verify title summary pre-filled with facility name
      expect(find.textContaining('Central Advanced Physics & AI Lab'), findsWidgets);

      // Verify Campus Facilities location selector tab is present
      expect(find.text('Campus Facilities'), findsOneWidget);
    });
  });
}
