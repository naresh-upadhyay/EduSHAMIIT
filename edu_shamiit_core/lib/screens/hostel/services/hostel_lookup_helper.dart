import '../../../../services/api_service.dart';
import '../../../../services/lookup_event_bus.dart';

class HostelLookupItem {
  final String id;
  final String code;
  final String label;
  final String description;
  final String status;
  final int sortOrder;

  const HostelLookupItem({
    required this.id,
    required this.code,
    required this.label,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory HostelLookupItem.fromJson(Map<String, dynamic> json) {
    return HostelLookupItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['value_code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class HostelLookupHelper {
  static final HostelLookupHelper instance = HostelLookupHelper._internal();
  HostelLookupHelper._internal() {
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
  final Map<String, List<HostelLookupItem>> _cache = {};

  /// Fetch active lookup values for a given key_code from DB
  Future<List<HostelLookupItem>> getActiveLookup(
    String keyCode, {
    List<HostelLookupItem>? fallbacks,
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
            .map((e) => HostelLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
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

  /// Get string labels for dropdowns (e.g. ['Standard', 'Deluxe', 'Toilet/Washroom'])
  Future<List<String>> getLookupLabels(
    String keyCode, {
    List<String>? defaultLabels,
    bool forceRefresh = false,
  }) async {
    final items = await getActiveLookup(keyCode, forceRefresh: forceRefresh);
    if (items.isNotEmpty) {
      final labels = <String>[];
      for (final item in items) {
        final l = item.label.trim();
        if (l.isNotEmpty && !labels.contains(l)) {
          labels.add(l);
        }
      }
      if (labels.isNotEmpty) return labels;
    }
    return defaultLabels ?? [];
  }

  /// Invalidate specific or all cached lookups
  void clearCache([String? keyCode]) {
    if (keyCode != null && keyCode.isNotEmpty) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }

  /// Preload common hostel lookup keys in parallel
  Future<void> preloadAllHostelLookups() async {
    await Future.wait([
      getActiveLookup('ACADEMIC_YEAR'),
      getActiveLookup('ROOM_TYPE'),
      getActiveLookup('ROOM_STATUS'),
      getActiveLookup('ROOM_FACILITY'),
      getActiveLookup('HOSTEL_GENDER_POLICY'),
      getActiveLookup('HOSTEL_BED_TYPE'),
      getActiveLookup('FACILITY_CONDITION'),
      getActiveLookup('HOSTEL_STAFF_ROLE'),
      getActiveLookup('HOSTEL_LEAVE_TYPE'),
      getActiveLookup('HOSTEL_COMPLAINT_CATEGORY'),
      getActiveLookup('HOSTEL_COMPLAINT_PRIORITY'),
      getActiveLookup('HOSTEL_FEE_BILLING_PLAN'),
      getActiveLookup('HOSTEL_INITIAL_FEE_PAYMENT_STATUS'),
    ]);
  }

  List<HostelLookupItem> _getDefaultLookups(String keyCode) {
    switch (keyCode) {
      case 'ACADEMIC_YEAR':
      case 'FINANCIAL_YEAR':
        return const [
          HostelLookupItem(id: '1', code: 'AY_2024_25', label: '2024 - 2025'),
          HostelLookupItem(id: '2', code: 'AY_2025_26', label: '2025 - 2026'),
          HostelLookupItem(id: '3', code: 'AY_2026_27', label: '2026 - 2027'),
          HostelLookupItem(id: '4', code: 'AY_2027_28', label: '2027 - 2028'),
        ];
      case 'ROOM_TYPE':
        return const [
          HostelLookupItem(id: '1', code: 'STANDARD', label: 'Standard'),
          HostelLookupItem(id: '2', code: 'DELUXE', label: 'Deluxe'),
          HostelLookupItem(id: '3', code: 'SUPER_DELUXE', label: 'Super Deluxe'),
          HostelLookupItem(id: '4', code: 'DORMITORY', label: 'Dormitory'),
          HostelLookupItem(id: '5', code: 'SINGLE', label: 'Single Occupancy'),
          HostelLookupItem(id: '6', code: 'STUDY_ROOM', label: 'Study Room'),
          HostelLookupItem(id: '7', code: 'TOILET_WASHROOM', label: 'Toilet/Washroom'),
          HostelLookupItem(id: '8', code: 'COMMON_ROOM', label: 'Common Room / Lounge'),
          HostelLookupItem(id: '9', code: 'MESS_DINING', label: 'Mess / Dining Hall'),
          HostelLookupItem(id: '10', code: 'WARDEN_OFFICE', label: 'Warden Office'),
          HostelLookupItem(id: '11', code: 'MEDICAL_ROOM', label: 'Medical / Sick Bay'),
          HostelLookupItem(id: '12', code: 'LAUNDRY', label: 'Laundry Room'),
        ];

      case 'ROOM_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'AVAILABLE', label: 'Available'),
          HostelLookupItem(id: '2', code: 'OCCUPIED', label: 'Occupied'),
          HostelLookupItem(id: '3', code: 'MAINTENANCE', label: 'Maintenance'),
          HostelLookupItem(id: '4', code: 'RESERVED', label: 'Reserved'),
          HostelLookupItem(id: '5', code: 'OPERATIONAL', label: 'Operational'),
        ];

      case 'ROOM_FACILITY':
        return const [
          HostelLookupItem(id: '1', code: 'WESTERN_TOILET', label: 'Western Toilet'),
          HostelLookupItem(id: '2', code: 'URINAL', label: 'Urinal'),
          HostelLookupItem(id: '3', code: 'WASH_BASIN', label: 'Wash Basin'),
          HostelLookupItem(id: '4', code: 'SHOWER', label: 'Shower'),
          HostelLookupItem(id: '5', code: 'GEYSER', label: 'Geyser'),
          HostelLookupItem(id: '6', code: 'MIRROR', label: 'Mirror'),
          HostelLookupItem(id: '7', code: 'EXHAUST_FAN', label: 'Exhaust Fan'),
          HostelLookupItem(id: '8', code: 'WATER_TAP', label: 'Water Tap'),
          HostelLookupItem(id: '9', code: 'HAND_DRYER', label: 'Hand Dryer'),
          HostelLookupItem(id: '10', code: 'SOAP_DISPENSER', label: 'Liquid Soap Dispenser'),
          HostelLookupItem(id: '11', code: 'TOWEL_RAIL', label: 'Towel Rail'),
          HostelLookupItem(id: '12', code: 'BEDS', label: 'Beds'),
          HostelLookupItem(id: '13', code: 'FANS', label: 'Fans'),
          HostelLookupItem(id: '14', code: 'AC', label: 'AC'),
          HostelLookupItem(id: '15', code: 'WIFI', label: 'WiFi'),
          HostelLookupItem(id: '16', code: 'STUDY_TABLE', label: 'Study Table'),
          HostelLookupItem(id: '17', code: 'WARDROBE', label: 'Wardrobe'),
          HostelLookupItem(id: '18', code: 'ATTACHED_WASHROOM', label: 'Attached Washroom'),
          HostelLookupItem(id: '19', code: 'POWER_OUTLETS', label: 'Power Outlets'),
          HostelLookupItem(id: '20', code: 'LIGHTING', label: 'Lighting'),
          HostelLookupItem(id: '21', code: 'BALCONY', label: 'Balcony'),
          HostelLookupItem(id: '22', code: 'TELEVISION', label: 'Television'),
          HostelLookupItem(id: '23', code: 'HOUSEKEEPING', label: 'Housekeeping'),
          HostelLookupItem(id: '24', code: 'WATER_PURIFIER', label: 'Water Purifier'),
          HostelLookupItem(id: '25', code: 'FIRST_AID_KIT', label: 'First Aid Kit'),
          HostelLookupItem(id: '26', code: 'FIRE_EXTINGUISHER', label: 'Fire Extinguisher'),
        ];

      case 'HOSTEL_GENDER_POLICY':
        return const [
          HostelLookupItem(id: '1', code: 'BOYS', label: 'Boys Only'),
          HostelLookupItem(id: '2', code: 'GIRLS', label: 'Girls Only'),
          HostelLookupItem(id: '3', code: 'COED', label: 'Co-Ed'),
          HostelLookupItem(id: '4', code: 'STAFF', label: 'Staff Quarters'),
        ];

      case 'HOSTEL_BED_TYPE':
        return const [
          HostelLookupItem(id: '1', code: 'SINGLE', label: 'Single Bed'),
          HostelLookupItem(id: '2', code: 'BUNK_LOWER', label: 'Bunk Bed (Lower)'),
          HostelLookupItem(id: '3', code: 'BUNK_UPPER', label: 'Bunk Bed (Upper)'),
          HostelLookupItem(id: '4', code: 'DOUBLE', label: 'Double Bed'),
        ];

      case 'FACILITY_CONDITION':
        return const [
          HostelLookupItem(id: '1', code: 'GOOD', label: 'Good'),
          HostelLookupItem(id: '2', code: 'WORKING', label: 'Working'),
          HostelLookupItem(id: '3', code: 'FAULTY', label: 'Faulty'),
          HostelLookupItem(id: '4', code: 'UNDER_REPAIR', label: 'Under Repair'),
          HostelLookupItem(id: '5', code: 'NOT_AVAILABLE', label: 'Not Available'),
          HostelLookupItem(id: '6', code: 'OUT_OF_SERVICE', label: 'Out of Service'),
        ];

      case 'HOSTEL_STAFF_ROLE':
      case 'STAFF_ROLE':
        return const [
          HostelLookupItem(id: '1', code: 'CHIEF_WARDEN', label: 'Chief Warden'),
          HostelLookupItem(id: '2', code: 'WARDEN', label: 'Warden'),
          HostelLookupItem(id: '3', code: 'ASST_WARDEN', label: 'Assistant Warden'),
          HostelLookupItem(id: '4', code: 'CARETAKER', label: 'Caretaker'),
          HostelLookupItem(id: '5', code: 'SECURITY_GUARD', label: 'Security Guard'),
          HostelLookupItem(id: '6', code: 'HOUSEKEEPING', label: 'Housekeeper'),
          HostelLookupItem(id: '7', code: 'ELECTRICIAN', label: 'Electrician'),
          HostelLookupItem(id: '8', code: 'PLUMBER', label: 'Plumber'),
          HostelLookupItem(id: '9', code: 'MESS_SUPERVISOR', label: 'Mess Supervisor'),
          HostelLookupItem(id: '10', code: 'NURSE', label: 'Medical Staff / Nurse'),
        ];

      case 'HOSTEL_STAFF_STATUS':
      case 'STAFF_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'ACTIVE', label: 'Active'),
          HostelLookupItem(id: '2', code: 'ON_DUTY', label: 'On Duty'),
          HostelLookupItem(id: '3', code: 'OFF_DUTY', label: 'Off Duty'),
          HostelLookupItem(id: '4', code: 'ON_LEAVE', label: 'On Leave'),
          HostelLookupItem(id: '5', code: 'INACTIVE', label: 'Inactive'),
        ];

      case 'HOSTEL_LEAVE_TYPE':
      case 'LEAVE_TYPE':
        return const [
          HostelLookupItem(id: '1', code: 'HOME_LEAVE', label: 'Home Leave'),
          HostelLookupItem(id: '2', code: 'LOCAL_OUTING', label: 'Local Outing'),
          HostelLookupItem(id: '3', code: 'NIGHT_OUTING', label: 'Night Outing'),
          HostelLookupItem(id: '4', code: 'MEDICAL_LEAVE', label: 'Medical Leave'),
          HostelLookupItem(id: '5', code: 'VACATION', label: 'Vacation Leave'),
          HostelLookupItem(id: '6', code: 'EMERGENCY', label: 'Emergency Leave'),
          HostelLookupItem(id: '7', code: 'ACADEMIC_TRIP', label: 'Academic / Competition'),
          HostelLookupItem(id: '8', code: 'OTHER', label: 'Other'),
        ];

      case 'HOSTEL_LEAVE_STATUS':
      case 'LEAVE_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'PENDING', label: 'Pending'),
          HostelLookupItem(id: '2', code: 'APPROVED', label: 'Approved'),
          HostelLookupItem(id: '3', code: 'ACTIVE_OUT', label: 'Active Out'),
          HostelLookupItem(id: '4', code: 'COMPLETED', label: 'Completed'),
          HostelLookupItem(id: '5', code: 'OVERDUE', label: 'Overdue'),
          HostelLookupItem(id: '6', code: 'REJECTED', label: 'Rejected'),
          HostelLookupItem(id: '7', code: 'CANCELLED', label: 'Cancelled'),
        ];

      case 'HOSTEL_COMPLAINT_CATEGORY':
      case 'COMPLAINT_CATEGORY':
        return const [
          HostelLookupItem(id: '1', code: 'PLUMBING', label: 'Plumbing'),
          HostelLookupItem(id: '2', code: 'ELECTRICAL', label: 'Electrical'),
          HostelLookupItem(id: '3', code: 'HOUSEKEEPING', label: 'Housekeeping'),
          HostelLookupItem(id: '4', code: 'FURNITURE', label: 'Furniture'),
          HostelLookupItem(id: '5', code: 'AC_HEATING', label: 'AC/Heating'),
          HostelLookupItem(id: '6', code: 'PEST_CONTROL', label: 'Pest Control'),
          HostelLookupItem(id: '7', code: 'FOOD_MESS', label: 'Food & Mess'),
          HostelLookupItem(id: '8', code: 'SECURITY', label: 'Security'),
          HostelLookupItem(id: '9', code: 'INTERNET_WIFI', label: 'Internet/WiFi'),
          HostelLookupItem(id: '10', code: 'OTHER', label: 'Other'),
        ];

      case 'HOSTEL_COMPLAINT_PRIORITY':
      case 'COMPLAINT_PRIORITY':
        return const [
          HostelLookupItem(id: '1', code: 'LOW', label: 'Low'),
          HostelLookupItem(id: '2', code: 'MEDIUM', label: 'Medium'),
          HostelLookupItem(id: '3', code: 'HIGH', label: 'High'),
          HostelLookupItem(id: '4', code: 'URGENT', label: 'Urgent'),
          HostelLookupItem(id: '5', code: 'CRITICAL', label: 'Critical'),
        ];

      case 'HOSTEL_COMPLAINT_STATUS':
      case 'COMPLAINT_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'OPEN', label: 'Open'),
          HostelLookupItem(id: '2', code: 'IN_PROGRESS', label: 'In Progress'),
          HostelLookupItem(id: '3', code: 'PENDING', label: 'Pending'),
          HostelLookupItem(id: '4', code: 'RESOLVED', label: 'Resolved'),
          HostelLookupItem(id: '5', code: 'COMPLETED', label: 'Completed'),
          HostelLookupItem(id: '6', code: 'REJECTED', label: 'Rejected'),
          HostelLookupItem(id: '7', code: 'CANCELLED', label: 'Cancelled'),
        ];

      case 'HOSTEL_FEE_STATUS':
      case 'FEE_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'PAID', label: 'Paid'),
          HostelLookupItem(id: '2', code: 'PARTIAL', label: 'Partial'),
          HostelLookupItem(id: '3', code: 'OVERDUE', label: 'Overdue'),
          HostelLookupItem(id: '4', code: 'UNPAID', label: 'Unpaid'),
          HostelLookupItem(id: '5', code: 'WAIVED', label: 'Waived'),
        ];

      case 'HOSTEL_FEE_BILLING_PLAN':
      case 'FEE_BILLING_PLAN':
        return const [
          HostelLookupItem(id: '1', code: 'MONTHLY', label: 'Monthly', description: 'Billed on a monthly basis'),
          HostelLookupItem(id: '2', code: 'QUARTERLY', label: 'Quarterly', description: 'Billed every 3 months'),
          HostelLookupItem(id: '3', code: 'BI_ANNUAL', label: 'Bi-Annual', description: 'Billed every 6 months'),
          HostelLookupItem(id: '4', code: 'ANNUAL', label: 'Annual', description: 'Billed once per academic year'),
        ];

      case 'HOSTEL_INITIAL_FEE_PAYMENT_STATUS':
      case 'INITIAL_FEE_PAYMENT_STATUS':
        return const [
          HostelLookupItem(id: '1', code: 'PAID', label: 'Paid (Deposit & First Month)', description: 'Security deposit and initial billing period paid in full'),
          HostelLookupItem(id: '2', code: 'PENDING', label: 'Pending Payment', description: 'Admission confirmed, payment pending invoice generation'),
          HostelLookupItem(id: '3', code: 'PARTIAL', label: 'Partial Advance Paid', description: 'Partial token or advance deposit paid'),
          HostelLookupItem(id: '4', code: 'WAIVED', label: 'Waived / Concession', description: 'Fees waived under scholarship or management quota'),
        ];

      case 'GENDER':
        return const [
          HostelLookupItem(id: '1', code: 'MALE', label: 'Male'),
          HostelLookupItem(id: '2', code: 'FEMALE', label: 'Female'),
          HostelLookupItem(id: '3', code: 'OTHER', label: 'Other'),
        ];

      case 'BLOOD_GROUP':
        return const [
          HostelLookupItem(id: '1', code: 'A_POS', label: 'A+'),
          HostelLookupItem(id: '2', code: 'A_NEG', label: 'A-'),
          HostelLookupItem(id: '3', code: 'B_POS', label: 'B+'),
          HostelLookupItem(id: '4', code: 'B_NEG', label: 'B-'),
          HostelLookupItem(id: '5', code: 'O_POS', label: 'O+'),
          HostelLookupItem(id: '6', code: 'O_NEG', label: 'O-'),
          HostelLookupItem(id: '7', code: 'AB_POS', label: 'AB+'),
          HostelLookupItem(id: '8', code: 'AB_NEG', label: 'AB-'),
        ];

      default:
        return const [];
    }
  }
}
