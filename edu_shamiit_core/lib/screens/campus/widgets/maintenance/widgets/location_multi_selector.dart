import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/campus_provider.dart';
import '../../../providers/facilities_provider.dart';

class SelectedLocationItem {
  final String? buildingId;
  final String? buildingName;
  final String? floorId;
  final String? floorName;
  final String? roomId;
  final String? roomName;
  final String? facilityId;
  final String? facilityName;
  final String displayName;
  final String locationType; // 'room' or 'facility'

  const SelectedLocationItem({
    this.buildingId,
    this.buildingName,
    this.floorId,
    this.floorName,
    this.roomId,
    this.roomName,
    this.facilityId,
    this.facilityName,
    required this.displayName,
    required this.locationType,
  });

  Map<String, dynamic> toJson() => {
        if (buildingId != null) 'building_id': buildingId,
        if (buildingName != null) 'building_name': buildingName,
        if (floorId != null) 'floor_id': floorId,
        if (floorName != null) 'floor_name': floorName,
        if (roomId != null) 'room_id': roomId,
        if (roomName != null) 'room_name': roomName,
        if (facilityId != null) 'facility_id': facilityId,
        if (facilityName != null) 'facility_name': facilityName,
        'location_name': displayName,
        'location_display': displayName,
        'location_type': locationType,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedLocationItem &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          facilityId == other.facilityId &&
          displayName == other.displayName;

  @override
  int get hashCode => roomId.hashCode ^ facilityId.hashCode ^ displayName.hashCode;
}

class LocationMultiSelector extends ConsumerStatefulWidget {
  final List<SelectedLocationItem> initialSelected;
  final bool allowMultiple;
  final int initialSourceTab;
  final ValueChanged<List<SelectedLocationItem>> onSelectionChanged;

  const LocationMultiSelector({
    super.key,
    this.initialSelected = const [],
    this.allowMultiple = true,
    this.initialSourceTab = 0,
    required this.onSelectionChanged,
  });

  @override
  ConsumerState<LocationMultiSelector> createState() => _LocationMultiSelectorState();
}

class _LocationMultiSelectorState extends ConsumerState<LocationMultiSelector> {
  int _sourceTab = 0; // 0: Buildings & Rooms, 1: Campus Facilities
  String? _selectedBuildingId;
  String? _selectedFloorId;
  final TextEditingController _searchController = TextEditingController();
  final Set<SelectedLocationItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _selectedItems.addAll(widget.initialSelected);
    if (widget.initialSourceTab != 0) {
      _sourceTab = widget.initialSourceTab;
    } else if (widget.initialSelected.any((item) => item.locationType == 'facility')) {
      _sourceTab = 1;
    }
  }

  @override
  void didUpdateWidget(LocationMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelected != oldWidget.initialSelected) {
      _selectedItems.clear();
      _selectedItems.addAll(widget.initialSelected);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onSelectionChanged(_selectedItems.toList());
  }

  void _toggleItem(SelectedLocationItem item) {
    setState(() {
      if (!widget.allowMultiple) {
        _selectedItems.clear();
        _selectedItems.add(item);
      } else {
        if (_selectedItems.contains(item)) {
          _selectedItems.remove(item);
        } else {
          _selectedItems.add(item);
        }
      }
    });
    _notifyChange();
  }

  void _removeItem(SelectedLocationItem item) {
    setState(() {
      _selectedItems.remove(item);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final campusState = ref.watch(campusProvider);
    final facilitiesState = ref.watch(facilitiesProvider);

    final buildings = campusState.buildings;
    final floors = campusState.floors;
    final rooms = campusState.rooms;
    final facilities = facilitiesState.facilities;

    // Filter floors by selected building
    final filteredFloors = _selectedBuildingId != null
        ? floors.where((f) => f.buildingId == _selectedBuildingId).toList()
        : floors;

    // Filter rooms by building, floor, and search query
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredRooms = rooms.where((r) {
      if (_selectedBuildingId != null && r.buildingId != _selectedBuildingId) return false;
      if (_selectedFloorId != null && r.floorId != _selectedFloorId) return false;
      if (searchQuery.isNotEmpty) {
        final match = r.name.toLowerCase().contains(searchQuery) ||
            r.roomNumber.toLowerCase().contains(searchQuery) ||
            r.roomType.toLowerCase().contains(searchQuery);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Filter facilities by search query
    final filteredFacilities = facilities.where((f) {
      if (searchQuery.isNotEmpty) {
        final name = (f['name'] ?? '').toString().toLowerCase();
        final code = (f['code'] ?? '').toString().toLowerCase();
        final category = (f['category'] ?? '').toString().toLowerCase();
        if (!name.contains(searchQuery) && !code.contains(searchQuery) && !category.contains(searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source Tab Selector: Building & Rooms vs Campus Facilities
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _sourceTab = 0),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _sourceTab == 0
                        ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _sourceTab == 0 ? const Color(0xFF2563EB) : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                        color: _sourceTab == 0 ? const Color(0xFF2563EB) : textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Buildings & Rooms',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _sourceTab == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _sourceTab == 0 ? const Color(0xFF2563EB) : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _sourceTab = 1),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _sourceTab == 1
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _sourceTab == 1 ? const Color(0xFF8B5CF6) : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.park_outlined,
                        size: 16,
                        color: _sourceTab == 1 ? const Color(0xFF8B5CF6) : textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Campus Facilities',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _sourceTab == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _sourceTab == 1 ? const Color(0xFF8B5CF6) : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Search Bar with Select All / Clear All (if multiple)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 12, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: _sourceTab == 0 ? 'Search rooms by name, number, type...' : 'Search facilities...',
                    hintStyle: TextStyle(fontSize: 11.5, color: textMuted),
                    prefixIcon: Icon(Icons.search, size: 15, color: textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            if (widget.allowMultiple) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_sourceTab == 0) {
                      for (final r in filteredRooms) {
                        final b = buildings.where((x) => x.id == r.buildingId).firstOrNull;
                        final f = floors.where((x) => x.id == r.floorId).firstOrNull;
                        final display = '${b?.code ?? "B"}/${r.roomNumber.isNotEmpty ? r.roomNumber : r.name}';
                        _selectedItems.add(SelectedLocationItem(
                          buildingId: r.buildingId,
                          buildingName: b?.name,
                          floorId: r.floorId,
                          floorName: f?.name,
                          roomId: r.id,
                          roomName: r.name,
                          displayName: display,
                          locationType: 'room',
                        ));
                      }
                    } else {
                      for (final fac in filteredFacilities) {
                        final name = fac['name']?.toString() ?? 'Facility';
                        _selectedItems.add(SelectedLocationItem(
                          facilityId: fac['id']?.toString(),
                          facilityName: name,
                          displayName: name,
                          locationType: 'facility',
                        ));
                      }
                    }
                  });
                  _notifyChange();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Select All', style: TextStyle(fontSize: 11)),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedItems.clear());
                  _notifyChange();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red[400])),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Cascading Dropdowns for Building & Rooms
        if (_sourceTab == 0) ...[
          Row(
            children: [
              Expanded(
                child: AppSearchableDropdownFormField<String>.fromMenuItems(
                  key: ValueKey('bld_$_selectedBuildingId'),
                  initialValue: _selectedBuildingId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Building',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Buildings', style: TextStyle(fontSize: 11.5))),
                    ...buildings.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            '${b.code} - ${b.name}',
                            style: const TextStyle(fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedBuildingId = val;
                      _selectedFloorId = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppSearchableDropdownFormField<String>.fromMenuItems(
                  key: ValueKey('flr_${_selectedBuildingId}_$_selectedFloorId'),
                  initialValue: _selectedFloorId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Floor',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Floors', style: TextStyle(fontSize: 11.5))),
                    ...filteredFloors.map((f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(
                            f.name,
                            style: const TextStyle(fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedFloorId = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // List / Multi-select area
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Material(
            color: cardBg,
            borderRadius: BorderRadius.circular(6),
            child: _sourceTab == 0
                ? filteredRooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            rooms.isEmpty ? 'No rooms loaded. Check Buildings tab.' : 'No rooms match your filter.',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredRooms.length,
                        itemBuilder: (context, idx) {
                          final r = filteredRooms[idx];
                          final b = buildings.where((x) => x.id == r.buildingId).firstOrNull;
                          final f = floors.where((x) => x.id == r.floorId).firstOrNull;
                          final display = '${b?.code ?? "B"}/${r.roomNumber.isNotEmpty ? r.roomNumber : r.name}';
                          final item = SelectedLocationItem(
                            buildingId: r.buildingId,
                            buildingName: b?.name,
                            floorId: r.floorId,
                            floorName: f?.name,
                            roomId: r.id,
                            roomName: r.name,
                            displayName: display,
                            locationType: 'room',
                          );
                          final isSelected = _selectedItems.contains(item);

                          return Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleItem(item),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                '$display (${r.roomType})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Cap: ${r.maxCapacity > 0 ? r.maxCapacity : r.seatingCapacity} seats • Status: ${r.operationalStatus}',
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        },
                      )
                : filteredFacilities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            facilities.isEmpty ? 'No campus facilities registered.' : 'No facilities match filter.',
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredFacilities.length,
                        itemBuilder: (context, idx) {
                          final fac = filteredFacilities[idx];
                          final name = fac['name']?.toString() ?? 'Facility';
                          final cat = fac['category']?.toString() ?? 'General';
                          final item = SelectedLocationItem(
                            facilityId: fac['id']?.toString(),
                            facilityName: name,
                            displayName: name,
                            locationType: 'facility',
                          );
                          final isSelected = _selectedItems.contains(item);

                          return Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggleItem(item),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '$cat • Cap: ${fac['capacity'] ?? "N/A"}',
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        },
                      ),
          ),
        ),

        // Selected Locations Chips Bar
        if (_selectedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Target Location(s): ${_selectedItems.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      ),
                    ),
                    if (widget.allowMultiple && _selectedItems.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Bulk Generation Mode',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _selectedItems.map((it) {
                    final isFacility = it.locationType == 'facility';
                    return Chip(
                      label: Text(it.displayName, style: const TextStyle(fontSize: 10.5)),
                      avatar: Icon(
                        isFacility ? Icons.park_outlined : Icons.meeting_room_outlined,
                        size: 13,
                        color: isFacility ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 12),
                      onDeleted: () => _removeItem(it),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
