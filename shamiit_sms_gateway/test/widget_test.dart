import 'package:flutter_test/flutter_test.dart';
import 'package:shamiit_sms_gateway/main.dart';

void main() {
  testWidgets('ShamiitSmsGatewayApp renders SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const ShamiitSmsGatewayApp());
    expect(find.text('SHAMIIT'), findsOneWidget);
    expect(find.text('SMS GATEWAY'), findsOneWidget);
    // Advance splash timers cleanly
    await tester.pump(const Duration(seconds: 3));
  });
}
