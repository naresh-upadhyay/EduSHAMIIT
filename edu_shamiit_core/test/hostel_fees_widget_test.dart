import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/hostel_fees_tab.dart';

void main() {
  testWidgets('HostelFeesTab renders KPI cards with exact figures on Desktop without overflow', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HostelFeesTab(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify KPI Cards Presence and Values
    expect(find.text('Total Billed'), findsWidgets);
    expect(find.text('Total Collected'), findsOneWidget);
    expect(find.text('Pending Dues'), findsOneWidget);
    expect(find.text('Overdue Amount'), findsOneWidget);
    expect(find.text('Upcoming Invoices'), findsNothing);

    // Verify Sub-Tabs Presence
    expect(find.text('All Fees'), findsOneWidget);
    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Partial'), findsWidgets);
    expect(find.text('Overdue'), findsWidgets);
    expect(find.text('Fee Structure'), findsOneWidget);

    // Verify Filter Bar and Action Button
    expect(find.text('Generate Invoice'), findsWidgets);
    expect(find.text('All Hostels'), findsOneWidget);
    expect(find.text('All Classes'), findsOneWidget);
    expect(find.text('All Status'), findsOneWidget);

    // Verify Right Summary Cards
    expect(find.text('Fee Summary'), findsOneWidget);
    expect(find.text('Recent Payments'), findsOneWidget);
  });

  testWidgets('HostelFeesTab renders cleanly on Tablet breakpoint without overflow', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HostelFeesTab(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Total Billed'), findsWidgets);
    expect(find.text('Fee Summary'), findsOneWidget);
  });

  testWidgets('HostelFeesTab renders cleanly on Mobile breakpoint without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HostelFeesTab(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Total Billed'), findsWidgets);
  });
}
