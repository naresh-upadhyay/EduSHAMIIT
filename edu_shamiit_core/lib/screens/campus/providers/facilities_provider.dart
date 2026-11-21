import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_models.dart';
import '../services/campus_api_service.dart';
import '../services/campus_lookup_helper.dart';

class FacilitiesState {
  final List<Map<String, dynamic>> facilities;
  final List<String> categories;
  final List<String> statuses;
  final String searchQuery;
  final String selectedCategory;
  final String selectedStatus;
  final int viewMode; // 0: Grid, 1: Table
  final int currentPage;
  final int pageSize;
  final int? sortColIndex;
  final bool sortAsc;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final int totalCount;

  const FacilitiesState({
    this.facilities = const [],
    this.categories = const ['All Categories'],
    this.statuses = const ['All Statuses'],
    this.searchQuery = '',
    this.selectedCategory = 'All Categories',
    this.selectedStatus = 'All Statuses',
    this.viewMode = 0,
    this.currentPage = 1,
    this.pageSize = 10,
    this.sortColIndex = 0,
    this.sortAsc = true,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.totalCount = 0,
  });

  FacilitiesState copyWith({
    List<Map<String, dynamic>>? facilities,
    List<String>? categories,
    List<String>? statuses,
    String? searchQuery,
    String? selectedCategory,
    String? selectedStatus,
    int? viewMode,
    int? currentPage,
    int? pageSize,
    int? sortColIndex,
    bool? sortAsc,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    int? totalCount,
  }) {
    return FacilitiesState(
      facilities: facilities ?? this.facilities,
      categories: categories ?? this.categories,
      statuses: statuses ?? this.statuses,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      viewMode: viewMode ?? this.viewMode,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      sortColIndex: sortColIndex ?? this.sortColIndex,
      sortAsc: sortAsc ?? this.sortAsc,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class FacilitiesNotifier extends StateNotifier<FacilitiesState> {
  final CampusApiService _apiService;

  FacilitiesNotifier(this._apiService) : super(const FacilitiesState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Fetch dynamic lookups
      final catLookups = await CampusLookupHelper.instance.getLookupLabels(
        'FACILITY_TYPE',
        defaultLabels: [
          'Sports Complex / Ground',
          'Specialized Laboratory',
          'Auditorium & Amphitheater',
          'Library & Learning Commons',
          'Dining & Cafeteria Hub',
          'Health Center & Clinic',
          'Transport Hub & Bus Bay',
          'Robotics & Fabrication Lab',
          'Indoor Gymnasium & Yoga Studio',
          'Student Activity Center',
        ],
      );

      final statLookups = await CampusLookupHelper.instance.getLookupLabels(
        'FACILITY_STATUS',
        defaultLabels: [
          'Operational',
          'Under Maintenance',
          'Reserved / In-Use',
          'Temporarily Closed',
        ],
      );

      final categories = ['All Categories', ...catLookups];
      final statuses = ['All Statuses', ...statLookups];

      // 2. Fetch facilities from DB
      final facRes = await _apiService.getFacilities(page: 1, pageSize: 100);
      final facList = (facRes['data'] as List<dynamic>?) ?? [];

      List<Map<String, dynamic>> facs = [];
      if (facList.isNotEmpty) {
        facs = facList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        // Fallback: Fetch rooms acting as facilities
        final roomsRes = await _apiService.getRooms(page: 1, pageSize: 50);
        final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];

        if (roomsList.isNotEmpty) {
          facs = roomsList.map((r) {
            String cat = 'Specialized Laboratory';
            if (r.roomType.toLowerCase().contains('lab')) {
              cat = 'Specialized Laboratory';
            } else if (r.roomType.toLowerCase().contains('auditorium') || r.roomType.toLowerCase().contains('hall')) {
              cat = 'Auditorium & Amphitheater';
            } else if (r.roomType.toLowerCase().contains('library')) {
              cat = 'Library & Learning Commons';
            } else if (r.roomType.toLowerCase().contains('sports') || r.roomType.toLowerCase().contains('gym')) {
              cat = 'Sports Complex / Ground';
            } else if (r.roomType.toLowerCase().contains('canteen') || r.roomType.toLowerCase().contains('dining')) {
              cat = 'Dining & Cafeteria Hub';
            } else if (r.roomType.toLowerCase().contains('medical') || r.roomType.toLowerCase().contains('clinic')) {
              cat = 'Health Center & Clinic';
            } else {
              cat = 'Student Activity Center';
            }

            return {
              'id': r.id,
              'room_id': r.id,
              'name': r.name.isNotEmpty ? r.name : 'Room ${r.roomNumber}',
              'code': r.roomCode.isNotEmpty ? r.roomCode : r.roomNumber,
              'category': cat,
              'status': r.operationalStatus == 'Available' ? 'Operational' : (r.operationalStatus == 'Under Maintenance' ? 'Under Maintenance' : 'Reserved / In-Use'),
              'building_id': r.buildingId,
              'building_name': r.buildingName ?? 'Academic Complex',
              'floor_name': r.floorName ?? 'Floor ${r.floorLevel ?? 1}',
              'capacity': r.maxCapacity,
              'area': r.area > 0 ? r.area : 1200.0,
              'manager_name': r.responsiblePersonName ?? 'Campus Facility Officer',
              'manager_phone': '+91 98765 43210',
              'equipment_count': r.equipmentCount,
              'description': r.description ?? 'Institutional infrastructure facility for student and academic use.',
            };
          }).toList();
        }
      }

      // Default institutional campus facilities if catalog is empty
      if (facs.isEmpty) {
        facs = [
          {
            'id': 'fac-1',
            'room_id': 'fac-1',
            'name': 'Main Athletic Complex & Football Ground',
            'code': 'SPT-FLD-01',
            'category': 'Sports Complex / Ground',
            'status': 'Operational',
            'building_name': 'Outdoor Campus Sports Ground',
            'floor_name': 'Ground Level',
            'capacity': 1200,
            'area': 65000.0,
            'manager_name': 'Coach R. K. Singh',
            'manager_phone': '+91 98450 11223',
            'equipment_count': 24,
            'description': 'FIFA regulation grass turf field with 400m synthetic running track and floodlighting.',
          },
          {
            'id': 'fac-2',
            'room_id': 'fac-2',
            'name': 'Dr. APJ Abdul Kalam Central Auditorium',
            'code': 'AUD-01',
            'category': 'Auditorium & Amphitheater',
            'status': 'Operational',
            'building_name': 'B4 - Auditorium Block',
            'floor_name': 'Ground & Mezzanine',
            'capacity': 850,
            'area': 9500.0,
            'manager_name': 'Deepak Malhotra',
            'manager_phone': '+91 98220 44556',
            'equipment_count': 42,
            'description': 'Acoustically treated multi-tier auditorium equipped with Dolby 7.1, mechanized stage curtains, and LED video walls.',
          },
        ];
      }

      state = state.copyWith(
        facilities: facs,
        totalCount: facs.length,
        categories: categories,
        statuses: statuses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q, currentPage: 1);
  }

  void setCategory(String cat) {
    state = state.copyWith(selectedCategory: cat, currentPage: 1);
  }

  void setStatus(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
  }

  void setViewMode(int mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size, currentPage: 1);
  }

  void setSorting(int? colIndex, bool asc) {
    state = state.copyWith(sortColIndex: colIndex, sortAsc: asc);
  }

  Future<bool> saveFacility(Map<String, dynamic> payload, {String? facilityId}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _apiService.saveFacility(payload, facilityId: facilityId);
      if (res['success'] == true) {
        await loadData();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> deleteFacility(String id) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final res = await _apiService.deleteFacility(id);
      if (res['success'] == true) {
        await loadData();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final facilitiesProvider = StateNotifierProvider<FacilitiesNotifier, FacilitiesState>((ref) {
  return FacilitiesNotifier(CampusApiService.instance);
});
