import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hostel_provider.dart';
import 'dialogs/add_edit_building_dialog.dart';
import 'dialogs/add_edit_floor_dialog.dart';
import 'dialogs/add_edit_room_dialog.dart';

class HostelLeftTree extends ConsumerStatefulWidget {
  const HostelLeftTree({super.key});

  @override
  ConsumerState<HostelLeftTree> createState() => _HostelLeftTreeState();
}

class _HostelLeftTreeState extends ConsumerState<HostelLeftTree> {
  final Map<String, bool> _expandedBuildings = {};
  final Map<String, bool> _expandedFloors = {};
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buildings = state.structureTree;
    final filteredBuildings = _searchQuery.isEmpty
        ? buildings
        : buildings.where((b) {
            final bMatch = b.name.toLowerCase().contains(_searchQuery) ||
                b.code.toLowerCase().contains(_searchQuery);
            final fMatch = b.floors.any((f) =>
                f.name.toLowerCase().contains(_searchQuery) ||
                'floor ${f.floorNumber}'.contains(_searchQuery));
            return bMatch || fMatch;
          }).toList();

    if (_searchQuery.isNotEmpty) {
      for (final b in filteredBuildings) {
        _expandedBuildings[b.id] = true;
      }
    }

    // Automatically expand selected building and floor if not yet set
    for (final b in buildings) {
      if (!_expandedBuildings.containsKey(b.id)) {
        _expandedBuildings[b.id] = (b.id == state.selectedBuildingId);
      }
      for (final f in b.floors) {
        if (!_expandedFloors.containsKey(f.id)) {
          _expandedFloors[f.id] = (f.id == state.selectedFloorId);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title and + Add Building Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Hostel Structure',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const AddEditBuildingDialog(),
                    );
                  },
                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Search hostel, wing, floor...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // Tree View
          Expanded(
            child: state.isTreeLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : filteredBuildings.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.apartment_outlined,
                                size: 40,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No Hostel Buildings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first building above',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredBuildings.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final building = filteredBuildings[index];
                          final isExpanded = _expandedBuildings[building.id] ?? false;

                          // Color accent for building icon matching screenshot
                          Color bIconColor = const Color(0xFF2563EB);
                          Color bIconBg = const Color(0xFFEFF6FF);
                          if (building.name.contains('Girls') || building.genderPolicy == 'GIRLS') {
                            bIconColor = index % 2 == 0 ? const Color(0xFFDB2777) : const Color(0xFF9333EA);
                            bIconBg = index % 2 == 0 ? const Color(0xFFFCE7F3) : const Color(0xFFF3E8FF);
                          } else if (building.name.contains('Boys Hostel B')) {
                            bIconColor = const Color(0xFF16A34A);
                            bIconBg = const Color(0xFFDCFCE7);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Building Row
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _expandedBuildings[building.id] = !isExpanded;
                                  });
                                  notifier.selectBuilding(building.id);
                                },
                                hoverColor: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                                        size: 18,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: bIconBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.apartment_rounded,
                                          size: 16,
                                          color: bIconColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          building.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      // Floors count chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${building.floors.length} floors',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Context menu
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 140),
                                        onSelected: (action) async {
                                          if (action == 'add_floor') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AddEditFloorDialog(preselectedBuildingId: building.id),
                                            );
                                          } else if (action == 'edit') {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AddEditBuildingDialog(building: building),
                                            );
                                          } else if (action == 'delete') {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Building'),
                                                content: Text('Are you sure you want to delete "${building.name}" and all associated floors?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true) {
                                              final ok = await notifier.service.deleteBuilding(building.id);
                                              if (ok) {
                                                notifier.showSuccess('Building deleted');
                                                notifier.refreshAll();
                                              } else {
                                                notifier.showError('Failed to delete building');
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'add_floor',
                                            child: Text('Add Floor', style: TextStyle(fontSize: 13)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit Building', style: TextStyle(fontSize: 13)),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete Building', style: TextStyle(fontSize: 13, color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Floors under building
                              if (isExpanded)
                                ...building.floors.map((floor) {
                                  final isFloorExpanded = _expandedFloors[floor.id] ?? false;
                                  final isFloorSelected = state.selectedFloorId == floor.id;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _expandedFloors[floor.id] = !isFloorExpanded;
                                          });
                                          notifier.selectFloor(building.id, floor.id);
                                        },
                                        child: Container(
                                          color: isFloorSelected
                                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                              : Colors.transparent,
                                          padding: const EdgeInsets.only(left: 24, right: 10, top: 6, bottom: 6),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isFloorExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                                                size: 16,
                                                color: const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.layers_outlined,
                                                size: 15,
                                                color: isFloorSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  floor.floorName,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: isFloorSelected ? FontWeight.w600 : FontWeight.w500,
                                                    color: isFloorSelected
                                                        ? const Color(0xFF2563EB)
                                                        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${floor.roomsCount} rooms',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, size: 15, color: Color(0xFF94A3B8)),
                                                padding: EdgeInsets.zero,
                                                onSelected: (action) async {
                                                  if (action == 'add_room') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AddEditRoomDialog(
                                                        preselectedBuildingId: building.id,
                                                        preselectedFloorId: floor.id,
                                                      ),
                                                    );
                                                  } else if (action == 'edit_floor') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AddEditFloorDialog(
                                                        defaultBuilding: building,
                                                        floor: floor,
                                                      ),
                                                    );
                                                  } else if (action == 'delete_floor') {
                                                    final confirmed = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text('Delete Floor'),
                                                        content: Text('Are you sure you want to delete "${floor.floorName}"?'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirmed == true) {
                                                      final ok = await notifier.service.deleteFloor(floor.id);
                                                      if (ok) {
                                                        notifier.showSuccess('Floor deleted');
                                                        notifier.refreshAll();
                                                      } else {
                                                        notifier.showError('Failed to delete floor');
                                                      }
                                                    }
                                                  }
                                                },
                                                itemBuilder: (ctx) => [
                                                  const PopupMenuItem(
                                                    value: 'add_room',
                                                    child: Text('Add Room', style: TextStyle(fontSize: 12)),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'edit_floor',
                                                    child: Text('Edit Floor', style: TextStyle(fontSize: 12)),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete_floor',
                                                    child: Text('Delete Floor', style: TextStyle(fontSize: 12, color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Rooms under floor
                                      if (isFloorExpanded && floor.rooms.isNotEmpty)
                                        ...floor.rooms.map((room) {
                                          final isRoomSelected = state.selectedRoomId == room.id;
                                          return InkWell(
                                            onTap: () {
                                              notifier.selectRoom(room.id);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.only(left: 48, right: 10, top: 4, bottom: 4),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.meeting_room_outlined,
                                                    size: 14,
                                                    color: isRoomSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      room.roomNumber,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isRoomSelected ? FontWeight.w600 : FontWeight.w400,
                                                        color: isRoomSelected
                                                            ? const Color(0xFF2563EB)
                                                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, size: 14, color: Color(0xFF94A3B8)),
                                                    padding: EdgeInsets.zero,
                                                    onSelected: (action) async {
                                                      if (action == 'edit') {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AddEditRoomDialog(treeRoom: room),
                                                        );
                                                      } else if (action == 'delete') {
                                                        final confirmed = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Delete Room'),
                                                            content: Text('Are you sure you want to delete room "${room.roomNumber}"?'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirmed == true) {
                                                          final ok = await notifier.service.deleteRoom(room.id);
                                                          if (ok) {
                                                            notifier.showSuccess('Room deleted');
                                                            notifier.refreshAll();
                                                          } else {
                                                            notifier.showError('Failed to delete room');
                                                          }
                                                        }
                                                      }
                                                    },
                                                    itemBuilder: (ctx) => [
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text('Edit Room', style: TextStyle(fontSize: 12)),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Delete Room', style: TextStyle(fontSize: 12, color: Colors.red)),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  );
                                }),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
