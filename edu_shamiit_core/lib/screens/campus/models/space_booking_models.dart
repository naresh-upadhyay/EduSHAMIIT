/// Space Booking High-Level KPI Summary
class SpaceBookingKpis {
  final int totalBookings;
  final double totalChangePct;
  final int confirmedBookings;
  final double confirmedPct;
  final int pendingBookings;
  final double pendingPct;
  final int rejectedBookings;
  final double rejectedPct;
  final int currentUsageSpaces;
  final double utilizationRate;
  final double utilizationChangePct;

  const SpaceBookingKpis({
    this.totalBookings = 246,
    this.totalChangePct = 12.0,
    this.confirmedBookings = 198,
    this.confirmedPct = 80.5,
    this.pendingBookings = 28,
    this.pendingPct = 11.4,
    this.rejectedBookings = 9,
    this.rejectedPct = 3.7,
    this.currentUsageSpaces = 34,
    this.utilizationRate = 72.8,
    this.utilizationChangePct = 4.6,
  });

  factory SpaceBookingKpis.fromJson(Map<String, dynamic> json) {
    return SpaceBookingKpis(
      totalBookings: json['total_bookings'] as int? ?? 246,
      totalChangePct: (json['total_change_pct'] as num?)?.toDouble() ?? 12.0,
      confirmedBookings: json['confirmed_bookings'] as int? ?? 198,
      confirmedPct: (json['confirmed_pct'] as num?)?.toDouble() ?? 80.5,
      pendingBookings: json['pending_bookings'] as int? ?? 28,
      pendingPct: (json['pending_pct'] as num?)?.toDouble() ?? 11.4,
      rejectedBookings: json['rejected_bookings'] as int? ?? 9,
      rejectedPct: (json['rejected_pct'] as num?)?.toDouble() ?? 3.7,
      currentUsageSpaces: json['current_usage_spaces'] as int? ?? 34,
      utilizationRate: (json['utilization_rate'] as num?)?.toDouble() ?? 72.8,
      utilizationChangePct: (json['utilization_change_pct'] as num?)?.toDouble() ?? 4.6,
    );
  }
}

/// A booking event on the timeline grid
class SpaceTimelineBooking {
  final String id;
  final String bookingRef;
  final String title;
  final String purpose;
  final String startTime;
  final String endTime;
  final DateTime? startDatetime;
  final DateTime? endDatetime;
  final String bookingDate;
  final bool isRecurring;
  final int durationMinutes;
  final String organizerName;
  final String organizerRole;
  final String status;

  const SpaceTimelineBooking({
    required this.id,
    required this.bookingRef,
    required this.title,
    required this.purpose,
    required this.startTime,
    required this.endTime,
    this.startDatetime,
    this.endDatetime,
    this.bookingDate = '',
    this.isRecurring = false,
    this.durationMinutes = 60,
    required this.organizerName,
    required this.organizerRole,
    required this.status,
  });

  factory SpaceTimelineBooking.fromJson(Map<String, dynamic> json) {
    return SpaceTimelineBooking(
      id: json['id']?.toString() ?? '',
      bookingRef: json['booking_ref']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'Academic',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      startDatetime: json['start_datetime'] != null ? DateTime.tryParse(json['start_datetime']) : null,
      endDatetime: json['end_datetime'] != null ? DateTime.tryParse(json['end_datetime']) : null,
      bookingDate: json['booking_date']?.toString() ?? '',
      isRecurring: json['is_recurring'] == true ||
          (json['recurrence_series_id'] != null && json['recurrence_series_id'].toString().isNotEmpty) ||
          (json['recurring_series_id'] != null && json['recurring_series_id'].toString().isNotEmpty),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      organizerName: json['organizer_name']?.toString() ?? '',
      organizerRole: json['organizer_role']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Confirmed',
    );
  }
}

/// A Room row on the Availability & Booking timeline
class SpaceTimelineRoom {
  final String roomId;
  final String roomName;
  final String roomNumber;
  final String roomCode;
  final String roomType;
  final int capacity;
  final String buildingId;
  final String buildingName;
  final String buildingCode;
  final String? floorId;
  final String? floorName;
  final List<SpaceTimelineBooking> bookings;

  const SpaceTimelineRoom({
    required this.roomId,
    required this.roomName,
    required this.roomNumber,
    required this.roomCode,
    required this.roomType,
    required this.capacity,
    required this.buildingId,
    required this.buildingName,
    required this.buildingCode,
    this.floorId,
    this.floorName,
    required this.bookings,
  });

  factory SpaceTimelineRoom.fromJson(Map<String, dynamic> json) {
    var rawBookings = json['bookings'] as List<dynamic>? ?? [];
    List<SpaceTimelineBooking> parsedBookings = rawBookings
        .map((b) => SpaceTimelineBooking.fromJson(b as Map<String, dynamic>))
        .toList();

    return SpaceTimelineRoom(
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? '',
      capacity: json['capacity'] as int? ?? 40,
      buildingId: json['building_id']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      buildingCode: json['building_code']?.toString() ?? '',
      floorId: json['floor_id']?.toString(),
      floorName: json['floor_name']?.toString(),
      bookings: parsedBookings,
    );
  }
}

/// Paged Booking Request item in table
class SpaceBookingRequestItem {
  final String id;
  final String bookingRef;
  final String title;
  final String? description;
  final String purpose;
  final String category;
  final String priority;
  final String status;
  final bool isApproved;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final String formattedSchedule;
  final String roomId;
  final String roomName;
  final String roomType;
  final String spaceDisplay;
  final String buildingId;
  final String buildingName;
  final String organizerName;
  final String organizerRole;
  final String requestedByDisplay;
  final int attendeeCount;
  final bool isRecurring;
  final String rejectionReason;

  const SpaceBookingRequestItem({
    required this.id,
    required this.bookingRef,
    required this.title,
    this.description,
    required this.purpose,
    required this.category,
    required this.priority,
    required this.status,
    required this.isApproved,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.formattedSchedule,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.spaceDisplay,
    required this.buildingId,
    required this.buildingName,
    required this.organizerName,
    required this.organizerRole,
    required this.requestedByDisplay,
    required this.attendeeCount,
    required this.isRecurring,
    this.rejectionReason = '',
  });

  factory SpaceBookingRequestItem.fromJson(Map<String, dynamic> json) {
    return SpaceBookingRequestItem(
      id: json['id']?.toString() ?? '',
      bookingRef: json['booking_ref']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      purpose: json['purpose']?.toString() ?? 'Academic',
      category: json['category']?.toString() ?? 'Academic',
      priority: json['priority']?.toString() ?? 'Normal',
      status: json['status']?.toString() ?? 'Pending',
      isApproved: json['is_approved'] as bool? ?? false,
      bookingDate: json['booking_date']?.toString() ?? '',
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      formattedSchedule: json['formatted_schedule']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? '',
      spaceDisplay: json['space_display']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      organizerName: json['organizer_name']?.toString() ?? '',
      organizerRole: json['organizer_role']?.toString() ?? '',
      requestedByDisplay: json['requested_by_display']?.toString() ?? '',
      attendeeCount: json['attendee_count'] as int? ?? 1,
      isRecurring: json['is_recurring'] as bool? ?? false,
      rejectionReason: json['rejection_reason']?.toString() ?? '',
    );
  }
}

/// Paged list container for booking requests
class SpaceBookingListResponse {
  final List<SpaceBookingRequestItem> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const SpaceBookingListResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory SpaceBookingListResponse.fromJson(Map<String, dynamic> json) {
    var rawList = json['items'] as List<dynamic>? ?? [];
    List<SpaceBookingRequestItem> parsed = rawList
        .map((x) => SpaceBookingRequestItem.fromJson(x as Map<String, dynamic>))
        .toList();

    return SpaceBookingListResponse(
      items: parsed,
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

/// Space Utilization Stats for Donut Chart
class SpaceUtilizationStats {
  final int totalSpaces;
  final double overallRate;
  final int inUseCount;
  final double inUsePct;
  final int availableCount;
  final double availablePct;
  final int maintenanceCount;
  final double maintenancePct;
  final int notBookableCount;
  final double notBookablePct;

  const SpaceUtilizationStats({
    this.totalSpaces = 150,
    this.overallRate = 72.8,
    this.inUseCount = 109,
    this.inUsePct = 72.8,
    this.availableCount = 32,
    this.availablePct = 21.4,
    this.maintenanceCount = 6,
    this.maintenancePct = 4.0,
    this.notBookableCount = 3,
    this.notBookablePct = 2.0,
  });

  factory SpaceUtilizationStats.fromJson(Map<String, dynamic> json) {
    final inUse = json['in_use'] as Map<String, dynamic>? ?? {};
    final avail = json['available'] as Map<String, dynamic>? ?? {};
    final maint = json['under_maintenance'] as Map<String, dynamic>? ?? {};
    final notBook = json['not_bookable'] as Map<String, dynamic>? ?? {};

    return SpaceUtilizationStats(
      totalSpaces: json['total_spaces'] as int? ?? 150,
      overallRate: (json['overall_rate'] as num?)?.toDouble() ?? 72.8,
      inUseCount: inUse['count'] as int? ?? 109,
      inUsePct: (inUse['percentage'] as num?)?.toDouble() ?? 72.8,
      availableCount: avail['count'] as int? ?? 32,
      availablePct: (avail['percentage'] as num?)?.toDouble() ?? 21.4,
      maintenanceCount: maint['count'] as int? ?? 6,
      maintenancePct: (maint['percentage'] as num?)?.toDouble() ?? 4.0,
      notBookableCount: notBook['count'] as int? ?? 3,
      notBookablePct: (notBook['percentage'] as num?)?.toDouble() ?? 2.0,
    );
  }
}

/// Bookable Room for dropdown selections
class BookableRoomItem {
  final String id;
  final String name;
  final String roomNumber;
  final String roomCode;
  final String roomType;
  final int maxCapacity;
  final String buildingId;
  final String buildingName;
  final String buildingCode;

  const BookableRoomItem({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.roomCode,
    required this.roomType,
    required this.maxCapacity,
    required this.buildingId,
    required this.buildingName,
    required this.buildingCode,
  });

  factory BookableRoomItem.fromJson(Map<String, dynamic> json) {
    return BookableRoomItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? 'Classroom',
      maxCapacity: json['max_capacity'] as int? ?? 40,
      buildingId: json['building_id']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      buildingCode: json['building_code']?.toString() ?? '',
    );
  }
}

/// Dynamic Requester Profile from User Management Directory
class SpaceRequesterProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String department;
  final String? avatarUrl;

  const SpaceRequesterProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    this.avatarUrl,
  });

  factory SpaceRequesterProfile.fromJson(Map<String, dynamic> json) {
    return SpaceRequesterProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Unknown User',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Faculty',
      department: json['department']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

/// Hourly Traffic Curve Data Point
class SpaceHourlyOccupancy {
  final int militaryHour;
  final String hourLabel;
  final int activeBookings;
  final double occupancyPct;

  const SpaceHourlyOccupancy({
    required this.militaryHour,
    required this.hourLabel,
    required this.activeBookings,
    required this.occupancyPct,
  });

  factory SpaceHourlyOccupancy.fromJson(Map<String, dynamic> json) {
    return SpaceHourlyOccupancy(
      militaryHour: json['military_hour'] as int? ?? 8,
      hourLabel: json['hour_label']?.toString() ?? '08:00 AM',
      activeBookings: json['active_bookings'] as int? ?? 0,
      occupancyPct: (json['occupancy_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Day of Week Traffic Metric
class SpaceDayOfWeekTraffic {
  final int dayIndex;
  final String dayName;
  final String dayShort;
  final int bookingsCount;
  final double utilizationPct;

  const SpaceDayOfWeekTraffic({
    required this.dayIndex,
    required this.dayName,
    required this.dayShort,
    required this.bookingsCount,
    required this.utilizationPct,
  });

  factory SpaceDayOfWeekTraffic.fromJson(Map<String, dynamic> json) {
    return SpaceDayOfWeekTraffic(
      dayIndex: json['day_index'] as int? ?? 1,
      dayName: json['day_name']?.toString() ?? 'Monday',
      dayShort: json['day_short']?.toString() ?? 'Mon',
      bookingsCount: json['bookings_count'] as int? ?? 0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Space Type Breakdown Item for Donut Chart
class SpaceTypeBreakdownItem {
  final String code;
  final String typeName;
  final int count;
  final double percentage;
  final String colorHex;

  const SpaceTypeBreakdownItem({
    required this.code,
    required this.typeName,
    required this.count,
    required this.percentage,
    required this.colorHex,
  });

  factory SpaceTypeBreakdownItem.fromJson(Map<String, dynamic> json) {
    return SpaceTypeBreakdownItem(
      code: json['code']?.toString() ?? '',
      typeName: json['type_name']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color_hex']?.toString() ?? '#3B82F6',
    );
  }
}

/// Building-wise Utilization Matrix Row
class SpaceBuildingUtilization {
  final String buildingId;
  final String buildingName;
  final String buildingCode;
  final int totalRooms;
  final int bookedRooms;
  final double utilizationPct;

  const SpaceBuildingUtilization({
    required this.buildingId,
    required this.buildingName,
    required this.buildingCode,
    required this.totalRooms,
    required this.bookedRooms,
    required this.utilizationPct,
  });

  factory SpaceBuildingUtilization.fromJson(Map<String, dynamic> json) {
    return SpaceBuildingUtilization(
      buildingId: json['building_id']?.toString() ?? '',
      buildingName: json['building_name']?.toString() ?? '',
      buildingCode: json['building_code']?.toString() ?? '',
      totalRooms: json['total_rooms'] as int? ?? 0,
      bookedRooms: json['booked_rooms'] as int? ?? 0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Comprehensive Space Analytics & Reports Model
class SpaceAnalyticsReport {
  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int rejectedBookings;
  final double totalBookedHours;
  final double avgDurationMinutes;
  final double overallUtilizationPct;
  final String peakHourLabel;
  final String mostActiveRoom;
  final int activeSpacesCount;
  final int totalSpacesCount;

  final List<SpaceHourlyOccupancy> hourlyOccupancy;
  final List<SpaceDayOfWeekTraffic> dayOfWeekTraffic;
  final List<SpaceTypeBreakdownItem> spaceTypeBreakdown;
  final List<SpaceBuildingUtilization> buildingUtilization;

  const SpaceAnalyticsReport({
    this.totalBookings = 224,
    this.confirmedBookings = 190,
    this.pendingBookings = 20,
    this.rejectedBookings = 7,
    this.totalBookedHours = 353.0,
    this.avgDurationMinutes = 95.0,
    this.overallUtilizationPct = 72.8,
    this.peakHourLabel = '10:00 AM - 12:00 PM',
    this.mostActiveRoom = 'Audio-Visual Seminar Hall',
    this.activeSpacesCount = 34,
    this.totalSpacesCount = 150,
    this.hourlyOccupancy = const [],
    this.dayOfWeekTraffic = const [],
    this.spaceTypeBreakdown = const [],
    this.buildingUtilization = const [],
  });

  factory SpaceAnalyticsReport.fromJson(Map<String, dynamic> json) {
    final kpis = json['summary_kpis'] as Map<String, dynamic>? ?? {};

    return SpaceAnalyticsReport(
      totalBookings: kpis['total_bookings'] as int? ?? 224,
      confirmedBookings: kpis['confirmed_bookings'] as int? ?? 190,
      pendingBookings: kpis['pending_bookings'] as int? ?? 20,
      rejectedBookings: kpis['rejected_bookings'] as int? ?? 7,
      totalBookedHours: (kpis['total_booked_hours'] as num?)?.toDouble() ?? 353.0,
      avgDurationMinutes: (kpis['avg_duration_minutes'] as num?)?.toDouble() ?? 95.0,
      overallUtilizationPct: (kpis['overall_utilization_pct'] as num?)?.toDouble() ?? 72.8,
      peakHourLabel: kpis['peak_hour_label']?.toString() ?? '10:00 AM - 12:00 PM',
      mostActiveRoom: kpis['most_active_room']?.toString() ?? 'Audio-Visual Seminar Hall',
      activeSpacesCount: kpis['active_spaces_count'] as int? ?? 34,
      totalSpacesCount: kpis['total_spaces_count'] as int? ?? 150,
      hourlyOccupancy: (json['hourly_occupancy'] as List<dynamic>?)
              ?.map((e) => SpaceHourlyOccupancy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dayOfWeekTraffic: (json['day_of_week_traffic'] as List<dynamic>?)
              ?.map((e) => SpaceDayOfWeekTraffic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      spaceTypeBreakdown: (json['space_type_breakdown'] as List<dynamic>?)
              ?.map((e) => SpaceTypeBreakdownItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      buildingUtilization: (json['building_utilization'] as List<dynamic>?)
              ?.map((e) => SpaceBuildingUtilization.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
