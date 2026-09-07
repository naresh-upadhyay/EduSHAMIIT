import 'package:intl/intl.dart';

class CirculationStatsModel {
  final int totalTransactions;
  final int booksIssuedToday;
  final double issuedDeltaPct;
  final int booksReturnedToday;
  final double returnedDeltaPct;
  final int currentlyIssued;
  final int overdueBooks;
  final int pendingRequests;
  final int pendingRenewals;
  final double totalFines;

  const CirculationStatsModel({
    this.totalTransactions = 0,
    this.booksIssuedToday = 0,
    this.issuedDeltaPct = 0.0,
    this.booksReturnedToday = 0,
    this.returnedDeltaPct = 0.0,
    this.currentlyIssued = 0,
    this.overdueBooks = 0,
    this.pendingRequests = 0,
    this.pendingRenewals = 0,
    this.totalFines = 0.0,
  });

  factory CirculationStatsModel.fromJson(Map<String, dynamic> json) {
    return CirculationStatsModel(
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      booksIssuedToday: (json['books_issued_today'] as num?)?.toInt() ?? 0,
      issuedDeltaPct: (json['issued_delta_pct'] as num?)?.toDouble() ?? 0.0,
      booksReturnedToday: (json['books_returned_today'] as num?)?.toInt() ?? 0,
      returnedDeltaPct: (json['returned_delta_pct'] as num?)?.toDouble() ?? 0.0,
      currentlyIssued: (json['currently_issued'] as num?)?.toInt() ?? 0,
      overdueBooks: (json['overdue_books'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pending_requests'] as num?)?.toInt() ?? 0,
      pendingRenewals: (json['pending_renewals'] as num?)?.toInt() ?? 0,
      totalFines: (json['total_fines'] as num?)?.toDouble() ?? 0.0,
    );
  }


  String get formattedTotalFines {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return fmt.format(totalFines);
  }
}

class LibraryTransactionModel {
  final String id;
  final String transactionCode;
  final String memberId;
  final String? memberUserId;
  final String memberName;

  final String memberCode;
  final String memberType;
  final String memberRole;
  final String memberClass;
  final String? memberAvatar;
  final String? memberPhone;
  final String? memberEmail;

  final String bookId;
  final String bookTitle;
  final String bookIsbn;
  final String? bookCoverUrl;
  final String bookAuthor;
  final String bookCategory;

  final String? copyId;
  final String copyAccession;
  final String copyBarcode;
  final String shelfLocation;

  final DateTime issueDate;
  final DateTime? dueDate;
  final DateTime? returnDate;

  final String status;
  final int daysOverdue;
  final double fineAmount;
  final String fineStatus;
  final String transactionType;
  final int renewalsUsed;
  final int maxRenewals;
  final String? returnCondition;

  final String? issuedByName;
  final String? receivedByName;
  final String? notes;
  final DateTime createdAt;

  const LibraryTransactionModel({
    required this.id,
    required this.transactionCode,
    required this.memberId,
    this.memberUserId,
    required this.memberName,
    required this.memberCode,
    required this.memberType,
    required this.memberRole,
    required this.memberClass,
    this.memberAvatar,
    this.memberPhone,
    this.memberEmail,
    required this.bookId,
    required this.bookTitle,
    required this.bookIsbn,
    this.bookCoverUrl,
    required this.bookAuthor,
    required this.bookCategory,
    this.copyId,
    required this.copyAccession,
    required this.copyBarcode,
    required this.shelfLocation,
    required this.issueDate,
    this.dueDate,
    this.returnDate,
    required this.status,
    this.daysOverdue = 0,
    this.fineAmount = 0.0,
    this.fineStatus = 'NONE',
    this.transactionType = 'MANUAL_ISSUE',
    this.renewalsUsed = 0,
    this.maxRenewals = 2,
    this.returnCondition,
    this.issuedByName,
    this.receivedByName,
    this.notes,
    required this.createdAt,
  });

  factory LibraryTransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return LibraryTransactionModel(
      id: json['id']?.toString() ?? '',
      transactionCode: json['transaction_code']?.toString() ?? 'TXN-0000',
      memberId: json['member_id']?.toString() ?? '',
      memberUserId: json['member_user_id']?.toString() ?? json['profile_id']?.toString() ?? json['student_id']?.toString(),
      memberName: json['member_name']?.toString() ?? 'Unknown Member',

      memberCode: json['member_code']?.toString() ?? 'N/A',
      memberType: json['member_type']?.toString() ?? 'Student',
      memberRole: json['member_role']?.toString() ?? 'Student',
      memberClass: json['member_class']?.toString() ?? 'N/A',
      memberAvatar: json['member_avatar']?.toString(),
      memberPhone: json['member_phone']?.toString(),
      memberEmail: json['member_email']?.toString(),
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? 'Untitled Book',
      bookIsbn: json['book_isbn']?.toString() ?? 'N/A',
      bookCoverUrl: json['book_cover_url']?.toString(),
      bookAuthor: json['book_author']?.toString() ?? 'Unknown Author',
      bookCategory: json['book_category']?.toString() ?? 'General',
      copyId: json['copy_id']?.toString(),
      copyAccession: json['copy_accession']?.toString() ?? 'N/A',
      copyBarcode: json['copy_barcode']?.toString() ?? 'N/A',
      shelfLocation: json['shelf_location']?.toString() ?? 'N/A',
      issueDate: parseDate(json['issue_date'], DateTime.now()),
      dueDate: parseNullableDate(json['due_date']),
      returnDate: parseNullableDate(json['return_date']),
      status: (json['status']?.toString() ?? 'ISSUED').toUpperCase(),
      daysOverdue: (json['days_overdue'] as num?)?.toInt() ?? 0,
      fineAmount: (json['fine_amount'] as num?)?.toDouble() ?? 0.0,
      fineStatus: (json['fine_status']?.toString() ?? 'NONE').toUpperCase(),
      transactionType: json['transaction_type']?.toString() ?? 'MANUAL_ISSUE',
      renewalsUsed: (json['renewals_used'] as num?)?.toInt() ?? 0,
      maxRenewals: (json['max_renewals'] as num?)?.toInt() ?? 2,
      returnCondition: json['return_condition']?.toString(),
      issuedByName: json['issued_by_name']?.toString(),
      receivedByName: json['received_by_name']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at'], DateTime.now()),
    );
  }

  String get formattedIssueDate => DateFormat('dd MMM yyyy').format(issueDate);
  String get formattedDueDate => dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate!) : '—';
  String get formattedReturnDate => returnDate != null ? DateFormat('dd MMM yyyy').format(returnDate!) : '—';

  String get formattedFine {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return fmt.format(fineAmount);
  }

  String get displayTransactionType {
    final s = status.toUpperCase();
    final t = transactionType.toUpperCase();
    if (s == 'PENDING_RETURN' || t == 'RETURN_REQUEST') return 'Return Request';
    if (s == 'PENDING_RENEW' || t == 'RENEW_REQUEST') return 'Renew Request';
    if (s == 'PENDING' || s == 'WAITING' || s == 'REQUESTED' || t == 'REQUEST_TO_ISSUE') return 'Issue Request';
    if (t == 'REQUEST_APPROVED') return 'Request Approved';
    if (s == 'RENEWED' || t == 'RENEWED') return 'Renewed';
    if (s == 'RETURNED' || t == 'MANUAL_RETURN') return 'Returned';
    if (s == 'LOST' || s == 'DAMAGED' || t == 'LOST_DAMAGED') return 'Lost / Damaged';
    if (t.contains('REQUEST')) return 'Request';
    return 'Manual Issue';
  }
}

class CirculationFilterOptionsModel {
  final List<String> transactionTypes;
  final List<String> statuses;
  final List<String> searchInFields;
  final List<String> roles;
  final List<String> classes;

  const CirculationFilterOptionsModel({
    this.transactionTypes = const ['All', 'Manual Issue', 'Request Approved', 'Manual Return', 'Renewed', 'Lost / Damaged'],
    this.statuses = const ['All', 'Issued', 'Returned', 'Overdue', 'Renewed', 'Pending', 'Lost', 'Damaged'],
    this.searchInFields = const ['All Transactions', 'Member Name', 'Member Code', 'Book Title', 'ISBN', 'Barcode', 'Transaction ID'],
    this.roles = const ['All', 'Student', 'Teacher', 'Staff', 'Parent'],
    this.classes = const [],
  });

  factory CirculationFilterOptionsModel.fromJson(Map<String, dynamic> json) {
    List<String> toList(dynamic val, List<String> fallback) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return fallback;
    }

    return CirculationFilterOptionsModel(
      transactionTypes: toList(json['transaction_types'], const ['All', 'Manual Issue', 'Request Approved', 'Manual Return', 'Renewed', 'Lost / Damaged']),
      statuses: toList(json['statuses'], const ['All', 'Issued', 'Returned', 'Overdue', 'Renewed', 'Pending', 'Lost', 'Damaged']),
      searchInFields: toList(json['search_in_fields'], const ['All Transactions', 'Member Name', 'Member Code', 'Book Title', 'ISBN', 'Barcode', 'Transaction ID']),
      roles: toList(json['roles'], const ['All', 'Student', 'Teacher', 'Staff', 'Parent']),
      classes: toList(json['classes'], const []),
    );
  }
}


class CirculationActivityModel {
  final String id;
  final String activityType;
  final String title;
  final String? description;
  final String? memberName;
  final String? bookTitle;
  final DateTime createdAt;
  final String timeAgo;

  const CirculationActivityModel({
    required this.id,
    required this.activityType,
    required this.title,
    this.description,
    this.memberName,
    this.bookTitle,
    required this.createdAt,
    required this.timeAgo,
  });

  factory CirculationActivityModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    return CirculationActivityModel(
      id: json['id']?.toString() ?? '',
      activityType: json['activity_type']?.toString() ?? 'ISSUE',
      title: json['title']?.toString() ?? 'Activity',
      description: json['description']?.toString(),
      memberName: json['member_name']?.toString(),
      bookTitle: json['book_title']?.toString(),
      createdAt: parseDate(json['created_at']),
      timeAgo: json['time_ago']?.toString() ?? DateFormat('hh:mm a').format(DateTime.now()),
    );
  }
}

class OverdueSummaryModel {
  final String bracket;
  final int minDays;
  final int maxDays;
  final int booksCount;
  final double estimatedFines;

  const OverdueSummaryModel({
    required this.bracket,
    required this.minDays,
    required this.maxDays,
    required this.booksCount,
    required this.estimatedFines,
  });

  factory OverdueSummaryModel.fromJson(Map<String, dynamic> json) {
    var rawBracket = json['bracket']?.toString() ?? '1-3 Days';
    final cleanedBracket = rawBracket
        .replaceAll('???', '-')
        .replaceAll('â€“', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-');

    return OverdueSummaryModel(
      bracket: cleanedBracket,
      minDays: (json['min_days'] as num?)?.toInt() ?? 1,
      maxDays: (json['max_days'] as num?)?.toInt() ?? 3,
      booksCount: (json['books_count'] as num?)?.toInt() ?? 0,
      estimatedFines: (json['estimated_fines'] as num?)?.toDouble() ?? 0.0,
    );
  }


  String get formattedFines {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return fmt.format(estimatedFines);
  }
}

class LibraryRequestModel {
  final String id;
  final String requestType;
  final String priority;
  final String status;
  final String? reason;
  final String? rejectionReason;
  final DateTime? requestedDueDate;
  final DateTime createdAt;
  final DateTime? processedAt;

  final String memberId;
  final String memberCode;
  final String memberName;
  final String memberRole;
  final String memberClass;

  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String bookIsbn;
  final String? bookCoverUrl;
  final int availableCopies;

  const LibraryRequestModel({
    required this.id,
    required this.requestType,
    required this.priority,
    required this.status,
    this.reason,
    this.rejectionReason,
    this.requestedDueDate,
    required this.createdAt,
    this.processedAt,
    required this.memberId,
    required this.memberCode,
    required this.memberName,
    required this.memberRole,
    required this.memberClass,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookIsbn,
    this.bookCoverUrl,
    required this.availableCopies,
  });

  factory LibraryRequestModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return LibraryRequestModel(
      id: json['id']?.toString() ?? '',
      requestType: json['request_type']?.toString() ?? 'ISSUE',
      priority: json['priority']?.toString() ?? 'NORMAL',
      status: json['status']?.toString() ?? 'PENDING',
      reason: json['reason']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      requestedDueDate: parseNullableDate(json['requested_due_date']),
      createdAt: parseDate(json['created_at'], DateTime.now()),
      processedAt: parseNullableDate(json['processed_at']),
      memberId: json['member_id']?.toString() ?? '',
      memberCode: json['member_code']?.toString() ?? 'N/A',
      memberName: json['member_name']?.toString() ?? 'Member',
      memberRole: json['member_role']?.toString() ?? 'Student',
      memberClass: json['member_class']?.toString() ?? 'N/A',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? 'Book Title',
      bookAuthor: json['book_author']?.toString() ?? 'Author',
      bookIsbn: json['book_isbn']?.toString() ?? 'N/A',
      bookCoverUrl: json['book_cover_url']?.toString(),
      availableCopies: (json['available_copies'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedCreatedAt => DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
}

class ScanResultModel {
  final String entityType; // 'BOOK_COPY', 'MEMBER', 'BOOK_TITLE'
  final Map<String, dynamic> raw;

  const ScanResultModel({
    required this.entityType,
    required this.raw,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      entityType: json['entity_type']?.toString() ?? 'UNKNOWN',
      raw: json,
    );
  }
}
