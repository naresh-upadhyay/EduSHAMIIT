import 'package:intl/intl.dart';

class TransactionItem {
  final String id;
  final String? transactionReference;
  final int amountPaise;
  final int baseFeePaise;
  final int excessPaise;
  final String paymentMode;
  final String? upiApp;
  final String? maskedSender;
  final String paymentStatus; // VERIFIED_SUCCESS, PENDING, UNMATCHED, REFUNDED, AWAITING_VERIFICATION
  final DateTime receivedAt;
  final DateTime? matchedAt;
  final DateTime? verifiedAt;
  final String? receiptNumber;
  final String? studentName;
  final String? invoiceNumber;
  final String? invoiceTitle;
  final String? intentReference;
  final List<dynamic>? auditHistory;

  TransactionItem({
    required this.id,
    this.transactionReference,
    required this.amountPaise,
    required this.baseFeePaise,
    this.excessPaise = 0,
    required this.paymentMode,
    this.upiApp,
    this.maskedSender,
    required this.paymentStatus,
    required this.receivedAt,
    this.matchedAt,
    this.verifiedAt,
    this.receiptNumber,
    this.studentName,
    this.invoiceNumber,
    this.invoiceTitle,
    this.intentReference,
    this.auditHistory,
  });

  String get formattedAmount {
    final double rupees = amountPaise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
        .format(rupees);
  }

  String get formattedBaseFee {
    final double rupees = baseFeePaise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
        .format(rupees);
  }

  String get formattedExcess {
    final double rupees = excessPaise / 100.0;
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2)
        .format(rupees);
  }

  String get formattedReceivedAt {
    return DateFormat('d MMM yyyy, hh:mm a').format(receivedAt.toLocal());
  }

  String get formattedMatchedAt {
    if (matchedAt == null) return formattedReceivedAt;
    return DateFormat('d MMM yyyy, hh:mm a').format(matchedAt!.toLocal());
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    DateTime rAt;
    try {
      rAt = DateTime.parse(json['received_at'] ?? '');
    } catch (_) {
      rAt = DateTime.now();
    }

    DateTime? mAt;
    if (json['matched_at'] != null) {
      try {
        mAt = DateTime.parse(json['matched_at']);
      } catch (_) {}
    }

    DateTime? vAt;
    if (json['verified_at'] != null) {
      try {
        vAt = DateTime.parse(json['verified_at']);
      } catch (_) {}
    }

    return TransactionItem(
      id: json['id']?.toString() ?? '',
      transactionReference: json['transaction_reference'],
      amountPaise: json['amount_paise'] ?? 0,
      baseFeePaise: json['base_fee_paise'] ?? json['amount_paise'] ?? 0,
      excessPaise: json['excess_paise'] ?? 0,
      paymentMode: json['payment_mode'] ?? 'UPI',
      upiApp: json['upi_app'] ?? 'UPI',
      maskedSender: json['masked_sender'] ?? '**** 0000',
      paymentStatus: json['payment_status'] ?? 'AWAITING_VERIFICATION',
      receivedAt: rAt,
      matchedAt: mAt,
      verifiedAt: vAt,
      receiptNumber: json['receipt_number'],
      studentName: json['student_name'],
      invoiceNumber: json['invoice_number'],
      invoiceTitle: json['invoice_title'] ?? 'Annual Tuition Fee',
      intentReference: json['intent_reference'] ?? 'EDU202611140042',
      auditHistory: json['audit_history'],
    );
  }

  static List<TransactionItem> getMockItems() {
    final now = DateTime.now();
    return [
      TransactionItem(
        id: '1',
        transactionReference: 'UPI/438729106731',
        amountPaise: 200034,
        baseFeePaise: 200000,
        excessPaise: 34,
        paymentMode: 'UPI (PhonePe)',
        upiApp: 'PhonePe',
        maskedSender: '**** 9821',
        paymentStatus: 'VERIFIED_SUCCESS',
        receivedAt: DateTime(now.year, now.month, now.day, 10, 18),
        matchedAt: DateTime(now.year, now.month, now.day, 10, 18),
        verifiedAt: DateTime(now.year, now.month, now.day, 10, 19),
        receiptNumber: 'RCP-2026-001042',
        studentName: 'Seema',
        invoiceNumber: 'INV-1042',
        invoiceTitle: 'Annual Tuition Fee',
        intentReference: 'EDU202611140042',
      ),
      TransactionItem(
        id: '2',
        transactionReference: 'GPay-319870221',
        amountPaise: 200005,
        baseFeePaise: 200000,
        excessPaise: 5,
        paymentMode: 'UPI (Google Pay)',
        upiApp: 'Google Pay',
        maskedSender: '**** 7712',
        paymentStatus: 'VERIFIED_SUCCESS',
        receivedAt: DateTime(now.year, now.month, now.day, 10, 7),
        matchedAt: DateTime(now.year, now.month, now.day, 10, 7),
        studentName: 'Mohan',
        invoiceNumber: 'INV-1041',
        invoiceTitle: 'Annual Tuition Fee',
        intentReference: 'EDU202611140041',
      ),
      TransactionItem(
        id: '3',
        transactionReference: 'UPI/438721993421',
        amountPaise: 150000,
        baseFeePaise: 150000,
        excessPaise: 0,
        paymentMode: 'UPI (PhonePe)',
        upiApp: 'PhonePe',
        maskedSender: '**** 2244',
        paymentStatus: 'UNMATCHED',
        receivedAt: DateTime(now.year, now.month, now.day, 9, 52),
      ),
      TransactionItem(
        id: '4',
        amountPaise: 1200000,
        baseFeePaise: 1200000,
        excessPaise: 0,
        paymentMode: 'UPI (Pending Intent)',
        upiApp: 'Pending Intent',
        paymentStatus: 'PENDING',
        receivedAt: DateTime(now.year, now.month, now.day, 9, 40),
        studentName: 'Amit',
        invoiceNumber: 'INV-1043',
        intentReference: 'EDU202611140043',
      ),
      TransactionItem(
        id: '5',
        transactionReference: 'RF-00018',
        amountPaise: 50000,
        baseFeePaise: 50000,
        excessPaise: 0,
        paymentMode: 'UPI (Refund)',
        paymentStatus: 'REFUNDED',
        receivedAt: now.subtract(const Duration(days: 1)),
        studentName: 'Riya',
        invoiceNumber: 'INV-1022',
      ),
      TransactionItem(
        id: '6',
        transactionReference: 'UPI/438720554821',
        amountPaise: 350000,
        baseFeePaise: 350000,
        excessPaise: 0,
        paymentMode: 'UPI (PhonePe)',
        upiApp: 'PhonePe',
        paymentStatus: 'VERIFIED_SUCCESS',
        receivedAt: now.subtract(const Duration(days: 1)),
        studentName: 'Rohan',
        invoiceNumber: 'INV-1039',
      ),
    ];
  }
}
