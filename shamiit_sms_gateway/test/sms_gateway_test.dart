import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamiit_sms_gateway/core/constants.dart';
import 'package:shamiit_sms_gateway/core/sms_utils.dart';
import 'package:shamiit_sms_gateway/core/theme.dart';
import 'package:shamiit_sms_gateway/models/sms_models.dart';
import 'package:shamiit_sms_gateway/services/api_service.dart';
import 'package:shamiit_sms_gateway/widgets/common_components.dart';

void main() {
  group('SmsUtils Validation & Encoding', () {
    test('Validates and normalizes Indian and E.164 phone numbers', () {
      expect(SmsUtils.normalizePhone('9876543210'), equals('+919876543210'));
      expect(SmsUtils.normalizePhone('09876543210'), equals('+919876543210'));
      expect(SmsUtils.normalizePhone('+91 98765 43210'), equals('+919876543210'));
      expect(SmsUtils.normalizePhone('+14155552671'), equals('+14155552671'));
      expect(SmsUtils.isValidPhone('12345'), isFalse);
      expect(SmsUtils.isValidPhone('invalid'), isFalse);
    });

    test('Parses comma/newline/CSV recipient lists and deduplicates', () {
      final list = SmsUtils.parseMultiplePhones('9876543210, +919876543210\n+918765432109; badnum');
      expect(list, equals(['+919876543210', '+918765432109']));
    });

    test('Accurately calculates GSM-7 vs Unicode UCS-2 segment boundaries', () {
      final singleGsm = SmsUtils.analyzeEncoding('A' * 160);
      expect(singleGsm.encoding, equals('GSM7'));
      expect(singleGsm.segmentCount, equals(1));
      expect(singleGsm.perSegmentLimit, equals(160));

      final multiGsm = SmsUtils.analyzeEncoding('A' * 161);
      expect(multiGsm.encoding, equals('GSM7'));
      expect(multiGsm.segmentCount, equals(2));
      expect(multiGsm.perSegmentLimit, equals(153));

      final singleUni = SmsUtils.analyzeEncoding('नमस्ते छात्र');
      expect(singleUni.encoding, equals('UNICODE'));
      expect(singleUni.segmentCount, equals(1));
      expect(singleUni.perSegmentLimit, equals(70));

      final multiUni = SmsUtils.analyzeEncoding('नमस्ते ' * 15);
      expect(multiUni.encoding, equals('UNICODE'));
      expect(multiUni.segmentCount, greaterThan(1));
      expect(multiUni.perSegmentLimit, equals(67));
    });

    test('Template variable substitution rejects missing required variables', () {
      const body = 'Dear {parent_name}, fee INR {amount} is due on {due_date}.';
      final rendered = SmsUtils.renderTemplateStrict(body, {
        'parent_name': 'Rajesh',
        'amount': '2500',
        'due_date': '30 Nov 2026',
      });
      expect(rendered, equals('Dear Rajesh, fee INR 2500 is due on 30 Nov 2026.'));
      expect(
        () => SmsUtils.renderTemplateStrict(body, {'parent_name': 'Rajesh'}),
        throwsFormatException,
      );
    });
  });

  group('Model Deserialization', () {
    test('SimInfo handles missing phone number gracefully', () {
      final sim = SimInfo.fromMap({
        'subscription_id': 17,
        'sim_slot_index': 0,
        'carrier_name': 'Jio',
        'phone_number': '',
        'is_active': true,
        'usage_mode': 'RECEIVE_ONLY',
      });
      expect(sim.subscriptionId, equals(17));
      expect(sim.phoneNumber, isNull);
      expect(sim.canSend, isFalse);
    });

    test('SmsMessageRecord parses multipart statuses and timestamps', () {
      final msg = SmsMessageRecord.fromMap({
        'message_uuid': 'msg-1',
        'direction': 'OUTBOUND',
        'recipient_number': '+919876543210',
        'message_body': 'Fee reminder',
        'encoding': 'GSM7',
        'segment_count': 2,
        'sending_sim_slot': 0,
        'sending_subscription_id': 17,
        'status': 'DELIVERED',
        'created_at': '2026-11-25T10:00:00Z',
        'part_statuses': [
          {'part': 1, 'sent_status': 'SENT', 'delivery_status': 'DELIVERED'},
          {'part': 2, 'sent_status': 'SENT', 'delivery_status': 'DELIVERED'},
        ],
      });
      expect(msg.segmentCount, equals(2));
      expect(msg.partStatuses.length, equals(2));
      expect(msg.isInbound, isFalse);
    });
  });

  group('Design System Widget Smoke Tests', () {
    testWidgets('Renders MetricCard, SimCard, and MessageListItem cleanly', (tester) async {
      final sim = SimInfo(
        subscriptionId: 12,
        simSlotIndex: 0,
        carrierName: 'Jio',
        displayName: 'Jio 4G',
        countryIso: 'IN',
        simState: 'READY',
        networkOperator: 'Jio',
        networkType: '4G LTE',
        signalLevel: 4,
        signalLabel: 'Excellent',
        isActive: true,
        isDataEnabled: true,
      );
      final msg = SmsMessageRecord(
        messageUuid: 'msg-test-1',
        direction: 'OUTBOUND',
        recipientNumber: '+919876543210',
        messageBody: 'Your fee payment is due.',
        encoding: 'GSM7',
        segmentCount: 1,
        sendingSimSlot: 0,
        carrierName: 'Jio',
        applicationSource: 'EduSHAMIIT',
        priority: 'NORMAL',
        status: 'DELIVERED',
        deliveryReportRequested: true,
        createdAt: '2026-11-25T10:00:00Z',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                const MetricCard(
                  icon: Icons.send,
                  iconColor: AppColors.primaryBlue,
                  iconBgColor: AppColors.primaryBlueLight,
                  value: '42',
                  label: 'Sent Today',
                ),
                SimCard(sim: sim, selected: true),
                MessageListItem(message: msg),
              ],
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Sent Today'), findsOneWidget);
      expect(find.text('SIM 1'), findsOneWidget);
      expect(find.text('(Jio)'), findsOneWidget);
      expect(find.text('To: +919876543210'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
    });
  });

  group('Server URL Migration', () {
    test('ApiService.init migrates deprecated sms.shamiit.com to eduapi.shamiit.com', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefsServerUrlKey: 'https://sms.shamiit.com/api/v1',
      });
      final api = ApiService();
      await api.init();
      expect(api.baseUrl, equals('https://eduapi.shamiit.com/api/v1'));
      expect(api.displayServerHost, equals('https://eduapi.shamiit.com'));
    });
  });

  group('Edge-to-Edge & Overflow Protection', () {
    testWidgets('showAppBottomSheet clears 3-button system navigation bar', (tester) async {
      const navBarHeight = 48.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewPadding: EdgeInsets.only(bottom: navBarHeight),
              padding: EdgeInsets.only(bottom: navBarHeight),
            ),
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showAppBottomSheet(
                        context: ctx,
                        icon: Icons.tune_rounded,
                        title: 'Gateway Settings',
                        builder: (_) => SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            child: const Text('Save & Sync Settings'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final btnRect = tester.getRect(find.widgetWithText(ElevatedButton, 'Save & Sync Settings'));
      expect(btnRect.bottom, lessThanOrEqualTo(800.0 - navBarHeight - 16.0));
    });

    testWidgets('InfoMetricRow renders long permission label on single line and bounds long URLs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 340,
              child: Column(
                children: [
                  InfoMetricRow(
                    label: 'READ_PHONE_STATE',
                    value: 'Granted',
                    statusIcon: Icons.check_circle_rounded,
                  ),
                  InfoMetricRow(
                    label: 'Server Endpoint',
                    value: 'https://eduapi.shamiit.com/very/long/endpoint/path/test',
                    monospace: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('READ_PHONE_STATE'), findsOneWidget);
      expect(find.text('Granted'), findsOneWidget);
      // Verify READ_PHONE_STATE is single-line height (< 24px) rather than wrapped onto 2 lines
      expect(tester.getSize(find.text('READ_PHONE_STATE')).height, lessThan(24.0));
      expect(tester.takeException(), isNull);
    });
  });
}
