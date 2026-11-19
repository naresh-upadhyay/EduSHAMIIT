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
          // 1. Building Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 520;

                return Column(
                  children: [
                    // Title and Actions
                    if (isCompact) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${building.code} - ${building.name}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
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
                      const SizedBox(height: 4),
                      Text(
                        building.description ?? 'Campus building and facility complex',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: onEditBuilding,
                          icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                          label: const Text('Edit Building', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              color: Color(0xFF2563EB),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${building.code} - ${building.name}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  building.description ?? 'Campus building and facility complex',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: onEditBuilding,
                            icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                            label: const Text('Edit Building', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
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
                    ],
                    const SizedBox(height: 16),

                    // Mini KPI Stats Row for Selected Building
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, miniConstraints) {
                          if (miniConstraints.maxWidth < 560) {
                            // 2x2 grid for mobile
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMiniStat(
                                        icon: Icons.layers_rounded,
                                        iconColor: const Color(0xFF8B5CF6),
                                        label: 'Total Floors',
                                        value: '$totalFloors',
                                        isDark: isDark,
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    Expanded(
                                      child: _buildMiniStat(
                                        icon: Icons.meeting_room_rounded,
                                        iconColor: const Color(0xFF7C3AED),
                                        label: 'Total Rooms',
                                        value: '$totalRooms',
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 18, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMiniStat(
                                        icon: Icons.group_rounded,
                                        iconColor: const Color(0xFF10B981),
                                        label: 'Total Capacity',
                                        value: _formatNumber(totalCapacity),
                                        isDark: isDark,
                                      ),
                                    ),
                                    Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    Expanded(
                                      child: _buildMiniStat(
                                        icon: Icons.pie_chart_rounded,
                                        iconColor: const Color(0xFF0284C7),
                                        label: 'Occupancy',
                                        value: '${_formatNumber(currentOccupancy)} ($occupancyRate%)',
                                        isDark: isDark,
                                        valueColor: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat(
                                  icon: Icons.layers_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  label: 'Total Floors',
                                  value: '$totalFloors',
                                  isDark: isDark,
                                ),
                              ),
                              Container(width: 1, height: 34, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              Expanded(
                                child: _buildMiniStat(
                                  icon: Icons.meeting_room_rounded,
                                  iconColor: const Color(0xFF7C3AED),
                                  label: 'Total Rooms',
                                  value: '$totalRooms',
                                  isDark: isDark,
                                ),
                              ),
                              Container(width: 1, height: 34, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              Expanded(
                                child: _buildMiniStat(
                                  icon: Icons.group_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  label: 'Total Capacity',
                                  value: _formatNumber(totalCapacity),
                                  isDark: isDark,
                                ),
                              ),
                              Container(width: 1, height: 34, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              Expanded(
                                child: _buildMiniStat(
                                  icon: Icons.pie_chart_rounded,
                                  iconColor: const Color(0xFF0284C7),
                                  label: 'Occupancy',
                                  value: '${_formatNumber(currentOccupancy)} ($occupancyRate%)',
                                  isDark: isDark,
                                  valueColor: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 2. Sub-Tabs Bar: Floors | Rooms | Occupancy | Maintenance | Documents
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSubTabItemScrollable('Floors', Icons.layers_outlined, 0),
                        _buildSubTabItemScrollable('Rooms', Icons.meeting_room_outlined, 1),
                        _buildSubTabItemScrollable('Occupancy', Icons.pie_chart_outline, 2),
                        _buildSubTabItemScrollable('Maintenance', Icons.build_outlined, 3),
                        _buildSubTabItemScrollable('Documents', Icons.description_outlined, 4),
                      ],
                    ),
                  );
                }

                return Row(
                  children: [
                    _buildSubTabItem('Floors', Icons.layers_outlined, 0),
                    _buildSubTabItem('Rooms', Icons.meeting_room_outlined, 1),
                    _buildSubTabItem('Occupancy', Icons.pie_chart_outline, 2),
                    _buildSubTabItem('Maintenance', Icons.build_outlined, 3),
                    _buildSubTabItem('Documents', Icons.description_outlined, 4),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 3. Tab Body
          if (activeSubTab == 0)
            FloorsSubtabView(
              building: building,
              floors: floors,
              isLoading: isFloorsLoading,
              onAddFloor: onAddFloor,
              onEditFloor: onEditFloor,
              onDeleteFloor: onDeleteFloor,
              onViewRooms: onViewRoomsOnFloor,
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

  Widget _buildMiniStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabItem(String label, IconData icon, int index) {
    final isActive = activeSubTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => onSubTabChanged(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
            children: [
              Icon(icon, size: 16, color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabItemScrollable(String label, IconData icon, int index) {
    final isActive = activeSubTab == index;

    return InkWell(
      onTap: () => onSubTabChanged(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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
    if (val >= 1000) {
      final s = val.toString();
      final len = s.length;
      return '${s.substring(0, len - 3)},${s.substring(len - 3)}';
    }
    return val.toString();
  }
}
