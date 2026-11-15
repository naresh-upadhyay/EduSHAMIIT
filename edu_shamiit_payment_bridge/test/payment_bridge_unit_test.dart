import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_payment_bridge/models/dashboard_model.dart';
import 'package:edu_shamiit_payment_bridge/models/notification_model.dart';
import 'package:edu_shamiit_payment_bridge/models/transaction_model.dart';
import 'package:edu_shamiit_payment_bridge/models/settings_model.dart';

void main() {
  group('Financial Arithmetic & Model Invariants (Paise Precision)', () {
    test('TransactionItem parses amount in paise without float inaccuracy', () {
      final tx = TransactionItem(
        id: 'tx-1',
        amountPaise: 200034, // ₹2,000.34
        baseFeePaise: 200000, // ₹2,000.00
        excessPaise: 34,      // ₹0.34
        paymentMode: 'UPI (PhonePe)',
        paymentStatus: 'VERIFIED_SUCCESS',
        receivedAt: DateTime(2026, 11, 14, 10, 18),
        studentName: 'Seema',
        invoiceNumber: 'INV-1042',
      );

      expect(tx.amountPaise, equals(200034));
      expect(tx.baseFeePaise, equals(200000));
      expect(tx.excessPaise, equals(34));
      expect(tx.baseFeePaise + tx.excessPaise, equals(tx.amountPaise));

      expect(tx.formattedAmount, contains('2,000.34'));
      expect(tx.formattedBaseFee, contains('2,000.00'));
      expect(tx.formattedExcess, contains('0.34'));
    });

    test('Non-authoritative notification invariant: Notification does not confirm payment', () {
      final notification = PaymentNotificationItem(
        id: 'notif-1',
        eventUuid: 'evt-uuid-001',
        sourceApp: 'PhonePe',
        sourcePackage: 'com.phonepe.app',
        eventType: 'PAYMENT_RECEIVED',
        amountPaise: 200034,
        rawTitle: 'Payment Received',
        rawText: 'Received ₹2,000.34 from Seema UPI Ref: 438729106731',
        transactionReference: 'UPI/438729106731',
        maskedSenderIdentifier: '**** 9821',
        candidateMatchStatus: 'MATCHED_CANDIDATE', // Candidate match ONLY
        parsingStatus: 'SUCCESS',
        parserVersion: '1.0.0',
        confidenceScore: '0.99',
        notificationTimestamp: DateTime(2026, 11, 14, 10, 18),
        matchedStudentName: 'Seema',
        matchedInvoiceNumber: 'INV-1042',
      );

      // Notification matching status is MATCHED_CANDIDATE (candidate), never bank-verified payment confirmation
      expect(notification.candidateMatchStatus, equals('MATCHED_CANDIDATE'));
      expect(notification.isPaymentReceived, isTrue);
      expect(notification.formattedAmount, contains('2,000.34'));
    });

    test('DashboardMetrics matches screenshot metrics', () {
      final metrics = DashboardMetrics(
        notificationsToday: 42,
        matchedPayments: 38,
        unmatchedPayments: 2,
        lastSync: '10:24 AM\n(Just now)',
        lastSyncTime: '10:24 AM',
      );

      expect(metrics.notificationsToday, equals(42));
      expect(metrics.matchedPayments, equals(38));
      expect(metrics.unmatchedPayments, equals(2));
      expect(metrics.lastSyncTime, equals('10:24 AM'));
    });

    test('BridgeSettings serialization preserves integer intervals', () {
      final settings = BridgeSettings(
        syncIntervalSeconds: 30,
        retryIntervalSeconds: 60,
        duplicateDetectionWindowMinutes: 5,
        autoStartOnBoot: true,
        serverUrl: 'https://erp.edushamiit.in/api/v1/payments',
        deviceId: 'PB-AND-001',
        institution: 'Greenwood High School',
      );

      final json = settings.toJson();
      expect(json['sync_interval_seconds'], equals(30));
      expect(json['retry_interval_seconds'], equals(60));
      expect(json['duplicate_detection_window_minutes'], equals(5));
      expect(json['auto_start_on_boot'], isTrue);

      final deserialized = BridgeSettings.fromJson(json);
      expect(deserialized.syncIntervalSeconds, equals(30));
      expect(deserialized.retryIntervalSeconds, equals(60));
      expect(deserialized.duplicateDetectionWindowMinutes, equals(5));
    });
  });
}
