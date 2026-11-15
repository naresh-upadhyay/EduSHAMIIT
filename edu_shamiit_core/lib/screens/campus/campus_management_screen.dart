import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/campus_models.dart';
import 'providers/campus_provider.dart';
import 'services/campus_api_service.dart';
import 'widgets/campus_header_bar.dart';
import 'widgets/campus_tabs_bar.dart';
import 'widgets/campus_kpi_cards.dart';
import 'widgets/buildings/building_left_panel.dart';
import 'widgets/buildings/building_center_panel.dart';
import 'widgets/buildings/building_right_details_panel.dart';
import 'widgets/dialogs/add_edit_building_dialog.dart';
import 'widgets/dialogs/add_edit_floor_dialog.dart';
import 'widgets/dialogs/add_edit_room_dialog.dart';
import 'widgets/dialogs/bulk_create_rooms_dialog.dart';
import 'widgets/dialogs/bulk_import_rooms_dialog.dart';
import 'widgets/dialogs/room_equipment_dialog.dart';
import 'widgets/dialogs/room_details_drawer.dart';
import 'widgets/dialogs/room_allocation_dialog.dart';
import 'widgets/space_booking/space_booking_tab_view.dart';
import 'widgets/maintenance/maintenance_tab_view.dart';
import 'widgets/safety_compliance/safety_compliance_tab_view.dart';
import 'widgets/device_management/device_management_tab_view.dart';
import 'widgets/facilities/facilities_tab_view.dart';
import 'widgets/utilities/utilities_services_tab_view.dart';
import 'widgets/reports/campus_reports_tab_view.dart';
import '../../utils/tab_url_sync.dart';

class CampusManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const CampusManagementScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<CampusManagementScreen> createState() => _CampusManagementScreenState();
}

class _CampusManagementScreenState extends ConsumerState<CampusManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialTab != 0) {
          ref.read(campusProvider.notifier).setActiveCampusTab(widget.initialTab);
        }
        ref.read(campusProvider.notifier).loadAll();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CampusManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(campusProvider.notifier).setActiveCampusTab(widget.initialTab);
        }
      });
    }
  }

  // Dialog Helpers
  void _openAddBuildingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDialog(
        onSaved: () {
          ref.read(campusProvider.notifier).loadAll();
          _showSnackbar('Building created successfully!');
        },
      ),
    );
  }

  void _openEditBuildingDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditBuildingDialog(
        building: building,
        onSaved: () {
          ref.read(campusProvider.notifier).loadAll();
          _showSnackbar('Building updated successfully!');
        },
      ),
    );
  }

  void _archiveBuilding(BuildingModel building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive ${building.name}?'),
        content: const Text(
          'Archiving this building preserves all historical rooms, timetables, and student allocations while marking it inactive for new assignments. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Archive Building'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.archiveBuilding(building.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadAll();
        _showSnackbar('Building successfully archived.');
      } else {
        _showSnackbar(res['message'] ?? 'Failed to archive building.', isError: true);
      }
    }
  }

  void _deleteBuilding(BuildingModel building) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${building.name}?'),
        content: const Text(
          'Are you sure you want to delete this building? Note: Buildings with active rooms or historical assignments cannot be deleted and must be archived instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Building'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteBuilding(building.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadAll();
        _showSnackbar('Building deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete building.', isError: true);
      }
    }
  }

  void _openAddFloorDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFloorDialog(
        buildingId: building.id,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Floor added successfully!');
        },
      ),
    );
  }

  void _openEditFloorDialog(BuildingModel building, BuildingFloorModel floor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFloorDialog(
        buildingId: building.id,
        floor: floor,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Floor updated successfully!');
        },
      ),
    );
  }

  void _deleteFloor(BuildingModel building, BuildingFloorModel floor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Floor ${floor.name}?'),
        content: const Text(
          'Are you sure you want to delete this floor? Floors containing active rooms cannot be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Floor'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteFloor(floor.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
        _showSnackbar('Floor deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete floor.', isError: true);
      }
    }
  }

  void _openAddRoomDialog(BuildingModel building, List<BuildingFloorModel> floors) {
    if (floors.isEmpty) {
      _showSnackbar('Please add at least one floor before creating rooms.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditRoomDialog(
        building: building,
        floors: floors,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Room created successfully!');
        },
      ),
    );
  }

  void _openEditRoomDialog(BuildingModel building, List<BuildingFloorModel> floors, RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditRoomDialog(
        building: building,
        floors: floors,
        room: room,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Room updated successfully!');
        },
      ),
    );
  }

  void _deleteRoom(BuildingModel building, RoomModel room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Room ${room.roomNumber}?'),
        content: const Text('Are you sure you want to delete this room? This action will mark it inactive.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Room'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await CampusApiService.instance.deleteRoom(room.id);
      if (res['success'] == true) {
        ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
        _showSnackbar('Room deleted successfully.');
      } else {
        _showSnackbar(res['message'] ?? 'Cannot delete room.', isError: true);
      }
    }
  }

  void _openBulkCreateDialog(BuildingModel building, List<BuildingFloorModel> floors) {
    if (floors.isEmpty) {
      _showSnackbar('Please add at least one floor before creating rooms.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkCreateRoomsDialog(
        building: building,
        floors: floors,
        onSaved: () {
          ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          _showSnackbar('Rooms successfully created in bulk!');
        },
      ),
    );
  }

  void _openBulkImportDialog(BuildingModel? building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BulkImportRoomsDialog(
        onImportCompleted: () {
          if (building != null) {
            ref.read(campusProvider.notifier).loadBuildingDetails(building.id);
          } else {
            ref.read(campusProvider.notifier).loadAll();
          }
          _showSnackbar('Import processed successfully!');
        },
      ),
    );
  }

  void _openEquipmentDialog(RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomEquipmentDialog(
        room: room,
        onUpdated: () {
          if (ref.read(campusProvider).selectedBuilding != null) {
            ref.read(campusProvider.notifier).reloadRooms();
          }
        },
      ),
    );
  }

  void _openAllocationDialog(RoomModel room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RoomAllocationDialog(
        room: room,
        onAllocated: () {
          if (ref.read(campusProvider).selectedBuilding != null) {
            ref.read(campusProvider.notifier).reloadRooms();
          }
          _showSnackbar('Room successfully allocated!');
        },
      ),
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(campusProvider);
    final notifier = ref.read(campusProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Main Scrollable Dashboard View
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Campus Header Bar
                  CampusHeaderBar(
                    onAddBuilding: _openAddBuildingDialog,
                    onBulkImport: () => _openBulkImportDialog(state.selectedBuilding),
                    onExport: () => CampusApiService.instance.exportData('rooms', buildingId: state.selectedBuilding?.id),
                  ),
                  const SizedBox(height: 12),

                  // Campus Navigation Tabs Header (Buildings & Rooms [ACTIVE], Facilities, Space Booking, etc.)
                  CampusTabsBar(
                    activeIndex: state.activeCampusTab,
                    onTabSelected: (idx) {
                      notifier.setActiveCampusTab(idx);
                      updateTabUrl('/admin/campus', idx);
                    },
                  ),
                  const SizedBox(height: 14),

                  if (state.activeCampusTab == 1)
                    const Expanded(child: FacilitiesTabView())
                  else if (state.activeCampusTab == 2)
                    const Expanded(child: SpaceBookingTabView())
                  else if (state.activeCampusTab == 3)
                    const Expanded(child: MaintenanceTabView())
                  else if (state.activeCampusTab == 4)
                    const Expanded(child: SafetyComplianceTabView())
                  else if (state.activeCampusTab == 5)
                    const Expanded(child: DeviceManagementTabView())
                  else if (state.activeCampusTab == 6)
                    const Expanded(child: UtilitiesServicesTabView())
                  else if (state.activeCampusTab == 7)
                    const Expanded(child: CampusReportsTabView())
                  else ...[
                    // Top KPI Summary Cards Row
                    CampusKpiCards(kpis: state.kpis),
                    const SizedBox(height: 16),

                    // Three-Column Split Dashboard Area
                    Expanded(
                      child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        final bld = state.selectedBuilding ?? (state.buildings.isNotEmpty ? state.buildings.first : null);
                        final primaryColor = Theme.of(context).colorScheme.primary;

                        if (state.isLoading) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading campus buildings and facilities...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (bld == null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text('No buildings available. Click below to add the first building.', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _openAddBuildingDialog,
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  label: const Text('Add Building', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                ),
                              ],
                            ),
                          );
                        }

                        if (screenWidth > 1200) {
                          // Desktop 3-Column Split
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Building Selector Panel (width ~290px)
                              SizedBox(
                                width: 290,
                                child: BuildingLeftPanel(
                                  buildings: state.buildings,
                                  selectedBuilding: state.selectedBuilding,
                                  onSelectBuilding: notifier.selectBuilding,
                                  onAddBuilding: _openAddBuildingDialog,
                                  searchQuery: state.buildingSearchQuery,
                                  onSearch: notifier.setBuildingSearchQuery,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Center Active Building Area (Flex expanded)
                              Expanded(
                                child: BuildingCenterPanel(
                                  building: bld,
                                  buildingDetails: state.selectedBuildingDetails,
                                  activeSubTab: state.activeBuildingSubTab,
                                  onSubTabChanged: notifier.setActiveBuildingSubTab,
                                  onEditBuilding: () => _openEditBuildingDialog(bld),
                                  onArchiveBuilding: () => _archiveBuilding(bld),
                                  onDeleteBuilding: () => _deleteBuilding(bld),
                                  floors: state.floors,
                                  isFloorsLoading: state.isFloorsLoading,
                                  onAddFloor: () => _openAddFloorDialog(bld),
                                  onEditFloor: (f) => _openEditFloorDialog(bld, f),
                                  onDeleteFloor: (f) => _deleteFloor(bld, f),
                                  onViewRoomsOnFloor: (f) {
                                    notifier.setFilterFloor(f.id);
                                    notifier.setActiveBuildingSubTab(1); // Switch to rooms tab
                                  },
                                  rooms: state.rooms,
                                  isRoomsLoading: state.isRoomsLoading,
                                  roomsViewMode: state.roomsViewMode,
                                  onRoomsViewModeChanged: notifier.setRoomsViewMode,
                                  roomSearchQuery: state.roomSearchQuery,
                                  onRoomSearch: notifier.setRoomSearch,
                                  filterFloorId: state.filterFloorId,
                                  onFilterFloor: notifier.setFilterFloor,
                                  filterRoomType: state.filterRoomType,
                                  onFilterRoomType: notifier.setFilterRoomType,
                                  filterStatus: state.filterRoomStatus,
                                  onFilterStatus: notifier.setFilterRoomStatus,
                                  onClearRoomFilters: notifier.clearFilters,
                                  onAddRoom: () => _openAddRoomDialog(bld, state.floors),
                                  onBulkCreateRooms: () => _openBulkCreateDialog(bld, state.floors),
                                  onInspectRoom: notifier.inspectRoom,
                                  onEditRoom: (r) => _openEditRoomDialog(bld, state.floors, r),
                                  onManageEquipment: _openEquipmentDialog,
                                  onDeleteRoom: (r) => _deleteRoom(bld, r),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Right Building Details & Quick Actions Panel (width ~290px)
                              SizedBox(
                                width: 290,
                                child: BuildingRightDetailsPanel(
                                  building: bld,
                                  onAddRoom: () => _openAddRoomDialog(bld, state.floors),
                                  onAllocateRoom: () {
                                    if (state.rooms.isNotEmpty) {
                                      _openAllocationDialog(state.rooms.first);
                                    } else {
                                      _showSnackbar('Create a room before allocating.', isError: true);
                                    }
                                  },
                                  onRoomSetup: () => notifier.setActiveBuildingSubTab(1),
                                  onImportRooms: () => _openBulkImportDialog(bld),
                                  onExportList: () => CampusApiService.instance.exportData('rooms', buildingId: bld.id),
                                  onRoomReport: () => _showSnackbar('Generating institutional infrastructure report...'),
                                ),
                              ),
                            ],
                          );
                        } else if (screenWidth >= 800) {
                          // Medium / Tablet Screen layout: Left panel + Center panel
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 240,
                                child: BuildingLeftPanel(
                                  buildings: state.buildings,
                                  selectedBuilding: state.selectedBuilding,
                                  onSelectBuilding: notifier.selectBuilding,
                                  onAddBuilding: _openAddBuildingDialog,
                                  searchQuery: state.buildingSearchQuery,
                                  onSearch: notifier.setBuildingSearchQuery,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BuildingCenterPanel(
                                  building: bld,
                                  buildingDetails: state.selectedBuildingDetails,
                                  activeSubTab: state.activeBuildingSubTab,
                                  onSubTabChanged: notifier.setActiveBuildingSubTab,
                                  onEditBuilding: () => _openEditBuildingDialog(bld),
                                  onArchiveBuilding: () => _archiveBuilding(bld),
                                  onDeleteBuilding: () => _deleteBuilding(bld),
                                  floors: state.floors,
                                  isFloorsLoading: state.isFloorsLoading,
                                  onAddFloor: () => _openAddFloorDialog(bld),
                                  onEditFloor: (f) => _openEditFloorDialog(bld, f),
                                  onDeleteFloor: (f) => _deleteFloor(bld, f),
                                  onViewRoomsOnFloor: (f) {
                                    notifier.setFilterFloor(f.id);
                                    notifier.setActiveBuildingSubTab(1);
                                  },
                                  rooms: state.rooms,
                                  isRoomsLoading: state.isRoomsLoading,
                                  roomsViewMode: state.roomsViewMode,
                                  onRoomsViewModeChanged: notifier.setRoomsViewMode,
                                  roomSearchQuery: state.roomSearchQuery,
                                  onRoomSearch: notifier.setRoomSearch,
                                  filterFloorId: state.filterFloorId,
                                  onFilterFloor: notifier.setFilterFloor,
                                  filterRoomType: state.filterRoomType,
                                  onFilterRoomType: notifier.setFilterRoomType,
                                  filterStatus: state.filterRoomStatus,
                                  onFilterStatus: notifier.setFilterRoomStatus,
                                  onClearRoomFilters: notifier.clearFilters,
                                  onAddRoom: () => _openAddRoomDialog(bld, state.floors),
                                  onBulkCreateRooms: () => _openBulkCreateDialog(bld, state.floors),
                                  onInspectRoom: notifier.inspectRoom,
                                  onEditRoom: (r) => _openEditRoomDialog(bld, state.floors, r),
                                  onManageEquipment: _openEquipmentDialog,
                                  onDeleteRoom: (r) => _deleteRoom(bld, r),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile Single-Column Layout (< 800px)
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Mobile Building Selector Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: bld.id,
                                            isExpanded: true,
                                            items: state.buildings.map((b) => DropdownMenuItem(
                                              value: b.id,
                                              child: Text(
                                                '${b.code} - ${b.name}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final found = state.buildings.firstWhere((b) => b.id == val, orElse: () => bld);
                                                notifier.selectBuilding(found);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: _openAddBuildingDialog,
                                        icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB)),
                                        tooltip: 'Add Building',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                                // Full-width BuildingCenterPanel
                                BuildingCenterPanel(
                                  building: bld,
                                  buildingDetails: state.selectedBuildingDetails,
                                  activeSubTab: state.activeBuildingSubTab,
                                  onSubTabChanged: notifier.setActiveBuildingSubTab,
                                  onEditBuilding: () => _openEditBuildingDialog(bld),
                                  onArchiveBuilding: () => _archiveBuilding(bld),
                                  onDeleteBuilding: () => _deleteBuilding(bld),
                                  floors: state.floors,
                                  isFloorsLoading: state.isFloorsLoading,
                                  onAddFloor: () => _openAddFloorDialog(bld),
                                  onEditFloor: (f) => _openEditFloorDialog(bld, f),
                                  onDeleteFloor: (f) => _deleteFloor(bld, f),
                                  onViewRoomsOnFloor: (f) {
                                    notifier.setFilterFloor(f.id);
                                    notifier.setActiveBuildingSubTab(1);
                                  },
                                  rooms: state.rooms,
                                  isRoomsLoading: state.isRoomsLoading,
                                  roomsViewMode: state.roomsViewMode,
                                  onRoomsViewModeChanged: notifier.setRoomsViewMode,
                                  roomSearchQuery: state.roomSearchQuery,
                                  onRoomSearch: notifier.setRoomSearch,
                                  filterFloorId: state.filterFloorId,
                                  onFilterFloor: notifier.setFilterFloor,
                                  filterRoomType: state.filterRoomType,
                                  onFilterRoomType: notifier.setFilterRoomType,
                                  filterStatus: state.filterRoomStatus,
                                  onFilterStatus: notifier.setFilterRoomStatus,
                                  onClearRoomFilters: notifier.clearFilters,
                                  onAddRoom: () => _openAddRoomDialog(bld, state.floors),
                                  onBulkCreateRooms: () => _openBulkCreateDialog(bld, state.floors),
                                  onInspectRoom: notifier.inspectRoom,
                                  onEditRoom: (r) => _openEditRoomDialog(bld, state.floors, r),
                                  onManageEquipment: _openEquipmentDialog,
                                  onDeleteRoom: (r) => _deleteRoom(bld, r),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

            // Slide-in Room Details Drawer (when a room is inspected)
            if (state.inspectedRoom != null && state.selectedBuilding != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Material(
                  elevation: 16,
                  child: RoomDetailsDrawer(
                    room: state.inspectedRoom!,
                    building: state.selectedBuilding!,
                    onClose: () => notifier.inspectRoom(null),
                    onEdit: () {
                      final r = state.inspectedRoom!;
                      notifier.inspectRoom(null);
                      _openEditRoomDialog(state.selectedBuilding!, state.floors, r);
                    },
                    onManageEquipment: () {
                      final r = state.inspectedRoom!;
                      _openEquipmentDialog(r);
                    },
                    onAllocate: () {
                      final r = state.inspectedRoom!;
                      _openAllocationDialog(r);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
