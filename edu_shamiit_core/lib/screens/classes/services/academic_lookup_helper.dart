import '../../../../services/api_service.dart';

class AcademicLookupItem {
  final String id;
  final String code;
  final String label;
  final String description;
  final String status;
  final int sortOrder;

  const AcademicLookupItem({
    required this.id,
    required this.code,
    required this.label,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory AcademicLookupItem.fromJson(Map<String, dynamic> json) {
    return AcademicLookupItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['value_code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class AcademicLookupHelper {
  static final AcademicLookupHelper instance = AcademicLookupHelper._internal();
  AcademicLookupHelper._internal();

  final ApiService _api = ApiService();
  final Map<String, List<AcademicLookupItem>> _cache = {};

  /// Fetch active lookup values for a given key_code. Only active values are returned.
  Future<List<AcademicLookupItem>> getActiveLookup(String keyCode, {List<AcademicLookupItem>? fallbacks, bool forceRefresh = false}) async {
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
            .map((e) => AcademicLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    // Return cached or fallback if API call fails
    final fallbackList = _cache[upperKey] ?? fallbacks ?? _getDefaultLookups(upperKey);
    _cache[upperKey] = fallbackList;
    return fallbackList;
  }

  /// Invalidate specific or all cached lookups
  void clearCache([String? keyCode]) {
    if (keyCode != null && keyCode.isNotEmpty) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }

  /// Get cached active list synchronously if available, otherwise return defaults
  List<AcademicLookupItem> getCachedLookup(String keyCode) {
    final upperKey = keyCode.toUpperCase().trim();
    return _cache[upperKey] ?? _getDefaultLookups(upperKey);
  }

  /// Preload all academic lookup keys in parallel
  Future<void> preloadAllAcademicLookups() async {
    await Future.wait([
      getActiveLookup('FINANCIAL_YEAR'),
      getActiveLookup('ROOM_TYPE'),
      getActiveLookup('ROOM_STATUS'),
      getActiveLookup('CAMPUS_BUILDING'),
      getActiveLookup('BUILDING_FLOOR'),
      getActiveLookup('ROOM_FACILITY'),
      getActiveLookup('CLASS_STAGE'),
      getActiveLookup('SUBJECT_TYPE'),
      getActiveLookup('ACADEMIC_STATUS'),
      getActiveLookup('ALLOCATION_TYPE'),
      getActiveLookup('DEPARTMENT'),
    ]);
  }

  List<AcademicLookupItem> _getDefaultLookups(String keyCode) {
    switch (keyCode) {
      case 'FINANCIAL_YEAR':
        return const [
          AcademicLookupItem(id: '1', code: 'FY_2026_27', label: '2026-27'),
          AcademicLookupItem(id: '2', code: 'FY_2025_26', label: '2025-26'),
          AcademicLookupItem(id: '3', code: 'FY_2024_25', label: '2024-25'),
          AcademicLookupItem(id: '4', code: 'FY_2023_24', label: '2023-24'),
          AcademicLookupItem(id: '5', code: 'FY_2022_23', label: '2022-23'),
          AcademicLookupItem(id: '6', code: 'FY_2021_22', label: '2021-22'),
          AcademicLookupItem(id: '7', code: 'FY_2020_21', label: '2020-21'),
        ];

      case 'DEPARTMENT':
      case 'DEPARTMENTS':
        return const [
          AcademicLookupItem(id: '1', code: 'ACADEMIC', label: 'Academic / Teaching'),
          AcademicLookupItem(id: '2', code: 'ADMINISTRATION', label: 'Administration'),
          AcademicLookupItem(id: '3', code: 'MATHEMATICS', label: 'Mathematics'),
          AcademicLookupItem(id: '4', code: 'SCIENCE', label: 'Science'),
          AcademicLookupItem(id: '5', code: 'LANGUAGES', label: 'English / Languages'),
          AcademicLookupItem(id: '6', code: 'SOCIAL_STUDIES', label: 'Social Studies & Humanities'),
          AcademicLookupItem(id: '7', code: 'COMPUTER_SCIENCE', label: 'Computer Science & IT'),
          AcademicLookupItem(id: '8', code: 'FINANCE', label: 'Finance & Accounts'),
          AcademicLookupItem(id: '9', code: 'HR', label: 'Human Resources'),
          AcademicLookupItem(id: '10', code: 'LIBRARY', label: 'Library & Information'),
          AcademicLookupItem(id: '11', code: 'SPORTS', label: 'Physical Education & Sports'),
          AcademicLookupItem(id: '12', code: 'ARTS', label: 'Arts & Performing Arts'),
          AcademicLookupItem(id: '13', code: 'TRANSPORT', label: 'Transport & Fleet'),
          AcademicLookupItem(id: '14', code: 'HOSTEL', label: 'Hostel & Residential'),
          AcademicLookupItem(id: '15', code: 'SECURITY', label: 'Security & Safety'),
          AcademicLookupItem(id: '16', code: 'HEALTH_CLINIC', label: 'Medical & Health Clinic'),
          AcademicLookupItem(id: '17', code: 'MAINTENANCE', label: 'Maintenance & Facilities'),
          AcademicLookupItem(id: '18', code: 'EXAMINATION', label: 'Examination & Assessment'),
          AcademicLookupItem(id: '19', code: 'STUDENT_AFFAIRS', label: 'Student Affairs & Admissions'),
          AcademicLookupItem(id: '20', code: 'GENERAL', label: 'General / Unassigned'),
        ];

      case 'ROOM_TYPE':
        return const [
          AcademicLookupItem(id: '1', code: 'CLASSROOM', label: 'Classroom'),
          AcademicLookupItem(id: '2', code: 'LABORATORY', label: 'Laboratory'),
          AcademicLookupItem(id: '3', code: 'COMPUTER_LAB', label: 'Computer Lab'),
          AcademicLookupItem(id: '4', code: 'AUDITORIUM', label: 'Auditorium'),
          AcademicLookupItem(id: '5', code: 'LIBRARY', label: 'Library'),
          AcademicLookupItem(id: '6', code: 'STAFF_ROOM', label: 'Staff Room'),
          AcademicLookupItem(id: '7', code: 'ACTIVITY_ROOM', label: 'Activity Room'),
          AcademicLookupItem(id: '8', code: 'ART_CRAFT_STUDIO', label: 'Art & Craft Studio'),
          AcademicLookupItem(id: '9', code: 'MUSIC_DANCE_STUDIO', label: 'Music & Dance Studio'),
          AcademicLookupItem(id: '10', code: 'SPORTS_COMPLEX', label: 'Sports Complex / Gym'),
          AcademicLookupItem(id: '11', code: 'INFIRMARY', label: 'Infirmary / Medical Room'),
          AcademicLookupItem(id: '12', code: 'CONFERENCE_HALL', label: 'Conference Hall'),
          AcademicLookupItem(id: '13', code: 'OTHER', label: 'Other'),
        ];

      case 'ROOM_STATUS':
        return const [
          AcademicLookupItem(id: '1', code: 'AVAILABLE', label: 'Available / In Service'),
          AcademicLookupItem(id: '2', code: 'MAINTENANCE', label: 'Maintenance / Out of Service'),
          AcademicLookupItem(id: '3', code: 'IN_USE', label: 'In Use / Occupied'),
          AcademicLookupItem(id: '4', code: 'RESERVED', label: 'Reserved'),
        ];

      case 'CAMPUS_BUILDING':
      case 'BUILDING':
        return const [
          AcademicLookupItem(id: '1', code: 'BLOCK_A', label: 'Academic Block A'),
          AcademicLookupItem(id: '2', code: 'BLOCK_B', label: 'Academic Block B'),
          AcademicLookupItem(id: '3', code: 'BLOCK_C', label: 'Academic Block C'),
          AcademicLookupItem(id: '4', code: 'ACTIVITY_BLOCK', label: 'Activity Block'),
          AcademicLookupItem(id: '5', code: 'SCIENCE_BLOCK', label: 'Science Block'),
          AcademicLookupItem(id: '6', code: 'ADMIN_BLOCK', label: 'Administrative Block'),
          AcademicLookupItem(id: '7', code: 'NEW_BUILDING', label: 'New Building'),
          AcademicLookupItem(id: '8', code: 'SPORTS_ARENA', label: 'Sports Arena'),
        ];

      case 'BUILDING_FLOOR':
      case 'FLOOR':
        return const [
          AcademicLookupItem(id: '1', code: 'GROUND_FLOOR', label: 'Ground Floor'),
          AcademicLookupItem(id: '2', code: '1ST_FLOOR', label: '1st Floor'),
          AcademicLookupItem(id: '3', code: '2ND_FLOOR', label: '2nd Floor'),
          AcademicLookupItem(id: '4', code: '3RD_FLOOR', label: '3rd Floor'),
          AcademicLookupItem(id: '5', code: '4TH_FLOOR', label: '4th Floor'),
          AcademicLookupItem(id: '6', code: 'BASEMENT', label: 'Basement'),
        ];

      case 'ROOM_FACILITY':
      case 'FACILITIES':
        return const [
          AcademicLookupItem(id: '1', code: 'PROJECTOR', label: 'Projector'),
          AcademicLookupItem(id: '2', code: 'SMART_BOARD', label: 'Smart Board'),
          AcademicLookupItem(id: '3', code: 'AC', label: 'AC'),
          AcademicLookupItem(id: '4', code: 'CCTV', label: 'CCTV'),
          AcademicLookupItem(id: '5', code: 'LAB_EQUIPMENT', label: 'Laboratory Equipment'),
          AcademicLookupItem(id: '6', code: 'COMPUTERS', label: 'Computers'),
          AcademicLookupItem(id: '7', code: 'INTERNET', label: 'Internet'),
          AcademicLookupItem(id: '8', code: 'AUDIO_SYSTEM', label: 'Audio System'),
          AcademicLookupItem(id: '9', code: 'ACCESSIBILITY', label: 'Accessibility'),
          AcademicLookupItem(id: '10', code: 'SAFETY_FUME_HOOD', label: 'Safety Fume Hood'),
          AcademicLookupItem(id: '11', code: 'QUIET_STUDY_PODS', label: 'Quiet Study Pods'),
          AcademicLookupItem(id: '12', code: 'WHITEBOARD', label: 'Whiteboard'),
          AcademicLookupItem(id: '13', code: 'NATURAL_LIGHTING', label: 'Natural Lighting'),
          AcademicLookupItem(id: '14', code: 'EASELS', label: 'Easels'),
          AcademicLookupItem(id: '15', code: 'POTTERY_WHEEL', label: 'Pottery Wheel'),
          AcademicLookupItem(id: '16', code: 'DISPLAY_BOARDS', label: 'Display Boards'),
          AcademicLookupItem(id: '17', code: 'MICROSCOPES', label: 'Microscopes'),
          AcademicLookupItem(id: '18', code: 'SPECIMEN_JARS', label: 'Specimen Jars'),
          AcademicLookupItem(id: '19', code: 'MUSICAL_INSTRUMENTS', label: 'Musical Instruments'),
          AcademicLookupItem(id: '20', code: 'ACOUSTIC_TREATMENT', label: 'Acoustic Treatment'),
          AcademicLookupItem(id: '21', code: 'LIGHTING_RIG', label: 'Lighting Rig'),
          AcademicLookupItem(id: '22', code: 'COFFEE_STATION', label: 'Coffee Station'),
        ];

      case 'CLASS_STAGE':
        return const [
          AcademicLookupItem(id: '1', code: 'PRE_PRIMARY', label: 'Pre-Primary'),
          AcademicLookupItem(id: '2', code: 'PRIMARY', label: 'Primary'),
          AcademicLookupItem(id: '3', code: 'MIDDLE_SCHOOL', label: 'Middle School'),
          AcademicLookupItem(id: '4', code: 'SECONDARY', label: 'Secondary'),
          AcademicLookupItem(id: '5', code: 'SENIOR_SECONDARY', label: 'Senior Secondary'),
        ];

      case 'SUBJECT_TYPE':
        return const [
          AcademicLookupItem(id: '1', code: 'CORE', label: 'Core'),
          AcademicLookupItem(id: '2', code: 'OPTIONAL', label: 'Optional / Elective'),
          AcademicLookupItem(id: '3', code: 'LANGUAGE', label: 'Language'),
          AcademicLookupItem(id: '4', code: 'PRACTICAL', label: 'Practical / Lab'),
          AcademicLookupItem(id: '5', code: 'ACTIVITY', label: 'Activity / Skill'),
          AcademicLookupItem(id: '6', code: 'VOCATIONAL', label: 'Vocational'),
          AcademicLookupItem(id: '7', code: 'CO_CURRICULAR', label: 'Co-Curricular'),
          AcademicLookupItem(id: '8', code: 'OTHER', label: 'Other'),
        ];

      case 'ACADEMIC_STATUS':
        return const [
          AcademicLookupItem(id: '1', code: 'ACTIVE', label: 'Active'),
          AcademicLookupItem(id: '2', code: 'INACTIVE', label: 'Inactive'),
          AcademicLookupItem(id: '3', code: 'ARCHIVED', label: 'Archived'),
        ];

      case 'ALLOCATION_TYPE':
        return const [
          AcademicLookupItem(id: '1', code: 'TIMETABLE', label: 'Timetable / Regular Class'),
          AcademicLookupItem(id: '2', code: 'EXAM', label: 'Exam / Assessment'),
          AcademicLookupItem(id: '3', code: 'EVENT', label: 'Event / Seminar'),
          AcademicLookupItem(id: '4', code: 'MAINTENANCE', label: 'Maintenance'),
          AcademicLookupItem(id: '5', code: 'TEMPORARY', label: 'Temporary Booking'),
        ];

      case 'CALENDAR_CATEGORY':
        return const [
          AcademicLookupItem(id: '1', code: 'ACADEMIC', label: 'Academic'),
          AcademicLookupItem(id: '2', code: 'EVENT', label: 'Event'),
          AcademicLookupItem(id: '3', code: 'HOLIDAY', label: 'Holiday'),
          AcademicLookupItem(id: '4', code: 'MEETING', label: 'Meeting'),
          AcademicLookupItem(id: '5', code: 'EXAMINATION', label: 'Examination'),
          AcademicLookupItem(id: '6', code: 'REMINDER', label: 'Reminder'),
          AcademicLookupItem(id: '7', code: 'PERSONAL', label: 'Personal'),
          AcademicLookupItem(id: '8', code: 'TASK', label: 'Task'),
          AcademicLookupItem(id: '9', code: 'CLASS', label: 'Class'),
          AcademicLookupItem(id: '10', code: 'TRAINING', label: 'Training'),
          AcademicLookupItem(id: '11', code: 'TRIP', label: 'Trip'),
          AcademicLookupItem(id: '12', code: 'LEAVE', label: 'Leave'),
          AcademicLookupItem(id: '13', code: 'GENERAL', label: 'General'),
          AcademicLookupItem(id: '14', code: 'SPORTS', label: 'Sports'),
          AcademicLookupItem(id: '15', code: 'ANNIVERSARY', label: 'Anniversary'),
        ];

      default:
        return const [];
    }
  }
}
