/// Top-level Campus KPIs matching executive dashboard
class CampusKpis {
  final int totalBuildings;
  final int totalFloors;
  final int totalRooms;
  final int totalCapacity;
  final int occupiedRooms;
  final int occupiedCapacity;
  final int availableRooms;
  final int availableCapacity;
  final double occupancyRate;
  final int maintenanceRooms;
  final int totalEquipment;
  final int equipmentNotWorking;

  const CampusKpis({
    this.totalBuildings = 0,
    this.totalFloors = 0,
    this.totalRooms = 0,
    this.totalCapacity = 0,
    this.occupiedRooms = 0,
    this.occupiedCapacity = 0,
    this.availableRooms = 0,
    this.availableCapacity = 0,
    this.occupancyRate = 0.0,
    this.maintenanceRooms = 0,
    this.totalEquipment = 0,
    this.equipmentNotWorking = 0,
  });

  factory CampusKpis.fromJson(Map<String, dynamic> json) {
    return CampusKpis(
      totalBuildings: (json['total_buildings'] as num?)?.toInt() ?? 0,
      totalFloors: (json['total_floors'] as num?)?.toInt() ?? 0,
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      occupiedRooms: (json['occupied_rooms'] as num?)?.toInt() ?? 0,
      occupiedCapacity: (json['occupied_capacity'] as num?)?.toInt() ?? 0,
      availableRooms: (json['available_rooms'] as num?)?.toInt() ?? 0,
      availableCapacity: (json['available_capacity'] as num?)?.toInt() ?? 0,
      occupancyRate: (json['occupancy_rate'] as num?)?.toDouble() ?? 0.0,
      maintenanceRooms: (json['maintenance_rooms'] as num?)?.toInt() ?? 0,
      totalEquipment: (json['total_equipment'] as num?)?.toInt() ?? 0,
      equipmentNotWorking: (json['equipment_not_working'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Building Entity Model
class BuildingModel {
  final String id;
  final String schoolId;
  final String? campusId;
  final String name;
  final String code;
  final String buildingType;
  final String? description;
  final String? purpose;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int totalFloors;
  final double totalArea;
  final String areaUnit;
  final int? constructionYear;
  final int numEntrances;
  final int numEmergencyExits;
  final String? managerName;
  final String? managerContact;
  final String? department;
  final String? imageUrl;
  final String? fireSafetyCertExpiry;
  final String? occupancyCertExpiry;
  final String status;
  final String? notes;
  final int totalRooms;
  final int totalCapacity;
  final int currentOccupancy;
  final double occupancyRate;
  final Map<String, dynamic>? lastInspection;

  const BuildingModel({
    required this.id,
    required this.schoolId,
    this.campusId,
    required this.name,
    required this.code,
    this.buildingType = 'Academic',
    this.description,
    this.purpose,
    this.address,
    this.latitude,
    this.longitude,
    this.totalFloors = 1,
    this.totalArea = 0.0,
    this.areaUnit = 'sq ft',
    this.constructionYear,
    this.numEntrances = 1,
    this.numEmergencyExits = 1,
    this.managerName,
    this.managerContact,
    this.department,
    this.imageUrl,
    this.fireSafetyCertExpiry,
    this.occupancyCertExpiry,
    this.status = 'Active',
    this.notes,
    this.totalRooms = 0,
    this.totalCapacity = 0,
    this.currentOccupancy = 0,
    this.occupancyRate = 0.0,
    this.lastInspection,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      campusId: json['campus_id']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      buildingType: json['building_type']?.toString() ?? 'Academic',
      description: json['description']?.toString(),
      purpose: json['purpose']?.toString(),
      address: json['address']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      totalFloors: (json['total_floors'] as num?)?.toInt() ?? 1,
      totalArea: (json['total_area'] as num?)?.toDouble() ?? 0.0,
      areaUnit: json['area_unit']?.toString() ?? 'sq ft',
      constructionYear: (json['construction_year'] as num?)?.toInt(),
      numEntrances: (json['num_entrances'] as num?)?.toInt() ?? 1,
      numEmergencyExits: (json['num_emergency_exits'] as num?)?.toInt() ?? 1,
      managerName: json['manager_name']?.toString(),
      managerContact: json['manager_contact']?.toString(),
      department: json['department']?.toString(),
      imageUrl: json['image_url']?.toString(),
      fireSafetyCertExpiry: json['fire_safety_cert_expiry']?.toString(),
      occupancyCertExpiry: json['occupancy_cert_expiry']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      notes: json['notes']?.toString(),
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      currentOccupancy: (json['current_occupancy'] as num?)?.toInt() ?? 0,
      occupancyRate: (json['occupancy_rate'] as num?)?.toDouble() ?? 0.0,
      lastInspection: json['last_inspection'] as Map<String, dynamic>?,
    );
  }

  BuildingModel copyWith({
    String? id,
    String? schoolId,
    String? campusId,
    String? name,
    String? code,
    String? buildingType,
    String? description,
    String? purpose,
    String? address,
    double? latitude,
    double? longitude,
    int? totalFloors,
    double? totalArea,
    String? areaUnit,
    int? constructionYear,
    int? numEntrances,
    int? numEmergencyExits,
    String? managerName,
    String? managerContact,
    String? department,
    String? imageUrl,
    String? fireSafetyCertExpiry,
    String? occupancyCertExpiry,
    String? status,
    String? notes,
    int? totalRooms,
    int? totalCapacity,
    int? currentOccupancy,
    double? occupancyRate,
    Map<String, dynamic>? lastInspection,
  }) {
    return BuildingModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      campusId: campusId ?? this.campusId,
      name: name ?? this.name,
      code: code ?? this.code,
      buildingType: buildingType ?? this.buildingType,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalFloors: totalFloors ?? this.totalFloors,
      totalArea: totalArea ?? this.totalArea,
      areaUnit: areaUnit ?? this.areaUnit,
      constructionYear: constructionYear ?? this.constructionYear,
      numEntrances: numEntrances ?? this.numEntrances,
      numEmergencyExits: numEmergencyExits ?? this.numEmergencyExits,
      managerName: managerName ?? this.managerName,
      managerContact: managerContact ?? this.managerContact,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      fireSafetyCertExpiry: fireSafetyCertExpiry ?? this.fireSafetyCertExpiry,
      occupancyCertExpiry: occupancyCertExpiry ?? this.occupancyCertExpiry,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      totalRooms: totalRooms ?? this.totalRooms,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      occupancyRate: occupancyRate ?? this.occupancyRate,
      lastInspection: lastInspection ?? this.lastInspection,
    );
  }
}

/// Building Floor Entity Model
class BuildingFloorModel {
  final String id;
  final String? schoolId;
  final String buildingId;
  final String name;
  final String floorCode;
  final int floorLevel;
  final int floorOrder;
  final String floorType;
  final double area;
  final String? description;
  final String status;
  final String? notes;
  final int totalRooms;
  final int capacity;
  final int occupancy;
  final double occupancyPercentage;
  final String roomTypesSummary;
  final int maintenanceCount;

  const BuildingFloorModel({
    required this.id,
    this.schoolId,
    required this.buildingId,
    required this.name,
    required this.floorCode,
    this.floorLevel = 0,
    this.floorOrder = 0,
    this.floorType = 'Standard',
    this.area = 0.0,
    this.description,
    this.status = 'Active',
    this.notes,
    this.totalRooms = 0,
    this.capacity = 0,
    this.occupancy = 0,
    this.occupancyPercentage = 0.0,
    this.roomTypesSummary = 'None',
    this.maintenanceCount = 0,
  });

  factory BuildingFloorModel.fromJson(Map<String, dynamic> json) {
    return BuildingFloorModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString(),
      buildingId: json['building_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      floorCode: json['floor_code']?.toString() ?? '',
      floorLevel: (json['floor_level'] as num?)?.toInt() ?? 0,
      floorOrder: (json['floor_order'] as num?)?.toInt() ?? 0,
      floorType: json['floor_type']?.toString() ?? 'Standard',
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      notes: json['notes']?.toString(),
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      occupancy: (json['occupancy'] as num?)?.toInt() ?? 0,
      occupancyPercentage: (json['occupancy_percentage'] as num?)?.toDouble() ?? 0.0,
      roomTypesSummary: json['room_types_summary']?.toString() ?? 'None',
      maintenanceCount: (json['maintenance_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Physical Room / Space Entity Model
class RoomModel {
  final String id;
  final String schoolId;
  final String buildingId;
  final String? buildingName;
  final String? buildingCode;
  final String floorId;
  final String? floorName;
  final int? floorLevel;
  final String name;
  final String roomNumber;
  final String roomCode;
  final String roomType;
  final String? description;
  final String? purpose;
  final double area;
  final String areaUnit;
  final double length;
  final double width;
  final double height;
  final int maxCapacity;
  final int recommendedCapacity;
  final int currentOccupancy;
  final int bedCount;
  final int seatingCapacity;
  final int workstationCount;
  final int numDoors;
  final int numWindows;
  final String operationalStatus;
  final String assignmentStatus;
  final bool isDifferentlyAbledAccessible;
  final String liftProximity;
  final String emergencyExitProximity;
  final String? locationNotes;
  final String? imageUrl;
  final String? responsibleDepartment;
  final String? responsiblePersonName;
  final int equipmentCount;
  final int equipmentNotWorking;
  final String equipmentSummary;

  const RoomModel({
    required this.id,
    required this.schoolId,
    required this.buildingId,
    this.buildingName,
    this.buildingCode,
    required this.floorId,
    this.floorName,
    this.floorLevel,
    required this.name,
    required this.roomNumber,
    required this.roomCode,
    this.roomType = 'Classroom',
    this.description,
    this.purpose,
    this.area = 0.0,
    this.areaUnit = 'sq ft',
    this.length = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.maxCapacity = 40,
    this.recommendedCapacity = 35,
    this.currentOccupancy = 0,
    this.bedCount = 0,
    this.seatingCapacity = 40,
    this.workstationCount = 0,
    this.numDoors = 1,
    this.numWindows = 2,
    this.operationalStatus = 'Available',
    this.assignmentStatus = 'Unassigned',
    this.isDifferentlyAbledAccessible = true,
    this.liftProximity = 'Nearby',
    this.emergencyExitProximity = 'Direct Access',
    this.locationNotes,
    this.imageUrl,
    this.responsibleDepartment,
    this.responsiblePersonName,
    this.equipmentCount = 0,
    this.equipmentNotWorking = 0,
    this.equipmentSummary = 'None',
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      buildingName: json['building_name']?.toString(),
      buildingCode: json['building_code']?.toString(),
      floorId: json['floor_id']?.toString() ?? '',
      floorName: json['floor_name']?.toString(),
      floorLevel: (json['floor_level'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      roomCode: json['room_code']?.toString() ?? '',
      roomType: json['room_type']?.toString() ?? 'Classroom',
      description: json['description']?.toString(),
      purpose: json['purpose']?.toString(),
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      areaUnit: json['area_unit']?.toString() ?? 'sq ft',
      length: (json['length'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 40,
      recommendedCapacity: (json['recommended_capacity'] as num?)?.toInt() ?? 35,
      currentOccupancy: (json['current_occupancy'] as num?)?.toInt() ?? 0,
      bedCount: (json['bed_count'] as num?)?.toInt() ?? 0,
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 40,
      workstationCount: (json['workstation_count'] as num?)?.toInt() ?? 0,
      numDoors: (json['num_doors'] as num?)?.toInt() ?? 1,
      numWindows: (json['num_windows'] as num?)?.toInt() ?? 2,
      operationalStatus: json['operational_status']?.toString() ?? 'Available',
      assignmentStatus: json['assignment_status']?.toString() ?? 'Unassigned',
      isDifferentlyAbledAccessible: json['is_differently_abled_accessible'] == true || json['is_differently_abled_accessible'] == null,
      liftProximity: json['lift_proximity']?.toString() ?? 'Nearby',
      emergencyExitProximity: json['emergency_exit_proximity']?.toString() ?? 'Direct Access',
      locationNotes: json['location_notes']?.toString(),
      imageUrl: json['image_url']?.toString(),
      responsibleDepartment: json['responsible_department']?.toString(),
      responsiblePersonName: json['responsible_person_name']?.toString(),
      equipmentCount: (json['equipment_count'] as num?)?.toInt() ?? 0,
      equipmentNotWorking: (json['equipment_not_working'] as num?)?.toInt() ?? 0,
      equipmentSummary: json['equipment_summary']?.toString() ?? 'None',
    );
  }
}

/// Room Equipment / Fixture Model
class RoomEquipmentModel {
  final String id;
  final String? roomId;
  final String equipmentName;
  final String equipmentCategory;
  final String? assetId;
  final int quantity;
  final String condition;
  final String operationalStatus;
  final String? installationDate;
  final String? lastServiceDate;
  final String? nextServiceDate;
  final String? remarks;

  const RoomEquipmentModel({
    required this.id,
    this.roomId,
    required this.equipmentName,
    this.equipmentCategory = 'General Fixture',
    this.assetId,
    this.quantity = 1,
    this.condition = 'Good',
    this.operationalStatus = 'Operational',
    this.installationDate,
    this.lastServiceDate,
    this.nextServiceDate,
    this.remarks,
  });

  factory RoomEquipmentModel.fromJson(Map<String, dynamic> json) {
    return RoomEquipmentModel(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString(),
      equipmentName: json['equipment_name']?.toString() ?? '',
      equipmentCategory: json['equipment_category']?.toString() ?? 'General Fixture',
      assetId: json['asset_id']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      condition: json['condition']?.toString() ?? 'Good',
      operationalStatus: json['operational_status']?.toString() ?? 'Operational',
      installationDate: json['installation_date']?.toString(),
      lastServiceDate: json['last_service_date']?.toString(),
      nextServiceDate: json['next_service_date']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }
}

/// Building Document / Compliance Model
class BuildingDocumentModel {
  final String id;
  final String? schoolId;
  final String? buildingId;
  final String? roomId;
  final String documentName;
  final String documentType;
  final String fileUrl;
  final int fileSizeBytes;
  final String mimeType;
  final String? issueDate;
  final String? expiryDate;
  final String? issuingAuthority;
  final String status;
  final String? createdAt;

  const BuildingDocumentModel({
    required this.id,
    this.schoolId,
    this.buildingId,
    this.roomId,
    required this.documentName,
    this.documentType = 'Compliance',
    required this.fileUrl,
    this.fileSizeBytes = 0,
    this.mimeType = 'application/pdf',
    this.issueDate,
    this.expiryDate,
    this.issuingAuthority,
    this.status = 'Valid',
    this.createdAt,
  });

  factory BuildingDocumentModel.fromJson(Map<String, dynamic> json) {
    return BuildingDocumentModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString(),
      buildingId: json['building_id']?.toString(),
      roomId: json['room_id']?.toString(),
      documentName: json['document_name']?.toString() ?? 'Document',
      documentType: json['document_type']?.toString() ?? 'Compliance',
      fileUrl: json['file_url']?.toString() ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type']?.toString() ?? 'application/pdf',
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      issuingAuthority: json['issuing_authority']?.toString(),
      status: json['status']?.toString() ?? 'Valid',
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// Building Occupancy / Allocation Model (Dynamic Space Booking Driven)
class BuildingOccupancyModel {
  final String id;
  final String roomId;
  final String roomNumber;
  final String? roomName;
  final String? roomCode;
  final String? floorId;
  final String? floorName;
  final int floorNumber;
  final String roomType;
  final String referenceModule;
  final String? referenceName;
  final String assignmentPurpose;
  final String? startDate;
  final String? endDate;
  final String? assignedToName;
  final String status;
  final String? notes;
  final int maxCapacity;
  final int seatingCapacity;
  final int currentOccupancy;
  final String? createdAt;

  // Real-time Space Booking Intelligence
  final String operationalStatus;
  final String bookingStatus; // 'OCCUPIED_NOW', 'AVAILABLE_NOW', 'SCHEDULED_LATER', 'MAINTENANCE'
  final String statusDisplay;
  final String activeTitle;
  final String activeTeacher;
  final String activePurpose;
  final String activeTimeRange;
  final int todaySessionsCount;
  final List<Map<String, dynamic>> todayBookings;
  final List<String> facilities;
  final double area;
  final String areaUnit;
  final double length;
  final double width;
  final double height;
  final int numDoors;
  final int numWindows;
  final bool isDifferentlyAbledAccessible;
  final String? liftProximity;
  final String? emergencyExitProximity;
  final bool isBookable;

  const BuildingOccupancyModel({
    required this.id,
    required this.roomId,
    required this.roomNumber,
    this.roomName,
    this.roomCode,
    this.floorId,
    this.floorName,
    this.floorNumber = 0,
    this.roomType = 'Classroom',
    this.referenceModule = 'General',
    this.referenceName,
    this.assignmentPurpose = 'General Allocation',
    this.startDate,
    this.endDate,
    this.assignedToName,
    this.status = 'Active',
    this.notes,
    this.maxCapacity = 40,
    this.seatingCapacity = 40,
    this.currentOccupancy = 0,
    this.createdAt,
    this.operationalStatus = 'Available',
    this.bookingStatus = 'AVAILABLE_NOW',
    this.statusDisplay = 'Available Now',
    this.activeTitle = '',
    this.activeTeacher = '',
    this.activePurpose = '',
    this.activeTimeRange = '',
    this.todaySessionsCount = 0,
    this.todayBookings = const [],
    this.facilities = const [],
    this.area = 0.0,
    this.areaUnit = 'sq ft',
    this.length = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    this.numDoors = 1,
    this.numWindows = 2,
    this.isDifferentlyAbledAccessible = true,
    this.liftProximity,
    this.emergencyExitProximity,
    this.isBookable = true,
  });

  factory BuildingOccupancyModel.fromJson(Map<String, dynamic> json) {
    final rawFac = json['facilities'];
    List<String> parsedFac = [];
    if (rawFac is List) {
      parsedFac = rawFac.map((e) => e.toString()).toList();
    }

    final rawBookings = json['today_bookings'];
    List<Map<String, dynamic>> parsedBookings = [];
    if (rawBookings is List) {
      parsedBookings = rawBookings
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return BuildingOccupancyModel(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? json['id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      roomName: json['room_name']?.toString() ?? json['name']?.toString(),
      roomCode: json['room_code']?.toString(),
      floorId: json['floor_id']?.toString(),
      floorName: json['floor_name']?.toString(),
      floorNumber: (json['floor_number'] as num?)?.toInt() ?? 0,
      roomType: json['room_type']?.toString() ?? json['type']?.toString() ?? 'Classroom',
      referenceModule: json['reference_module']?.toString() ?? 'General',
      referenceName: json['reference_name']?.toString() ?? json['active_title']?.toString(),
      assignmentPurpose: json['assignment_purpose']?.toString() ?? json['active_purpose']?.toString() ?? 'General Allocation',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      assignedToName: json['assigned_to_name']?.toString() ?? json['active_teacher']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      notes: json['notes']?.toString(),
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? (json['capacity'] as num?)?.toInt() ?? 40,
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? (json['max_capacity'] as num?)?.toInt() ?? 40,
      currentOccupancy: (json['current_occupancy'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
      operationalStatus: json['operational_status']?.toString() ?? 'Available',
      bookingStatus: json['booking_status']?.toString() ?? 'AVAILABLE_NOW',
      statusDisplay: json['status_display']?.toString() ?? 'Available Now',
      activeTitle: json['active_title']?.toString() ?? json['reference_name']?.toString() ?? '',
      activeTeacher: json['active_teacher']?.toString() ?? json['assigned_to_name']?.toString() ?? '',
      activePurpose: json['active_purpose']?.toString() ?? json['assignment_purpose']?.toString() ?? '',
      activeTimeRange: json['active_time_range']?.toString() ?? '',
      todaySessionsCount: (json['today_sessions_count'] as num?)?.toInt() ?? parsedBookings.length,
      todayBookings: parsedBookings,
      facilities: parsedFac,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      areaUnit: json['area_unit']?.toString() ?? 'sq ft',
      length: (json['length'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      numDoors: (json['num_doors'] as num?)?.toInt() ?? 1,
      numWindows: (json['num_windows'] as num?)?.toInt() ?? 2,
      isDifferentlyAbledAccessible: json['is_differently_abled_accessible'] == true,
      liftProximity: json['lift_proximity']?.toString(),
      emergencyExitProximity: json['emergency_exit_proximity']?.toString(),
      isBookable: json['is_bookable'] != false,
    );
  }
}

/// Building Maintenance Request Model
class BuildingMaintenanceModel {
  final String id;
  final String requestCode;
  final String title;
  final String? description;
  final String requestType;
  final String priority;
  final String status;
  final String? buildingId;
  final String? floorId;
  final String? roomId;
  final String? roomNumber;
  final String? floorName;
  final String? reportedByName;
  final String? assignedToName;
  final String? scheduledAt;
  final String? preferredDate;
  final double estimatedCost;
  final double actualCost;
  final String? resolutionNotes;
  final String? createdAt;

  const BuildingMaintenanceModel({
    required this.id,
    required this.requestCode,
    required this.title,
    this.description,
    this.requestType = 'Corrective',
    this.priority = 'Medium',
    this.status = 'Pending',
    this.buildingId,
    this.floorId,
    this.roomId,
    this.roomNumber,
    this.floorName,
    this.reportedByName,
    this.assignedToName,
    this.scheduledAt,
    this.preferredDate,
    this.estimatedCost = 0.0,
    this.actualCost = 0.0,
    this.resolutionNotes,
    this.createdAt,
  });

  factory BuildingMaintenanceModel.fromJson(Map<String, dynamic> json) {
    return BuildingMaintenanceModel(
      id: json['id']?.toString() ?? '',
      requestCode: json['request_code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      requestType: json['request_type']?.toString() ?? 'Corrective',
      priority: json['priority']?.toString() ?? 'Medium',
      status: json['status']?.toString() ?? 'Pending',
      buildingId: json['building_id']?.toString(),
      floorId: json['floor_id']?.toString(),
      roomId: json['room_id']?.toString(),
      roomNumber: json['room_number']?.toString(),
      floorName: json['floor_name']?.toString(),
      reportedByName: json['reported_by_name']?.toString(),
      assignedToName: json['assigned_to_name']?.toString(),
      scheduledAt: json['scheduled_at']?.toString(),
      preferredDate: json['preferred_date']?.toString(),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? 0.0,
      resolutionNotes: json['resolution_notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}
