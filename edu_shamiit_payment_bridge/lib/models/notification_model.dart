import 'package:intl/intl.dart';

class PaymentNotificationItem {
  final String id;
  final String eventUuid;
  final String sourcePackage;
  final String sourceApp;
  final String eventType;
  final int amountPaise;
  final String? senderName;
  final String? maskedSenderIdentifier;
  final String? transactionReference;
  final DateTime notificationTimestamp;
  final String? rawTitle;
  final String? rawText;
  final String parserVersion;
  final String confidenceScore;
  final String parsingStatus;
  final String candidateMatchStatus; // MATCHED_CANDIDATE, UNMATCHED, IGNORED, DUPLICATE, REVIEW_REQUIRED
  final String? matchedStudentName;
  final String? matchedInvoiceNumber;

  PaymentNotificationItem({
    required this.id,
    required this.eventUuid,
    required this.sourcePackage,
    required this.sourceApp,
    required this.eventType,
    required this.amountPaise,
    this.senderName,
    this.maskedSenderIdentifier,
    this.transactionReference,
    required this.notificationTimestamp,
    this.rawTitle,
    this.rawText,
    required this.parserVersion,
    required this.confidenceScore,
    required this.parsingStatus,
    required this.candidateMatchStatus,
    this.matchedStudentName,
    this.matchedInvoiceNumber,
  });

  String get formattedAmount {
    final double rupees = amountPaise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
        .format(rupees);
  }

  bool get isIncoming => eventType == 'PAYMENT_RECEIVED';
  bool get isPaymentReceived => isIncoming;

  String get formattedTime {
    return DateFormat('hh:mm a').format(notificationTimestamp.toLocal());
  }

  String get dateGroupKey {
    final now = DateTime.now();
    final local = notificationTimestamp.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final notifDate = DateTime(local.year, local.month, local.day);

    if (notifDate == today) {
      return 'Today, ${DateFormat('d MMM yyyy').format(local)}';
    } else if (notifDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('d MMM yyyy').format(local)}';
    } else {
      return DateFormat('d MMM yyyy').format(local);
    }
  }

  factory PaymentNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['notification_timestamp'] ?? '');
    } catch (_) {
      ts = DateTime.now();
    }

    return PaymentNotificationItem(
      id: json['id']?.toString() ?? '',
      eventUuid: json['event_uuid'] ?? '',
      sourcePackage: json['source_package'] ?? '',
      sourceApp: json['source_app'] ?? 'PhonePe',
      eventType: json['event_type'] ?? 'PAYMENT_RECEIVED',
      amountPaise: json['amount_paise'] ?? 0,
      senderName: json['sender_name'],
      maskedSenderIdentifier: json['masked_sender_identifier'] ?? '**** 0000',
      transactionReference: json['transaction_reference'],
      notificationTimestamp: ts,
      rawTitle: json['raw_title'],
      rawText: json['raw_text'],
      parserVersion: json['parser_version'] ?? '1.0.0',
      confidenceScore: json['confidence_score'] ?? 'HIGH',
      parsingStatus: json['parsing_status'] ?? 'PARSED',
      candidateMatchStatus: json['candidate_match_status'] ?? 'UNMATCHED',
      matchedStudentName: json['matched_student_name'],
      matchedInvoiceNumber: json['matched_invoice_number'],
    );
  }

  static List<PaymentNotificationItem> getMockItems() {
    final now = DateTime.now();
    return [
      PaymentNotificationItem(
        id: '1',
        eventUuid: '88888888-0000-0000-0000-000000000001',
        sourcePackage: 'com.phonepe.app',
        sourceApp: 'PhonePe',
        eventType: 'PAYMENT_RECEIVED',
        amountPaise: 200034,
        maskedSenderIdentifier: '**** 9821',
        transactionReference: 'UPI/438729106731',
        notificationTimestamp: DateTime(now.year, now.month, now.day, 10, 18),
        candidateMatchStatus: 'MATCHED_CANDIDATE',
        matchedStudentName: 'Seema',
        matchedInvoiceNumber: 'INV-1042',
        parserVersion: '1.0.0',
        confidenceScore: 'HIGH',
        parsingStatus: 'PARSED',
      ),
      PaymentNotificationItem(
        id: '2',
        eventUuid: '88888888-0000-0000-0000-000000000002',
        sourcePackage: 'com.google.android.apps.nbu.paisa.user',
        sourceApp: 'Google Pay',
        eventType: 'PAYMENT_RECEIVED',
        amountPaise: 200005,
        maskedSenderIdentifier: '**** 7712',
        transactionReference: 'GPay-319870221',
        notificationTimestamp: DateTime(now.year, now.month, now.day, 10, 7),
        candidateMatchStatus: 'MATCHED_CANDIDATE',
        matchedStudentName: 'Mohan',
        matchedInvoiceNumber: 'INV-1041',
        parserVersion: '1.0.0',
        confidenceScore: 'HIGH',
        parsingStatus: 'PARSED',
      ),
      PaymentNotificationItem(
        id: '3',
        eventUuid: '88888888-0000-0000-0000-000000000003',
        sourcePackage: 'com.phonepe.app',
        sourceApp: 'PhonePe',
        eventType: 'PAYMENT_RECEIVED',
        amountPaise: 150000,
        maskedSenderIdentifier: '**** 2244',
        transactionReference: 'UPI/438721993421',
        notificationTimestamp: DateTime(now.year, now.month, now.day, 9, 52),
        candidateMatchStatus: 'UNMATCHED',
        parserVersion: '1.0.0',
        confidenceScore: 'HIGH',
        parsingStatus: 'PARSED',
      ),
      PaymentNotificationItem(
        id: '4',
        eventUuid: '88888888-0000-0000-0000-000000000004',
        sourcePackage: 'com.google.android.apps.nbu.paisa.user',
        sourceApp: 'Google Pay',
        eventType: 'PAYMENT_SENT',
        amountPaise: 50000,
        maskedSenderIdentifier: '**** 1100',
        transactionReference: 'GPay-88990011',
        notificationTimestamp: DateTime(now.year, now.month, now.day, 9, 20),
        candidateMatchStatus: 'IGNORED',
        parserVersion: '1.0.0',
        confidenceScore: 'HIGH',
        parsingStatus: 'PARSED',
      ),
      PaymentNotificationItem(
        id: '5',
        eventUuid: '88888888-0000-0000-0000-000000000005',
        sourcePackage: 'com.phonepe.app',
        sourceApp: 'PhonePe',
        eventType: 'PAYMENT_RECEIVED',
        amountPaise: 350000,
        maskedSenderIdentifier: '**** 6631',
        transactionReference: 'UPI/438720554821',
        notificationTimestamp: now.subtract(const Duration(days: 1)),
        candidateMatchStatus: 'MATCHED_CANDIDATE',
        matchedStudentName: 'Rohan',
        matchedInvoiceNumber: 'INV-1039',
        parserVersion: '1.0.0',
        confidenceScore: 'HIGH',
        parsingStatus: 'PARSED',
      ),
    ];
  }
}
