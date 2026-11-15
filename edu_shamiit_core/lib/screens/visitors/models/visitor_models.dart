/// KPI Summary Data for Visitors Dashboard
class VisitorKPIs {
  final int totalVisitors;
  final String totalTrend;
  final String totalSubtitle;
  final int currentlyInside;
  final String currentlyInsideSubtitle;
  final int checkedInToday;
  final String checkedInTodaySubtitle;
  final int checkedOutToday;
  final String checkedOutTodaySubtitle;
  final int overstay;
  final String overstaySubtitle;
  final int scheduledToday;
  final String scheduledTodaySubtitle;

  const VisitorKPIs({
    this.totalVisitors = 256,
    this.totalTrend = '↑ 12%',
    this.totalSubtitle = 'This Month',
    this.currentlyInside = 38,
    this.currentlyInsideSubtitle = 'On campus now',
    this.checkedInToday = 62,
    this.checkedInTodaySubtitle = 'Till now',
    this.checkedOutToday = 58,
    this.checkedOutTodaySubtitle = 'Completed visits',
    this.overstay = 4,
    this.overstaySubtitle = 'Exceeding allowed time',
    this.scheduledToday = 12,
    this.scheduledTodaySubtitle = 'Upcoming visitors',
  });

  factory VisitorKPIs.fromJson(Map<String, dynamic> json) {
    return VisitorKPIs(
      totalVisitors: (json['total_visitors'] as num?)?.toInt() ?? 256,
      totalTrend: json['total_trend']?.toString() ?? '↑ 12%',
      totalSubtitle: json['total_subtitle']?.toString() ?? 'This Month',
      currentlyInside: (json['currently_inside'] as num?)?.toInt() ?? 38,
      currentlyInsideSubtitle: json['currently_inside_subtitle']?.toString() ?? 'On campus now',
      checkedInToday: (json['checked_in_today'] as num?)?.toInt() ?? 62,
      checkedInTodaySubtitle: json['checked_in_today_subtitle']?.toString() ?? 'Till now',
      checkedOutToday: (json['checked_out_today'] as num?)?.toInt() ?? 58,
      checkedOutTodaySubtitle: json['checked_out_today_subtitle']?.toString() ?? 'Completed visits',
      overstay: (json['overstay'] as num?)?.toInt() ?? 4,
      overstaySubtitle: json['overstay_subtitle']?.toString() ?? 'Exceeding allowed time',
      scheduledToday: (json['scheduled_today'] as num?)?.toInt() ?? 12,
      scheduledTodaySubtitle: json['scheduled_today_subtitle']?.toString() ?? 'Upcoming visitors',
    );
  }
}

/// Visitor List Item for Table Rows
class VisitorItem {
  final String id;
  final String visitNumber;
  final String visitorId;
  final String visitorName;
  final String? photoUrl;
  final String phone;
  final String visitorType;
  final String category;
  final String purpose;
  final String location;
  final String destination;
  final String entryLocation;
  final String hostName;
  final String? hostDepartment;
  final String checkInAt;
  final String? expectedOutAt;
  final String? actualCheckOutAt;
  final String status; // 'Inside', 'Checked Out', 'Overstay', 'Scheduled', etc.
  final String? vehicleNumber;
  final String? passReference;
  final String? remarks;

  const VisitorItem({
    required this.id,
    required this.visitNumber,
    required this.visitorId,
    required this.visitorName,
    this.photoUrl,
    required this.phone,
    required this.visitorType,
    required this.category,
    required this.purpose,
    required this.location,
    required this.destination,
    this.entryLocation = 'Main Gate',
    required this.hostName,
    this.hostDepartment,
    required this.checkInAt,
    this.expectedOutAt,
    this.actualCheckOutAt,
    required this.status,
    this.vehicleNumber,
    this.passReference,
    this.remarks,
  });

  factory VisitorItem.fromJson(Map<String, dynamic> json) {
    return VisitorItem(
      id: json['id']?.toString() ?? '',
      visitNumber: json['visit_number']?.toString() ?? '',
      visitorId: json['visitor_id']?.toString() ?? '',
      visitorName: json['visitor_name']?.toString() ?? 'Guest',
      photoUrl: json['photo_url']?.toString(),
      phone: json['phone']?.toString() ?? '',
      visitorType: json['visitor_type']?.toString() ?? 'Guest',
      category: json['category']?.toString() ?? 'Guest',
      purpose: json['purpose']?.toString() ?? 'General Visit',
      location: json['location']?.toString() ?? json['destination']?.toString() ?? 'Main Gate',
      destination: json['destination']?.toString() ?? 'Main Gate',
      entryLocation: json['entry_location']?.toString() ?? 'Main Gate',
      hostName: json['host_name']?.toString() ?? 'Faculty / Staff',
      hostDepartment: json['host_department']?.toString(),
      checkInAt: json['check_in_at']?.toString() ?? '',
      expectedOutAt: json['expected_out_at']?.toString(),
      actualCheckOutAt: json['actual_check_out_at']?.toString(),
      status: json['status']?.toString() ?? 'Inside',
      vehicleNumber: json['vehicle_number']?.toString(),
      passReference: json['pass_reference']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }

  String get expectedOut => expectedOutAt ?? '-';
}

/// 360 Full Visit Details for Inspector Drawer
class VisitorDetail360 {
  final Map<String, dynamic> visit;
  final Map<String, dynamic> visitor;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> visitHistory;
  final List<Map<String, dynamic>> accessEvents;

  const VisitorDetail360({
    required this.visit,
    required this.visitor,
    this.documents = const [],
    this.visitHistory = const [],
    this.accessEvents = const [],
  });

  factory VisitorDetail360.fromJson(Map<String, dynamic> json) {
    return VisitorDetail360(
      visit: (json['visit'] as Map<String, dynamic>?) ?? {},
      visitor: (json['visitor'] as Map<String, dynamic>?) ?? {},
      documents: (json['documents'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      visitHistory: (json['visit_history'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      accessEvents: (json['access_events'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }

  String get visitorName => visitor['full_name']?.toString() ?? 'Visitor';
  String get phone => visitor['phone']?.toString() ?? '-';
  String get email => visitor['email']?.toString() ?? 'rajesh@gmail.com';
  String get visitorType => visitor['visitor_type']?.toString() ?? 'Parent';
  String get idType => visitor['id_type']?.toString() ?? 'Aadhaar Card';
  String get idNumberMasked => visitor['id_number_masked']?.toString() ?? 'XXXX-XXXX-1234';
  String? get photoUrl => visitor['photo_url']?.toString();
  String get status => visit['status']?.toString() ?? 'Inside';
  String get purpose => visit['purpose']?.toString() ?? '-';
  String get location => visit['destination']?.toString() ?? visit['entry_location']?.toString() ?? 'Main Gate';
  String get hostName => visit['host_name']?.toString() ?? '-';
  String get checkInAt => visit['check_in_at']?.toString() ?? '-';
  String get expectedOutAt => visit['expected_out_at']?.toString() ?? '-';
  String get durationText => visit['duration_text']?.toString() ?? '1 hr 45 mins (ongoing)';
  String get vehicleNumber => visit['vehicle_number']?.toString() ?? '-';
  String get remarks => visit['remarks']?.toString() ?? 'Meeting regarding academic progress';
}

/// Scheduled KPI Summary Data matching Screenshot 1
class ScheduledKPIs {
  final int totalScheduled;
  final String totalScheduledSubtitle;
  final int today;
  final String todaySubtitle;
  final int thisWeek;
  final String thisWeekSubtitle;
  final int expectedVisitors;
  final String expectedVisitorsSubtitle;
  final int pendingApproval;
  final String pendingApprovalSubtitle;

  const ScheduledKPIs({
    this.totalScheduled = 12,
    this.totalScheduledSubtitle = 'Upcoming visitors',
    this.today = 4,
    this.todaySubtitle = 'Scheduled for today',
    this.thisWeek = 8,
    this.thisWeekSubtitle = 'Next 7 days',
    this.expectedVisitors = 26,
    this.expectedVisitorsSubtitle = 'This week',
    this.pendingApproval = 3,
    this.pendingApprovalSubtitle = 'Awaiting approval',
  });

  factory ScheduledKPIs.fromJson(Map<String, dynamic> json) {
    return ScheduledKPIs(
      totalScheduled: (json['total_scheduled'] as num?)?.toInt() ?? 12,
      totalScheduledSubtitle: json['total_scheduled_subtitle']?.toString() ?? 'Upcoming visitors',
      today: (json['today'] as num?)?.toInt() ?? 4,
      todaySubtitle: json['today_subtitle']?.toString() ?? 'Scheduled for today',
      thisWeek: (json['this_week'] as num?)?.toInt() ?? 8,
      thisWeekSubtitle: json['this_week_subtitle']?.toString() ?? 'Next 7 days',
      expectedVisitors: (json['expected_visitors'] as num?)?.toInt() ?? 26,
      expectedVisitorsSubtitle: json['expected_visitors_subtitle']?.toString() ?? 'This week',
      pendingApproval: (json['pending_approval'] as num?)?.toInt() ?? 3,
      pendingApprovalSubtitle: json['pending_approval_subtitle']?.toString() ?? 'Awaiting approval',
    );
  }
}

/// Blacklisted KPI Summary Data matching Screenshot 2
class BlacklistKPIs {
  final int totalBlacklisted;
  final String totalBlacklistedSubtitle;
  final int activeBlocks;
  final String activeBlocksSubtitle;
  final int expiredBlocks;
  final String expiredBlocksSubtitle;
  final int attemptedEntries;
  final String attemptedEntriesSubtitle;

  const BlacklistKPIs({
    this.totalBlacklisted = 18,
    this.totalBlacklistedSubtitle = 'Restricted from entry',
    this.activeBlocks = 15,
    this.activeBlocksSubtitle = 'Currently restricted',
    this.expiredBlocks = 3,
    this.expiredBlocksSubtitle = 'Restriction ended',
    this.attemptedEntries = 5,
    this.attemptedEntriesSubtitle = 'Blocked at gate',
  });

  factory BlacklistKPIs.fromJson(Map<String, dynamic> json) {
    return BlacklistKPIs(
      totalBlacklisted: (json['total_blacklisted'] as num?)?.toInt() ?? 18,
      totalBlacklistedSubtitle: json['total_blacklisted_subtitle']?.toString() ?? 'Restricted from entry',
      activeBlocks: (json['active_blocks'] as num?)?.toInt() ?? 15,
      activeBlocksSubtitle: json['active_blocks_subtitle']?.toString() ?? 'Currently restricted',
      expiredBlocks: (json['expired_blocks'] as num?)?.toInt() ?? 3,
      expiredBlocksSubtitle: json['expired_blocks_subtitle']?.toString() ?? 'Restriction ended',
      attemptedEntries: (json['attempted_entries'] as num?)?.toInt() ?? 5,
      attemptedEntriesSubtitle: json['attempted_entries_subtitle']?.toString() ?? 'Blocked at gate',
    );
  }
}

/// Scheduled Appointment Item for Tab 2
class ScheduledAppointmentItem {
  final String id;
  final String appointmentNumber;
  final String visitorId;
  final String visitorName;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? company;
  final String visitorType;
  final String hostName;
  final String? hostDepartment;
  final String? hostSubtitle;
  final String purpose;
  final String destination;
  final String location;
  final String scheduledDate;
  final String scheduledStartAt;
  final String scheduledEndAt;
  final String dateTimeText;
  final String status; // 'Confirmed', 'Pending', 'Rejected', 'Cancelled'
  final String? approvedByName;
  final String? rejectionReason;
  final String? notes;
  final int expectedCount;
  final String expectedVisitorsText;
  final String? vehicleNumber;
  final String idType;
  final String idNumberMasked;
  final String? remarks;

  const ScheduledAppointmentItem({
    required this.id,
    required this.appointmentNumber,
    required this.visitorId,
    required this.visitorName,
    required this.phone,
    this.email,
    this.photoUrl,
    this.company,
    required this.visitorType,
    required this.hostName,
    this.hostDepartment,
    this.hostSubtitle,
    required this.purpose,
    required this.destination,
    this.location = 'Main Gate',
    required this.scheduledDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    this.dateTimeText = '',
    required this.status,
    this.approvedByName,
    this.rejectionReason,
    this.notes,
    this.expectedCount = 1,
    this.expectedVisitorsText = '1',
    this.vehicleNumber,
    this.idType = 'Aadhaar Card',
    this.idNumberMasked = 'XXXX-XXXX-1234',
    this.remarks,
  });

  factory ScheduledAppointmentItem.fromJson(Map<String, dynamic> json) {
    return ScheduledAppointmentItem(
      id: json['id']?.toString() ?? '',
      appointmentNumber: json['appointment_number']?.toString() ?? '',
      visitorId: json['visitor_id']?.toString() ?? '',
      visitorName: json['visitor_name']?.toString() ?? 'Guest',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      company: json['company']?.toString(),
      visitorType: json['visitor_type']?.toString() ?? 'Parent',
      hostName: json['host_name']?.toString() ?? 'Host',
      hostDepartment: json['host_department']?.toString(),
      hostSubtitle: json['host_subtitle']?.toString() ?? json['host_department']?.toString(),
      purpose: json['purpose']?.toString() ?? 'PTM Meeting',
      destination: json['destination']?.toString() ?? 'Main Gate',
      location: json['location']?.toString() ?? json['destination']?.toString() ?? 'Main Gate',
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      scheduledStartAt: json['scheduled_start_at']?.toString() ?? '',
      scheduledEndAt: json['scheduled_end_at']?.toString() ?? '',
      dateTimeText: json['date_time_text']?.toString() ?? '${json['scheduled_date'] ?? ''}\n${json['scheduled_start_at'] ?? ''} - ${json['scheduled_end_at'] ?? ''}'.trim(),
      status: json['status']?.toString() ?? 'Pending',
      approvedByName: json['approved_by_name']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      notes: json['notes']?.toString(),
      expectedCount: (json['expected_count'] as num?)?.toInt() ?? 1,
      expectedVisitorsText: json['expected_visitors_text']?.toString() ?? '1',
      vehicleNumber: json['vehicle_number']?.toString(),
      idType: json['id_type']?.toString() ?? 'Aadhaar Card',
      idNumberMasked: json['id_number_masked']?.toString() ?? 'XXXX-XXXX-1234',
      remarks: json['remarks']?.toString() ?? json['notes']?.toString(),
    );
  }

  String get visitorPhone => phone;
  String get scheduledStart => scheduledStartAt;
  String get scheduledEnd => scheduledEndAt;
}

/// 360 Degree Scheduled Appointment Details for Right Drawer
class AppointmentDetail360 {
  final ScheduledAppointmentItem appointment;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> visitHistory;
  final List<Map<String, dynamic>> relatedAppointments;

  const AppointmentDetail360({
    required this.appointment,
    this.documents = const [],
    this.visitHistory = const [],
    this.relatedAppointments = const [],
  });

  factory AppointmentDetail360.fromJson(Map<String, dynamic> json) {
    final apptMap = (json['appointment'] as Map<String, dynamic>?) ?? {};
    return AppointmentDetail360(
      appointment: ScheduledAppointmentItem.fromJson(apptMap),
      documents: (json['documents'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      visitHistory: ((json['visit_history'] ?? json['history']) as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      relatedAppointments: (json['related_appointments'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }
}

/// Blacklisted Visitor Item for Tab 3
class BlacklistedVisitorItem {
  final String id;
  final String visitorId;
  final String visitorName;
  final String visitorPhone;
  final String? email;
  final String? photoUrl;
  final String idType;
  final String idNumberMasked;
  final String scopeType;
  final String scopeName;
  final String reasonCategory;
  final String confidentialNotes;
  final String status; // 'Active', 'Expired', 'Lifted'
  final String effectiveFrom;
  final String blockedOnText;
  final String validTillText;
  final bool isPermanent;
  final String? reviewAt;
  final String? requestedByName;
  final String? approvedByName;
  final String? blockedByName;
  final String? liftedByName;
  final String? liftReason;
  final String? remarks;

  const BlacklistedVisitorItem({
    required this.id,
    required this.visitorId,
    required this.visitorName,
    required this.visitorPhone,
    this.email,
    this.photoUrl,
    this.idType = 'Aadhaar Card',
    this.idNumberMasked = 'XXXX-1234',
    required this.scopeType,
    required this.scopeName,
    required this.reasonCategory,
    required this.confidentialNotes,
    required this.status,
    required this.effectiveFrom,
    this.blockedOnText = '',
    this.validTillText = 'Permanent',
    this.isPermanent = true,
    this.reviewAt,
    this.requestedByName,
    this.approvedByName,
    this.blockedByName,
    this.liftedByName,
    this.liftReason,
    this.remarks,
  });

  factory BlacklistedVisitorItem.fromJson(Map<String, dynamic> json) {
    return BlacklistedVisitorItem(
      id: json['id']?.toString() ?? '',
      visitorId: json['visitor_id']?.toString() ?? '',
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorPhone: json['visitor_phone']?.toString() ?? json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      idType: json['id_type']?.toString() ?? 'Aadhaar',
      idNumberMasked: json['id_number_masked']?.toString() ?? 'XXXX-1234',
      scopeType: json['scope_type']?.toString() ?? 'INSTITUTION',
      scopeName: json['scope_name']?.toString() ?? 'Main Gate',
      reasonCategory: json['reason_category']?.toString() ?? 'Theft',
      confidentialNotes: json['confidential_notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      effectiveFrom: json['effective_from']?.toString() ?? '',
      blockedOnText: json['blocked_on']?.toString() ?? json['effective_from']?.toString() ?? '',
      validTillText: json['valid_till']?.toString() ?? json['valid_till_text']?.toString() ?? 'Permanent',
      isPermanent: json['is_permanent'] == true ||
          ((json['is_permanent'] == null) &&
              ((json['valid_till']?.toString().toLowerCase() == 'permanent') ||
                  (json['valid_till_text']?.toString().toLowerCase() == 'permanent'))),
      reviewAt: json['review_at']?.toString() ?? json['expires_at']?.toString(),
      requestedByName: json['requested_by_name']?.toString(),
      approvedByName: json['approved_by_name']?.toString(),
      blockedByName: json['blocked_by_name']?.toString() ?? 'Rahul Sharma (Security)',
      liftedByName: json['lifted_by_name']?.toString(),
      liftReason: json['lift_reason']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }

  String get expiresAt => reviewAt ?? validTillText;
  String get mobileNo => visitorPhone;
}

/// 360 Degree Blacklisted Visitor Details for Right Drawer
class RestrictionDetail360 {
  final BlacklistedVisitorItem restriction;
  final List<Map<String, dynamic>> attemptedEntries;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> documents;

  const RestrictionDetail360({
    required this.restriction,
    this.attemptedEntries = const [],
    this.history = const [],
    this.documents = const [],
  });

  factory RestrictionDetail360.fromJson(Map<String, dynamic> json) {
    final resMap = (json['restriction'] as Map<String, dynamic>?) ?? {};
    return RestrictionDetail360(
      restriction: BlacklistedVisitorItem.fromJson(resMap),
      attemptedEntries: (json['attempted_entries'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      history: (json['history'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      documents: (json['documents'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }
}

/// Category and Location Analytics Breakdown
class VisitorAnalyticsData {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> recentVisitors;

  const VisitorAnalyticsData({
    this.categories = const [],
    this.locations = const [],
    this.recentVisitors = const [],
  });

  factory VisitorAnalyticsData.fromJson(Map<String, dynamic> json) {
    return VisitorAnalyticsData(
      categories: (json['categories'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      locations: (json['locations'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
      recentVisitors: (json['recent_visitors'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [],
    );
  }
}

/// Pagination State
class VisitorPagination {
  final int totalRecords;
  final int page;
  final int pageSize;
  final int totalPages;

  const VisitorPagination({
    this.totalRecords = 0,
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
  });

  factory VisitorPagination.fromJson(Map<String, dynamic> json) {
    return VisitorPagination(
      totalRecords: (json['total_records'] as num?)?.toInt() ??
          (json['total'] as num?)?.toInt() ??
          0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 10,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  VisitorPagination copyWith({
    int? totalRecords,
    int? page,
    int? pageSize,
    int? totalPages,
  }) {
    return VisitorPagination(
      totalRecords: totalRecords ?? this.totalRecords,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
    );
  }
}

/// Visitor Profile Item for the View Visitors Profile Popup and Pass Generator
class VisitorProfileItem {
  final String id;
  final String schoolId;
  final String fullName;
  final String phone;
  final String? alternatePhone;
  final String? email;
  final String? company;
  final String? designation;
  final String visitorType;
  final String idType;
  final String idNumberMasked;
  final String verificationStatus;
  final String? photoUrl;
  final String? notes;
  final bool isBlacklisted;
  final int totalVisits;
  final String? lastVisitAt;
  final String createdAt;
  final String updatedAt;

  const VisitorProfileItem({
    required this.id,
    required this.schoolId,
    required this.fullName,
    required this.phone,
    this.alternatePhone,
    this.email,
    this.company,
    this.designation,
    this.visitorType = 'Parent',
    this.idType = 'Aadhaar Card',
    this.idNumberMasked = 'XXXX-XXXX-1234',
    this.verificationStatus = 'VERIFIED',
    this.photoUrl,
    this.notes,
    this.isBlacklisted = false,
    this.totalVisits = 0,
    this.lastVisitAt,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory VisitorProfileItem.fromJson(Map<String, dynamic> json) {
    return VisitorProfileItem(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      alternatePhone: json['alternate_phone']?.toString(),
      email: json['email']?.toString(),
      company: json['company']?.toString(),
      designation: json['designation']?.toString(),
      visitorType: json['visitor_type']?.toString() ?? 'Parent',
      idType: json['id_type']?.toString() ?? 'Aadhaar Card',
      idNumberMasked: json['id_number_masked']?.toString() ?? 'XXXX-XXXX-1234',
      verificationStatus: json['verification_status']?.toString() ?? 'VERIFIED',
      photoUrl: json['photo_url']?.toString(),
      notes: json['notes']?.toString(),
      isBlacklisted: json['is_blacklisted'] == true,
      totalVisits: (json['total_visits'] as num?)?.toInt() ?? 0,
      lastVisitAt: json['last_visit_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

/// Generated Gate Pass Model with scannable QR Code
class GeneratedGatePassItem {
  final String passId;
  final String passNumber;
  final String visitId;
  final String visitNumber;
  final String visitorId;
  final String visitorName;
  final String visitorType;
  final String phone;
  final String company;
  final String? photoUrl;
  final String destination;
  final String hostName;
  final String purpose;
  final String issuedAt;
  final String expiresAt;
  final String? checkInAt;
  final String status;
  final String visitStatus;
  final String qrCodeBase64;
  final String qrCodeUrl;

  const GeneratedGatePassItem({
    required this.passId,
    required this.passNumber,
    required this.visitId,
    required this.visitNumber,
    required this.visitorId,
    required this.visitorName,
    required this.visitorType,
    required this.phone,
    this.company = '',
    this.photoUrl,
    required this.destination,
    required this.hostName,
    required this.purpose,
    required this.issuedAt,
    required this.expiresAt,
    this.checkInAt,
    this.status = 'ACTIVE',
    this.visitStatus = 'Scheduled',
    required this.qrCodeBase64,
    required this.qrCodeUrl,
  });

  factory GeneratedGatePassItem.fromJson(Map<String, dynamic> json) {
    return GeneratedGatePassItem(
      passId: json['pass_id']?.toString() ?? '',
      passNumber: json['pass_number']?.toString() ?? '',
      visitId: json['visit_id']?.toString() ?? '',
      visitNumber: json['visit_number']?.toString() ?? '',
      visitorId: json['visitor_id']?.toString() ?? '',
      visitorName: json['visitor_name']?.toString() ?? '',
      visitorType: json['visitor_type']?.toString() ?? 'Parent',
      phone: json['phone']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      destination: json['destination']?.toString() ?? 'Main Gate',
      hostName: json['host_name']?.toString() ?? 'Administration',
      purpose: json['purpose']?.toString() ?? 'Official Visit',
      issuedAt: json['issued_at']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
      checkInAt: json['check_in_at']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      visitStatus: json['visit_status']?.toString() ?? 'Scheduled',
      qrCodeBase64: json['qr_code_base64']?.toString() ?? '',
      qrCodeUrl: json['qr_code_url']?.toString() ?? '',
    );
  }
}

/// Gate Pass Scan & Verification Result
class GatePassScanResult {
  final bool success;
  final bool isValid;
  final String? decodedText;
  final String? suggestedAction; // 'CHECK_IN', 'CHECK_OUT', 'ALREADY_CHECKED_OUT'
  final bool isBlacklisted;
  final String message;
  final Map<String, dynamic>? data;

  const GatePassScanResult({
    required this.success,
    required this.isValid,
    this.decodedText,
    this.suggestedAction,
    this.isBlacklisted = false,
    required this.message,
    this.data,
  });

  factory GatePassScanResult.fromJson(Map<String, dynamic> json) {
    return GatePassScanResult(
      success: json['success'] == true,
      isValid: json['is_valid'] == true,
      decodedText: json['decoded_text']?.toString(),
      suggestedAction: json['suggested_action']?.toString(),
      isBlacklisted: json['is_blacklisted'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Smart Host Search Result Item (Cross-module Student & Staff lookup)
class HostSearchResultItem {
  final String id;
  final String name;
  final String role;
  final String hostType; // 'STUDENT' or 'STAFF'
  final String department;
  final String phone;
  final String email;
  final String? avatarUrl;
  final String details;
  final bool isHostelResident;
  final String? hostelName;
  final String? hostelRoom;
  final String? activeOutingPass;
  final String? rawClassSection;
  final String? rawRollNumber;
  final String? rawDesignation;

  const HostSearchResultItem({
    required this.id,
    required this.name,
    required this.role,
    required this.hostType,
    required this.department,
    required this.phone,
    required this.email,
    this.avatarUrl,
    required this.details,
    this.isHostelResident = false,
    this.hostelName,
    this.hostelRoom,
    this.activeOutingPass,
    this.rawClassSection,
    this.rawRollNumber,
    this.rawDesignation,
  });

  factory HostSearchResultItem.fromJson(Map<String, dynamic> json) {
    return HostSearchResultItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'staff',
      hostType: json['host_type']?.toString() ??
          (json['role']?.toString().toLowerCase() == 'student' ? 'STUDENT' : 'STAFF'),
      department: json['department']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      details: json['details']?.toString() ?? '',
      isHostelResident: json['is_hostel_resident'] == true || json['hostel_room'] != null,
      hostelName: json['hostel_name']?.toString(),
      hostelRoom: json['hostel_room']?.toString(),
      activeOutingPass: json['active_outing_pass']?.toString() ?? json['outing_details']?.toString(),
      rawClassSection: json['class_section']?.toString(),
      rawRollNumber: json['roll_number']?.toString(),
      rawDesignation: json['designation']?.toString(),
    );
  }

  bool get isStudent => hostType == 'STUDENT' || role.toLowerCase() == 'student';
  String get fullName => name;
  String get displayName {
    if (isStudent) {
      if (rawClassSection != null && rawClassSection!.isNotEmpty) {
        return '$name (Class $rawClassSection)';
      }
      return details.isNotEmpty ? '$name ($details)' : name;
    }
    if (rawDesignation != null && rawDesignation!.isNotEmpty) {
      return '$name ($rawDesignation)';
    }
    if (department.isNotEmpty) {
      return '$name ($department)';
    }
    return details.isNotEmpty ? '$name ($details)' : name;
  }

  String? get classSection => rawClassSection ?? (details.isNotEmpty ? details : null);
  String? get rollNumber => rawRollNumber;
  String? get designation => rawDesignation ?? (department.isNotEmpty ? department : null);
  bool get hasActiveOuting => activeOutingPass != null && activeOutingPass!.isNotEmpty;
  String? get outingDetails => activeOutingPass;
}

/// Realtime Blacklist Check Result
class InstantRestrictionResult {
  final bool isRestricted;
  final Map<String, dynamic>? restriction;
  final VisitorProfileItem? profile;

  const InstantRestrictionResult({
    required this.isRestricted,
    this.restriction,
    this.profile,
  });

  String get restrictionReason =>
      restriction?['restriction_reason']?.toString() ??
      restriction?['reason']?.toString() ??
      restriction?['reason_category']?.toString() ??
      restriction?['remarks']?.toString() ??
      '';

  String get restrictionType =>
      restriction?['restriction_type']?.toString() ??
      restriction?['scope_type']?.toString() ??
      'RESTRICTED';

  factory InstantRestrictionResult.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? restMap = json['restriction'] is Map<String, dynamic>
        ? json['restriction'] as Map<String, dynamic>
        : (json['is_restricted'] == true ? json : null);
    return InstantRestrictionResult(
      isRestricted: json['is_restricted'] == true,
      restriction: restMap,
      profile: json['profile'] is Map<String, dynamic>
          ? VisitorProfileItem.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

