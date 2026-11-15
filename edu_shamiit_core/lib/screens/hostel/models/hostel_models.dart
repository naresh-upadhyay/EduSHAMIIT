class HostelKPIs {
  final int totalBuildings;
  final int totalFloors;
  final int totalRooms;
  final int residentialRooms;
  final int totalBeds;
  final int availableBeds;
  final int occupiedBeds;
  final int reservedBeds;
  final int occupiedRooms;
  final int availableRooms;
  final double occupancyPercentage;
  final double availablePercentage;
  final int maintenanceRooms;
  final int equipmentFaults;
  final String academicYear;

  HostelKPIs({
    this.totalBuildings = 0,
    this.totalFloors = 0,
    this.totalRooms = 0,
    this.residentialRooms = 0,
    this.totalBeds = 0,
    this.availableBeds = 0,
    this.occupiedBeds = 0,
    this.reservedBeds = 0,
    this.occupiedRooms = 0,
    this.availableRooms = 0,
    this.occupancyPercentage = 0.0,
    this.availablePercentage = 0.0,
    this.maintenanceRooms = 0,
    this.equipmentFaults = 0,
    this.academicYear = '2024 - 2025',
  });

  factory HostelKPIs.fromJson(Map<String, dynamic> json) {
    return HostelKPIs(
      totalBuildings: json['total_buildings'] as int? ?? 0,
      totalFloors: json['total_floors'] as int? ?? 0,
      totalRooms: json['total_rooms'] as int? ?? 0,
      residentialRooms: json['residential_rooms'] as int? ?? 0,
      totalBeds: json['total_beds'] as int? ?? 0,
      availableBeds: json['available_beds'] as int? ?? 0,
      occupiedBeds: json['occupied_beds'] as int? ?? 0,
      reservedBeds: json['reserved_beds'] as int? ?? 0,
      occupiedRooms: json['occupied_rooms'] as int? ?? 0,
      availableRooms: json['available_rooms'] as int? ?? 0,
      occupancyPercentage: (json['occupancy_percentage'] as num?)?.toDouble() ?? 0.0,
      availablePercentage: (json['available_percentage'] as num?)?.toDouble() ?? 0.0,
      maintenanceRooms: json['maintenance_rooms'] as int? ?? 0,
      equipmentFaults: json['equipment_faults'] as int? ?? 0,
      academicYear: json['academic_year'] as String? ?? '2024 - 2025',
    );
  }
}

class HostelBuilding {
  final String id;
  final String code;
  final String name;
  final String hostelName;
  final String genderPolicy;
  final int floorsCount;
  final String status;
  final String? description;
  final List<HostelFloor> floors;

  HostelBuilding({
    required this.id,
    required this.code,
    required this.name,
    required this.hostelName,
    this.genderPolicy = 'BOYS',
    this.floorsCount = 1,
    this.status = 'OPERATIONAL',
    this.description,
    this.floors = const [],
  });

  factory HostelBuilding.fromJson(Map<String, dynamic> json) {
    final rawFloors = json['floors'] as List<dynamic>? ?? [];
    return HostelBuilding(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      hostelName: json['hostel_name'] as String? ?? json['name'] as String? ?? '',
      genderPolicy: json['gender_policy'] as String? ?? 'BOYS',
      floorsCount: json['floors_count'] as int? ?? 1,
      status: json['status'] as String? ?? 'OPERATIONAL',
      description: json['description'] as String?,
      floors: rawFloors.map((f) => HostelFloor.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

class HostelFloor {
  final String id;
  final String? buildingId;
  final int floorNumber;
  final String floorCode;
  final String floorName;
  final String? wing;
  final String status;
  final int roomsCount;
  final List<HostelTreeRoom> rooms;

  String get name => floorName;
  String get code => floorCode;

  HostelFloor({
    required this.id,
    this.buildingId,
    required this.floorNumber,
    required this.floorCode,
    required this.floorName,
    this.wing,
    this.status = 'OPERATIONAL',
    this.roomsCount = 0,
    this.rooms = const [],
  });

  factory HostelFloor.fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'] as List<dynamic>? ?? [];
    return HostelFloor(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      floorNumber: json['floor_number'] as int? ?? 0,
      floorCode: json['floor_code'] as String? ?? '',
      floorName: json['floor_name'] as String? ?? '',
      wing: json['wing'] as String?,
      status: json['status'] as String? ?? 'OPERATIONAL',
      roomsCount: json['rooms_count'] as int? ?? 0,
      rooms: rawRooms.map((r) => HostelTreeRoom.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

class HostelTreeRoom {
  final String id;
  final String roomNumber;
  final String roomCode;
  final String roomType;
  final bool isResidential;
  final String status;
  final int capacity;
  final int occupied;

  HostelTreeRoom({
    required this.id,
    required this.roomNumber,
    required this.roomCode,
    required this.roomType,
    this.isResidential = true,
    this.status = 'AVAILABLE',
    this.capacity = 1,
    this.occupied = 0,
  });

  factory HostelTreeRoom.fromJson(Map<String, dynamic> json) {
    return HostelTreeRoom(
      id: json['id'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      roomCode: json['room_code'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'Standard',
      isResidential: json['is_residential'] as bool? ?? true,
      status: json['status'] as String? ?? 'AVAILABLE',
      capacity: json['capacity'] as int? ?? 1,
      occupied: json['occupied'] as int? ?? 0,
    );
  }
}

class HostelRoomItem {
  final String id;
  final String buildingId;
  final String buildingName;
  final String floorId;
  final String floorName;
  final String roomNumber;
  final String roomCode;
  final String? roomName;
  final String roomType;
  final bool isResidential;
  final int? capacity;
  final int? occupied;
  final String capacityLabel;
  final String occupiedLabel;
  final String status;
  final String cleanlinessStatus;
  final String conditionStatus;
  final double roomSizeSqm;
  final double monthlyFee;
  final String genderRestriction;
  final int photosCount;
  final List<String> photos;
  final List<FacilitySummary> facilitiesSummary;

  final int? explicitAvailableBeds;

  List<FacilitySummary> get facilities => facilitiesSummary;

  int get availableBeds => explicitAvailableBeds ?? ((capacity ?? 0) - (occupied ?? 0));

  HostelRoomItem({
    required this.id,
    required this.buildingId,
    required this.buildingName,
    required this.floorId,
    required this.floorName,
    required this.roomNumber,
    required this.roomCode,
    this.roomName,
    required this.roomType,
    this.isResidential = true,
    this.capacity,
    this.occupied,
    this.explicitAvailableBeds,
    this.capacityLabel = '-',
    this.occupiedLabel = '-',
    this.status = 'AVAILABLE',
    this.cleanlinessStatus = 'CLEAN',
    this.conditionStatus = 'GOOD',
    this.roomSizeSqm = 18.0,
    this.monthlyFee = 6000.0,
    this.genderRestriction = 'BOYS',
    this.photosCount = 0,
    this.photos = const [],
    this.facilitiesSummary = const [],
  });

  factory HostelRoomItem.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    final rawFacilities = json['facilities_summary'] as List<dynamic>? ?? [];
    return HostelRoomItem(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      floorId: json['floor_id'] as String? ?? '',
      floorName: json['floor_name'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      roomCode: json['room_code'] as String? ?? '',
      roomName: json['room_name'] as String?,
      roomType: json['room_type'] as String? ?? 'Standard',
      isResidential: json['is_residential'] as bool? ?? true,
      capacity: json['capacity'] as int?,
      occupied: json['occupied'] as int?,
      explicitAvailableBeds: json['available_beds'] as int?,
      capacityLabel: json['capacity_label'] as String? ?? '-',
      occupiedLabel: json['occupied_label'] as String? ?? '-',
      status: json['status'] as String? ?? 'AVAILABLE',
      cleanlinessStatus: json['cleanliness_status'] as String? ?? 'CLEAN',
      conditionStatus: json['condition_status'] as String? ?? 'GOOD',
      roomSizeSqm: (json['room_size_sqm'] as num?)?.toDouble() ?? 0.0,
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      genderRestriction: json['gender_restriction'] as String? ?? 'COED',
      photosCount: json['photos_count'] as int? ?? rawPhotos.length,
      photos: rawPhotos.map((e) => e.toString()).toList(),
      facilitiesSummary: rawFacilities.map((f) => FacilitySummary.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

class FacilitySummary {
  final String name;
  final String status;
  final int quantity;

  FacilitySummary({
    required this.name,
    required this.status,
    this.quantity = 1,
  });

  factory FacilitySummary.fromJson(Map<String, dynamic> json) {
    return FacilitySummary(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'GOOD',
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

class HostelRoomDetail {
  final String id;
  final String roomNumber;
  final String roomCode;
  final String? roomName;
  final String buildingId;
  final String buildingName;
  final String hostelName;
  final String floorId;
  final String floorName;
  final String roomType;
  final bool isResidential;
  final int capacity;
  final int currentOccupancy;
  final double roomSizeSqm;
  final double monthlyFee;
  final String status;
  final String cleanlinessStatus;
  final String conditionStatus;
  final String genderRestriction;
  final bool attachedWashroom;
  final String? notes;
  final List<String> photos;
  final List<String> amenities;
  final List<HostelBed> beds;
  final List<HostelEquipment> facilities;
  final List<HostelAllocatedStudent> students;
  final List<HostelMaintenanceItem> maintenance;
  final List<HostelHistoryEvent> history;

  double get roomSizeSqM => roomSizeSqm;

  HostelRoomDetail({
    required this.id,
    required this.roomNumber,
    required this.roomCode,
    this.roomName,
    required this.buildingId,
    required this.buildingName,
    required this.hostelName,
    required this.floorId,
    required this.floorName,
    required this.roomType,
    this.isResidential = true,
    this.capacity = 1,
    this.currentOccupancy = 0,
    this.roomSizeSqm = 18.0,
    this.monthlyFee = 6000.0,
    this.status = 'AVAILABLE',
    this.cleanlinessStatus = 'CLEAN',
    this.conditionStatus = 'GOOD',
    this.genderRestriction = 'BOYS',
    this.attachedWashroom = true,
    this.notes,
    this.photos = const [],
    this.amenities = const [],
    this.beds = const [],
    this.facilities = const [],
    this.students = const [],
    this.maintenance = const [],
    this.history = const [],
  });

  factory HostelRoomDetail.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? [];
    final rawAmenities = json['amenities'] as List<dynamic>? ?? [];
    final rawBeds = json['beds'] as List<dynamic>? ?? [];
    final rawFacilities = json['facilities'] as List<dynamic>? ?? [];
    final rawStudents = json['students'] as List<dynamic>? ?? [];
    final rawMaintenance = json['maintenance'] as List<dynamic>? ?? [];
    final rawHistory = json['history'] as List<dynamic>? ?? [];

    return HostelRoomDetail(
      id: json['id'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      roomCode: json['room_code'] as String? ?? '',
      roomName: json['room_name'] as String?,
      buildingId: json['building_id'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      hostelName: json['hostel_name'] as String? ?? '',
      floorId: json['floor_id'] as String? ?? '',
      floorName: json['floor_name'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'Standard',
      isResidential: json['is_residential'] as bool? ?? true,
      capacity: json['capacity'] as int? ?? 1,
      currentOccupancy: json['current_occupancy'] as int? ?? 0,
      roomSizeSqm: (json['room_size_sqm'] as num?)?.toDouble() ?? 0.0,
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'AVAILABLE',
      cleanlinessStatus: json['cleanliness_status'] as String? ?? 'CLEAN',
      conditionStatus: json['condition_status'] as String? ?? 'GOOD',
      genderRestriction: json['gender_restriction'] as String? ?? 'COED',
      attachedWashroom: json['attached_washroom'] as bool? ?? true,
      notes: json['notes'] as String?,
      photos: rawPhotos.map((e) => e.toString()).toList(),
      amenities: rawAmenities.map((e) => e.toString()).toList(),
      beds: rawBeds.map((b) => HostelBed.fromJson(b as Map<String, dynamic>)).toList(),
      facilities: rawFacilities.map((f) => HostelEquipment.fromJson(f as Map<String, dynamic>)).toList(),
      students: rawStudents.map((s) => HostelAllocatedStudent.fromJson(s as Map<String, dynamic>)).toList(),
      maintenance: rawMaintenance.map((m) => HostelMaintenanceItem.fromJson(m as Map<String, dynamic>)).toList(),
      history: rawHistory.map((h) => HostelHistoryEvent.fromJson(h as Map<String, dynamic>)).toList(),
    );
  }
}

class HostelBed {
  final String id;
  final String bedCode;
  final String? bedNumber;
  final String bedType;
  final String condition;
  final String status;
  final double? monthlyFee;
  final Map<String, dynamic>? occupant;

  String get bedNumberOrCode => bedNumber ?? bedCode;
  double? get monthlyPrice => monthlyFee;
  bool get isAvailable => status.toUpperCase() == 'AVAILABLE' && occupant == null;

  HostelBed({
    required this.id,
    required this.bedCode,
    this.bedNumber,
    this.bedType = 'Single',
    this.condition = 'GOOD',
    this.status = 'AVAILABLE',
    this.monthlyFee,
    this.occupant,
  });

  factory HostelBed.fromJson(Map<String, dynamic> json) {
    return HostelBed(
      id: json['id'] as String? ?? '',
      bedCode: json['bed_code'] as String? ?? '',
      bedNumber: json['bed_number'] as String? ?? json['bed_code'] as String? ?? '',
      bedType: json['bed_type'] as String? ?? 'Single',
      condition: json['condition'] as String? ?? 'GOOD',
      status: json['status'] as String? ?? 'AVAILABLE',
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble(),
      occupant: json['occupant'] as Map<String, dynamic>?,
    );
  }
}

class HostelEquipment {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final String status;
  final String? assetTag;
  final bool isCritical;
  final String? notes;

  String get condition => status;

  HostelEquipment({
    required this.id,
    required this.name,
    this.category = 'FURNITURE',
    this.quantity = 1,
    this.status = 'GOOD',
    this.assetTag,
    this.isCritical = false,
    this.notes,
  });

  factory HostelEquipment.fromJson(Map<String, dynamic> json) {
    return HostelEquipment(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'FURNITURE',
      quantity: json['quantity'] as int? ?? 1,
      status: json['status'] as String? ?? 'GOOD',
      assetTag: json['asset_tag'] as String?,
      isCritical: json['is_critical'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

typedef HostelStudentOccupant = HostelAllocatedStudent;

class HostelAllocatedStudent {
  final String allocationId;
  final String studentId;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String rollNumber;
  final String bedCode;
  final String status;
  final String? checkInDate;
  final String feeStatus;
  final double monthlyFee;

  String get studentName => fullName;
  String get admissionNumber => rollNumber;
  String get bedNumber => bedCode;

  HostelAllocatedStudent({
    required this.allocationId,
    required this.studentId,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.rollNumber,
    required this.bedCode,
    required this.status,
    this.checkInDate,
    required this.feeStatus,
    required this.monthlyFee,
  });

  factory HostelAllocatedStudent.fromJson(Map<String, dynamic> json) {
    return HostelAllocatedStudent(
      allocationId: json['allocation_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      rollNumber: json['roll_number'] as String? ?? '',
      bedCode: json['bed_code'] as String? ?? '',
      status: json['status'] as String? ?? 'CHECKED_IN',
      checkInDate: json['check_in_date'] as String?,
      feeStatus: json['fee_status'] as String? ?? 'PAID',
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 6000.0,
    );
  }

  HostelStudentRosterItem toRosterItem({
    required String hostelId,
    required String buildingName,
    required String roomId,
    required String roomNumber,
    String? floorId,
  }) {
    return HostelStudentRosterItem(
      id: allocationId,
      admissionId: allocationId,
      allocationId: allocationId,
      studentId: studentId,
      photoUrl: avatarUrl,
      studentName: fullName,
      guardianName: '',
      guardianRelation: '',
      rollNo: rollNumber,
      className: '',
      hostelId: hostelId,
      hostelName: buildingName,
      buildingId: hostelId,
      floorId: floorId,
      roomId: roomId,
      roomNumber: roomNumber,
      bedId: null,
      bedNo: bedCode,
      status: status,
      rawStatus: status,
      feeStatus: feeStatus,
      admissionDate: checkInDate ?? '',
      gender: '',
      bloodGroup: '',
      emergencyContact: '',
      address: '',
      feePlan: 'Monthly',
      hostelType: 'Boys',
      initialPaymentAmount: 0.0,
    );
  }
}

class HostelMaintenanceItem {
  final String id;
  final String ticketNumber;
  final String title;
  final String priority;
  final String status;
  final bool blocksAllocation;
  final String? createdAt;
  final String? slaDueDate;

  HostelMaintenanceItem({
    required this.id,
    required this.ticketNumber,
    required this.title,
    required this.priority,
    required this.status,
    this.blocksAllocation = false,
    this.createdAt,
    this.slaDueDate,
  });

  factory HostelMaintenanceItem.fromJson(Map<String, dynamic> json) {
    return HostelMaintenanceItem(
      id: json['id'] as String? ?? '',
      ticketNumber: json['ticket_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      priority: json['priority'] as String? ?? 'MEDIUM',
      status: json['status'] as String? ?? 'OPEN',
      blocksAllocation: json['blocks_allocation'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      slaDueDate: json['sla_due_date'] as String?,
    );
  }
}

class HostelHistoryEvent {
  final String id;
  final String eventType;
  final String studentName;
  final String? reason;
  final String? createdAt;
  final String? performedBy;

  HostelHistoryEvent({
    required this.id,
    required this.eventType,
    required this.studentName,
    this.reason,
    this.createdAt,
    this.performedBy,
  });

  factory HostelHistoryEvent.fromJson(Map<String, dynamic> json) {
    return HostelHistoryEvent(
      id: json['id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      reason: json['reason'] as String?,
      createdAt: json['created_at'] as String?,
      performedBy: json['performed_by'] as String?,
    );
  }
}

class HostelFilterOptions {
  final List<Map<String, dynamic>> hostels;
  final List<Map<String, dynamic>> floors;
  final List<String> roomTypes;
  final List<String> statuses;

  HostelFilterOptions({
    this.hostels = const [],
    this.floors = const [],
    this.roomTypes = const [],
    this.statuses = const [],
  });

  factory HostelFilterOptions.fromJson(Map<String, dynamic> json) {
    final rawHostels = json['hostels'] as List<dynamic>? ?? [];
    final rawFloors = json['floors'] as List<dynamic>? ?? [];
    final rawTypes = json['room_types'] as List<dynamic>? ?? [];
    final rawStatuses = json['statuses'] as List<dynamic>? ?? [];

    return HostelFilterOptions(
      hostels: rawHostels.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      floors: rawFloors.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      roomTypes: rawTypes.map((e) => e.toString()).toList(),
      statuses: rawStatuses.map((e) => e.toString()).toList(),
    );
  }
}

class HostelStudentsKPIs {
  final int totalStudents;
  final int hostelsCount;
  final int boysCount;
  final int boysPct;
  final int girlsCount;
  final int girlsPct;
  final int newAdmissionsMonth;
  final int pendingDuesCount;
  final int currentlyOutCount;
  final String academicYear;

  HostelStudentsKPIs({
    this.totalStudents = 356,
    this.hostelsCount = 4,
    this.boysCount = 198,
    this.boysPct = 56,
    this.girlsCount = 158,
    this.girlsPct = 44,
    this.newAdmissionsMonth = 24,
    this.pendingDuesCount = 12,
    this.currentlyOutCount = 8,
    this.academicYear = '2024 - 2025',
  });

  factory HostelStudentsKPIs.fromJson(Map<String, dynamic> json) {
    return HostelStudentsKPIs(
      totalStudents: json['total_students'] as int? ?? 0,
      hostelsCount: json['hostels_count'] as int? ?? 4,
      boysCount: json['boys_count'] as int? ?? 0,
      boysPct: json['boys_pct'] as int? ?? 0,
      girlsCount: json['girls_count'] as int? ?? 0,
      girlsPct: json['girls_pct'] as int? ?? 0,
      newAdmissionsMonth: json['new_admissions_month'] as int? ?? 0,
      pendingDuesCount: json['pending_dues_count'] as int? ?? 0,
      currentlyOutCount: json['currently_out_count'] as int? ?? 0,
      academicYear: json['academic_year'] as String? ?? '2024 - 2025',
    );
  }
}

class HostelStudentRosterItem {
  final String id;
  final String admissionId;
  final String? allocationId;
  final String studentId;
  final String? photoUrl;
  final String studentName;
  final String guardianName;
  final String guardianRelation;
  final String rollNo;
  final String className;
  final String? hostelId;
  final String hostelName;
  final String? buildingId;
  final String? floorId;
  final String? roomId;
  final String roomNumber;
  final String? bedId;
  final String bedNo;
  final String status;
  final String rawStatus;
  final String feeStatus;
  final String admissionDate;
  final String gender;
  final String bloodGroup;
  final String emergencyContact;
  final String address;
  final String feePlan;
  final String hostelType;
  final double initialPaymentAmount;

  HostelStudentRosterItem({
    required this.id,
    required this.admissionId,
    this.allocationId,
    required this.studentId,
    this.photoUrl,
    required this.studentName,
    this.guardianName = '',
    this.guardianRelation = '',
    required this.rollNo,
    required this.className,
    this.hostelId,
    required this.hostelName,
    this.buildingId,
    this.floorId,
    this.roomId,
    required this.roomNumber,
    this.bedId,
    required this.bedNo,
    required this.status,
    required this.rawStatus,
    required this.feeStatus,
    this.admissionDate = '',
    this.gender = 'Male',
    this.bloodGroup = 'B+',
    this.emergencyContact = '',
    this.address = '',
    this.feePlan = 'Monthly',
    this.hostelType = 'AC Room',
    this.initialPaymentAmount = 0.0,
  });

  factory HostelStudentRosterItem.fromJson(Map<String, dynamic> json) {
    return HostelStudentRosterItem(
      id: json['id'] as String? ?? json['admission_id'] as String? ?? '',
      admissionId: json['admission_id'] as String? ?? json['id'] as String? ?? '',
      allocationId: json['allocation_id'] as String?,
      studentId: json['student_id'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      studentName: json['student_name'] as String? ?? '',
      guardianName: json['guardian_name'] as String? ?? '',
      guardianRelation: json['guardian_relation'] as String? ?? '',
      rollNo: json['roll_no'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      hostelId: json['hostel_id'] as String?,
      hostelName: json['hostel_name'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      floorId: json['floor_id'] as String?,
      roomId: json['room_id'] as String?,
      roomNumber: json['room_number'] as String? ?? '-',
      bedId: json['bed_id'] as String?,
      bedNo: json['bed_no'] as String? ?? '1',
      status: json['status'] as String? ?? 'Active',
      rawStatus: json['raw_status'] as String? ?? 'ACTIVE',
      feeStatus: json['fee_status'] as String? ?? 'Paid',
      admissionDate: json['admission_date'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Male',
      bloodGroup: json['blood_group'] as String? ?? 'B+',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      address: json['address'] as String? ?? '',
      feePlan: json['fee_plan'] as String? ?? 'Monthly',
      hostelType: json['hostel_type'] as String? ?? 'AC Room',
      initialPaymentAmount: (json['initial_payment_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HostelStudentRosterPagination {
  final int page;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;

  HostelStudentRosterPagination({
    this.page = 1,
    this.pageSize = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.hasPrev = false,
    this.hasNext = false,
  });

  factory HostelStudentRosterPagination.fromJson(Map<String, dynamic> json) {
    final total = json['total_records'] as int? ??
        json['total_count'] as int? ??
        json['total'] as int? ??
        0;
    final page = json['page'] as int? ?? 1;
    final pageSize = json['page_size'] as int? ?? 10;
    final totalPages = json['total_pages'] as int? ?? (total > 0 ? (total / pageSize).ceil() : 1);
    final hasPrev = json['has_prev'] as bool? ?? (page > 1);
    final hasNext = json['has_next'] as bool? ?? json['hasNext'] as bool? ?? (page < totalPages);

    return HostelStudentRosterPagination(
      page: page,
      pageSize: pageSize,
      totalRecords: total,
      totalPages: totalPages,
      hasPrev: hasPrev,
      hasNext: hasNext,
    );
  }
}

class HostelStudentActivity {
  final String id;
  final String activityType;
  final String title;
  final String subtext;
  final String badgeColor;
  final String performedBy;
  final String timestamp;

  HostelStudentActivity({
    required this.id,
    required this.activityType,
    required this.title,
    required this.subtext,
    this.badgeColor = 'blue',
    this.performedBy = '',
    this.timestamp = '',
  });

  factory HostelStudentActivity.fromJson(Map<String, dynamic> json) {
    return HostelStudentActivity(
      id: json['id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtext: json['subtext'] as String? ?? '',
      badgeColor: json['badge_color'] as String? ?? 'blue',
      performedBy: json['performed_by'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

class HostelStudentDocument {
  final String id;
  final String documentName;
  final String documentType;
  final String fileUrl;
  final int fileSizeBytes;
  final String mimeType;
  final String verificationStatus;
  final String createdAt;
  final String formattedDate;

  const HostelStudentDocument({
    required this.id,
    required this.documentName,
    required this.documentType,
    required this.fileUrl,
    this.fileSizeBytes = 0,
    this.mimeType = 'application/pdf',
    this.verificationStatus = 'VERIFIED',
    this.createdAt = '',
    this.formattedDate = '',
  });

  String get formattedSize {
    if (fileSizeBytes <= 0) return '1.2 MB';
    if (fileSizeBytes >= 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  String get fileSizeFormatted => formattedSize;

  String get extensionBadge {
    final lowerName = documentName.toLowerCase();
    final lowerUrl = fileUrl.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    if (lowerName.endsWith('.pdf') || lowerUrl.contains('.pdf') || lowerMime.contains('pdf')) return 'PDF';
    if (lowerName.endsWith('.png') || lowerUrl.contains('.png') || lowerMime.contains('png')) return 'PNG';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || lowerMime.contains('jpeg') || lowerMime.contains('jpg')) return 'JPG';
    if (lowerName.endsWith('.webp') || lowerUrl.contains('.webp') || lowerMime.contains('webp')) return 'WEBP';
    if (lowerName.endsWith('.gif') || lowerUrl.contains('.gif') || lowerMime.contains('gif')) return 'GIF';
    if (lowerName.endsWith('.docx') || lowerUrl.contains('.docx') || lowerMime.contains('wordprocessingml')) return 'DOCX';
    if (lowerName.endsWith('.doc') || lowerUrl.contains('.doc') || lowerMime.contains('msword')) return 'DOC';
    if (lowerName.endsWith('.xlsx') || lowerUrl.contains('.xlsx') || lowerMime.contains('spreadsheetml')) return 'XLSX';
    if (lowerName.endsWith('.xls') || lowerUrl.contains('.xls') || lowerMime.contains('ms-excel')) return 'XLS';
    if (lowerName.endsWith('.csv') || lowerUrl.contains('.csv') || lowerMime.contains('csv')) return 'CSV';
    if (lowerName.endsWith('.txt') || lowerUrl.contains('.txt') || lowerMime.contains('text/plain')) return 'TXT';
    if (lowerName.endsWith('.ppt') || lowerName.endsWith('.pptx') || lowerMime.contains('presentation')) return 'PPT';

    if (lowerMime.isNotEmpty && !lowerMime.contains('octet-stream')) {
      final part = lowerMime.split('/').last.split('+').first.toUpperCase();
      if (part.isNotEmpty && part.length <= 5) return part;
    }
    return 'PDF';
  }

  String get fileExtension => extensionBadge;

  factory HostelStudentDocument.fromJson(Map<String, dynamic> json) {
    return HostelStudentDocument(
      id: json['id'] as String? ?? '',
      documentName: json['document_name'] as String? ?? json['name'] as String? ?? 'Document',
      documentType: json['document_type'] as String? ?? json['type'] as String? ?? 'Other',
      fileUrl: json['file_url'] as String? ?? json['url'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? (json['size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/pdf',
      verificationStatus: json['verification_status'] as String? ?? json['status'] as String? ?? 'VERIFIED',
      createdAt: json['created_at'] as String? ?? '',
      formattedDate: json['formatted_date'] as String? ?? '',
    );
  }
}

class HostelStudentLeaveHistoryItem {
  final String id;
  final String leaveType;
  final String requestSubtype;
  final String startDate;
  final String endDate;
  final String status;
  final String reason;
  final String destination;
  final String passNumber;
  final String createdAt;

  const HostelStudentLeaveHistoryItem({
    required this.id,
    required this.leaveType,
    required this.requestSubtype,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.reason,
    this.destination = '',
    this.passNumber = '',
    this.createdAt = '',
  });

  factory HostelStudentLeaveHistoryItem.fromJson(Map<String, dynamic> json) {
    return HostelStudentLeaveHistoryItem(
      id: json['id'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? 'LEAVE',
      requestSubtype: json['request_subtype'] as String? ?? json['leave_type'] as String? ?? 'Outing',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      reason: json['reason'] as String? ?? 'Personal',
      destination: json['destination'] as String? ?? '',
      passNumber: json['pass_number'] as String? ?? json['request_number'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class HostelStudentDetail360 {
  final String admissionId;
  final String? allocationId;
  final String studentId;
  final String studentName;

  String get id => studentId;
  final String? avatarUrl;
  final String status;
  final String admissionStatus;
  final String rollNo;
  final String className;
  final String? hostelId;
  final String hostelName;
  final String? buildingId;
  final String? roomId;
  final String roomNumber;
  final String? bedId;
  final String bedNo;
  final String admissionDate;
  final String roomAndBed;
  final String hostelType;
  final String feePlan;
  final String bloodGroup;
  final String emergencyContact;
  final String emergencyContactLabel;
  final String address;
  final String email;
  final String phone;
  final String gender;
  final String fatherName;
  final String motherName;
  final String guardianRelation;
  final Map<String, dynamic> feeSummary;
  final double initialPaymentAmount;
  final List<HostelStudentActivity> activities;
  final List<HostelStudentDocument> documents;
  final List<HostelStudentLeaveHistoryItem> leaves;

  String get admissionNumber => rollNo.isNotEmpty ? rollNo : admissionId;
  String get bedNumber => bedNo;
  String get guardianName => fatherName.isNotEmpty ? fatherName : (motherName.isNotEmpty ? motherName : 'Guardian');
  String get wardenContact => emergencyContact.isNotEmpty ? emergencyContact : '+91 98765 43210';

  HostelStudentDetail360({
    required this.admissionId,
    this.allocationId,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.status,
    required this.admissionStatus,
    required this.rollNo,
    required this.className,
    this.hostelId,
    required this.hostelName,
    this.buildingId,
    this.roomId,
    required this.roomNumber,
    this.bedId,
    required this.bedNo,
    required this.admissionDate,
    required this.roomAndBed,
    required this.hostelType,
    required this.feePlan,
    required this.bloodGroup,
    required this.emergencyContact,
    required this.emergencyContactLabel,
    required this.address,
    this.email = '',
    this.phone = '',
    this.gender = 'Male',
    this.fatherName = '',
    this.motherName = '',
    this.guardianRelation = '',
    this.feeSummary = const {},
    this.initialPaymentAmount = 0.0,
    this.activities = const [],
    this.documents = const [],
    this.leaves = const [],
  });

  factory HostelStudentDetail360.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'] as List<dynamic>? ?? [];
    final rawDocs = json['documents'] as List<dynamic>? ?? [];
    final rawLeaves = json['leaves'] as List<dynamic>? ?? [];

    return HostelStudentDetail360(
      admissionId: json['admission_id'] as String? ?? '',
      allocationId: json['allocation_id'] as String?,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'Active',
      admissionStatus: json['admission_status'] as String? ?? 'ACTIVE',
      rollNo: json['roll_no'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      hostelId: json['hostel_id'] as String?,
      hostelName: json['hostel_name'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      roomId: json['room_id'] as String?,
      roomNumber: json['room_number'] as String? ?? '-',
      bedId: json['bed_id'] as String?,
      bedNo: json['bed_no'] as String? ?? '1',
      admissionDate: json['admission_date'] as String? ?? '',
      roomAndBed: json['room_and_bed'] as String? ?? '-',
      hostelType: json['hostel_type'] as String? ?? 'AC Room',
      feePlan: json['fee_plan'] as String? ?? 'Monthly',
      bloodGroup: json['blood_group'] as String? ?? 'B+',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      emergencyContactLabel: json['emergency_contact_label'] as String? ?? '',
      address: json['address'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Male',
      fatherName: json['father_name'] as String? ?? '',
      motherName: json['mother_name'] as String? ?? '',
      guardianRelation: json['guardian_relation'] as String? ?? '',
      feeSummary: json['fee_summary'] != null ? Map<String, dynamic>.from(json['fee_summary'] as Map) : {},
      initialPaymentAmount: (json['initial_payment_amount'] as num?)?.toDouble() ??
          ((json['fee_summary'] != null ? (json['fee_summary'] as Map)['initial_payment_amount'] : null) as num?)?.toDouble() ??
          0.0,
      activities: rawActivities.map((a) => HostelStudentActivity.fromJson(a as Map<String, dynamic>)).toList(),
      documents: rawDocs.map((d) => HostelStudentDocument.fromJson(d as Map<String, dynamic>)).toList(),
      leaves: rawLeaves.map((l) => HostelStudentLeaveHistoryItem.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }

  HostelStudentDetail360 copyWith({
    String? admissionId,
    String? allocationId,
    String? studentId,
    String? studentName,
    String? avatarUrl,
    String? status,
    String? admissionStatus,
    String? rollNo,
    String? className,
    String? hostelId,
    String? hostelName,
    String? buildingId,
    String? roomId,
    String? roomNumber,
    String? bedId,
    String? bedNo,
    String? admissionDate,
    String? roomAndBed,
    String? hostelType,
    String? feePlan,
    String? bloodGroup,
    String? emergencyContact,
    String? emergencyContactLabel,
    String? address,
    String? email,
    String? phone,
    String? gender,
    String? fatherName,
    String? motherName,
    String? guardianRelation,
    Map<String, dynamic>? feeSummary,
    double? initialPaymentAmount,
    List<HostelStudentActivity>? activities,
    List<HostelStudentDocument>? documents,
    List<HostelStudentLeaveHistoryItem>? leaves,
  }) {
    return HostelStudentDetail360(
      admissionId: admissionId ?? this.admissionId,
      allocationId: allocationId ?? this.allocationId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      admissionStatus: admissionStatus ?? this.admissionStatus,
      rollNo: rollNo ?? this.rollNo,
      className: className ?? this.className,
      hostelId: hostelId ?? this.hostelId,
      hostelName: hostelName ?? this.hostelName,
      buildingId: buildingId ?? this.buildingId,
      roomId: roomId ?? this.roomId,
      roomNumber: roomNumber ?? this.roomNumber,
      bedId: bedId ?? this.bedId,
      bedNo: bedNo ?? this.bedNo,
      admissionDate: admissionDate ?? this.admissionDate,
      roomAndBed: roomAndBed ?? this.roomAndBed,
      hostelType: hostelType ?? this.hostelType,
      feePlan: feePlan ?? this.feePlan,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContactLabel: emergencyContactLabel ?? this.emergencyContactLabel,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      guardianRelation: guardianRelation ?? this.guardianRelation,
      feeSummary: feeSummary ?? this.feeSummary,
      initialPaymentAmount: initialPaymentAmount ?? this.initialPaymentAmount,
      activities: activities ?? this.activities,
      documents: documents ?? this.documents,
      leaves: leaves ?? this.leaves,
    );
  }
}

class EligibleStudentItem {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? gender;
  final String? avatarUrl;
  final String? rollNumber;
  final String? className;
  final String? fatherName;
  final String? bloodGroup;
  final String? address;

  EligibleStudentItem({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.gender,
    this.avatarUrl,
    this.rollNumber,
    this.className,
    this.fatherName,
    this.bloodGroup,
    this.address,
  });

  factory EligibleStudentItem.fromJson(Map<String, dynamic> json) {
    return EligibleStudentItem(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rollNumber: json['roll_number'] as String?,
      className: json['class_name'] as String?,
      fatherName: json['father_name'] as String?,
      bloodGroup: json['blood_group'] as String?,
      address: json['address'] as String?,
    );
  }
}

// ============================================================================
// HOSTEL STAFF MANAGEMENT MODELS
// ============================================================================

class HostelStaffKPIs {
  final int totalStaff;
  final int wardensCount;
  final int wardensBoys;
  final int wardensGirls;
  final int caretakersCount;
  final int supportCount;
  final int onLeaveCount;
  final int pendingAssignmentsCount;
  final String academicYear;

  HostelStaffKPIs({
    this.totalStaff = 0,
    this.wardensCount = 0,
    this.wardensBoys = 0,
    this.wardensGirls = 0,
    this.caretakersCount = 0,
    this.supportCount = 0,
    this.onLeaveCount = 0,
    this.pendingAssignmentsCount = 0,
    this.academicYear = '2026 - 2027',
  });

  factory HostelStaffKPIs.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    return HostelStaffKPIs(
      totalStaff: (data['total_staff'] as num?)?.toInt() ?? 0,
      wardensCount: (data['wardens_count'] as num?)?.toInt() ?? 0,
      wardensBoys: (data['wardens_boys'] as num?)?.toInt() ?? 0,
      wardensGirls: (data['wardens_girls'] as num?)?.toInt() ?? 0,
      caretakersCount: (data['caretakers_count'] as num?)?.toInt() ?? 0,
      supportCount: (data['support_count'] as num?)?.toInt() ?? 0,
      onLeaveCount: (data['on_leave_count'] as num?)?.toInt() ?? 0,
      pendingAssignmentsCount: ((data['pending_assignments_count'] ?? data['pending_count']) as num?)?.toInt() ?? 0,
      academicYear: data['academic_year'] as String? ?? '2026 - 2027',
    );
  }
}

class HostelStaffRosterItem {
  final String assignmentId;
  final String profileId;
  final int rowNum;
  final String name;
  final String employeeId;
  final String? photoUrl;
  final String role;
  final String? hostelId;
  final String hostelName;
  final String hostelCode;
  final String assignedArea;
  final String contact;
  final String email;
  final String status;
  final String shiftTimings;
  final String joiningDate;

  HostelStaffRosterItem({
    required this.assignmentId,
    required this.profileId,
    required this.rowNum,
    required this.name,
    this.employeeId = '',
    this.photoUrl,
    required this.role,
    this.hostelId,
    required this.hostelName,
    this.hostelCode = '',
    required this.assignedArea,
    required this.contact,
    this.email = '',
    required this.status,
    this.shiftTimings = '',
    this.joiningDate = '',
  });

  factory HostelStaffRosterItem.fromJson(Map<String, dynamic> json) {
    return HostelStaffRosterItem(
      assignmentId: json['assignment_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      rowNum: (json['row_num'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      role: json['role'] as String? ?? 'Staff',
      hostelId: json['hostel_id'] as String?,
      hostelName: json['hostel_name'] as String? ?? '',
      hostelCode: json['hostel_code'] as String? ?? '',
      assignedArea: json['assigned_area'] as String? ?? 'Overall',
      contact: json['contact'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      shiftTimings: json['shift_timings'] as String? ?? '',
      joiningDate: json['joining_date'] as String? ?? '',
    );
  }
}

class HostelStaffRosterPagination {
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;

  int get page => currentPage;

  HostelStaffRosterPagination({
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.hasPrev = false,
    this.hasNext = false,
  });

  factory HostelStaffRosterPagination.fromJson(Map<String, dynamic> json) {
    return HostelStaffRosterPagination(
      currentPage: json['current_page'] as int? ?? json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalRecords: json['total_records'] as int? ?? 0,
      totalPages: json['total_pages'] as int? ?? 1,
      hasPrev: json['has_prev'] as bool? ?? false,
      hasNext: json['has_next'] as bool? ?? false,
    );
  }
}

class HostelStaffArea {
  final String id;
  final String areaName;
  final String areaType;
  final String badgeLabel;
  final bool isPrimary;

  HostelStaffArea({
    required this.id,
    required this.areaName,
    this.areaType = 'SUPERVISION',
    this.badgeLabel = 'Assigned',
    this.isPrimary = false,
  });

  factory HostelStaffArea.fromJson(Map<String, dynamic> json) {
    return HostelStaffArea(
      id: json['id'] as String? ?? '',
      areaName: json['area_name'] as String? ?? '',
      areaType: json['area_type'] as String? ?? 'SUPERVISION',
      badgeLabel: json['badge_label'] as String? ?? 'Assigned',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class HostelStaffActivity {
  final String id;
  final String activityType;
  final String title;
  final String description;
  final String badgeColor;
  final String? performedByName;
  final String createdAt;

  HostelStaffActivity({
    required this.id,
    required this.activityType,
    required this.title,
    this.description = '',
    this.badgeColor = 'blue',
    this.performedByName,
    this.createdAt = '',
  });

  factory HostelStaffActivity.fromJson(Map<String, dynamic> json) {
    return HostelStaffActivity(
      id: json['id'] as String? ?? '',
      activityType: json['activity_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      badgeColor: json['badge_color'] as String? ?? 'blue',
      performedByName: json['performed_by_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class HostelStaffDocument {
  final String id;
  final String documentName;
  final String documentType;
  final String fileUrl;
  final int fileSizeBytes;
  final String mimeType;
  final String verificationStatus;
  final String? verifiedByName;
  final String? verifiedAt;
  final String? notes;
  final String createdAt;
  final String formattedDate;

  const HostelStaffDocument({
    required this.id,
    required this.documentName,
    required this.documentType,
    required this.fileUrl,
    this.fileSizeBytes = 0,
    this.mimeType = 'application/pdf',
    this.verificationStatus = 'VERIFIED',
    this.verifiedByName,
    this.verifiedAt,
    this.notes,
    this.createdAt = '',
    this.formattedDate = '',
  });

  String get fileExtension {
    final lowerName = documentName.toLowerCase();
    final lowerUrl = fileUrl.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    if (lowerName.endsWith('.pdf') || lowerUrl.contains('.pdf') || lowerMime.contains('pdf')) return 'PDF';
    if (lowerName.endsWith('.png') || lowerUrl.contains('.png') || lowerMime.contains('png')) return 'PNG';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg') || lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || lowerMime.contains('jpeg') || lowerMime.contains('jpg')) return 'JPG';
    if (lowerName.endsWith('.webp') || lowerUrl.contains('.webp') || lowerMime.contains('webp')) return 'WEBP';
    if (lowerName.endsWith('.gif') || lowerUrl.contains('.gif') || lowerMime.contains('gif')) return 'GIF';
    if (lowerName.endsWith('.docx') || lowerUrl.contains('.docx') || lowerMime.contains('wordprocessingml')) return 'DOCX';
    if (lowerName.endsWith('.doc') || lowerUrl.contains('.doc') || lowerMime.contains('msword')) return 'DOC';
    if (lowerName.endsWith('.xlsx') || lowerUrl.contains('.xlsx') || lowerMime.contains('spreadsheetml')) return 'XLSX';
    if (lowerName.endsWith('.xls') || lowerUrl.contains('.xls') || lowerMime.contains('ms-excel')) return 'XLS';
    if (lowerName.endsWith('.csv') || lowerUrl.contains('.csv') || lowerMime.contains('csv')) return 'CSV';
    if (lowerName.endsWith('.txt') || lowerUrl.contains('.txt') || lowerMime.contains('text/plain')) return 'TXT';
    if (lowerName.endsWith('.ppt') || lowerName.endsWith('.pptx') || lowerMime.contains('presentation')) return 'PPT';

    if (lowerMime.isNotEmpty && !lowerMime.contains('octet-stream')) {
      final part = lowerMime.split('/').last.split('+').first.toUpperCase();
      if (part.isNotEmpty && part.length <= 5) return part;
    }
    return 'PDF';
  }

  String get fileSizeFormatted {
    if (fileSizeBytes <= 0) return '1.2 MB';
    if (fileSizeBytes >= 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  factory HostelStaffDocument.fromJson(Map<String, dynamic> json) {
    return HostelStaffDocument(
      id: json['id'] as String? ?? '',
      documentName: json['document_name'] as String? ?? 'Document',
      documentType: json['document_type'] as String? ?? 'Other',
      fileUrl: json['file_url'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/pdf',
      verificationStatus: json['verification_status'] as String? ?? 'VERIFIED',
      verifiedByName: json['verified_by_name'] as String?,
      verifiedAt: json['verified_at'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      formattedDate: json['formatted_date'] as String? ?? json['created_at'] as String? ?? '',
    );
  }
}

class HostelStaffLeave {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String rawStartDate;
  final String rawEndDate;
  final double daysCount;
  final String reason;
  final String status;
  final String substituteStaffName;
  final String emergencyContact;
  final String? approvedByName;
  final String createdAt;

  const HostelStaffLeave({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.rawStartDate = '',
    this.rawEndDate = '',
    this.daysCount = 1.0,
    required this.reason,
    required this.status,
    this.substituteStaffName = 'Backup Warden',
    this.emergencyContact = '',
    this.approvedByName,
    this.createdAt = '',
  });

  factory HostelStaffLeave.fromJson(Map<String, dynamic> json) {
    return HostelStaffLeave(
      id: json['id'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? 'Casual Leave',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      rawStartDate: json['raw_start_date'] as String? ?? json['start_date'] as String? ?? '',
      rawEndDate: json['raw_end_date'] as String? ?? json['end_date'] as String? ?? '',
      daysCount: (json['days_count'] as num?)?.toDouble() ?? 1.0,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'APPROVED',
      substituteStaffName: json['substitute_staff_name'] as String? ?? 'Backup Warden',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      approvedByName: json['approved_by_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class HostelStaffDetail360 {
  final String assignmentId;
  final String profileId;
  final String fullName;
  final String employeeId;
  final String? avatarUrl;
  final String role;
  final String? hostelId;
  final String hostelName;
  final String contact;
  final String email;
  final String address;
  final String emergencyContact;
  final String shiftTimings;
  final String reportingTo;
  final String status;
  final String joiningDate;
  final List<HostelStaffArea> assignedAreas;
  final List<HostelStaffActivity> activities;
  final List<HostelStaffDocument> documents;
  final List<HostelStaffLeave> leaves;
  final double monthlyLeavesTaken;
  final String activeSubstituteWarden;
  final String activeLeaveReason;
  final String? responsibilities;
  final String? remarks;

  HostelStaffDetail360({
    required this.assignmentId,
    required this.profileId,
    required this.fullName,
    this.employeeId = 'HS001',
    this.avatarUrl,
    required this.role,
    this.hostelId,
    required this.hostelName,
    required this.contact,
    required this.email,
    required this.address,
    required this.emergencyContact,
    required this.shiftTimings,
    required this.reportingTo,
    required this.status,
    required this.joiningDate,
    this.assignedAreas = const [],
    this.activities = const [],
    this.documents = const [],
    this.leaves = const [],
    this.monthlyLeavesTaken = 0.0,
    this.activeSubstituteWarden = 'Backup Warden',
    this.activeLeaveReason = '',
    this.responsibilities,
    this.remarks,
  });

  factory HostelStaffDetail360.fromJson(Map<String, dynamic> json) {
    final rawAreas = json['assigned_areas'] as List<dynamic>? ?? [];
    final rawActivities = json['activities'] as List<dynamic>? ?? [];
    final rawDocs = json['documents'] as List<dynamic>? ?? [];
    final rawLeaves = json['leaves'] as List<dynamic>? ?? [];

    return HostelStaffDetail360(
      assignmentId: json['assignment_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? 'HS001',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'Warden',
      hostelId: json['hostel_id'] as String?,
      hostelName: json['hostel_name'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      emergencyContact: json['emergency_contact'] as String? ?? '',
      shiftTimings: json['shift_timings'] as String? ?? '',
      reportingTo: json['reporting_to'] as String? ?? 'Hostel Administrator',
      status: json['status'] as String? ?? 'Active',
      joiningDate: json['joining_date'] as String? ?? '',
      assignedAreas: rawAreas.map((a) => HostelStaffArea.fromJson(a as Map<String, dynamic>)).toList(),
      activities: rawActivities.map((a) => HostelStaffActivity.fromJson(a as Map<String, dynamic>)).toList(),
      documents: rawDocs.map((d) => HostelStaffDocument.fromJson(d as Map<String, dynamic>)).toList(),
      leaves: rawLeaves.map((l) => HostelStaffLeave.fromJson(l as Map<String, dynamic>)).toList(),
      monthlyLeavesTaken: (json['monthly_leaves_taken'] as num?)?.toDouble() ?? 0.0,
      activeSubstituteWarden: json['active_substitute_warden'] as String? ?? 'Backup Warden',
      activeLeaveReason: json['active_leave_reason'] as String? ?? '',
      responsibilities: json['responsibilities'] as String?,
      remarks: json['remarks'] as String?,
    );
  }

  HostelStaffDetail360 copyWith({
    String? assignmentId,
    String? profileId,
    String? fullName,
    String? employeeId,
    String? avatarUrl,
    String? role,
    String? hostelId,
    String? hostelName,
    String? contact,
    String? email,
    String? address,
    String? emergencyContact,
    String? shiftTimings,
    String? reportingTo,
    String? status,
    String? joiningDate,
    List<HostelStaffArea>? assignedAreas,
    List<HostelStaffActivity>? activities,
    List<HostelStaffDocument>? documents,
    List<HostelStaffLeave>? leaves,
    double? monthlyLeavesTaken,
    String? activeSubstituteWarden,
    String? activeLeaveReason,
    String? responsibilities,
    String? remarks,
  }) {
    return HostelStaffDetail360(
      assignmentId: assignmentId ?? this.assignmentId,
      profileId: profileId ?? this.profileId,
      fullName: fullName ?? this.fullName,
      employeeId: employeeId ?? this.employeeId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      hostelId: hostelId ?? this.hostelId,
      hostelName: hostelName ?? this.hostelName,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      shiftTimings: shiftTimings ?? this.shiftTimings,
      reportingTo: reportingTo ?? this.reportingTo,
      status: status ?? this.status,
      joiningDate: joiningDate ?? this.joiningDate,
      assignedAreas: assignedAreas ?? this.assignedAreas,
      activities: activities ?? this.activities,
      documents: documents ?? this.documents,
      leaves: leaves ?? this.leaves,
      monthlyLeavesTaken: monthlyLeavesTaken ?? this.monthlyLeavesTaken,
      activeSubstituteWarden: activeSubstituteWarden ?? this.activeSubstituteWarden,
      activeLeaveReason: activeLeaveReason ?? this.activeLeaveReason,
      responsibilities: responsibilities ?? this.responsibilities,
      remarks: remarks ?? this.remarks,
    );
  }
}

class EligibleStaffProfileItem {
  final String id;
  final String fullName;
  final String role;
  final String? employeeId;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String status;

  EligibleStaffProfileItem({
    required this.id,
    required this.fullName,
    required this.role,
    this.employeeId,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.status,
  });

  factory EligibleStaffProfileItem.fromJson(Map<String, dynamic> json) {
    return EligibleStaffProfileItem(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      employeeId: json['employee_id'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'Active',
    );
  }
}


