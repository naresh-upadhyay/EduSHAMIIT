import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campus_models.dart';
import '../services/campus_api_service.dart';

class CampusState {
  final bool isLoading;
  final bool isFloorsLoading;
  final bool isRoomsLoading;
  final int activeCampusTab; // 0: Buildings & Rooms, 1: Facilities, 2: Space Booking, etc.
  final CampusKpis kpis;
  final Map<String, dynamic> lookups;

  // Buildings list
  final List<BuildingModel> buildings;
  final int totalBuildingsCount;
  final BuildingModel? selectedBuilding;
  final Map<String, dynamic>? selectedBuildingDetails;
  final int activeBuildingSubTab; // 0: Floors, 1: Rooms, 2: Occupancy, 3: Maintenance, 4: Documents
  final String buildingSearchQuery;

  // Floors
  final List<BuildingFloorModel> floors;
  final int totalFloorsCount;
  final int floorsPage;
  final int floorsPageSize;
  final String? floorsSortBy;
  final String? floorsSortOrder;

  // Rooms
  final List<RoomModel> rooms;
  final int totalRoomsCount;
  final int roomsPage;
  final int roomsPageSize;
  final int roomsViewMode; // 0: Table, 1: Grid
  final String roomSearchQuery;
  final String? filterFloorId;
  final String? filterRoomType;
  final String? filterRoomStatus;
  final String? filterAssignmentStatus;
  final String? roomsSortBy;
  final String? roomsSortOrder;

  // Building Documents
  final List<BuildingDocumentModel> buildingDocuments;
  final bool isDocumentsLoading;

  // Building Occupancy (Dynamic Space Booking Driven)
  final List<BuildingOccupancyModel> buildingOccupancy;
  final Map<String, dynamic> occupancyMetrics;
  final bool isOccupancyLoading;
  final String? selectedOccupancyDate;
  final String occupancyFilterStatus; // 'ALL', 'OCCUPIED_NOW', 'AVAILABLE_NOW', 'SCHEDULED_TODAY', 'MAINTENANCE'
  final String occupancySearchQuery;
  final BuildingOccupancyModel? selectedOccupancyRoom;

  // Building Maintenance
  final List<BuildingMaintenanceModel> buildingMaintenance;
  final bool isMaintenanceLoading;

  // Inspect drawer
  final RoomModel? inspectedRoom;
  final String? errorMessage;

  const CampusState({
    this.isLoading = false,
    this.isFloorsLoading = false,
    this.isRoomsLoading = false,
    this.activeCampusTab = 0,
    this.kpis = const CampusKpis(),
    this.lookups = const {},
    this.buildings = const [],
    this.totalBuildingsCount = 0,
    this.selectedBuilding,
    this.selectedBuildingDetails,
    this.activeBuildingSubTab = 0,
    this.buildingSearchQuery = '',
    this.floors = const [],
    this.totalFloorsCount = 0,
    this.floorsPage = 1,
    this.floorsPageSize = 10,
    this.floorsSortBy,
    this.floorsSortOrder = 'asc',
    this.rooms = const [],
    this.totalRoomsCount = 0,
    this.roomsPage = 1,
    this.roomsPageSize = 10,
    this.roomsSortBy,
    this.roomsSortOrder = 'asc',
    this.roomsViewMode = 0,
    this.roomSearchQuery = '',
    this.filterFloorId,
    this.filterRoomType,
    this.filterRoomStatus,
    this.filterAssignmentStatus,
    this.buildingDocuments = const [],
    this.isDocumentsLoading = false,
    this.buildingOccupancy = const [],
    this.occupancyMetrics = const {},
    this.isOccupancyLoading = false,
    this.selectedOccupancyDate,
    this.occupancyFilterStatus = 'ALL',
    this.occupancySearchQuery = '',
    this.selectedOccupancyRoom,
    this.buildingMaintenance = const [],
    this.isMaintenanceLoading = false,
    this.inspectedRoom,
    this.errorMessage,
  });

  CampusState copyWith({
    bool? isLoading,
    bool? isFloorsLoading,
    bool? isRoomsLoading,
    int? activeCampusTab,
    CampusKpis? kpis,
    Map<String, dynamic>? lookups,
    List<BuildingModel>? buildings,
    int? totalBuildingsCount,
    BuildingModel? selectedBuilding,
    Map<String, dynamic>? selectedBuildingDetails,
    int? activeBuildingSubTab,
    String? buildingSearchQuery,
    List<BuildingFloorModel>? floors,
    int? totalFloorsCount,
    int? floorsPage,
    int? floorsPageSize,
    String? floorsSortBy,
    String? floorsSortOrder,
    List<RoomModel>? rooms,
    int? totalRoomsCount,
    int? roomsPage,
    int? roomsPageSize,
    String? roomsSortBy,
    String? roomsSortOrder,
    int? roomsViewMode,
    String? roomSearchQuery,
    String? filterFloorId,
    String? filterRoomType,
    String? filterRoomStatus,
    String? filterAssignmentStatus,
    List<BuildingDocumentModel>? buildingDocuments,
    bool? isDocumentsLoading,
    List<BuildingOccupancyModel>? buildingOccupancy,
    Map<String, dynamic>? occupancyMetrics,
    bool? isOccupancyLoading,
    String? selectedOccupancyDate,
    String? occupancyFilterStatus,
    String? occupancySearchQuery,
    BuildingOccupancyModel? selectedOccupancyRoom,
    bool clearSelectedOccupancyRoom = false,
    List<BuildingMaintenanceModel>? buildingMaintenance,
    bool? isMaintenanceLoading,
    RoomModel? inspectedRoom,
    String? errorMessage,
    bool clearInspectedRoom = false,
    bool clearSelectedBuilding = false,
    bool clearFloorFilter = false,
    bool clearRoomTypeFilter = false,
    bool clearRoomStatusFilter = false,
    bool clearAssignmentFilter = false,
  }) {
    return CampusState(
      isLoading: isLoading ?? this.isLoading,
      isFloorsLoading: isFloorsLoading ?? this.isFloorsLoading,
      isRoomsLoading: isRoomsLoading ?? this.isRoomsLoading,
      activeCampusTab: activeCampusTab ?? this.activeCampusTab,
      kpis: kpis ?? this.kpis,
      lookups: lookups ?? this.lookups,
      buildings: buildings ?? this.buildings,
      totalBuildingsCount: totalBuildingsCount ?? this.totalBuildingsCount,
      selectedBuilding: clearSelectedBuilding ? null : (selectedBuilding ?? this.selectedBuilding),
      selectedBuildingDetails: selectedBuildingDetails ?? this.selectedBuildingDetails,
      activeBuildingSubTab: activeBuildingSubTab ?? this.activeBuildingSubTab,
      buildingSearchQuery: buildingSearchQuery ?? this.buildingSearchQuery,
      floors: floors ?? this.floors,
      totalFloorsCount: totalFloorsCount ?? this.totalFloorsCount,
      floorsPage: floorsPage ?? this.floorsPage,
      floorsPageSize: floorsPageSize ?? this.floorsPageSize,
      floorsSortBy: floorsSortBy ?? this.floorsSortBy,
      floorsSortOrder: floorsSortOrder ?? this.floorsSortOrder,
      rooms: rooms ?? this.rooms,
      totalRoomsCount: totalRoomsCount ?? this.totalRoomsCount,
      roomsPage: roomsPage ?? this.roomsPage,
      roomsPageSize: roomsPageSize ?? this.roomsPageSize,
      roomsSortBy: roomsSortBy ?? this.roomsSortBy,
      roomsSortOrder: roomsSortOrder ?? this.roomsSortOrder,
      roomsViewMode: roomsViewMode ?? this.roomsViewMode,
      roomSearchQuery: roomSearchQuery ?? this.roomSearchQuery,
      filterFloorId: clearFloorFilter ? null : (filterFloorId ?? this.filterFloorId),
      filterRoomType: clearRoomTypeFilter ? null : (filterRoomType ?? this.filterRoomType),
      filterRoomStatus: clearRoomStatusFilter ? null : (filterRoomStatus ?? this.filterRoomStatus),
      filterAssignmentStatus: clearAssignmentFilter ? null : (filterAssignmentStatus ?? this.filterAssignmentStatus),
      buildingDocuments: buildingDocuments ?? this.buildingDocuments,
      isDocumentsLoading: isDocumentsLoading ?? this.isDocumentsLoading,
      buildingOccupancy: buildingOccupancy ?? this.buildingOccupancy,
      occupancyMetrics: occupancyMetrics ?? this.occupancyMetrics,
      isOccupancyLoading: isOccupancyLoading ?? this.isOccupancyLoading,
      selectedOccupancyDate: selectedOccupancyDate ?? this.selectedOccupancyDate,
      occupancyFilterStatus: occupancyFilterStatus ?? this.occupancyFilterStatus,
      occupancySearchQuery: occupancySearchQuery ?? this.occupancySearchQuery,
      selectedOccupancyRoom: clearSelectedOccupancyRoom ? null : (selectedOccupancyRoom ?? this.selectedOccupancyRoom),
      buildingMaintenance: buildingMaintenance ?? this.buildingMaintenance,
      isMaintenanceLoading: isMaintenanceLoading ?? this.isMaintenanceLoading,
      inspectedRoom: clearInspectedRoom ? null : (inspectedRoom ?? this.inspectedRoom),
      errorMessage: errorMessage,
    );
  }
}

class CampusNotifier extends StateNotifier<CampusState> {
  final CampusApiService _api;

  CampusNotifier(this._api) : super(const CampusState(isLoading: true));

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final kpisFuture = _api.getKpis();
      final lookupsFuture = _api.getLookups();
      final buildingsFuture = _api.getBuildings(page: 1, pageSize: 20);

      final results = await Future.wait([kpisFuture, lookupsFuture, buildingsFuture]);

      final kpis = results[0] as CampusKpis;
      final lookups = results[1] as Map<String, dynamic>;
      final bldRes = results[2] as Map<String, dynamic>;
      final buildings = (bldRes['data'] as List<BuildingModel>?) ?? [];
      final totalBuildings = (bldRes['total_count'] as int?) ?? buildings.length;

      BuildingModel? selected = state.selectedBuilding;
      if (selected != null) {
        selected = buildings.firstWhere(
          (b) => b.id == selected!.id,
          orElse: () => buildings.isNotEmpty ? buildings.first : selected!,
        );
      } else if (buildings.isNotEmpty) {
        selected = buildings.first;
      }

      state = state.copyWith(
        isLoading: false,
        kpis: kpis,
        lookups: lookups,
        buildings: buildings,
        totalBuildingsCount: totalBuildings,
        selectedBuilding: selected,
      );

      if (selected != null) {
        await loadBuildingDetails(selected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadBuildingDetails(String buildingId) async {
    state = state.copyWith(isFloorsLoading: true, isRoomsLoading: true);
    try {
      final results = await Future.wait([
        _api.getBuildingDetails(buildingId).catchError((_) => <String, dynamic>{}),
        _api.getFloors(
          buildingId,
          page: state.floorsPage,
          pageSize: state.floorsPageSize,
          sortBy: state.floorsSortBy,
          sortOrder: state.floorsSortOrder,
        ).catchError((_) => <BuildingFloorModel>[]),
        _api.getRooms(
          buildingId: buildingId,
          page: state.roomsPage,
          pageSize: state.roomsPageSize,
          search: state.roomSearchQuery,
          floorId: state.filterFloorId,
          roomType: state.filterRoomType,
          operationalStatus: state.filterRoomStatus,
          assignmentStatus: state.filterAssignmentStatus,
          sortBy: state.roomsSortBy,
          sortOrder: state.roomsSortOrder,
        ).catchError((_) => <String, dynamic>{}),
      ]);

      final details = results[0] as Map<String, dynamic>;
      final floors = results[1] as List<BuildingFloorModel>;
      final roomsRes = results[2] as Map<String, dynamic>;

      final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];
      final totalRooms = (roomsRes['total_count'] as int?) ?? roomsList.length;

      RoomModel? freshInspected = state.inspectedRoom;
      if (freshInspected != null) {
        final match = roomsList.cast<RoomModel?>().firstWhere(
          (r) => r?.id == freshInspected!.id,
          orElse: () => null,
        );
        if (match != null) {
          freshInspected = match;
        }
      }

      state = state.copyWith(
        isFloorsLoading: false,
        isRoomsLoading: false,
        selectedBuildingDetails: details.isNotEmpty ? details : state.selectedBuildingDetails,
        floors: floors,
        totalFloorsCount: floors.length,
        rooms: roomsList,
        totalRoomsCount: totalRooms,
        inspectedRoom: freshInspected,
      );
    } catch (e) {
      state = state.copyWith(
        isFloorsLoading: false,
        isRoomsLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void selectBuilding(BuildingModel building) {
    state = state.copyWith(
      selectedBuilding: building,
      roomsPage: 1,
      floorsPage: 1,
      filterFloorId: null,
      clearFloorFilter: true,
      filterRoomType: null,
      clearRoomTypeFilter: true,
      filterRoomStatus: null,
      clearRoomStatusFilter: true,
      filterAssignmentStatus: null,
      clearAssignmentFilter: true,
      clearInspectedRoom: true,
    );
    loadBuildingDetails(building.id);
    if (state.activeBuildingSubTab == 2) {
      loadBuildingOccupancy(building.id);
    } else if (state.activeBuildingSubTab == 3) {
      loadBuildingMaintenance(building.id);
    } else if (state.activeBuildingSubTab == 4) {
      loadBuildingDocuments(building.id);
    }
  }

  void updateBuildingImage(String buildingId, String imageUrl) {
    final updatedBuildings = state.buildings.map((b) {
      if (b.id == buildingId) {
        return b.copyWith(imageUrl: imageUrl);
      }
      return b;
    }).toList();

    BuildingModel? updatedSelected = state.selectedBuilding;
    if (updatedSelected != null && updatedSelected.id == buildingId) {
      updatedSelected = updatedSelected.copyWith(imageUrl: imageUrl);
    }

    state = state.copyWith(
      buildings: updatedBuildings,
      selectedBuilding: updatedSelected,
    );
  }

  void setActiveCampusTab(int tabIndex) {
    state = state.copyWith(activeCampusTab: tabIndex);
  }

  void setActiveBuildingSubTab(int subTabIndex) {
    state = state.copyWith(activeBuildingSubTab: subTabIndex);
    if (state.selectedBuilding != null) {
      if (subTabIndex == 1 && state.rooms.isEmpty) {
        reloadRooms(page: 1);
      } else if (subTabIndex == 2) {
        loadBuildingOccupancy(state.selectedBuilding!.id);
      } else if (subTabIndex == 3) {
        loadBuildingMaintenance(state.selectedBuilding!.id);
      } else if (subTabIndex == 4) {
        loadBuildingDocuments(state.selectedBuilding!.id);
      }
    }
  }

  void setBuildingSearchQuery(String query) async {
    state = state.copyWith(buildingSearchQuery: query);
    final res = await _api.getBuildings(search: query, page: 1, pageSize: 20);
    final buildings = (res['data'] as List<BuildingModel>?) ?? [];
    state = state.copyWith(
      buildings: buildings,
      totalBuildingsCount: (res['total_count'] as int?) ?? buildings.length,
    );
  }

  // Floors pagination, sorting & reload
  Future<void> setFloorsPage(int page) async {
    if (state.selectedBuilding == null) return;
    state = state.copyWith(floorsPage: page, isFloorsLoading: true);
    final floors = await _api.getFloors(
      state.selectedBuilding!.id,
      page: page,
      pageSize: state.floorsPageSize,
      sortBy: state.floorsSortBy,
      sortOrder: state.floorsSortOrder,
    );
    state = state.copyWith(isFloorsLoading: false, floors: floors);
  }

  Future<void> setFloorsPageSize(int pageSize) async {
    if (state.selectedBuilding == null) return;
    state = state.copyWith(floorsPageSize: pageSize, floorsPage: 1, isFloorsLoading: true);
    final floors = await _api.getFloors(
      state.selectedBuilding!.id,
      page: 1,
      pageSize: pageSize,
      sortBy: state.floorsSortBy,
      sortOrder: state.floorsSortOrder,
    );
    state = state.copyWith(isFloorsLoading: false, floors: floors, floorsPage: 1);
  }

  Future<void> setFloorSort(String columnKey, bool ascending) async {
    if (state.selectedBuilding == null) return;
    final sortOrder = ascending ? 'asc' : 'desc';
    state = state.copyWith(
      floorsSortBy: columnKey,
      floorsSortOrder: sortOrder,
      isFloorsLoading: true,
      floorsPage: 1,
    );
    final floors = await _api.getFloors(
      state.selectedBuilding!.id,
      page: 1,
      pageSize: state.floorsPageSize,
      sortBy: columnKey,
      sortOrder: sortOrder,
    );
    state = state.copyWith(isFloorsLoading: false, floors: floors, floorsPage: 1);
  }

  // Rooms filtering, pagination & search
  Future<void> setRoomsPage(int page) async {
    await reloadRooms(page: page);
  }

  Future<void> setRoomsPageSize(int pageSize) async {
    state = state.copyWith(roomsPageSize: pageSize, roomsPage: 1);
    await reloadRooms(page: 1);
  }

  Future<void> setRoomSort(String columnKey, bool ascending) async {
    final sortOrder = ascending ? 'asc' : 'desc';
    state = state.copyWith(
      roomsSortBy: columnKey,
      roomsSortOrder: sortOrder,
      roomsPage: 1,
    );
    await reloadRooms(page: 1);
  }

  Future<void> reloadRooms({int? page}) async {
    if (state.selectedBuilding == null) return;
    final targetPage = page ?? state.roomsPage;
    state = state.copyWith(isRoomsLoading: true, roomsPage: targetPage);
    final roomsRes = await _api.getRooms(
      buildingId: state.selectedBuilding!.id,
      page: targetPage,
      pageSize: state.roomsPageSize,
      search: state.roomSearchQuery,
      floorId: state.filterFloorId,
      roomType: state.filterRoomType,
      operationalStatus: state.filterRoomStatus,
      assignmentStatus: state.filterAssignmentStatus,
      sortBy: state.roomsSortBy,
      sortOrder: state.roomsSortOrder,
    );
    final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];
    final totalRooms = (roomsRes['total_count'] as int?) ?? roomsList.length;

    RoomModel? freshInspected = state.inspectedRoom;
    if (freshInspected != null) {
      final match = roomsList.cast<RoomModel?>().firstWhere(
        (r) => r?.id == freshInspected!.id,
        orElse: () => null,
      );
      if (match != null) {
        freshInspected = match;
      }
    }

    state = state.copyWith(
      isRoomsLoading: false,
      rooms: roomsList,
      totalRoomsCount: totalRooms,
      roomsPage: targetPage,
      inspectedRoom: freshInspected,
    );
  }

  void setRoomSearch(String query) {
    state = state.copyWith(roomSearchQuery: query, roomsPage: 1);
    reloadRooms(page: 1);
  }

  void setFilterFloor(String? floorId) {
    state = state.copyWith(
      filterFloorId: floorId,
      clearFloorFilter: floorId == null,
      roomsPage: 1,
    );
    reloadRooms(page: 1);
  }

  void setFilterRoomType(String? type) {
    state = state.copyWith(
      filterRoomType: type,
      clearRoomTypeFilter: type == null || type == 'All',
      roomsPage: 1,
    );
    reloadRooms(page: 1);
  }

  void setFilterRoomStatus(String? status) {
    state = state.copyWith(
      filterRoomStatus: status,
      clearRoomStatusFilter: status == null || status == 'All',
      roomsPage: 1,
    );
    reloadRooms(page: 1);
  }

  void setRoomsViewMode(int mode) {
    state = state.copyWith(roomsViewMode: mode);
  }

  void inspectRoom(RoomModel? room) {
    state = state.copyWith(inspectedRoom: room, clearInspectedRoom: room == null);
  }

  void clearFilters() {
    state = state.copyWith(
      roomSearchQuery: '',
      filterFloorId: null,
      clearFloorFilter: true,
      filterRoomType: null,
      clearRoomTypeFilter: true,
      filterRoomStatus: null,
      clearRoomStatusFilter: true,
      filterAssignmentStatus: null,
      clearAssignmentFilter: true,
      roomsPage: 1,
    );
    reloadRooms(page: 1);
  }

  /// Called after a room is created/updated so it instantly appears in the grid
  Future<void> onRoomCreated(String buildingId, {String? targetFloorId}) async {
    state = state.copyWith(
      filterFloorId: targetFloorId,
      clearFloorFilter: targetFloorId == null,
      roomSearchQuery: '',
      clearRoomTypeFilter: true,
      clearRoomStatusFilter: true,
      clearAssignmentFilter: true,
      roomsPage: 1,
      activeBuildingSubTab: 1,
    );
    await loadBuildingDetails(buildingId);

    // If rooms list is empty but building has rooms (e.g. floor mismatch), auto-clear floor filter so room is visible
    if (state.rooms.isEmpty && state.totalRoomsCount > 0 && state.filterFloorId != null) {
      state = state.copyWith(
        filterFloorId: null,
        clearFloorFilter: true,
        roomsPage: 1,
      );
      await loadBuildingDetails(buildingId);
    }
  }

  // =========================================================================
  // SUBTAB 4: Building Documents CRUD
  // =========================================================================
  Future<void> loadBuildingDocuments(String buildingId) async {
    state = state.copyWith(isDocumentsLoading: true);
    try {
      final docs = await _api.getBuildingDocuments(buildingId);
      state = state.copyWith(isDocumentsLoading: false, buildingDocuments: docs);
    } catch (e) {
      state = state.copyWith(isDocumentsLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> saveBuildingDocument(String buildingId, Map<String, dynamic> payload, {String? docId}) async {
    final res = await _api.saveBuildingDocument(buildingId, payload, docId: docId);
    if (res['success'] == true) {
      await loadBuildingDocuments(buildingId);
      return true;
    }
    return false;
  }

  Future<bool> deleteBuildingDocument(String buildingId, String docId) async {
    final res = await _api.deleteBuildingDocument(buildingId, docId);
    if (res['success'] == true) {
      await loadBuildingDocuments(buildingId);
      return true;
    }
    return false;
  }

  // =========================================================================
  // SUBTAB 2: Building Occupancy CRUD (Dynamic Space Booking Driven)
  // =========================================================================
  Future<void> loadBuildingOccupancy(
    String buildingId, {
    String? targetDate,
    String? statusFilter,
    String? floorId,
    String? roomType,
    String? search,
  }) async {
    state = state.copyWith(isOccupancyLoading: true);
    try {
      final dateToUse = targetDate ?? state.selectedOccupancyDate;
      final statusToUse = statusFilter ?? state.occupancyFilterStatus;
      final searchToUse = search ?? state.occupancySearchQuery;

      final res = await _api.getBuildingOccupancy(
        buildingId,
        targetDate: dateToUse,
        statusFilter: statusToUse,
        floorId: floorId,
        roomType: roomType,
        search: searchToUse,
        pageSize: 200,
      );
      final list = (res['data'] as List<BuildingOccupancyModel>?) ?? [];
      final metrics = (res['metrics'] as Map<String, dynamic>?) ?? {};

      // Preserve or update selected occupancy room for the inspector
      BuildingOccupancyModel? updatedSelectedRoom;
      if (state.selectedOccupancyRoom != null) {
        final match = list.where((r) => r.roomId == state.selectedOccupancyRoom!.roomId);
        if (match.isNotEmpty) {
          updatedSelectedRoom = match.first;
        }
      }

      state = state.copyWith(
        isOccupancyLoading: false,
        buildingOccupancy: list,
        occupancyMetrics: metrics,
        selectedOccupancyDate: res['target_date']?.toString() ?? dateToUse,
        selectedOccupancyRoom: updatedSelectedRoom,
      );
    } catch (e) {
      state = state.copyWith(isOccupancyLoading: false, errorMessage: e.toString());
    }
  }

  void setOccupancyDate(String dateStr) {
    state = state.copyWith(selectedOccupancyDate: dateStr);
    if (state.selectedBuilding != null) {
      loadBuildingOccupancy(state.selectedBuilding!.id, targetDate: dateStr);
    }
  }

  void setOccupancyFilterStatus(String status) {
    state = state.copyWith(occupancyFilterStatus: status);
    if (state.selectedBuilding != null) {
      loadBuildingOccupancy(state.selectedBuilding!.id, statusFilter: status);
    }
  }

  void setOccupancySearchQuery(String query) {
    state = state.copyWith(occupancySearchQuery: query);
    if (state.selectedBuilding != null) {
      loadBuildingOccupancy(state.selectedBuilding!.id, search: query);
    }
  }

  void selectOccupancyRoom(BuildingOccupancyModel? room) {
    if (room == null) {
      state = state.copyWith(clearSelectedOccupancyRoom: true);
    } else {
      state = state.copyWith(selectedOccupancyRoom: room);
    }
  }

  Future<Map<String, dynamic>> assignClassSectionToRoom(String buildingId, Map<String, dynamic> payload) async {
    final res = await _api.assignClassSectionToRoom(buildingId, payload);
    if (res['success'] == true) {
      await loadBuildingOccupancy(buildingId);
      await loadBuildingDetails(buildingId);
    }
    return res;
  }

  Future<bool> saveBuildingOccupancy(String buildingId, Map<String, dynamic> payload, {String? assignmentId}) async {
    final res = await _api.saveBuildingOccupancy(buildingId, payload, assignmentId: assignmentId);
    if (res['success'] == true) {
      await loadBuildingOccupancy(buildingId);
      await loadBuildingDetails(buildingId);
      return true;
    }
    return false;
  }

  Future<bool> deleteBuildingOccupancy(String buildingId, String assignmentId) async {
    final res = await _api.deleteBuildingOccupancy(buildingId, assignmentId);
    if (res['success'] == true) {
      await loadBuildingOccupancy(buildingId);
      await loadBuildingDetails(buildingId);
      return true;
    }
    return false;
  }

  // =========================================================================
  // SUBTAB 3: Building Maintenance CRUD
  // =========================================================================
  Future<void> loadBuildingMaintenance(String buildingId) async {
    state = state.copyWith(isMaintenanceLoading: true);
    try {
      final items = await _api.getBuildingMaintenance(buildingId);
      state = state.copyWith(isMaintenanceLoading: false, buildingMaintenance: items);
    } catch (e) {
      state = state.copyWith(isMaintenanceLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> saveBuildingMaintenance(String buildingId, Map<String, dynamic> payload, {String? requestId}) async {
    final res = await _api.saveBuildingMaintenance(buildingId, payload, requestId: requestId);
    if (res['success'] == true) {
      await loadBuildingMaintenance(buildingId);
      return true;
    }
    return false;
  }

  Future<bool> deleteBuildingMaintenance(String buildingId, String requestId) async {
    final res = await _api.deleteBuildingMaintenance(buildingId, requestId);
    if (res['success'] == true) {
      await loadBuildingMaintenance(buildingId);
      return true;
    }
    return false;
  }

  Future<bool> updateBuildingMaintenanceStatus(String buildingId, String requestId, String status) async {
    final res = await _api.saveBuildingMaintenance(buildingId, {'status': status}, requestId: requestId);
    if (res['success'] == true) {
      await loadBuildingMaintenance(buildingId);
      return true;
    }
    return false;
  }
}

final campusProvider = StateNotifierProvider<CampusNotifier, CampusState>((ref) {
  return CampusNotifier(CampusApiService.instance);
});
