import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_management_models.dart';
import '../services/device_management_api_service.dart';

class DeviceManagementState {
  final bool isLoading;
  final bool isDevicesLoading;
  final DeviceManagementKpis kpis;
  final List<BuildingDeviceBreakdown> buildingsBreakdown;
  final List<DeviceTypeBreakdown> devicesByType;
  final List<EnergyDataPoint> energyData;
  final Map<String, List<EnergyDataPoint>> allEnergyData;
  final String energyTimePeriod;
  final List<ActiveAutomationItem> activeAutomations;
  final List<DeviceSceneItem> scenes;
  final List<DeviceAlertItem> recentAlerts;
  final List<DeviceItemModel> devices;
  final int totalDevices;
  final int currentPage;
  final int pageSize;
  final int selectedSubNavIndex;
  final String activeTableTab;
  final String searchQuery;
  final String? filterBuilding;
  final String? filterFloor;
  final String? filterRoom;
  final String? filterType;
  final String? filterStatus;
  final Set<String> selectedDeviceIds;
  final LocationTreeNode? locationTree;
  final String selectedCampusBuildingCode;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> automationsList;
  final List<Map<String, dynamic>> schedulesList;
  final List<Map<String, dynamic>> alertsList;
  final List<Map<String, dynamic>> auditLogsList;
  final DeviceTypesProfilesKpis typesProfilesKpis;
  final List<DeviceTypeDetailItem> deviceTypesList;
  final int totalDeviceTypes;
  final int deviceTypesPage;
  final int deviceTypesPageSize;
  final int deviceTypesTotalPages;
  final String? selectedDeviceTypeId;
  final DeviceTypeDetailItem? selectedDeviceTypeDetail;
  final List<DeviceProfileItem> deviceProfilesList;
  final List<CapabilityTemplateItem> capabilitiesLibrary;
  final String typesActiveSubTab;
  final String typesSearchQuery;
  final String typesFilterCategory;
  final String typesFilterStatus;
  final bool typesIsGridView;
  final bool isTypesLoading;
  final DeviceGroupsKpis groupsKpis;
  final List<DeviceGroupItem> groupsList;
  final int totalGroupsCount;
  final int groupsPage;
  final int groupsPageSize;
  final int groupsTotalPages;
  final String? selectedGroupId;
  final DeviceGroupItem? selectedGroupDetail;
  final String groupsActiveSubTab;
  final String groupsSearchQuery;
  final String groupsFilterLocation;
  final String groupsFilterType;
  final String groupsFilterProfile;
  final bool groupsIsGridView;
  final bool isGroupsLoading;
  final List<Map<String, dynamic>> selectedGroupMembers;
  final LocationsMappingKpis locationsKpis;
  final LocationHierarchyNode? locationsHierarchy;
  final String selectedLocationFloorId;
  final String? selectedLocationBuildingId;
  final String? selectedLocationRoomId;
  final LocationDetailsModel? selectedLocationDetails;
  final List<DeviceLocationMappingItem> locationMappedDevices;
  final int locationDevicesTotal;
  final int locationDevicesPage;
  final int locationDevicesPageSize;
  final String locationActiveSubTab;
  final String locationDeviceTypeFilter;
  final String locationGroupFilter;
  final String locationProfileFilter;
  final String locationStatusFilter;
  final String locationSearchQuery;
  final bool locationIsGridView;
  final FloorPlanAssetModel? floorPlanAsset;
  final List<FloorPlanMarkerModel> floorPlanMarkers;
  final FloorPlanLegendModel floorPlanLegend;
  final bool isLocationsLoading;
  final bool isLocationDevicesLoading;

  // Live Control State
  final LiveControlKpis liveControlKpis;
  final List<LiveControlDeviceItem> liveControlDevices;
  final String? selectedLiveDeviceId;
  final LiveControlDeviceItem? selectedLiveDevice;
  final LiveControlDeviceDetails? liveDeviceDetails;
  final String liveControlSubTab;
  final String liveControlRightTab;
  final String liveControlFloorId;
  final String? liveControlBuildingId;
  final String? liveControlRoomId;
  final String liveControlTypeFilter;
  final String liveControlGroupFilter;
  final String liveControlStatusFilter;
  final String liveControlSearchQuery;
  final bool isLiveControlGridMode;
  final bool isLiveControlLoading;

  const DeviceManagementState({
    this.isLoading = false,
    this.isDevicesLoading = false,
    this.kpis = const DeviceManagementKpis(),
    this.buildingsBreakdown = const [],
    this.devicesByType = const [],
    this.energyData = const [],
    this.allEnergyData = const {},
    this.energyTimePeriod = 'Day',
    this.activeAutomations = const [],
    this.scenes = const [],
    this.recentAlerts = const [],
    this.devices = const [],
    this.totalDevices = 0,
    this.currentPage = 1,
    this.pageSize = 10,
    this.selectedSubNavIndex = 0,
    this.activeTableTab = 'Live Device Control',
    this.searchQuery = '',
    this.filterBuilding,
    this.filterFloor,
    this.filterRoom,
    this.filterType,
    this.filterStatus,
    this.selectedDeviceIds = const {},
    this.locationTree,
    this.selectedCampusBuildingCode = 'Entire Campus',
    this.groups = const [],
    this.automationsList = const [],
    this.schedulesList = const [],
    this.alertsList = const [],
    this.auditLogsList = const [],
    this.typesProfilesKpis = const DeviceTypesProfilesKpis(),
    this.deviceTypesList = const [],
    this.totalDeviceTypes = 24,
    this.deviceTypesPage = 1,
    this.deviceTypesPageSize = 10,
    this.deviceTypesTotalPages = 3,
    this.selectedDeviceTypeId,
    this.selectedDeviceTypeDetail,
    this.deviceProfilesList = const [],
    this.capabilitiesLibrary = const [],
    this.typesActiveSubTab = 'Device Types (24)',
    this.typesSearchQuery = '',
    this.typesFilterCategory = 'All Categories',
    this.typesFilterStatus = 'All Status',
    this.typesIsGridView = false,
    this.isTypesLoading = false,
    this.groupsKpis = const DeviceGroupsKpis(),
    this.groupsList = const [],
    this.totalGroupsCount = 128,
    this.groupsPage = 1,
    this.groupsPageSize = 10,
    this.groupsTotalPages = 13,
    this.selectedGroupId,
    this.selectedGroupDetail,
    this.groupsActiveSubTab = 'All Groups (128)',
    this.groupsSearchQuery = '',
    this.groupsFilterLocation = 'All Locations',
    this.groupsFilterType = 'All Device Types',
    this.groupsFilterProfile = 'All Profiles',
    this.groupsIsGridView = false,
    this.isGroupsLoading = false,
    this.selectedGroupMembers = const [],
    this.locationsKpis = const LocationsMappingKpis(),
    this.locationsHierarchy,
    this.selectedLocationFloorId = 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
    this.selectedLocationBuildingId,
    this.selectedLocationRoomId,
    this.selectedLocationDetails,
    this.locationMappedDevices = const [],
    this.locationDevicesTotal = 14,
    this.locationDevicesPage = 1,
    this.locationDevicesPageSize = 10,
    this.locationActiveSubTab = 'Location Hierarchy',
    this.locationDeviceTypeFilter = 'All Device Types',
    this.locationGroupFilter = 'All Groups',
    this.locationProfileFilter = 'All Profiles',
    this.locationStatusFilter = 'All Status',
    this.locationSearchQuery = '',
    this.locationIsGridView = false,
    this.floorPlanAsset,
    this.floorPlanMarkers = const [],
    this.floorPlanLegend = const FloorPlanLegendModel(),
    this.isLocationsLoading = false,
    this.isLocationDevicesLoading = false,
    this.liveControlKpis = const LiveControlKpis(),
    this.liveControlDevices = const [],
    this.selectedLiveDeviceId = 'c1c00000-0000-0000-0000-000000000009',
    this.selectedLiveDevice,
    this.liveDeviceDetails,
    this.liveControlSubTab = 'Device Control',
    this.liveControlRightTab = 'Control',
    this.liveControlFloorId = 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
    this.liveControlBuildingId = '2af829b6-81a4-469a-a91a-71f2bd390fc4',
    this.liveControlRoomId = '7a9cd5c9-de76-419f-9c80-8c4fe5d973aa',
    this.liveControlTypeFilter = 'All Device Types',
    this.liveControlGroupFilter = 'All Groups',
    this.liveControlStatusFilter = 'All Status',
    this.liveControlSearchQuery = '',
    this.isLiveControlGridMode = true,
    this.isLiveControlLoading = false,
  });

  DeviceManagementState copyWith({
    bool? isLoading,
    bool? isDevicesLoading,
    DeviceManagementKpis? kpis,
    List<BuildingDeviceBreakdown>? buildingsBreakdown,
    List<DeviceTypeBreakdown>? devicesByType,
    List<EnergyDataPoint>? energyData,
    Map<String, List<EnergyDataPoint>>? allEnergyData,
    String? energyTimePeriod,
    List<ActiveAutomationItem>? activeAutomations,
    List<DeviceSceneItem>? scenes,
    List<DeviceAlertItem>? recentAlerts,
    List<DeviceItemModel>? devices,
    int? totalDevices,
    int? currentPage,
    int? pageSize,
    int? selectedSubNavIndex,
    String? activeTableTab,
    String? searchQuery,
    String? filterBuilding,
    String? filterFloor,
    String? filterRoom,
    String? filterType,
    String? filterStatus,
    Set<String>? selectedDeviceIds,
    LocationTreeNode? locationTree,
    String? selectedCampusBuildingCode,
    List<Map<String, dynamic>>? groups,
    List<Map<String, dynamic>>? automationsList,
    List<Map<String, dynamic>>? schedulesList,
    List<Map<String, dynamic>>? alertsList,
    List<Map<String, dynamic>>? auditLogsList,
    DeviceTypesProfilesKpis? typesProfilesKpis,
    List<DeviceTypeDetailItem>? deviceTypesList,
    int? totalDeviceTypes,
    int? deviceTypesPage,
    int? deviceTypesPageSize,
    int? deviceTypesTotalPages,
    String? selectedDeviceTypeId,
    DeviceTypeDetailItem? selectedDeviceTypeDetail,
    List<DeviceProfileItem>? deviceProfilesList,
    List<CapabilityTemplateItem>? capabilitiesLibrary,
    String? typesActiveSubTab,
    String? typesSearchQuery,
    String? typesFilterCategory,
    String? typesFilterStatus,
    bool? typesIsGridView,
    bool? isTypesLoading,
    DeviceGroupsKpis? groupsKpis,
    List<DeviceGroupItem>? groupsList,
    int? totalGroupsCount,
    int? groupsPage,
    int? groupsPageSize,
    int? groupsTotalPages,
    String? selectedGroupId,
    DeviceGroupItem? selectedGroupDetail,
    String? groupsActiveSubTab,
    String? groupsSearchQuery,
    String? groupsFilterLocation,
    String? groupsFilterType,
    String? groupsFilterProfile,
    bool? groupsIsGridView,
    bool? isGroupsLoading,
    List<Map<String, dynamic>>? selectedGroupMembers,
    LocationsMappingKpis? locationsKpis,
    LocationHierarchyNode? locationsHierarchy,
    String? selectedLocationFloorId,
    String? selectedLocationBuildingId,
    String? selectedLocationRoomId,
    LocationDetailsModel? selectedLocationDetails,
    List<DeviceLocationMappingItem>? locationMappedDevices,
    int? locationDevicesTotal,
    int? locationDevicesPage,
    int? locationDevicesPageSize,
    String? locationActiveSubTab,
    String? locationDeviceTypeFilter,
    String? locationGroupFilter,
    String? locationProfileFilter,
    String? locationStatusFilter,
    String? locationSearchQuery,
    bool? locationIsGridView,
    FloorPlanAssetModel? floorPlanAsset,
    List<FloorPlanMarkerModel>? floorPlanMarkers,
    FloorPlanLegendModel? floorPlanLegend,
    bool? isLocationsLoading,
    bool? isLocationDevicesLoading,
    LiveControlKpis? liveControlKpis,
    List<LiveControlDeviceItem>? liveControlDevices,
    String? selectedLiveDeviceId,
    LiveControlDeviceItem? selectedLiveDevice,
    LiveControlDeviceDetails? liveDeviceDetails,
    String? liveControlSubTab,
    String? liveControlRightTab,
    String? liveControlFloorId,
    String? liveControlBuildingId,
    String? liveControlRoomId,
    String? liveControlTypeFilter,
    String? liveControlGroupFilter,
    String? liveControlStatusFilter,
    String? liveControlSearchQuery,
    bool? isLiveControlGridMode,
    bool? isLiveControlLoading,
    bool clearLiveControlRoom = false,
    bool clearSelectedLocationRoom = false,
  }) {
    return DeviceManagementState(
      isLoading: isLoading ?? this.isLoading,
      isDevicesLoading: isDevicesLoading ?? this.isDevicesLoading,
      kpis: kpis ?? this.kpis,
      buildingsBreakdown: buildingsBreakdown ?? this.buildingsBreakdown,
      devicesByType: devicesByType ?? this.devicesByType,
      energyData: energyData ?? this.energyData,
      allEnergyData: allEnergyData ?? this.allEnergyData,
      energyTimePeriod: energyTimePeriod ?? this.energyTimePeriod,
      activeAutomations: activeAutomations ?? this.activeAutomations,
      scenes: scenes ?? this.scenes,
      recentAlerts: recentAlerts ?? this.recentAlerts,
      devices: devices ?? this.devices,
      totalDevices: totalDevices ?? this.totalDevices,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      selectedSubNavIndex: selectedSubNavIndex ?? this.selectedSubNavIndex,
      activeTableTab: activeTableTab ?? this.activeTableTab,
      searchQuery: searchQuery ?? this.searchQuery,
      filterBuilding: filterBuilding ?? this.filterBuilding,
      filterFloor: filterFloor ?? this.filterFloor,
      filterRoom: filterRoom ?? this.filterRoom,
      filterType: filterType ?? this.filterType,
      filterStatus: filterStatus ?? this.filterStatus,
      selectedDeviceIds: selectedDeviceIds ?? this.selectedDeviceIds,
      locationTree: locationTree ?? this.locationTree,
      selectedCampusBuildingCode: selectedCampusBuildingCode ?? this.selectedCampusBuildingCode,
      groups: groups ?? this.groups,
      automationsList: automationsList ?? this.automationsList,
      schedulesList: schedulesList ?? this.schedulesList,
      alertsList: alertsList ?? this.alertsList,
      auditLogsList: auditLogsList ?? this.auditLogsList,
      typesProfilesKpis: typesProfilesKpis ?? this.typesProfilesKpis,
      deviceTypesList: deviceTypesList ?? this.deviceTypesList,
      totalDeviceTypes: totalDeviceTypes ?? this.totalDeviceTypes,
      deviceTypesPage: deviceTypesPage ?? this.deviceTypesPage,
      deviceTypesPageSize: deviceTypesPageSize ?? this.deviceTypesPageSize,
      deviceTypesTotalPages: deviceTypesTotalPages ?? this.deviceTypesTotalPages,
      selectedDeviceTypeId: selectedDeviceTypeId ?? this.selectedDeviceTypeId,
      selectedDeviceTypeDetail: selectedDeviceTypeDetail ?? this.selectedDeviceTypeDetail,
      deviceProfilesList: deviceProfilesList ?? this.deviceProfilesList,
      capabilitiesLibrary: capabilitiesLibrary ?? this.capabilitiesLibrary,
      typesActiveSubTab: typesActiveSubTab ?? this.typesActiveSubTab,
      typesSearchQuery: typesSearchQuery ?? this.typesSearchQuery,
      typesFilterCategory: typesFilterCategory ?? this.typesFilterCategory,
      typesFilterStatus: typesFilterStatus ?? this.typesFilterStatus,
      typesIsGridView: typesIsGridView ?? this.typesIsGridView,
      isTypesLoading: isTypesLoading ?? this.isTypesLoading,
      groupsKpis: groupsKpis ?? this.groupsKpis,
      groupsList: groupsList ?? this.groupsList,
      totalGroupsCount: totalGroupsCount ?? this.totalGroupsCount,
      groupsPage: groupsPage ?? this.groupsPage,
      groupsPageSize: groupsPageSize ?? this.groupsPageSize,
      groupsTotalPages: groupsTotalPages ?? this.groupsTotalPages,
      selectedGroupId: selectedGroupId ?? this.selectedGroupId,
      selectedGroupDetail: selectedGroupDetail ?? this.selectedGroupDetail,
      groupsActiveSubTab: groupsActiveSubTab ?? this.groupsActiveSubTab,
      groupsSearchQuery: groupsSearchQuery ?? this.groupsSearchQuery,
      groupsFilterLocation: groupsFilterLocation ?? this.groupsFilterLocation,
      groupsFilterType: groupsFilterType ?? this.groupsFilterType,
      groupsFilterProfile: groupsFilterProfile ?? this.groupsFilterProfile,
      groupsIsGridView: groupsIsGridView ?? this.groupsIsGridView,
      isGroupsLoading: isGroupsLoading ?? this.isGroupsLoading,
      selectedGroupMembers: selectedGroupMembers ?? this.selectedGroupMembers,
      locationsKpis: locationsKpis ?? this.locationsKpis,
      locationsHierarchy: locationsHierarchy ?? this.locationsHierarchy,
      selectedLocationFloorId: selectedLocationFloorId ?? this.selectedLocationFloorId,
      selectedLocationBuildingId: selectedLocationBuildingId ?? this.selectedLocationBuildingId,
      selectedLocationRoomId: clearSelectedLocationRoom ? null : (selectedLocationRoomId ?? this.selectedLocationRoomId),
      selectedLocationDetails: selectedLocationDetails ?? this.selectedLocationDetails,
      locationMappedDevices: locationMappedDevices ?? this.locationMappedDevices,
      locationDevicesTotal: locationDevicesTotal ?? this.locationDevicesTotal,
      locationDevicesPage: locationDevicesPage ?? this.locationDevicesPage,
      locationDevicesPageSize: locationDevicesPageSize ?? this.locationDevicesPageSize,
      locationActiveSubTab: locationActiveSubTab ?? this.locationActiveSubTab,
      locationDeviceTypeFilter: locationDeviceTypeFilter ?? this.locationDeviceTypeFilter,
      locationGroupFilter: locationGroupFilter ?? this.locationGroupFilter,
      locationProfileFilter: locationProfileFilter ?? this.locationProfileFilter,
      locationStatusFilter: locationStatusFilter ?? this.locationStatusFilter,
      locationSearchQuery: locationSearchQuery ?? this.locationSearchQuery,
      locationIsGridView: locationIsGridView ?? this.locationIsGridView,
      floorPlanAsset: floorPlanAsset ?? this.floorPlanAsset,
      floorPlanMarkers: floorPlanMarkers ?? this.floorPlanMarkers,
      floorPlanLegend: floorPlanLegend ?? this.floorPlanLegend,
      isLocationsLoading: isLocationsLoading ?? this.isLocationsLoading,
      isLocationDevicesLoading: isLocationDevicesLoading ?? this.isLocationDevicesLoading,
      liveControlKpis: liveControlKpis ?? this.liveControlKpis,
      liveControlDevices: liveControlDevices ?? this.liveControlDevices,
      selectedLiveDeviceId: selectedLiveDeviceId ?? this.selectedLiveDeviceId,
      selectedLiveDevice: selectedLiveDevice ?? this.selectedLiveDevice,
      liveDeviceDetails: liveDeviceDetails ?? this.liveDeviceDetails,
      liveControlSubTab: liveControlSubTab ?? this.liveControlSubTab,
      liveControlRightTab: liveControlRightTab ?? this.liveControlRightTab,
      liveControlFloorId: liveControlFloorId ?? this.liveControlFloorId,
      liveControlBuildingId: liveControlBuildingId ?? this.liveControlBuildingId,
      liveControlRoomId: clearLiveControlRoom ? null : (liveControlRoomId ?? this.liveControlRoomId),
      liveControlTypeFilter: liveControlTypeFilter ?? this.liveControlTypeFilter,
      liveControlGroupFilter: liveControlGroupFilter ?? this.liveControlGroupFilter,
      liveControlStatusFilter: liveControlStatusFilter ?? this.liveControlStatusFilter,
      liveControlSearchQuery: liveControlSearchQuery ?? this.liveControlSearchQuery,
      isLiveControlGridMode: isLiveControlGridMode ?? this.isLiveControlGridMode,
      isLiveControlLoading: isLiveControlLoading ?? this.isLiveControlLoading,
    );
  }
}

class DeviceManagementNotifier extends StateNotifier<DeviceManagementState> {
  final DeviceManagementApiService _api;

  DeviceManagementNotifier(this._api) : super(const DeviceManagementState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadOverview(),
      loadDevices(),
      loadLocationTree(),
      loadGroups(),
      loadAutomations(),
      loadSchedules(),
      loadAlerts(),
      loadAuditLogs(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadOverview() async {
    try {
      final res = await _api.getOverview();
      if (res.isNotEmpty) {
        final kpis = res['kpis'] is Map ? DeviceManagementKpis.fromJson(Map<String, dynamic>.from(res['kpis'])) : const DeviceManagementKpis();
        final bldList = (res['buildings_breakdown'] as List? ?? [])
            .map((e) => BuildingDeviceBreakdown.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final typeList = (res['devices_by_type'] as List? ?? [])
            .map((e) => DeviceTypeBreakdown.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final energyMap = <String, List<EnergyDataPoint>>{};
        if (res['energy_usage'] is Map) {
          final rawMap = res['energy_usage'] as Map;
          for (final key in ['day', 'week', 'month', 'year']) {
            if (rawMap[key] is List) {
              energyMap[key] = (rawMap[key] as List)
                  .map((e) => EnergyDataPoint.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
          }
        }

        final currentPoints = energyMap[state.energyTimePeriod.toLowerCase()] ?? energyMap['day'] ?? [];

        final autoList = (res['active_automations'] as List? ?? [])
            .map((e) => ActiveAutomationItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final scenesList = (res['scenes'] as List? ?? [])
            .map((e) => DeviceSceneItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final alertsList = (res['recent_alerts'] as List? ?? [])
            .map((e) => DeviceAlertItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        state = state.copyWith(
          kpis: kpis,
          buildingsBreakdown: bldList,
          devicesByType: typeList,
          allEnergyData: energyMap,
          energyData: currentPoints,
          activeAutomations: autoList,
          scenes: scenesList,
          recentAlerts: alertsList,
        );
      }
    } catch (_) {}
  }

  Future<void> loadDevices() async {
    state = state.copyWith(isDevicesLoading: true);
    try {
      final res = await _api.listDevices(
        search: state.searchQuery,
        buildingId: state.filterBuilding,
        floorId: state.filterFloor,
        roomId: state.filterRoom,
        typeCode: state.filterType,
        status: state.filterStatus,
        page: state.currentPage,
        pageSize: state.pageSize,
      );

      final rawList = res['devices'] as List? ?? [];
      final list = rawList
          .map((e) => DeviceItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      state = state.copyWith(
        devices: list,
        totalDevices: (res['total'] as num?)?.toInt() ?? list.length,
        isDevicesLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isDevicesLoading: false);
    }
  }

  Future<void> loadLocationTree() async {
    try {
      final tree = await _api.getLocationTree();
      if (tree != null) {
        state = state.copyWith(locationTree: tree);
      }
    } catch (_) {}
  }

  Future<void> loadGroups() async {
    try {
      final list = await _api.getGroups();
      state = state.copyWith(groups: list);
    } catch (_) {}
  }

  Future<void> loadAutomations() async {
    try {
      final list = await _api.getAutomations();
      state = state.copyWith(automationsList: list);
    } catch (_) {}
  }

  Future<void> loadSchedules() async {
    try {
      final list = await _api.getSchedules();
      state = state.copyWith(schedulesList: list);
    } catch (_) {}
  }

  Future<void> loadAlerts() async {
    try {
      final list = await _api.getAlerts();
      state = state.copyWith(alertsList: list);
    } catch (_) {}
  }

  Future<void> loadAuditLogs() async {
    try {
      final list = await _api.getAuditLogs();
      state = state.copyWith(auditLogsList: list);
    } catch (_) {}
  }

  void setSubNavIndex(int index) {
    state = state.copyWith(selectedSubNavIndex: index);
    if (index == 1) {
      loadDevices();
    } else if (index == 2) {
      loadTypesAndProfilesData();
    } else if (index == 3) {
      loadGroups();
    } else if (index == 4) {
      loadLocationsMappingData();
    } else if (index == 5) {
      loadLiveControlData();
    } else if (index == 7) {
      loadAutomations();
    } else if (index == 8) {
      loadSchedules();
    } else if (index == 11) {
      loadAlerts();
    } else if (index == 14) {
      loadAuditLogs();
    } else if (index == 15) {
      _api.exportDevicesCsv();
    }
  }

  void setTableTab(String tab) {
    state = state.copyWith(activeTableTab: tab);
    if (tab == 'By Location') {
      final sorted = List<DeviceItemModel>.from(state.devices)
        ..sort((a, b) => a.locationDisplay.compareTo(b.locationDisplay));
      state = state.copyWith(devices: sorted);
    } else if (tab == 'By Type') {
      final sorted = List<DeviceItemModel>.from(state.devices)
        ..sort((a, b) => a.typeName.compareTo(b.typeName));
      state = state.copyWith(devices: sorted);
    } else {
      loadDevices();
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    loadDevices();
  }

  void setFilterBuilding(String? bld) {
    final effective = (bld == 'All' || bld == 'Entire Campus') ? null : bld;
    state = state.copyWith(
      filterBuilding: effective,
      filterFloor: null,
      filterRoom: null,
      selectedCampusBuildingCode: effective ?? 'Entire Campus',
      currentPage: 1,
    );
    loadDevices();
  }

  void setFilterLocation({String? buildingId, String? floorId, String? roomId}) {
    final effectiveBld = (buildingId == 'All' || buildingId == 'Entire Campus') ? null : buildingId;
    state = state.copyWith(
      filterBuilding: effectiveBld,
      filterFloor: floorId,
      filterRoom: roomId,
      selectedCampusBuildingCode: effectiveBld ?? 'Entire Campus',
      currentPage: 1,
    );
    loadDevices();
  }

  void setFilterType(String? type) {
    final effective = (type == 'All' || type == 'All Types') ? null : type;
    state = state.copyWith(filterType: effective, currentPage: 1);
    loadDevices();
  }

  void setFilterStatus(String? status) {
    final effective = (status == 'All' || status == 'All Status') ? null : status;
    state = state.copyWith(filterStatus: effective, currentPage: 1);
    loadDevices();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    loadDevices();
  }

  void setEnergyTimePeriod(String period) {
    final key = period.toLowerCase();
    final points = state.allEnergyData[key] ?? state.energyData;
    state = state.copyWith(energyTimePeriod: period, energyData: points);
  }

  void setSelectedCampusBuilding(String code) {
    final effective = (code == 'Entire Campus' || code == 'All') ? null : code;
    state = state.copyWith(
      selectedCampusBuildingCode: code,
      filterBuilding: effective,
      currentPage: 1,
    );
    loadDevices();
  }

  void toggleSelectDevice(String id) {
    final updated = Set<String>.from(state.selectedDeviceIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedDeviceIds: updated);
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      final allIds = state.devices.map((d) => d.id).toSet();
      state = state.copyWith(selectedDeviceIds: allIds);
    } else {
      state = state.copyWith(selectedDeviceIds: {});
    }
  }

  // --- Real-Time Device Controls ---

  Future<void> toggleDevicePower(DeviceItemModel device) async {
    final nextPower = !device.powerState;
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['power'] = nextPower;
        return d.copyWith(powerState: nextPower, currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_power', {'power': nextPower});
    loadOverview();
  }

  Future<void> setDeviceTemperature(DeviceItemModel device, int temp) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['temperature'] = temp;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_temperature', {'temperature': temp});
  }

  Future<void> setDeviceHvacMode(DeviceItemModel device, String mode) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['mode'] = mode;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_mode', {'mode': mode});
  }

  Future<void> setDeviceFanSpeed(DeviceItemModel device, String speed) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['speed'] = speed;
        curState['fan_speed'] = speed;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_fan_speed', {'speed': speed});
  }

  Future<void> setDeviceBrightness(DeviceItemModel device, int brightness) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['brightness'] = brightness;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_level', {'brightness': brightness});
  }

  Future<void> setDeviceProjectorInput(DeviceItemModel device, String input) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['input'] = input;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_input', {'input': input});
  }

  Future<void> setDeviceProjectorVolume(DeviceItemModel device, int volume) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        curState['volume'] = volume;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'set_volume', {'volume': volume});
  }

  Future<void> toggleGateLock(DeviceItemModel device, String action) async {
    final updatedDevices = state.devices.map((d) {
      if (d.id == device.id) {
        final curState = Map<String, dynamic>.from(d.currentState);
        if (action == 'Open') curState['position'] = 'Open';
        if (action == 'Close') curState['position'] = 'Closed';
        if (action == 'Lock') curState['locked'] = true;
        if (action == 'Unlock') curState['locked'] = false;
        return d.copyWith(currentState: curState);
      }
      return d;
    }).toList();
    state = state.copyWith(devices: updatedDevices);

    await _api.executeCommand(device.id, 'gate_control', {'action': action});
  }

  Future<void> rebootDevice(String deviceId) async {
    await _api.rebootDevice(deviceId);
  }

  Future<void> toggleAutomation(String automationId) async {
    await _api.toggleAutomation(automationId);
    await loadAutomations();
    await loadOverview();
  }

  Future<void> toggleSchedule(String scheduleId) async {
    await _api.toggleSchedule(scheduleId);
    await loadSchedules();
    await loadOverview();
  }

  Future<void> resolveAlert(String alertId) async {
    await _api.resolveAlert(alertId);
    await loadAlerts();
    await loadOverview();
  }

  Future<void> createCustomScene(String name, String code, String description) async {
    await _api.createScene({
      'name': name,
      'code': code,
      'description': description,
      'icon': 'auto_awesome',
      'color': '#2563EB',
    });
    await loadOverview();
  }

  Future<void> executeQuickControl(String actionType) async {
    final targetIds = state.selectedDeviceIds.isNotEmpty
        ? state.selectedDeviceIds.toList()
        : state.devices.map((d) => d.id).toList();

    if (actionType == 'Turn ON') {
      await _api.executeBulkCommand(targetIds, 'turn_on', {'power': true});
    } else if (actionType == 'Turn OFF') {
      await _api.executeBulkCommand(targetIds, 'turn_off', {'power': false});
    } else if (actionType == 'Set Level') {
      await _api.executeBulkCommand(targetIds, 'set_level', {'brightness': 75});
    } else if (actionType == 'Set Temperature') {
      await _api.executeBulkCommand(targetIds, 'set_temperature', {'temperature': 24});
    } else if (actionType == 'Power Supply') {
      await _api.executeBulkCommand(targetIds, 'set_power_mode', {'mode': 'medium'});
    } else if (actionType == 'Apply Scene') {
      if (state.scenes.isNotEmpty) {
        await executeScene(state.scenes.first);
        return;
      }
    }
    await loadDevices();
    await loadOverview();
  }

  Future<void> executeQuickControlWithParams(String commandType, Map<String, dynamic> params) async {
    final targetIds = state.selectedDeviceIds.isNotEmpty
        ? state.selectedDeviceIds.toList()
        : state.devices.map((d) => d.id).toList();

    await _api.executeBulkCommand(targetIds, commandType, params);
    await loadDevices();
    await loadOverview();
  }

  Future<void> executeScene(DeviceSceneItem scene) async {
    await _api.executeScene(scene.id);
    await loadDevices();
    await loadOverview();
  }

  Future<void> deleteDevice(String deviceId) async {
    await _api.deleteDevice(deviceId);
    await loadDevices();
    await loadOverview();
  }

  Future<bool> updateDevice(String deviceId, Map<String, dynamic> data) async {
    final success = await _api.updateDevice(deviceId, data);
    if (success) {
      await loadDevices();
      await loadOverview();
    }
    return success;
  }

  Future<Map<String, dynamic>> pingDevice(String deviceId) async {
    return await _api.pingDevice(deviceId);
  }

  // --- Device Groups CRUD ---
  Future<bool> createDeviceGroup(Map<String, dynamic> payload) async {
    final res = await _api.createGroup(payload);
    if (res['success'] == true) {
      await loadGroups();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> updateDeviceGroup(String groupId, Map<String, dynamic> payload) async {
    final res = await _api.updateGroup(groupId, payload);
    if (res['success'] == true) {
      await loadGroups();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> deleteDeviceGroup(String groupId) async {
    final ok = await _api.deleteGroup(groupId);
    if (ok) {
      await loadGroups();
      await loadOverview();
    }
    return ok;
  }

  Future<bool> executeGroupAction(String groupId, String action, [Map<String, dynamic>? params]) async {
    final ok = await _api.executeGroupAction(groupId, action, params);
    if (ok) {
      await loadDevices();
      await loadGroups();
      await loadOverview();
    }
    return ok;
  }

  Future<bool> bulkUpdateDeviceGroupsStatus(List<String> groupIds, String status) async {
    bool allSuccess = true;
    for (final id in groupIds) {
      final res = await _api.updateGroup(id, {'status': status});
      if (res['success'] != true) allSuccess = false;
    }
    await loadGroups();
    await loadOverview();
    return allSuccess;
  }

  Future<bool> bulkDeleteDeviceGroups(List<String> groupIds) async {
    bool allSuccess = true;
    for (final id in groupIds) {
      final ok = await _api.deleteGroup(id);
      if (!ok) allSuccess = false;
    }
    await loadGroups();
    await loadOverview();
    return allSuccess;
  }

  // --- Automation Rules CRUD ---
  Future<bool> createAutomationRule(Map<String, dynamic> payload) async {
    final res = await _api.createAutomationRule(payload);
    if (res['success'] == true) {
      await loadAutomations();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> updateAutomationRule(String ruleId, Map<String, dynamic> payload) async {
    final res = await _api.updateAutomationRule(ruleId, payload);
    if (res['success'] == true) {
      await loadAutomations();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<bool> deleteAutomationRule(String ruleId) async {
    final ok = await _api.deleteAutomationRule(ruleId);
    if (ok) {
      await loadAutomations();
      await loadOverview();
    }
    return ok;
  }

  Future<bool> duplicateAutomationRule(String ruleId) async {
    final res = await _api.duplicateAutomationRule(ruleId);
    if (res['success'] == true) {
      await loadAutomations();
      await loadOverview();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> testAutomationRule(Map<String, dynamic> payload) async {
    return await _api.testAutomationRule(payload);
  }

  Future<Map<String, dynamic>> runAutomationCron() async {
    final res = await _api.runAutomationCron();
    await loadAutomations();
    await loadOverview();
    return res;
  }

  Future<Map<String, dynamic>> getAutomationCronStatus() async {
    return await _api.getAutomationCronStatus();
  }

  // ============================================================================
  // DEVICE TYPES & PROFILES NOTIFIER METHODS
  // ============================================================================

  Future<void> loadTypesAndProfilesData() async {
    state = state.copyWith(isTypesLoading: true);
    try {
      final kpis = await _api.getTypesProfilesKpis();
      final typesRes = await _api.getDeviceTypes(
        category: state.typesFilterCategory,
        status: state.typesFilterStatus,
        search: state.typesSearchQuery,
        page: state.deviceTypesPage,
        pageSize: state.deviceTypesPageSize,
      );
      final typesList = (typesRes['types'] as List<DeviceTypeDetailItem>?) ?? [];
      final profiles = await _api.getDeviceProfiles();
      final capabilities = await _api.getCapabilitiesLibrary();

      String? selId = state.selectedDeviceTypeId;
      DeviceTypeDetailItem? selDetail = state.selectedDeviceTypeDetail;

      if (typesList.isNotEmpty) {
        if (selId == null || !typesList.any((t) => t.id == selId)) {
          selId = typesList.first.id;
        }
        selDetail = await _api.getDeviceTypeDetail(selId) ?? typesList.first;
      }

      state = state.copyWith(
        isTypesLoading: false,
        typesProfilesKpis: kpis,
        deviceTypesList: typesList,
        totalDeviceTypes: typesRes['total'] ?? typesList.length,
        deviceTypesPage: typesRes['page'] ?? state.deviceTypesPage,
        deviceTypesTotalPages: typesRes['total_pages'] ?? 1,
        selectedDeviceTypeId: selId,
        selectedDeviceTypeDetail: selDetail,
        deviceProfilesList: profiles,
        capabilitiesLibrary: capabilities,
      );
    } catch (_) {
      state = state.copyWith(isTypesLoading: false);
    }
  }

  void setTypesSubTab(String subTab) {
    state = state.copyWith(typesActiveSubTab: subTab);
    if (subTab.contains('Control Profiles')) {
      loadDeviceProfiles();
    } else if (subTab.contains('Capability Templates')) {
      loadCapabilitiesLibrary();
    }
  }

  Future<void> loadDeviceProfiles({String? deviceTypeId}) async {
    final profiles = await _api.getDeviceProfiles(
      deviceTypeId: deviceTypeId ?? state.selectedDeviceTypeId,
      search: state.typesSearchQuery,
      status: state.typesFilterStatus != 'All Status' ? state.typesFilterStatus : null,
    );
    state = state.copyWith(deviceProfilesList: profiles);
  }

  Future<void> loadCapabilitiesLibrary() async {
    final caps = await _api.getCapabilitiesLibrary();
    state = state.copyWith(capabilitiesLibrary: caps);
  }

  void setTypesSearchQuery(String query) {
    state = state.copyWith(typesSearchQuery: query, deviceTypesPage: 1);
    loadTypesAndProfilesData();
  }

  void setTypesFilterCategory(String category) {
    state = state.copyWith(typesFilterCategory: category, deviceTypesPage: 1);
    loadTypesAndProfilesData();
  }

  void setTypesFilterStatus(String status) {
    state = state.copyWith(typesFilterStatus: status, deviceTypesPage: 1);
    loadTypesAndProfilesData();
  }

  void setTypesPage(int page) {
    state = state.copyWith(deviceTypesPage: page);
    loadTypesAndProfilesData();
  }

  void toggleTypesGridView(bool isGrid) {
    state = state.copyWith(typesIsGridView: isGrid);
  }

  Future<void> selectDeviceType(String typeId) async {
    state = state.copyWith(selectedDeviceTypeId: typeId);
    final detail = await _api.getDeviceTypeDetail(typeId);
    if (detail != null) {
      state = state.copyWith(selectedDeviceTypeDetail: detail);
    }
  }

  Future<bool> createDeviceType(Map<String, dynamic> data) async {
    final res = await _api.createDeviceType(data);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> updateDeviceType(String typeId, Map<String, dynamic> data) async {
    final res = await _api.updateDeviceType(typeId, data);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> deleteDeviceType(String typeId) async {
    final res = await _api.deleteDeviceType(typeId);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> duplicateDeviceType(String typeId) async {
    final res = await _api.duplicateDeviceType(typeId);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> bulkUpdateDeviceTypesStatus(List<String> typeIds, bool isActive) async {
    bool allSuccess = true;
    for (final id in typeIds) {
      final res = await _api.updateDeviceType(id, {'is_active': isActive});
      if (res['success'] != true) allSuccess = false;
    }
    await loadTypesAndProfilesData();
    return allSuccess;
  }

  Future<bool> bulkDeleteDeviceTypes(List<String> typeIds) async {
    bool allSuccess = true;
    for (final id in typeIds) {
      final res = await _api.deleteDeviceType(id);
      if (res['success'] != true) allSuccess = false;
    }
    await loadTypesAndProfilesData();
    return allSuccess;
  }

  Future<bool> createDeviceProfile(Map<String, dynamic> data) async {
    final res = await _api.createDeviceProfile(data);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> updateDeviceProfile(String profileId, Map<String, dynamic> data) async {
    final res = await _api.updateDeviceProfile(profileId, data);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> deleteDeviceProfile(String profileId) async {
    final res = await _api.deleteDeviceProfile(profileId);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<bool> duplicateDeviceProfile(String profileId) async {
    final res = await _api.duplicateDeviceProfile(profileId);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> deployDeviceProfile(String profileId, Map<String, dynamic> data) async {
    final res = await _api.deployDeviceProfile(profileId, data);
    if (res['success'] == true) {
      await loadTypesAndProfilesData();
    }
    return res;
  }

  // ============================================================================
  // DEVICE GROUPS ENTERPRISE NOTIFIER METHODS
  // ============================================================================

  Future<void> loadDeviceGroupsData() async {
    state = state.copyWith(isGroupsLoading: true);
    try {
      final kpis = await _api.getDeviceGroupsKpis();
      final res = await _api.getDeviceGroups(
        status: state.groupsActiveSubTab,
        location: state.groupsFilterLocation != 'All Locations' ? state.groupsFilterLocation : null,
        groupType: state.groupsFilterType != 'All Device Types' ? state.groupsFilterType : null,
        profile: state.groupsFilterProfile != 'All Profiles' ? state.groupsFilterProfile : null,
        search: state.groupsSearchQuery,
        page: state.groupsPage,
        pageSize: state.groupsPageSize,
      );

      final list = (res['groups'] as List<DeviceGroupItem>?) ?? [];
      String? selId = state.selectedGroupId;
      DeviceGroupItem? selDetail = state.selectedGroupDetail;

      if (list.isNotEmpty) {
        if (selId == null || !list.any((g) => g.id == selId)) {
          selId = list.first.id;
        }
        selDetail = await _api.getDeviceGroupDetail(selId) ?? list.first;
      }

      state = state.copyWith(
        isGroupsLoading: false,
        groupsKpis: kpis,
        groupsList: list,
        totalGroupsCount: res['total'] ?? list.length,
        groupsPage: res['page'] ?? state.groupsPage,
        groupsTotalPages: res['total_pages'] ?? 1,
        selectedGroupId: selId,
        selectedGroupDetail: selDetail,
      );

      if (selId != null) {
        await loadGroupMembers(selId);
      }
    } catch (_) {
      state = state.copyWith(isGroupsLoading: false);
    }
  }

  Future<void> selectDeviceGroup(String groupId) async {
    state = state.copyWith(selectedGroupId: groupId);
    try {
      final detail = await _api.getDeviceGroupDetail(groupId);
      if (detail != null) {
        state = state.copyWith(selectedGroupDetail: detail);
      }
      await loadGroupMembers(groupId);
    } catch (_) {}
  }

  Future<void> loadGroupMembers(String groupId) async {
    try {
      final members = await _api.getDeviceGroupMembers(groupId);
      state = state.copyWith(selectedGroupMembers: members);
    } catch (_) {}
  }

  void setGroupsSubTab(String subTab) {
    state = state.copyWith(groupsActiveSubTab: subTab, groupsPage: 1);
    loadDeviceGroupsData();
  }

  void setGroupsSearchQuery(String query) {
    state = state.copyWith(groupsSearchQuery: query, groupsPage: 1);
    loadDeviceGroupsData();
  }

  void setGroupsFilterLocation(String location) {
    state = state.copyWith(groupsFilterLocation: location, groupsPage: 1);
    loadDeviceGroupsData();
  }

  void setGroupsFilterType(String type) {
    state = state.copyWith(groupsFilterType: type, groupsPage: 1);
    loadDeviceGroupsData();
  }

  void setGroupsFilterProfile(String profile) {
    state = state.copyWith(groupsFilterProfile: profile, groupsPage: 1);
    loadDeviceGroupsData();
  }

  void setGroupsPage(int page) {
    state = state.copyWith(groupsPage: page);
    loadDeviceGroupsData();
  }

  void setGroupsViewMode(bool isGrid) {
    state = state.copyWith(groupsIsGridView: isGrid);
  }

  Future<bool> createGroupItem(Map<String, dynamic> payload) async {
    final res = await _api.createGroup(payload);
    if (res['success'] == true) {
      await loadDeviceGroupsData();
      return true;
    }
    return false;
  }

  Future<bool> updateGroupItem(String groupId, Map<String, dynamic> payload) async {
    final res = await _api.updateGroup(groupId, payload);
    if (res['success'] == true) {
      await loadDeviceGroupsData();
      return true;
    }
    return false;
  }

  Future<bool> deleteGroupItem(String groupId) async {
    final ok = await _api.deleteGroup(groupId);
    if (ok) {
      await loadDeviceGroupsData();
    }
    return ok;
  }

  Future<bool> duplicateGroupItem(String groupId) async {
    final ok = await _api.duplicateDeviceGroup(groupId);
    if (ok) {
      await loadDeviceGroupsData();
    }
    return ok;
  }

  Future<bool> toggleGroupStatusItem(String groupId, String status) async {
    final ok = await _api.toggleDeviceGroupStatus(groupId, status);
    if (ok) {
      await loadDeviceGroupsData();
    }
    return ok;
  }

  Future<Map<String, dynamic>> executeGroupControlCommand(String groupId, String commandType, [Map<String, dynamic>? parameters]) async {
    final res = await _api.executeGroupCommand(groupId, commandType, parameters);
    if (res['success'] == true) {
      await loadDeviceGroupsData();
      await loadDevices();
    }
    return res;
  }

  Future<bool> addGroupMembers(String groupId, List<String> deviceIds) async {
    final ok = await _api.addDeviceGroupMembers(groupId, deviceIds);
    if (ok) {
      await loadDeviceGroupsData();
      await loadGroupMembers(groupId);
    }
    return ok;
  }

  Future<bool> removeGroupMember(String groupId, String deviceId) async {
    final ok = await _api.removeDeviceGroupMember(groupId, deviceId);
    if (ok) {
      await loadDeviceGroupsData();
      await loadGroupMembers(groupId);
    }
    return ok;
  }

  Future<int> exportDeviceGroupsCsv() async {
    final list = await _api.exportDeviceGroups();
    return list.length;
  }

  Future<int> importDeviceGroups() async {
    await loadDeviceGroupsData();
    return state.totalGroupsCount;
  }

  // ============================================================================
  // LOCATIONS & SPATIAL MAPPING NOTIFIER METHODS
  // ============================================================================

  Future<void> loadLocationsMappingData() async {
    state = state.copyWith(isLocationsLoading: true);
    try {
      if (state.devices.isEmpty) {
        await loadDevices();
      }
      final kpis = await _api.fetchLocationsMappingKpis();
      final hierarchy = await _api.fetchLocationsHierarchy();
      final details = await _api.fetchLocationDetails(
        floorId: state.selectedLocationFloorId,
        buildingId: state.selectedLocationBuildingId,
      );
      final fpRes = await _api.fetchFloorPlanAndMarkers(state.selectedLocationFloorId);
      final devRes = await _api.fetchLocationDevices(
        floorId: state.selectedLocationFloorId,
        buildingId: state.selectedLocationBuildingId,
        roomId: state.selectedLocationRoomId,
        deviceType: state.locationDeviceTypeFilter,
        groupId: state.locationGroupFilter,
        profileId: state.locationProfileFilter,
        mappingStatus: state.locationStatusFilter,
        search: state.locationSearchQuery,
        page: state.locationDevicesPage,
        limit: state.locationDevicesPageSize,
      );

      state = state.copyWith(
        locationsKpis: kpis,
        locationsHierarchy: hierarchy,
        selectedLocationDetails: details,
        floorPlanAsset: fpRes['floor_plan'] as FloorPlanAssetModel?,
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? [],
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? const FloorPlanLegendModel(),
        locationMappedDevices: devRes['devices'] as List<DeviceLocationMappingItem>? ?? [],
        locationDevicesTotal: devRes['total'] as int? ?? (devRes['devices'] as List?)?.length ?? 0,
        isLocationsLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLocationsLoading: false);
    }
  }

  Future<void> selectLocationFloor({
    required String floorId,
    String? buildingId,
    String? roomId,
  }) async {
    state = state.copyWith(
      selectedLocationFloorId: floorId,
      selectedLocationBuildingId: buildingId,
      selectedLocationRoomId: roomId,
      locationDevicesPage: 1,
      isLocationDevicesLoading: true,
    );

    try {
      final details = await _api.fetchLocationDetails(floorId: floorId, buildingId: buildingId);
      final fpRes = await _api.fetchFloorPlanAndMarkers(floorId);
      final devRes = await _api.fetchLocationDevices(
        floorId: floorId,
        buildingId: buildingId,
        roomId: roomId,
        deviceType: state.locationDeviceTypeFilter,
        groupId: state.locationGroupFilter,
        profileId: state.locationProfileFilter,
        mappingStatus: state.locationStatusFilter,
        search: state.locationSearchQuery,
        page: 1,
        limit: state.locationDevicesPageSize,
      );

      state = state.copyWith(
        selectedLocationDetails: details,
        floorPlanAsset: fpRes['floor_plan'] as FloorPlanAssetModel?,
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? [],
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? const FloorPlanLegendModel(),
        locationMappedDevices: devRes['devices'] as List<DeviceLocationMappingItem>? ?? [],
        locationDevicesTotal: devRes['total'] as int? ?? (devRes['devices'] as List?)?.length ?? 0,
        isLocationDevicesLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLocationDevicesLoading: false);
    }
  }

  void setLocationSubTab(String tab) {
    state = state.copyWith(locationActiveSubTab: tab);
  }

  void setLocationDeviceTypeFilter(String type) {
    state = state.copyWith(locationDeviceTypeFilter: type, locationDevicesPage: 1);
    _reloadLocationDevicesOnly();
  }

  void setLocationGroupFilter(String group) {
    state = state.copyWith(locationGroupFilter: group, locationDevicesPage: 1);
    _reloadLocationDevicesOnly();
  }

  void setLocationProfileFilter(String profile) {
    state = state.copyWith(locationProfileFilter: profile, locationDevicesPage: 1);
    _reloadLocationDevicesOnly();
  }

  void setLocationStatusFilter(String status) {
    state = state.copyWith(locationStatusFilter: status, locationDevicesPage: 1);
    _reloadLocationDevicesOnly();
  }

  void setLocationSearch(String query) {
    state = state.copyWith(locationSearchQuery: query, locationDevicesPage: 1);
    _reloadLocationDevicesOnly();
  }

  void setLocationDevicesPage(int page) {
    state = state.copyWith(locationDevicesPage: page);
    _reloadLocationDevicesOnly();
  }

  void setLocationViewMode(bool isGrid) {
    state = state.copyWith(locationIsGridView: isGrid);
  }

  Future<void> _reloadLocationDevicesOnly() async {
    state = state.copyWith(isLocationDevicesLoading: true);
    try {
      final devRes = await _api.fetchLocationDevices(
        floorId: state.selectedLocationFloorId,
        buildingId: state.selectedLocationBuildingId,
        roomId: state.selectedLocationRoomId,
        deviceType: state.locationDeviceTypeFilter,
        groupId: state.locationGroupFilter,
        profileId: state.locationProfileFilter,
        mappingStatus: state.locationStatusFilter,
        search: state.locationSearchQuery,
        page: state.locationDevicesPage,
        limit: state.locationDevicesPageSize,
      );
      state = state.copyWith(
        locationMappedDevices: devRes['devices'] as List<DeviceLocationMappingItem>? ?? [],
        locationDevicesTotal: devRes['total'] as int? ?? (devRes['devices'] as List?)?.length ?? 0,
        isLocationDevicesLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLocationDevicesLoading: false);
    }
  }

  Future<bool> mapDevicesToLocation({
    required List<String> deviceIds,
    required String buildingId,
    required String floorId,
    String? roomId,
    String mountType = 'Wall',
    double mountHeight = 2.4,
    String? assetTag,
    String? notes,
  }) async {
    final ok = await _api.mapDevicesToLocation(
      deviceIds: deviceIds,
      buildingId: buildingId,
      floorId: floorId,
      roomId: roomId,
      mountType: mountType,
      mountHeight: mountHeight,
      assetTag: assetTag,
      notes: notes,
    );
    if (ok) {
      await loadLocationsMappingData();
      await loadDevices();
    }
    return ok;
  }

  Future<bool> bulkMapDevices({
    required List<String> deviceIds,
    required String buildingId,
    required String floorId,
    String? roomId,
    String mountType = 'Wall',
    double mountHeight = 2.4,
    String? assetTagPrefix,
    String? notes,
  }) async {
    final ok = await _api.bulkMapDevices(
      deviceIds: deviceIds,
      buildingId: buildingId,
      floorId: floorId,
      roomId: roomId,
      mountType: mountType,
      mountHeight: mountHeight,
      assetTagPrefix: assetTagPrefix,
      notes: notes,
    );
    if (ok) {
      await loadLocationsMappingData();
      await loadDevices();
    }
    return ok;
  }

  Future<bool> unmapDevices({
    required List<String> deviceIds,
    String? reason,
  }) async {
    final ok = await _api.unmapDevicesFromLocation(deviceIds: deviceIds, reason: reason);
    if (ok) {
      await loadLocationsMappingData();
      await loadDevices();
    }
    return ok;
  }

  Future<bool> moveDevice({
    required String deviceId,
    required String toBuildingId,
    required String toFloorId,
    String? toRoomId,
    String? reason,
  }) async {
    final ok = await _api.moveDeviceLocation(
      deviceId: deviceId,
      toBuildingId: toBuildingId,
      toFloorId: toFloorId,
      toRoomId: toRoomId,
      reason: reason,
    );
    if (ok) {
      await loadLocationsMappingData();
      await loadDevices();
    }
    return ok;
  }

  Future<bool> saveFloorPlanMarker({
    required String floorId,
    required String deviceId,
    String? floorPlanId,
    String? roomId,
    required double posX,
    required double posY,
    double rotation = 0,
    String? label,
  }) async {
    final ok = await _api.saveFloorPlanMarker(
      floorId: floorId,
      deviceId: deviceId,
      floorPlanId: floorPlanId,
      roomId: roomId,
      posX: posX,
      posY: posY,
      rotation: rotation,
      label: label,
    );
    if (ok) {
      final fpRes = await _api.fetchFloorPlanAndMarkers(floorId);
      state = state.copyWith(
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? state.floorPlanMarkers,
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? state.floorPlanLegend,
      );
    }
    return ok;
  }

  Future<bool> deleteFloorPlanMarker({
    required String floorId,
    required String markerId,
  }) async {
    final ok = await _api.deleteFloorPlanMarker(floorId: floorId, markerId: markerId);
    if (ok) {
      final fpRes = await _api.fetchFloorPlanAndMarkers(floorId);
      state = state.copyWith(
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? state.floorPlanMarkers,
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? state.floorPlanLegend,
      );
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // LIVE CONTROL NOTIFIER METHODS
  // ---------------------------------------------------------------------------

  Future<void> loadLiveControlData() async {
    state = state.copyWith(isLiveControlLoading: true);
    try {
      final kpis = await _api.fetchLiveControlKpis();
      final hierarchy = await _api.fetchLocationsHierarchy();
      final fpRes = await _api.fetchFloorPlanAndMarkers(state.liveControlFloorId);
      final devices = await _api.fetchLiveControlDevices(
        floorId: state.liveControlFloorId,
        buildingId: state.liveControlBuildingId,
        roomId: state.liveControlRoomId,
        category: state.liveControlTypeFilter,
        status: state.liveControlStatusFilter,
        search: state.liveControlSearchQuery,
      );

      LiveControlDeviceItem? selectedDev;
      final targetId = state.selectedLiveDeviceId ?? 'c1c00000-0000-0000-0000-000000000009';
      if (devices.isNotEmpty) {
        selectedDev = devices.firstWhere(
          (d) => d.id == targetId || d.deviceCode == 'AC-A1-103',
          orElse: () => devices.first,
        );
      }

      LiveControlDeviceDetails? details;
      if (selectedDev != null) {
        details = await _api.fetchLiveControlDeviceDetails(selectedDev.id);
      }

      state = state.copyWith(
        isLiveControlLoading: false,
        liveControlKpis: kpis,
        locationsHierarchy: hierarchy ?? state.locationsHierarchy,
        floorPlanAsset: fpRes['asset'] as FloorPlanAssetModel? ?? state.floorPlanAsset,
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? state.floorPlanMarkers,
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? state.floorPlanLegend,
        liveControlDevices: devices,
        selectedLiveDeviceId: selectedDev?.id ?? state.selectedLiveDeviceId,
        selectedLiveDevice: selectedDev,
        liveDeviceDetails: details,
      );
    } catch (_) {
      state = state.copyWith(isLiveControlLoading: false);
    }
  }

  void setLiveControlSubTab(String subTab) {
    state = state.copyWith(liveControlSubTab: subTab);
  }

  void setLiveControlRightTab(String rightTab) {
    state = state.copyWith(liveControlRightTab: rightTab);
  }

  void setLiveControlViewMode(bool isGrid) {
    state = state.copyWith(isLiveControlGridMode: isGrid);
  }

  Future<void> setLiveControlFilters({
    String? type,
    String? group,
    String? status,
    String? search,
  }) async {
    state = state.copyWith(
      liveControlTypeFilter: type ?? state.liveControlTypeFilter,
      liveControlGroupFilter: group ?? state.liveControlGroupFilter,
      liveControlStatusFilter: status ?? state.liveControlStatusFilter,
      liveControlSearchQuery: search ?? state.liveControlSearchQuery,
    );
    await reloadLiveControlDevices();
  }

  Future<void> selectLiveControlLocation({
    String? buildingId,
    String? floorId,
    String? roomId,
    bool clearRoom = false,
  }) async {
    final shouldClearRoom = clearRoom || (floorId != null && roomId == null);
    final targetBuildingId = buildingId ?? state.liveControlBuildingId;
    final targetFloorId = floorId ?? state.liveControlFloorId;

    state = state.copyWith(
      liveControlBuildingId: targetBuildingId,
      liveControlFloorId: targetFloorId,
      liveControlRoomId: shouldClearRoom ? null : roomId,
      clearLiveControlRoom: shouldClearRoom,
    );

    // If floor changed or floor plan needs sync, reload floor plan
    if (targetFloorId.isNotEmpty && (floorId != null || state.floorPlanAsset?.floorId != targetFloorId)) {
      final fpRes = await _api.fetchFloorPlanAndMarkers(targetFloorId);
      state = state.copyWith(
        floorPlanAsset: fpRes['asset'] as FloorPlanAssetModel? ?? state.floorPlanAsset,
        floorPlanMarkers: fpRes['markers'] as List<FloorPlanMarkerModel>? ?? state.floorPlanMarkers,
        floorPlanLegend: fpRes['legend'] as FloorPlanLegendModel? ?? state.floorPlanLegend,
      );
    }

    await reloadLiveControlDevices();
  }

  Future<void> reloadLiveControlDevices() async {
    try {
      final devices = await _api.fetchLiveControlDevices(
        buildingId: state.liveControlBuildingId,
        floorId: state.liveControlFloorId,
        roomId: state.liveControlRoomId,
        category: state.liveControlTypeFilter,
        status: state.liveControlStatusFilter,
        search: state.liveControlSearchQuery,
      );

      LiveControlDeviceItem? currentSelected = state.selectedLiveDevice;
      if (devices.isNotEmpty) {
        currentSelected = devices.firstWhere(
          (d) => d.id == state.selectedLiveDeviceId,
          orElse: () => devices.first,
        );
      } else {
        currentSelected = null;
      }

      state = state.copyWith(
        liveControlDevices: devices,
        selectedLiveDeviceId: currentSelected?.id,
        selectedLiveDevice: currentSelected,
      );

      if (currentSelected != null) {
        final details = await _api.fetchLiveControlDeviceDetails(currentSelected.id);
        state = state.copyWith(liveDeviceDetails: details);
      } else {
        state = state.copyWith(liveDeviceDetails: null);
      }
    } catch (_) {}
  }

  Future<void> selectLiveControlDevice(LiveControlDeviceItem device) async {
    state = state.copyWith(
      selectedLiveDeviceId: device.id,
      selectedLiveDevice: device,
    );
    try {
      final details = await _api.fetchLiveControlDeviceDetails(device.id);
      state = state.copyWith(liveDeviceDetails: details);
    } catch (_) {}
  }

  Future<bool> executeLiveDeviceCommand({
    required String deviceId,
    required String commandType,
    required Map<String, dynamic> payload,
  }) async {
    // 1. Optimistic state update in local devices list
    final currentDevs = List<LiveControlDeviceItem>.from(state.liveControlDevices);
    final idx = currentDevs.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      final oldDev = currentDevs[idx];
      final newCurrentState = Map<String, dynamic>.from(oldDev.currentState);

      bool newPower = oldDev.powerState;
      if (commandType == 'set_power' || commandType == 'turn_on' || commandType == 'turn_off') {
        newPower = payload['power'] == true || commandType == 'turn_on';
        newCurrentState['power'] = newPower;
      } else if (commandType == 'set_brightness') {
        newCurrentState['brightness'] = payload['brightness'];
        newCurrentState['power'] = true;
        newPower = true;
      } else if (commandType == 'set_temperature') {
        newCurrentState['temperature'] = payload['temperature'];
      } else if (commandType == 'set_mode') {
        newCurrentState['mode'] = payload['mode'];
      } else if (commandType == 'set_fan_speed') {
        newCurrentState['fan_speed'] = payload['fan_speed'];
      } else if (commandType == 'set_swing') {
        newCurrentState['swing'] = payload['swing'];
      } else if (commandType == 'set_channels') {
        newCurrentState['channels'] = payload['channels'];
      } else if (commandType == 'set_lock') {
        newCurrentState['status'] = payload['status'];
        newCurrentState['lock_state'] = (payload['status'] == 'locked');
      } else if (commandType == 'set_volume') {
        newCurrentState['volume'] = payload['volume'];
      } else if (commandType == 'set_input') {
        newCurrentState['input'] = payload['input'];
      } else if (commandType == 'quick_preset') {
        newCurrentState['quick_preset'] = payload['preset'];
        if (payload['preset'] == 'Classroom') {
          newCurrentState['temperature'] = 24;
          newCurrentState['mode'] = 'Cool';
        } else if (payload['preset'] == 'Meeting') {
          newCurrentState['temperature'] = 22;
          newCurrentState['mode'] = 'Cool';
        } else if (payload['preset'] == 'Energy Save') {
          newCurrentState['temperature'] = 26;
          newCurrentState['mode'] = 'Cool';
        }
      }

      final updatedDev = oldDev.copyWith(
        powerState: newPower,
        currentState: newCurrentState,
      );
      currentDevs[idx] = updatedDev;

      LiveControlDeviceItem? updatedSelected = state.selectedLiveDevice;
      if (state.selectedLiveDeviceId == deviceId) {
        updatedSelected = updatedDev;
      }

      state = state.copyWith(
        liveControlDevices: currentDevs,
        selectedLiveDevice: updatedSelected,
      );
    }

    // 2. Execute via backend API & MQTT
    final res = await _api.executeLiveControlCommand(
      deviceId: deviceId,
      commandType: commandType,
      payload: payload,
    );

    // 3. Refresh command history logs for inspector
    if (state.selectedLiveDeviceId == deviceId) {
      final details = await _api.fetchLiveControlDeviceDetails(deviceId);
      if (details != null) {
        state = state.copyWith(liveDeviceDetails: details);
      }
    }

    return res['success'] == true;
  }
}

final deviceManagementProvider = StateNotifierProvider<DeviceManagementNotifier, DeviceManagementState>((ref) {
  return DeviceManagementNotifier(DeviceManagementApiService.instance);
});
