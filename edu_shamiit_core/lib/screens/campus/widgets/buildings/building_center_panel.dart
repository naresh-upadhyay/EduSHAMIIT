import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import 'documents_subtab_view.dart';
import 'floors_subtab_view.dart';
import 'maintenance_subtab_view.dart';
import 'occupancy_subtab_view.dart';
import 'rooms_subtab_view.dart';

class BuildingCenterPanel extends StatelessWidget {
  final BuildingModel building;
  final Map<String, dynamic>? buildingDetails;
  final int activeSubTab; // 0: Floors, 1: Rooms, 2: Occupancy, 3: Maintenance, 4: Documents
  final ValueChanged<int> onSubTabChanged;
  final VoidCallback onEditBuilding;
  final VoidCallback onArchiveBuilding;
  final VoidCallback onDeleteBuilding;

  // Floors Props
  final List<BuildingFloorModel> floors;
  final bool isFloorsLoading;
  final VoidCallback onAddFloor;
  final ValueChanged<BuildingFloorModel> onEditFloor;
  final ValueChanged<BuildingFloorModel> onDeleteFloor;
  final ValueChanged<BuildingFloorModel> onViewRoomsOnFloor;
  final int totalFloorsCount;
  final int floorsPage;
  final int floorsPageSize;
  final ValueChanged<int>? onFloorsPageChanged;
  final ValueChanged<int>? onFloorsPageSizeChanged;
  final String? floorsSortBy;
  final String? floorsSortOrder;
  final void Function(String, bool)? onFloorsSortChanged;

  // Rooms Props
  final List<RoomModel> rooms;
  final bool isRoomsLoading;
  final int roomsViewMode;
  final ValueChanged<int> onRoomsViewModeChanged;
  final String roomSearchQuery;
  final ValueChanged<String> onRoomSearch;
  final String? filterFloorId;
  final ValueChanged<String?> onFilterFloor;
  final String? filterRoomType;
  final ValueChanged<String?> onFilterRoomType;
  final String? filterStatus;
  final ValueChanged<String?> onFilterStatus;
  final VoidCallback onClearRoomFilters;
  final VoidCallback onAddRoom;
  final VoidCallback onBulkCreateRooms;
  final ValueChanged<RoomModel> onInspectRoom;
  final ValueChanged<RoomModel> onEditRoom;
  final ValueChanged<RoomModel> onManageEquipment;
  final ValueChanged<RoomModel> onDeleteRoom;
  final int totalRoomsCount;
  final int roomsPage;
  final int roomsPageSize;
  final ValueChanged<int>? onRoomsPageChanged;
  final ValueChanged<int>? onRoomsPageSizeChanged;
  final String? roomsSortBy;
  final String? roomsSortOrder;
  final void Function(String, bool)? onRoomsSortChanged;

  // Occupancy Props
  final List<BuildingOccupancyModel> occupancyList;
  final bool isOccupancyLoading;
  final VoidCallback? onAddOccupancy;
  final ValueChanged<BuildingOccupancyModel>? onEditOccupancy;
  final ValueChanged<BuildingOccupancyModel>? onDeleteOccupancy;

  // Maintenance Props
  final List<BuildingMaintenanceModel> maintenanceList;
  final bool isMaintenanceLoading;
  final VoidCallback? onAddMaintenance;
  final ValueChanged<BuildingMaintenanceModel>? onEditMaintenance;
  final ValueChanged<BuildingMaintenanceModel>? onDeleteMaintenance;
  final void Function(BuildingMaintenanceModel, String)? onQuickUpdateMaintenanceStatus;

  // Documents Props
  final List<BuildingDocumentModel> documentsList;
  final bool isDocumentsLoading;
  final VoidCallback? onAddDocument;
  final ValueChanged<BuildingDocumentModel>? onEditDocument;
  final ValueChanged<BuildingDocumentModel>? onDeleteDocument;

  const BuildingCenterPanel({
    super.key,
    required this.building,
    this.buildingDetails,
    required this.activeSubTab,
    required this.onSubTabChanged,
    required this.onEditBuilding,
    required this.onArchiveBuilding,
    required this.onDeleteBuilding,
    required this.floors,
    this.isFloorsLoading = false,
    required this.onAddFloor,
    required this.onEditFloor,
    required this.onDeleteFloor,
    required this.onViewRoomsOnFloor,
    this.totalFloorsCount = 0,
    this.floorsPage = 1,
    this.floorsPageSize = 10,
    this.onFloorsPageChanged,
    this.onFloorsPageSizeChanged,
    this.floorsSortBy,
    this.floorsSortOrder,
    this.onFloorsSortChanged,
    required this.rooms,
    this.isRoomsLoading = false,
    required this.roomsViewMode,
    required this.onRoomsViewModeChanged,
    required this.roomSearchQuery,
    required this.onRoomSearch,
    this.filterFloorId,
    required this.onFilterFloor,
    this.filterRoomType,
    required this.onFilterRoomType,
    this.filterStatus,
    required this.onFilterStatus,
    required this.onClearRoomFilters,
    required this.onAddRoom,
    required this.onBulkCreateRooms,
    required this.onInspectRoom,
    required this.onEditRoom,
    required this.onManageEquipment,
    required this.onDeleteRoom,
    this.totalRoomsCount = 0,
    this.roomsPage = 1,
    this.roomsPageSize = 10,
    this.onRoomsPageChanged,
    this.onRoomsPageSizeChanged,
    this.roomsSortBy,
    this.roomsSortOrder,
    this.onRoomsSortChanged,
    this.occupancyList = const [],
    this.isOccupancyLoading = false,
    this.onAddOccupancy,
    this.onEditOccupancy,
    this.onDeleteOccupancy,
    this.maintenanceList = const [],
    this.isMaintenanceLoading = false,
    this.onAddMaintenance,
    this.onEditMaintenance,
    this.onDeleteMaintenance,
    this.onQuickUpdateMaintenanceStatus,
    this.documentsList = const [],
    this.isDocumentsLoading = false,
    this.onAddDocument,
    this.onEditDocument,
    this.onDeleteDocument,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final summary = buildingDetails?['summary'] as Map<String, dynamic>?;
    final totalFloors = summary?['total_floors'] ?? building.totalFloors;
    final totalRooms = summary?['total_rooms'] ?? building.totalRooms;
    final totalCapacity = summary?['total_capacity'] ?? building.totalCapacity;
    final currentOccupancy = summary?['current_occupancy'] ?? building.currentOccupancy;
    final occupancyRate = summary?['occupancy_rate'] ?? building.occupancyRate;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Sleek Compact Building Summary Header (Combined header + mini metrics)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${building.code} - ${building.name}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onEditBuilding,
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'archive') onArchiveBuilding();
                              if (val == 'delete') onDeleteBuilding();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'archive', child: Text('Archive Building')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Building', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              building.buildingType,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                          _buildMiniBadge(Icons.layers_rounded, const Color(0xFF8B5CF6), '$totalFloors Floors', isDark),
                          _buildMiniBadge(Icons.meeting_room_rounded, const Color(0xFF7C3AED), '$totalRooms Rooms', isDark),
                          _buildMiniBadge(Icons.group_rounded, const Color(0xFF10B981), '${_formatNumber(totalCapacity)} Cap', isDark),
                          _buildMiniBadge(Icons.pie_chart_rounded, const Color(0xFF0284C7), '${_formatNumber(currentOccupancy)} ($occupancyRate%)', isDark),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${building.code} - ${building.name}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              building.buildingType,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildMiniBadge(Icons.layers_rounded, const Color(0xFF8B5CF6), '$totalFloors Floors', isDark),
                              _buildMiniBadge(Icons.meeting_room_rounded, const Color(0xFF7C3AED), '$totalRooms Rooms', isDark),
                              _buildMiniBadge(Icons.group_rounded, const Color(0xFF10B981), '${_formatNumber(totalCapacity)} Cap', isDark),
                              _buildMiniBadge(Icons.pie_chart_rounded, const Color(0xFF0284C7), '${_formatNumber(currentOccupancy)} ($occupancyRate%)', isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: onEditBuilding,
                      icon: const Icon(Icons.edit, size: 12),
                      label: const Text('Edit Building', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'archive') onArchiveBuilding();
                        if (val == 'delete') onDeleteBuilding();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'archive', child: Text('Archive Building')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete Building', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // 2. Sub-Tabs Bar: Floors | Rooms | Occupancy | Maintenance | Documents
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTabItem('Floors', Icons.layers_outlined, 0),
                  _buildSubTabItem('Rooms', Icons.meeting_room_outlined, 1),
                  _buildSubTabItem('Occupancy', Icons.pie_chart_outline, 2),
                  _buildSubTabItem('Maintenance', Icons.build_circle_outlined, 3),
                  _buildSubTabItem('Documents', Icons.description_outlined, 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Active Subtab View Content
          if (activeSubTab == 0)
            FloorsSubtabView(
              building: building,
              floors: floors,
              isLoading: isFloorsLoading,
              onAddFloor: onAddFloor,
              onEditFloor: onEditFloor,
              onDeleteFloor: onDeleteFloor,
              onViewRooms: onViewRoomsOnFloor,
              totalFloorsCount: totalFloorsCount > 0 ? totalFloorsCount : floors.length,
              currentPage: floorsPage,
              pageSize: floorsPageSize,
              onPageChanged: onFloorsPageChanged ?? (_) {},
              onPageSizeChanged: onFloorsPageSizeChanged ?? (_) {},
              sortBy: floorsSortBy,
              sortOrder: floorsSortOrder,
              onSortChanged: onFloorsSortChanged,
            )
          else if (activeSubTab == 1)
            RoomsSubtabView(
              building: building,
              rooms: rooms,
              floors: floors,
              isLoading: isRoomsLoading,
              viewMode: roomsViewMode,
              onViewModeChanged: onRoomsViewModeChanged,
              searchQuery: roomSearchQuery,
              onSearch: onRoomSearch,
              filterFloorId: filterFloorId,
              onFilterFloor: onFilterFloor,
              filterRoomType: filterRoomType,
              onFilterRoomType: onFilterRoomType,
              filterStatus: filterStatus,
              onFilterStatus: onFilterStatus,
              onClearFilters: onClearRoomFilters,
              onAddRoom: onAddRoom,
              onBulkCreate: onBulkCreateRooms,
              onInspectRoom: onInspectRoom,
              onEditRoom: onEditRoom,
              onManageEquipment: onManageEquipment,
              onDeleteRoom: onDeleteRoom,
              totalRoomsCount: totalRoomsCount > 0 ? totalRoomsCount : rooms.length,
              currentPage: roomsPage,
              pageSize: roomsPageSize,
              onPageChanged: onRoomsPageChanged ?? (_) {},
              onPageSizeChanged: onRoomsPageSizeChanged ?? (_) {},
              sortBy: roomsSortBy,
              sortOrder: roomsSortOrder,
              onSortChanged: onRoomsSortChanged,
            )
          else if (activeSubTab == 2)
            OccupancySubtabView(
              building: building,
              occupancyList: occupancyList,
              rooms: rooms,
              isLoading: isOccupancyLoading,
              onAddOccupancy: onAddOccupancy ?? () {},
              onEditOccupancy: onEditOccupancy ?? (_) {},
              onDeleteOccupancy: onDeleteOccupancy ?? (_) {},
            )
          else if (activeSubTab == 3)
            MaintenanceSubtabView(
              building: building,
              maintenanceList: maintenanceList,
              floors: floors,
              rooms: rooms,
              isLoading: isMaintenanceLoading,
              onAddMaintenance: onAddMaintenance ?? () {},
              onEditMaintenance: onEditMaintenance ?? (_) {},
              onDeleteMaintenance: onDeleteMaintenance ?? (_) {},
              onQuickUpdateStatus: onQuickUpdateMaintenanceStatus ?? (_, __) {},
            )
          else
            DocumentsSubtabView(
              building: building,
              documents: documentsList,
              isLoading: isDocumentsLoading,
              onAddDocument: onAddDocument ?? () {},
              onEditDocument: onEditDocument ?? (_) {},
              onDeleteDocument: onDeleteDocument ?? (_) {},
            ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, Color color, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(String label, IconData icon, int index) {
    final isActive = activeSubTab == index;

    return InkWell(
      onTap: () => onSubTabChanged(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
