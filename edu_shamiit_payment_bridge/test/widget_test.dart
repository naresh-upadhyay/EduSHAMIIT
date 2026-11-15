import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_payment_bridge/main.dart';

void main() {
  testWidgets('EduSHAMIIT Payment Bridge smoke & dashboard rendering test',
      (WidgetTester tester) async {
    // Provide a large enough test surface for phone layout
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const EduShamiitPaymentBridgeApp());
    await tester.pumpAndSettle();

    // Verify Brand Title & Running badge
    expect(find.text('EduSHAMIIT'), findsOneWidget);
    expect(find.text('Payment Bridge'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);

    // Verify Main Toggle Card
    expect(find.text('Payment Listener Active'), findsOneWidget);
    expect(find.text('Monitoring UPI payment notifications'), findsOneWidget);

    // Verify Top 4 Metric Boxes
    expect(find.text('Notifications\nToday'), findsOneWidget);
    expect(find.text('Matched\nPayments'), findsOneWidget);
    expect(find.text('Unmatched\nPayments'), findsOneWidget);
    expect(find.text('Last Sync'), findsOneWidget);

    // Verify System Status section
    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Notification Access'), findsOneWidget);
    expect(find.text('Monitored UPI Apps'), findsOneWidget);
    expect(find.text('Backend Connection'), findsOneWidget);

    // Verify Bottom Navigation items
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Navigation across bottom tabs test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const EduShamiitPaymentBridgeApp());
    await tester.pumpAndSettle();

    // Tap on Notifications tab
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    // Verify filter chips in Notifications screen
    expect(find.text('All (42)'), findsOneWidget);
    expect(find.text('Matched (38)'), findsOneWidget);
    expect(find.text('Unmatched (2)'), findsOneWidget);

    // Tap on Transactions tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    // Verify summary metric labels in Transactions screen
    expect(find.text('Successful'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Refunds'), findsWidgets);

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Settings section headers
    expect(find.text('Notification Listener'), findsOneWidget);
    expect(find.text('Monitored UPI Applications'), findsOneWidget);
    expect(find.text('Backend Configuration'), findsOneWidget);
    expect(find.text('Processing Settings'), findsOneWidget);
  });
}
