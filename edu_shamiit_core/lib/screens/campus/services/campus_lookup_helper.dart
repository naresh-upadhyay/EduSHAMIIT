import '../../../../services/api_service.dart';
import '../../../../services/lookup_event_bus.dart';
import '../models/campus_models.dart';
import 'campus_api_service.dart';

class CampusLookupItem {
  final String id;
  final String code;
  final String label;
  final String description;
  final String status;
  final int sortOrder;

  const CampusLookupItem({
    required this.id,
    required this.code,
    required this.label,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory CampusLookupItem.fromJson(Map<String, dynamic> json) {
    return CampusLookupItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['value_code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CampusLookupHelper {
  static final CampusLookupHelper instance = CampusLookupHelper._internal();

  CampusLookupHelper._internal() {
    // Listen to global lookup modifications from Lookup Management
    LookupEventBus.instance.addListener(() {
      final event = LookupEventBus.instance.lastEvent;
      if (event?.keyCode != null && event!.keyCode!.isNotEmpty) {
        clearCache(event.keyCode);
      } else {
        clearCache();
      }
    });
  }

  final ApiService _api = ApiService();
  final Map<String, List<CampusLookupItem>> _cache = {};

  void clearCache([String? keyCode]) {
    if (keyCode != null && keyCode.isNotEmpty) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }

  /// Fetch active lookup values for a given key_code.
  Future<List<CampusLookupItem>> getActiveLookup(
    String keyCode, {
    List<CampusLookupItem>? fallbacks,
    bool forceRefresh = false,
  }) async {
    final upperKey = keyCode.toUpperCase().trim();
    if (!forceRefresh && _cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!;
    }

    try {
      final res = await _api.get(
        '/lookups/code/$upperKey',
        query: {'include_inactive': false},
        useCache: false,
      );

      if (res['success'] == true && res['values'] is List) {
        final list = (res['values'] as List)
            .map((e) => CampusLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    // Fallback: check campus built-in lookups endpoint
    try {
      final campusLookups = await CampusApiService.instance.getLookups();
      final keyMapping = _mapToCampusLookupKey(upperKey);
      if (keyMapping != null && campusLookups[keyMapping] is List) {
        final list = (campusLookups[keyMapping] as List)
            .map((val) => CampusLookupItem(
                  id: val.toString(),
                  code: val.toString().toUpperCase().replaceAll(' ', '_'),
                  label: val.toString(),
                ))
            .toList();
        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    final fallbackList = _cache[upperKey] ?? fallbacks ?? _getDefaultLookups(upperKey);
    _cache[upperKey] = fallbackList;
    return fallbackList;
  }

  /// Get string labels for dropdowns
  Future<List<String>> getLookupLabels(
    String keyCode, {
    List<String>? defaultLabels,
    bool forceRefresh = false,
  }) async {
    final items = await getActiveLookup(keyCode, forceRefresh: forceRefresh);
    if (items.isNotEmpty) {
      return items.map((e) => e.label).toList();
    }
    return defaultLabels ?? [];
  }

  // Synchronous getter with immediate defaults while async query fetches
  List<String> getImmediateLabels(String keyCode) {
    final upperKey = keyCode.toUpperCase().trim();
    if (_cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!.map((e) => e.label).toList();
    }
    // Fetch in background to populate cache
    getActiveLookup(keyCode);
    return _getDefaultLookups(upperKey).map((e) => e.label).toList();
  }

  // Entity queries from logical tables
  Future<List<BuildingModel>> getActiveBuildings({bool forceRefresh = false}) async {
    try {
      final res = await CampusApiService.instance.getBuildings(page: 1, pageSize: 100);
      return (res['data'] as List<BuildingModel>?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<BuildingFloorModel>> getFloorsForBuilding(String buildingId) async {
    try {
      return await CampusApiService.instance.getFloors(buildingId, page: 1, pageSize: 100);
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _cachedUsers = [];

  Future<List<Map<String, dynamic>>> getStaffUsers({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUsers.isNotEmpty) {
      return _cachedUsers;
    }
    try {
      final res = await _api.get('/auth/users', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        _cachedUsers = list;
        return list;
      }
    } catch (_) {}
    return _cachedUsers;
  }

  Future<List<String>> getDepartments() async {
    return getLookupLabels(
      'DEPARTMENT',
      defaultLabels: [
        'Academic Affairs',
        'Computer Science & IT',
        'Physical Sciences',
        'Biological Sciences',
        'Mathematics & Statistics',
        'Humanities & Languages',
        'Administration & Finance',
        'Sports & Physical Education',
        'Library & Information Services',
        'Campus Facilities & Maintenance',
      ],
    );
  }

  Future<List<String>> getTechnicians() async {
    return getLookupLabels(
      'TECHNICIAN_STAFF',
      defaultLabels: [
        'Suresh Sharma (Chief Electrical Specialist)',
        'Ramesh Kumar (General Electrical)',
        'Kiran Verma (IT & AV Infrastructure)',
        'Gopal Das (Carpentry & Civil)',
        'Vinod Patil (HVAC & Mechanical)',
        'Sunil Rao (Plumbing & Sanitation)',
      ],
    );
  }

  Future<List<String>> getMaintenanceVendors() async {
    return getLookupLabels(
      'MAINTENANCE_VENDOR',
      defaultLabels: [
        'CoolAir Solutions Pvt Ltd (HVAC AMC)',
        'PowerGrid Electric Services Ltd (AMC)',
        'FlowMaster Plumbing & Fire Systems',
        'Apex AV & Smart Classroom Systems',
        'CleanEnvironment Waste & Sanitation',
        'Internal Campus Maintenance Team',
      ],
    );
  }

  String? _mapToCampusLookupKey(String keyCode) {
    switch (keyCode) {
      case 'BUILDING_TYPE':
        return 'building_types';
      case 'BUILDING_STATUS':
        return 'building_statuses';
      case 'ROOM_TYPE':
        return 'room_types';
      case 'ROOM_STATUS':
      case 'ROOM_OPERATIONAL_STATUS':
        return 'room_statuses';
      case 'ROOM_ASSIGNMENT_STATUS':
        return 'assignment_statuses';
      case 'EQUIPMENT_CATEGORY':
        return 'equipment_categories';
      case 'EQUIPMENT_CONDITION':
        return 'equipment_conditions';
      case 'EQUIPMENT_STATUS':
        return 'equipment_statuses';
      case 'AREA_UNIT':
        return 'area_units';
      default:
        return null;
    }
  }

  List<CampusLookupItem> _getDefaultLookups(String keyCode) {
    switch (keyCode) {
      case 'BUILDING_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'ACADEMIC', label: 'Academic'),
          CampusLookupItem(id: '2', code: 'ADMINISTRATIVE', label: 'Administrative'),
          CampusLookupItem(id: '3', code: 'RESIDENTIAL', label: 'Residential'),
          CampusLookupItem(id: '4', code: 'HOSTEL', label: 'Hostel'),
          CampusLookupItem(id: '5', code: 'LIBRARY', label: 'Library'),
          CampusLookupItem(id: '6', code: 'LABORATORY', label: 'Laboratory Complex'),
          CampusLookupItem(id: '7', code: 'SPORTS', label: 'Sports & Athletics'),
          CampusLookupItem(id: '8', code: 'AUDITORIUM', label: 'Auditorium & Arts'),
          CampusLookupItem(id: '9', code: 'DINING', label: 'Dining / Cafeteria'),
          CampusLookupItem(id: '10', code: 'MEDICAL', label: 'Medical & Infirmary'),
          CampusLookupItem(id: '11', code: 'UTILITY', label: 'Utility & Power'),
          CampusLookupItem(id: '12', code: 'STORAGE', label: 'Storage / Warehouse'),
          CampusLookupItem(id: '13', code: 'OTHER', label: 'Other'),
        ];

      case 'BUILDING_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'ACTIVE', label: 'Active'),
          CampusLookupItem(id: '2', code: 'UNDER_CONSTRUCTION', label: 'Under Construction'),
          CampusLookupItem(id: '3', code: 'UNDER_RENOVATION', label: 'Under Renovation'),
          CampusLookupItem(id: '4', code: 'TEMPORARILY_CLOSED', label: 'Temporarily Closed'),
          CampusLookupItem(id: '5', code: 'INACTIVE', label: 'Inactive'),
          CampusLookupItem(id: '6', code: 'ARCHIVED', label: 'Archived'),
        ];

      case 'ROOM_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'CLASSROOM', label: 'Classroom'),
          CampusLookupItem(id: '2', code: 'SMART_CLASSROOM', label: 'Smart Classroom'),
          CampusLookupItem(id: '3', code: 'LECTURE_HALL', label: 'Lecture Hall'),
          CampusLookupItem(id: '4', code: 'SEMINAR_HALL', label: 'Seminar Hall'),
          CampusLookupItem(id: '5', code: 'EXAMINATION_HALL', label: 'Examination Hall'),
          CampusLookupItem(id: '6', code: 'PHYSICS_LAB', label: 'Physics Lab'),
          CampusLookupItem(id: '7', code: 'CHEMISTRY_LAB', label: 'Chemistry Lab'),
          CampusLookupItem(id: '8', code: 'BIOLOGY_LAB', label: 'Biology Lab'),
          CampusLookupItem(id: '9', code: 'COMPUTER_LAB', label: 'Computer Lab'),
          CampusLookupItem(id: '10', code: 'LANGUAGE_LAB', label: 'Language Lab'),
          CampusLookupItem(id: '11', code: 'ROBOTICS_LAB', label: 'Robotics & AI Lab'),
          CampusLookupItem(id: '12', code: 'PRINCIPAL_OFFICE', label: 'Principal Office'),
          CampusLookupItem(id: '13', code: 'STAFF_ROOM', label: 'Staff Room'),
          CampusLookupItem(id: '14', code: 'FACULTY_OFFICE', label: 'Faculty Office'),
          CampusLookupItem(id: '15', code: 'RECEPTION', label: 'Reception & Helpdesk'),
          CampusLookupItem(id: '16', code: 'MEETING_ROOM', label: 'Conference / Meeting Room'),
          CampusLookupItem(id: '17', code: 'ADMIN_OFFICE', label: 'Administrative Office'),
          CampusLookupItem(id: '18', code: 'ACCOUNTS_OFFICE', label: 'Accounts Office'),
          CampusLookupItem(id: '19', code: 'LIBRARY', label: 'Library'),
          CampusLookupItem(id: '20', code: 'READING_ROOM', label: 'Reading Room'),
          CampusLookupItem(id: '21', code: 'DIGITAL_LIBRARY', label: 'Digital Library'),
          CampusLookupItem(id: '22', code: 'HOSTEL_ROOM', label: 'Hostel Room'),
          CampusLookupItem(id: '23', code: 'DORMITORY', label: 'Dormitory'),
          CampusLookupItem(id: '24', code: 'WASHROOM', label: 'Washroom'),
          CampusLookupItem(id: '25', code: 'ACCESSIBLE_WASHROOM', label: 'Accessible Washroom'),
          CampusLookupItem(id: '26', code: 'SERVER_ROOM', label: 'Server & IT Hub'),
          CampusLookupItem(id: '27', code: 'ELECTRICAL_ROOM', label: 'Electrical Room'),
          CampusLookupItem(id: '28', code: 'AUDITORIUM', label: 'Auditorium'),
          CampusLookupItem(id: '29', code: 'CANTEEN', label: 'Canteen / Dining'),
          CampusLookupItem(id: '30', code: 'MEDICAL_ROOM', label: 'Medical / Infirmary Room'),
          CampusLookupItem(id: '31', code: 'SPORTS_ROOM', label: 'Sports Room / Gym'),
          CampusLookupItem(id: '32', code: 'STORAGE', label: 'Storage & Archive'),
          CampusLookupItem(id: '33', code: 'OTHER', label: 'Other'),
        ];

      case 'ROOM_STATUS':
      case 'ROOM_OPERATIONAL_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'AVAILABLE', label: 'Available'),
          CampusLookupItem(id: '2', code: 'OCCUPIED', label: 'Occupied'),
          CampusLookupItem(id: '3', code: 'RESERVED', label: 'Reserved'),
          CampusLookupItem(id: '4', code: 'UNDER_MAINTENANCE', label: 'Under Maintenance'),
          CampusLookupItem(id: '5', code: 'TEMPORARILY_UNAVAILABLE', label: 'Temporarily Unavailable'),
          CampusLookupItem(id: '6', code: 'INACTIVE', label: 'Inactive'),
        ];

      case 'ROOM_ASSIGNMENT_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'UNASSIGNED', label: 'Unassigned'),
          CampusLookupItem(id: '2', code: 'ASSIGNED', label: 'Assigned'),
          CampusLookupItem(id: '3', code: 'PARTIALLY_ASSIGNED', label: 'Partially Assigned'),
          CampusLookupItem(id: '4', code: 'RESERVED', label: 'Reserved'),
        ];

      case 'EQUIPMENT_CATEGORY':
        return const [
          CampusLookupItem(id: '1', code: 'ELECTRICAL', label: 'Electrical & Lighting'),
          CampusLookupItem(id: '2', code: 'IT_AV', label: 'IT & Audio-Visual'),
          CampusLookupItem(id: '3', code: 'FURNITURE', label: 'Furniture & Seating'),
          CampusLookupItem(id: '4', code: 'PLUMBING', label: 'Plumbing & Sanitation'),
          CampusLookupItem(id: '5', code: 'SAFETY', label: 'Safety & Medical'),
          CampusLookupItem(id: '6', code: 'HVAC', label: 'HVAC & Air Cooling'),
          CampusLookupItem(id: '7', code: 'LABORATORY', label: 'Laboratory Apparatus'),
          CampusLookupItem(id: '8', code: 'GENERAL', label: 'General Fixture'),
        ];

      case 'EQUIPMENT_CONDITION':
        return const [
          CampusLookupItem(id: '1', code: 'NEW', label: 'New'),
          CampusLookupItem(id: '2', code: 'EXCELLENT', label: 'Excellent'),
          CampusLookupItem(id: '3', code: 'GOOD', label: 'Good'),
          CampusLookupItem(id: '4', code: 'FAIR', label: 'Fair'),
          CampusLookupItem(id: '5', code: 'POOR', label: 'Poor'),
          CampusLookupItem(id: '6', code: 'DAMAGED', label: 'Damaged / Needs Replacement'),
        ];

      case 'EQUIPMENT_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'OPERATIONAL', label: 'Operational'),
          CampusLookupItem(id: '2', code: 'NOT_WORKING', label: 'Not Working'),
          CampusLookupItem(id: '3', code: 'UNDER_MAINTENANCE', label: 'Under Maintenance'),
          CampusLookupItem(id: '4', code: 'DEGRADED', label: 'Degraded Performance'),
          CampusLookupItem(id: '5', code: 'DECOMMISSIONED', label: 'Decommissioned'),
        ];

      case 'FACILITY_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'SPORTS_GROUND', label: 'Sports Complex / Ground'),
          CampusLookupItem(id: '2', code: 'LABORATORY', label: 'Specialized Laboratory'),
          CampusLookupItem(id: '3', code: 'AUDITORIUM', label: 'Auditorium & Amphitheater'),
          CampusLookupItem(id: '4', code: 'LIBRARY_COMMONS', label: 'Library & Learning Commons'),
          CampusLookupItem(id: '5', code: 'DINING_CANTEEN', label: 'Dining & Cafeteria Hub'),
          CampusLookupItem(id: '6', code: 'HEALTH_CENTER', label: 'Health Center & Clinic'),
          CampusLookupItem(id: '7', code: 'TRANSPORT_TERMINAL', label: 'Transport Hub & Bus Bay'),
          CampusLookupItem(id: '8', code: 'INNOVATION_FABLAB', label: 'Robotics & Fabrication Lab'),
          CampusLookupItem(id: '9', code: 'FITNESS_GYM', label: 'Indoor Gymnasium & Yoga Studio'),
          CampusLookupItem(id: '10', code: 'STUDENT_ACTIVITY', label: 'Student Activity Center'),
        ];

      case 'FACILITY_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'OPERATIONAL', label: 'Operational'),
          CampusLookupItem(id: '2', code: 'UNDER_MAINTENANCE', label: 'Under Maintenance'),
          CampusLookupItem(id: '3', code: 'RESERVED', label: 'Reserved / In-Use'),
          CampusLookupItem(id: '4', code: 'TEMPORARILY_CLOSED', label: 'Temporarily Closed'),
          CampusLookupItem(id: '5', code: 'INACTIVE', label: 'Inactive'),
        ];

      case 'BOOKING_PURPOSE':
        return const [
          CampusLookupItem(id: '1', code: 'CLASS_LECTURE', label: 'Class / Lecture Instruction'),
          CampusLookupItem(id: '2', code: 'EXAM', label: 'Examination / Assessment'),
          CampusLookupItem(id: '3', code: 'WORKSHOP', label: 'Workshop / Seminar / Conference'),
          CampusLookupItem(id: '4', code: 'SPORTS', label: 'Sports & Athletic Training'),
          CampusLookupItem(id: '5', code: 'CULTURAL', label: 'Cultural & Club Activity'),
          CampusLookupItem(id: '6', code: 'STAFF_MEETING', label: 'Staff / Faculty Meeting'),
          CampusLookupItem(id: '7', code: 'PARENT_MEETING', label: 'Parent-Teacher Orientation'),
          CampusLookupItem(id: '8', code: 'MAINTENANCE_DOWNTIME', label: 'Scheduled Maintenance Downtime'),
          CampusLookupItem(id: '9', code: 'OTHER', label: 'Other Special Event'),
        ];

      case 'BOOKING_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'PENDING', label: 'Pending Approval'),
          CampusLookupItem(id: '2', code: 'APPROVED', label: 'Approved & Confirmed'),
          CampusLookupItem(id: '3', code: 'REJECTED', label: 'Rejected'),
          CampusLookupItem(id: '4', code: 'CANCELLED', label: 'Cancelled'),
          CampusLookupItem(id: '5', code: 'COMPLETED', label: 'Completed'),
          CampusLookupItem(id: '6', code: 'IN_PROGRESS', label: 'In-Progress'),
        ];

      case 'ORGANIZER_ROLE':
        return const [
          CampusLookupItem(id: '1', code: 'FACULTY', label: 'Faculty'),
          CampusLookupItem(id: '2', code: 'STUDENT_REP', label: 'Student Club / Representative'),
          CampusLookupItem(id: '3', code: 'HOD', label: 'Department HOD'),
          CampusLookupItem(id: '4', code: 'ADMIN_OFFICE', label: 'Administration Office'),
          CampusLookupItem(id: '5', code: 'IT_TEAM', label: 'IT & Network Team'),
          CampusLookupItem(id: '6', code: 'CULTURAL_COMM', label: 'Cultural Committee'),
          CampusLookupItem(id: '7', code: 'SPORTS_STAFF', label: 'Sports & Athletics Staff'),
        ];

      case 'BOOKING_PRIORITY':
        return const [
          CampusLookupItem(id: '1', code: 'LOW', label: 'Low'),
          CampusLookupItem(id: '2', code: 'NORMAL', label: 'Normal'),
          CampusLookupItem(id: '3', code: 'HIGH', label: 'High'),
          CampusLookupItem(id: '4', code: 'URGENT', label: 'Urgent / VIP'),
        ];

      case 'MAINTENANCE_CATEGORY':
        return const [
          CampusLookupItem(id: '1', code: 'ELECTRICAL', label: 'Electrical & Power'),
          CampusLookupItem(id: '2', code: 'PLUMBING', label: 'Plumbing & Drainage'),
          CampusLookupItem(id: '3', code: 'HVAC', label: 'HVAC & Air Conditioning'),
          CampusLookupItem(id: '4', code: 'CARPENTRY', label: 'Carpentry & Furniture'),
          CampusLookupItem(id: '5', code: 'IT_AV', label: 'IT & Audio-Visual Systems'),
          CampusLookupItem(id: '6', code: 'CIVIL', label: 'Civil, Painting & Structural'),
          CampusLookupItem(id: '7', code: 'SANITATION', label: 'Sanitation & Pest Control'),
          CampusLookupItem(id: '8', code: 'FIRE_SAFETY', label: 'Fire Safety Equipment'),
          CampusLookupItem(id: '9', code: 'SECURITY_CCTV', label: 'Security & Access Control'),
        ];

      case 'MAINTENANCE_PRIORITY':
        return const [
          CampusLookupItem(id: '1', code: 'LOW', label: 'Low'),
          CampusLookupItem(id: '2', code: 'MEDIUM', label: 'Medium'),
          CampusLookupItem(id: '3', code: 'HIGH', label: 'High'),
          CampusLookupItem(id: '4', code: 'CRITICAL', label: 'Critical / Emergency'),
        ];

      case 'MAINTENANCE_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'CORRECTIVE', label: 'Corrective / Breakdown Repair'),
          CampusLookupItem(id: '2', code: 'PREVENTIVE', label: 'Preventive / Scheduled Service'),
          CampusLookupItem(id: '3', code: 'EMERGENCY', label: 'Emergency Safety Intervention'),
          CampusLookupItem(id: '4', code: 'INSPECTION', label: 'Statutory Inspection / Audit'),
        ];

      case 'INCIDENT_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'SLIP_FALL', label: 'Slip, Trip & Fall'),
          CampusLookupItem(id: '2', code: 'FIRE_SMOKE', label: 'Fire / Smoke Alert'),
          CampusLookupItem(id: '3', code: 'ELECTRICAL_SPARK', label: 'Electrical Hazard / Short Circuit'),
          CampusLookupItem(id: '4', code: 'CHEMICAL_SPILL', label: 'Chemical Spill / Lab Accident'),
          CampusLookupItem(id: '5', code: 'WATER_FLOOD', label: 'Water Leakage / Flooding'),
          CampusLookupItem(id: '6', code: 'VANDALISM', label: 'Vandalism / Property Damage'),
          CampusLookupItem(id: '7', code: 'UNAUTHORIZED_ACCESS', label: 'Unauthorized Access / Security Breach'),
          CampusLookupItem(id: '8', code: 'MEDICAL_EMERGENCY', label: 'Medical Emergency / Fainting'),
        ];

      case 'INCIDENT_SEVERITY':
        return const [
          CampusLookupItem(id: '1', code: 'LOW', label: 'Low'),
          CampusLookupItem(id: '2', code: 'MEDIUM', label: 'Medium'),
          CampusLookupItem(id: '3', code: 'HIGH', label: 'High'),
          CampusLookupItem(id: '4', code: 'CRITICAL', label: 'Critical'),
        ];

      case 'INCIDENT_STATUS':
        return const [
          CampusLookupItem(id: '1', code: 'REPORTED', label: 'Reported'),
          CampusLookupItem(id: '2', code: 'UNDER_INVESTIGATION', label: 'Under Investigation'),
          CampusLookupItem(id: '3', code: 'ACTION_TAKEN', label: 'Action Taken'),
          CampusLookupItem(id: '4', code: 'RESOLVED', label: 'Resolved'),
          CampusLookupItem(id: '5', code: 'CLOSED', label: 'Closed'),
        ];

      case 'CERTIFICATE_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'FIRE_SAFETY_NOC', label: 'Fire Safety NOC & Clearance'),
          CampusLookupItem(id: '2', code: 'STRUCTURAL_SAFETY', label: 'Building Structural Safety Certificate'),
          CampusLookupItem(id: '3', code: 'ELECTRICAL_FITNESS', label: 'Electrical Installation Fitness Certificate'),
          CampusLookupItem(id: '4', code: 'ELEVATOR_LICENSE', label: 'Elevator / Lift Operating License'),
          CampusLookupItem(id: '5', code: 'SANITATION_HYGIENE', label: 'Sanitation & Public Hygiene Certificate'),
          CampusLookupItem(id: '6', code: 'DRINKING_WATER', label: 'Potable Drinking Water Quality Certificate'),
          CampusLookupItem(id: '7', code: 'POLLUTION_CONTROL', label: 'Pollution Control / DG Set Clearance'),
        ];

      case 'DRILL_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'FIRE_EVACUATION', label: 'Fire Evacuation & Alarm Response Drill'),
          CampusLookupItem(id: '2', code: 'EARTHQUAKE_PREPAREDNESS', label: 'Earthquake Preparedness & Drop-Cover Drill'),
          CampusLookupItem(id: '3', code: 'LOCKDOWN_INTRUDER', label: 'Lockdown / Active Intruder Simulation'),
          CampusLookupItem(id: '4', code: 'MEDICAL_TRIAGE', label: 'Medical Emergency & First Aid Response Drill'),
          CampusLookupItem(id: '5', code: 'SEVERE_WEATHER', label: 'Severe Weather / Storm Shelter Drill'),
        ];

      case 'UTILITY_TYPE':
        return const [
          CampusLookupItem(id: '1', code: 'ELECTRICITY_GRID', label: 'State Power Grid & Substation'),
          CampusLookupItem(id: '2', code: 'SOLAR_PV', label: 'Rooftop Solar PV Generation'),
          CampusLookupItem(id: '3', code: 'DIESEL_GENERATOR', label: 'Backup Diesel Generator Sets (DG)'),
          CampusLookupItem(id: '4', code: 'WATER_SUPPLY', label: 'Municipal Water & Deep Borewells'),
          CampusLookupItem(id: '5', code: 'RO_TREATMENT', label: 'Central RO Water Purification Plant'),
          CampusLookupItem(id: '6', code: 'WASTEWATER_STP', label: 'Sewage Treatment Plant (STP)'),
          CampusLookupItem(id: '7', code: 'CAMPUS_INTERNET', label: 'High-Speed Internet / Optical Fiber Leased Line'),
          CampusLookupItem(id: '8', code: 'PNG_GAS', label: 'Piped Natural Gas (PNG) / Lab LPG Bank'),
        ];

      case 'AREA_UNIT':
        return const [
          CampusLookupItem(id: '1', code: 'SQ_FT', label: 'sq ft'),
          CampusLookupItem(id: '2', code: 'SQ_M', label: 'sq m'),
        ];

      default:
        return [];
    }
  }
}
