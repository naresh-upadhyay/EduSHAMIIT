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
