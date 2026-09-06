/// Representation of a Library Member joined with Profile Identity Information
class LibraryMemberModel {
  final String id;
  final String schoolId;
  final String profileId;
  final String memberCode;
  final String memberName;
  final String membershipType;
  final String? email;
  final String? phone;
  final String? role;
  final String? className;
  final String? department;
  final String? admissionNumber;
  final String? employeeId;
  final String? avatarUrl;
  final DateTime? membershipStartDate;
  final DateTime? membershipExpiryDate;
  final int borrowingLimit;
  final int maxIssueDurationDays;
  final bool renewalAllowed;
  final int maxRenewals;
  final int booksIssued;
  final int totalBorrowedCount;
  final double outstandingFine;
  final int overdueCount;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LibraryMemberModel({
    required this.id,
    required this.schoolId,
    required this.profileId,
    required this.memberCode,
    required this.memberName,
    required this.membershipType,
    this.email,
    this.phone,
    this.role,
    this.className,
    this.department,
    this.admissionNumber,
    this.employeeId,
    this.avatarUrl,
    this.membershipStartDate,
    this.membershipExpiryDate,
    this.borrowingLimit = 3,
    this.maxIssueDurationDays = 14,
    this.renewalAllowed = true,
    this.maxRenewals = 2,
    this.booksIssued = 0,
    this.totalBorrowedCount = 0,
    this.outstandingFine = 0.0,
    this.overdueCount = 0,
    this.status = 'ACTIVE',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isSuspended => status.toUpperCase() == 'SUSPENDED';
  bool get isInactive => status.toUpperCase() == 'INACTIVE';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get hasActiveBooks => booksIssued > 0;
  bool get hasOverdue => overdueCount > 0;
  bool get hasFines => outstandingFine > 0;

  String get classOrDepartment => (className != null && className!.isNotEmpty)
      ? className!
      : (department != null && department!.isNotEmpty ? department! : 'General');

  factory LibraryMemberModel.fromJson(Map<String, dynamic> json) {
    return LibraryMemberModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      memberCode: json['member_code']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? json['full_name']?.toString() ?? 'Unknown Member',
      membershipType: json['membership_type']?.toString() ?? 'Student',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      className: json['class_name']?.toString() ?? json['class']?.toString(),
      department: json['department']?.toString(),
      admissionNumber: json['admission_number']?.toString(),
      employeeId: json['employee_id']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      membershipStartDate: json['membership_start_date'] != null
          ? DateTime.tryParse(json['membership_start_date'].toString())
          : null,
      membershipExpiryDate: json['membership_expiry_date'] != null
          ? DateTime.tryParse(json['membership_expiry_date'].toString())
          : null,
      borrowingLimit: int.tryParse(json['borrowing_limit']?.toString() ?? '') ?? 3,
      maxIssueDurationDays: int.tryParse(json['max_issue_duration_days']?.toString() ?? '') ?? 14,
      renewalAllowed: json['renewal_allowed'] == true || json['renewal_allowed']?.toString() == 'true',
      maxRenewals: int.tryParse(json['max_renewals']?.toString() ?? '') ?? 2,
      booksIssued: int.tryParse(json['current_borrowed_count']?.toString() ?? '') ?? 0,
      totalBorrowedCount: int.tryParse(json['total_borrowed_count']?.toString() ?? '') ?? 0,
      outstandingFine: double.tryParse(json['outstanding_fine']?.toString() ?? '') ?? 0.0,
      overdueCount: int.tryParse(json['overdue_count']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

/// Aggregated KPI Metrics
class MemberStatsModel {
  final int totalMembers;
  final int activeMembers;
  final int newThisMonth;
  final int membersWithBooks;
  final double totalOutstandingFine;
  final int studentsCount;
  final int teachersCount;
  final int staffCount;
  final int suspendedCount;
  final int inactiveCount;
  final int expiringSoonCount;

  const MemberStatsModel({
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.newThisMonth = 0,
    this.membersWithBooks = 0,
    this.totalOutstandingFine = 0.0,
    this.studentsCount = 0,
    this.teachersCount = 0,
    this.staffCount = 0,
    this.suspendedCount = 0,
    this.inactiveCount = 0,
    this.expiringSoonCount = 0,
  });

  factory MemberStatsModel.fromJson(Map<String, dynamic> json) {
    return MemberStatsModel(
      totalMembers: int.tryParse(json['total_members']?.toString() ?? '') ?? 0,
      activeMembers: int.tryParse(json['active_members']?.toString() ?? '') ?? 0,
      newThisMonth: int.tryParse(json['new_this_month']?.toString() ?? '') ?? 0,
      membersWithBooks: int.tryParse(json['members_with_books']?.toString() ?? '') ?? 0,
      totalOutstandingFine: double.tryParse(json['total_outstanding_fine']?.toString() ?? '') ?? 0.0,
      studentsCount: int.tryParse(json['students_count']?.toString() ?? '') ?? 0,
      teachersCount: int.tryParse(json['teachers_count']?.toString() ?? '') ?? 0,
      staffCount: int.tryParse(json['staff_count']?.toString() ?? '') ?? 0,
      suspendedCount: int.tryParse(json['suspended_count']?.toString() ?? '') ?? 0,
      inactiveCount: int.tryParse(json['inactive_count']?.toString() ?? '') ?? 0,
      expiringSoonCount: int.tryParse(json['expiring_soon_count']?.toString() ?? '') ?? 0,
    );
  }
}

/// Active Issued Book on a Member Profile
class MemberBorrowItemModel {
  final String borrowId;
  final String bookId;
  final String? copyId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? isbn13;
  final String? accessionNumber;
  final String? barcode;
  final String? location;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final DateTime? returnDate;
  final String status;
  final double fineAmount;
  final bool isOverdue;
  final int daysOverdue;

  const MemberBorrowItemModel({
    required this.borrowId,
    required this.bookId,
    this.copyId,
    required this.title,
    this.author,
    this.coverUrl,
    this.isbn13,
    this.accessionNumber,
    this.barcode,
    this.location,
    this.issueDate,
    this.dueDate,
    this.returnDate,
    this.status = 'ISSUED',
    this.fineAmount = 0.0,
    this.isOverdue = false,
    this.daysOverdue = 0,
  });

  factory MemberBorrowItemModel.fromJson(Map<String, dynamic> json) {
    return MemberBorrowItemModel(
      borrowId: json['borrow_id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      copyId: json['copy_id']?.toString(),
      title: json['title']?.toString() ?? 'Book Title',
      author: json['author']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      isbn13: json['isbn13']?.toString(),
      accessionNumber: json['accession_number']?.toString(),
      barcode: json['barcode']?.toString(),
      location: json['location']?.toString(),
      issueDate: json['issue_date'] != null ? DateTime.tryParse(json['issue_date'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      returnDate: json['return_date'] != null ? DateTime.tryParse(json['return_date'].toString()) : null,
      status: json['status']?.toString() ?? 'ISSUED',
      fineAmount: double.tryParse(json['fine_amount']?.toString() ?? '') ?? 0.0,
      isOverdue: json['is_overdue'] == true || json['is_overdue']?.toString() == 'true',
      daysOverdue: int.tryParse(json['days_overdue']?.toString() ?? '') ?? 0,
    );
  }
}

/// Itemized Fine Record
class MemberFineItemModel {
  final String id;
  final double amount;
  final double paidAmount;
  final double waivedAmount;
  final double outstandingAmount;
  final String reason;
  final String status;
  final DateTime? createdAt;
  final String? bookTitle;
  final DateTime? issueDate;
  final DateTime? dueDate;

  const MemberFineItemModel({
    required this.id,
    required this.amount,
    this.paidAmount = 0.0,
    this.waivedAmount = 0.0,
    this.outstandingAmount = 0.0,
    this.reason = 'OVERDUE_FINE',
    this.status = 'UNPAID',
    this.createdAt,
    this.bookTitle,
    this.issueDate,
    this.dueDate,
  });

  factory MemberFineItemModel.fromJson(Map<String, dynamic> json) {
    return MemberFineItemModel(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '') ?? 0.0,
      waivedAmount: double.tryParse(json['waived_amount']?.toString() ?? '') ?? 0.0,
      outstandingAmount: double.tryParse(json['outstanding_amount']?.toString() ?? '') ?? 0.0,
      reason: json['reason']?.toString() ?? 'OVERDUE_FINE',
      status: json['status']?.toString() ?? 'UNPAID',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      bookTitle: json['book_title']?.toString(),
      issueDate: json['issue_date'] != null ? DateTime.tryParse(json['issue_date'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
    );
  }
}

/// Audit Log Entry
class MemberAuditModel {
  final String id;
  final String actionType;
  final String description;
  final DateTime? createdAt;
  final String? performedByName;

  const MemberAuditModel({
    required this.id,
    required this.actionType,
    required this.description,
    this.createdAt,
    this.performedByName,
  });

  factory MemberAuditModel.fromJson(Map<String, dynamic> json) {
    return MemberAuditModel(
      id: json['id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? 'LOG',
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      performedByName: json['performed_by_name']?.toString(),
    );
  }
}

/// Profile Search Result for Add Member Dialog
class ProfileSearchResultModel {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final String? className;
  final String? department;
  final String? admissionNumber;
  final String? employeeId;
  final String? avatarUrl;
  final bool isAlreadyMember;
  final String? existingMemberId;
  final String? existingMemberCode;
  final String? existingMemberStatus;

  const ProfileSearchResultModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.className,
    this.department,
    this.admissionNumber,
    this.employeeId,
    this.avatarUrl,
    this.isAlreadyMember = false,
    this.existingMemberId,
    this.existingMemberCode,
    this.existingMemberStatus,
  });

  String get classOrDeptSubtitle {
    final parts = <String>[];
    parts.add(role.toUpperCase());
    if (className != null && className!.isNotEmpty) parts.add(className!);
    if (department != null && department!.isNotEmpty) parts.add(department!);
    if (admissionNumber != null && admissionNumber!.isNotEmpty) parts.add('Roll: $admissionNumber');
    return parts.join(' • ');
  }

  factory ProfileSearchResultModel.fromJson(Map<String, dynamic> json) {
    return ProfileSearchResultModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Unnamed',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'student',
      className: json['class']?.toString(),
      department: json['department']?.toString(),
      admissionNumber: json['admission_number']?.toString(),
      employeeId: json['employee_id']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      isAlreadyMember: json['is_already_member'] == true || json['is_already_member']?.toString() == 'true',
      existingMemberId: json['existing_member_id']?.toString(),
      existingMemberCode: json['existing_member_code']?.toString(),
      existingMemberStatus: json['existing_member_status']?.toString(),
    );
  }
}

/// Dynamic Filter Options fetched from backend lookups
class MemberFilterOptionsModel {
  final List<String> memberTypes;
  final List<String> classes;
  final List<String> departments;
  final List<String> statuses;

  const MemberFilterOptionsModel({
    this.memberTypes = const ['Student', 'Teacher', 'Staff', 'Librarian', 'Special / Research'],
    this.classes = const [],
    this.departments = const [],
    this.statuses = const ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'EXPIRED', 'EXPIRING_SOON'],
  });

  factory MemberFilterOptionsModel.fromJson(Map<String, dynamic> json) {
    return MemberFilterOptionsModel(
      memberTypes: (json['member_types'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Student', 'Teacher', 'Staff', 'Librarian', 'Special / Research'],
      classes: (json['classes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      departments: (json['departments'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      statuses: (json['statuses'] as List?)?.map((e) => e.toString()).toList() ??
          const ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'EXPIRED', 'EXPIRING_SOON'],
    );
  }
}
