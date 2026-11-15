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
    this.rooms = const [],
    this.totalRoomsCount = 0,
    this.roomsPage = 1,
    this.roomsPageSize = 10,
    this.roomsViewMode = 0,
    this.roomSearchQuery = '',
    this.filterFloorId,
    this.filterRoomType,
    this.filterRoomStatus,
    this.filterAssignmentStatus,
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
    List<RoomModel>? rooms,
    int? totalRoomsCount,
    int? roomsPage,
    int? roomsPageSize,
    int? roomsViewMode,
    String? roomSearchQuery,
    String? filterFloorId,
    String? filterRoomType,
    String? filterRoomStatus,
    String? filterAssignmentStatus,
    RoomModel? inspectedRoom,
    String? errorMessage,
    bool clearInspectedRoom = false,
    bool clearSelectedBuilding = false,
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
      rooms: rooms ?? this.rooms,
      totalRoomsCount: totalRoomsCount ?? this.totalRoomsCount,
      roomsPage: roomsPage ?? this.roomsPage,
      roomsPageSize: roomsPageSize ?? this.roomsPageSize,
      roomsViewMode: roomsViewMode ?? this.roomsViewMode,
      roomSearchQuery: roomSearchQuery ?? this.roomSearchQuery,
      filterFloorId: filterFloorId ?? this.filterFloorId,
      filterRoomType: filterRoomType ?? this.filterRoomType,
      filterRoomStatus: filterRoomStatus ?? this.filterRoomStatus,
      filterAssignmentStatus: filterAssignmentStatus ?? this.filterAssignmentStatus,
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
      if (selected == null && buildings.isNotEmpty) {
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
      final details = await _api.getBuildingDetails(buildingId);
      final floors = await _api.getFloors(buildingId, page: state.floorsPage, pageSize: state.floorsPageSize);
      final roomsRes = await _api.getRooms(
        buildingId: buildingId,
        page: state.roomsPage,
        pageSize: state.roomsPageSize,
        search: state.roomSearchQuery,
        floorId: state.filterFloorId,
        roomType: state.filterRoomType,
        operationalStatus: state.filterRoomStatus,
      );

      final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];
      final totalRooms = (roomsRes['total_count'] as int?) ?? roomsList.length;

      state = state.copyWith(
        isFloorsLoading: false,
        isRoomsLoading: false,
        selectedBuildingDetails: details,
        floors: floors,
        totalFloorsCount: floors.length,
        rooms: roomsList,
        totalRoomsCount: totalRooms,
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
    if (state.selectedBuilding?.id == building.id) return;
    state = state.copyWith(
      selectedBuilding: building,
      roomsPage: 1,
      floorsPage: 1,
      filterFloorId: null,
      filterRoomType: null,
      filterRoomStatus: null,
      clearInspectedRoom: true,
    );
    loadBuildingDetails(building.id);
  }

  void setActiveCampusTab(int tabIndex) {
    state = state.copyWith(activeCampusTab: tabIndex);
  }

  void setActiveBuildingSubTab(int subTabIndex) {
    state = state.copyWith(activeBuildingSubTab: subTabIndex);
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

  // Floors pagination & reload
  Future<void> setFloorsPage(int page) async {
    if (state.selectedBuilding == null) return;
    state = state.copyWith(floorsPage: page, isFloorsLoading: true);
    final floors = await _api.getFloors(state.selectedBuilding!.id, page: page, pageSize: state.floorsPageSize);
    state = state.copyWith(isFloorsLoading: false, floors: floors);
  }

  // Rooms filtering, pagination & search
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
    );
    final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];
    final totalRooms = (roomsRes['total_count'] as int?) ?? roomsList.length;

    state = state.copyWith(
      isRoomsLoading: false,
      rooms: roomsList,
      totalRoomsCount: totalRooms,
      roomsPage: targetPage,
    );
  }

  void setRoomSearch(String query) {
    state = state.copyWith(roomSearchQuery: query, roomsPage: 1);
    reloadRooms(page: 1);
  }

  void setFilterFloor(String? floorId) {
    state = state.copyWith(filterFloorId: floorId, roomsPage: 1);
    reloadRooms(page: 1);
  }

  void setFilterRoomType(String? type) {
    state = state.copyWith(filterRoomType: type, roomsPage: 1);
    reloadRooms(page: 1);
  }

  void setFilterRoomStatus(String? status) {
    state = state.copyWith(filterRoomStatus: status, roomsPage: 1);
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
      filterRoomType: null,
      filterRoomStatus: null,
      filterAssignmentStatus: null,
      roomsPage: 1,
    );
    reloadRooms(page: 1);
  }
}

final campusProvider = StateNotifierProvider<CampusNotifier, CampusState>((ref) {
  return CampusNotifier(CampusApiService.instance);
});
