import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceLocationExplorerCard extends StatefulWidget {
  final LocationTreeNode? tree;
  final String? selectedNodeId;
  final String? selectedBreadcrumb;
  final Function(
    String? buildingId,
    String? floorId,
    String? roomId,
    String? nodeId,
    String? breadcrumb,
  ) onLocationSelected;
  final VoidCallback? onClearLocation;

  const DeviceLocationExplorerCard({
    super.key,
    required this.tree,
    this.selectedNodeId,
    this.selectedBreadcrumb,
    required this.onLocationSelected,
    this.onClearLocation,
  });

  @override
  State<DeviceLocationExplorerCard> createState() => _DeviceLocationExplorerCardState();
}

class _DeviceLocationExplorerCardState extends State<DeviceLocationExplorerCard> {
  String _searchQuery = '';
  final Set<String> _expandedNodeIds = {'entire_campus', 'B1', 'GF', '1F'};

  @override
  void didUpdateWidget(covariant DeviceLocationExplorerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNodeId != null && widget.selectedNodeId != oldWidget.selectedNodeId) {
      _expandedNodeIds.add(widget.selectedNodeId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter = widget.selectedNodeId != null &&
        widget.selectedNodeId != 'entire_campus' &&
        widget.selectedNodeId != 'All' &&
        widget.selectedNodeId!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.account_tree_outlined, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location Explorer',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasActiveFilter && widget.onClearLocation != null)
                  InkWell(
                    onTap: widget.onClearLocation,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Active Location Filter Banner (if selected)
          if (hasActiveFilter)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 13, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.selectedBreadcrumb ?? widget.selectedNodeId ?? 'Filtered',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onClearLocation != null)
                    InkWell(
                      onTap: widget.onClearLocation,
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF2563EB)),
                    ),
                ],
              ),
            ),

          // Search Box
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              height: 32,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search building, floor, room...',
                  hintStyle: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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

          // Hierarchical Tree View
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.tree != null && widget.tree!.children.isNotEmpty) ...[
                    if (_searchQuery.isNotEmpty &&
                        !widget.tree!.name.toLowerCase().contains(_searchQuery) &&
                        !_hasMatchingChild(widget.tree!, _searchQuery))
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No matching locations found',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      _buildDynamicTreeNode(
                        node: widget.tree!,
                        level: 0,
                        isDark: isDark,
                        parentBuildingId: null,
                        parentBuildingName: null,
                        parentFloorId: null,
                        parentFloorName: null,
                      ),
                  ] else
                    _buildEntireCampusFallback(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTreeNode({
    required LocationTreeNode node,
    required int level,
    required bool isDark,
    String? parentBuildingId,
    String? parentBuildingName,
    String? parentFloorId,
    String? parentFloorName,
  }) {
    if (_searchQuery.isNotEmpty && !node.name.toLowerCase().contains(_searchQuery)) {
      final hasMatching = _hasMatchingChild(node, _searchQuery);
      if (!hasMatching) return const SizedBox.shrink();
    }

    final nodeId = node.id.isNotEmpty ? node.id : (node.code.isNotEmpty ? node.code : 'root');
    final isExpanded = _expandedNodeIds.contains(nodeId) || _searchQuery.isNotEmpty || level == 0;
    
    // Check if currently selected
    final activeSel = widget.selectedNodeId;
    final isSelected = activeSel != null && (
      activeSel == nodeId ||
      (node.code.isNotEmpty && activeSel == node.code) ||
      (level == 0 && (activeSel == 'entire_campus' || activeSel == 'All'))
    );

    IconData icon;
    if (level == 0) {
      icon = Icons.domain_rounded;
    } else if (level == 1) {
      icon = Icons.apartment_rounded;
    } else if (level == 2) {
      icon = Icons.layers_outlined;
    } else {
      icon = Icons.meeting_room_outlined;
    }

    final title = '${node.name}${node.deviceCount > 0 ? " (${node.deviceCount})" : ""}';

    // Track ancestry for child nodes
    final currentBldId = level == 1 ? (node.id.isNotEmpty ? node.id : node.code) : parentBuildingId;
    final currentBldName = level == 1 ? node.name : parentBuildingName;
    final currentFloorId = level == 2 ? (node.id.isNotEmpty ? node.id : node.code) : parentFloorId;
    final currentFloorName = level == 2 ? node.name : parentFloorName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: title,
          icon: icon,
          isExpanded: isExpanded,
          isSelected: isSelected,
          level: level,
          onTap: () {
            setState(() {
              if (_expandedNodeIds.contains(nodeId)) {
                _expandedNodeIds.remove(nodeId);
              } else {
                _expandedNodeIds.add(nodeId);
              }
            });

            if (level == 0) {
              widget.onLocationSelected(null, null, null, 'entire_campus', 'Entire Campus');
            } else if (level == 1) {
              final bldVal = node.id.isNotEmpty ? node.id : node.code;
              widget.onLocationSelected(bldVal, null, null, nodeId, node.name);
            } else if (level == 2) {
              final flVal = node.id.isNotEmpty ? node.id : node.code;
              final crumb = currentBldName != null ? '$currentBldName > ${node.name}' : node.name;
              widget.onLocationSelected(currentBldId, flVal, null, nodeId, crumb);
            } else {
              final rmVal = node.id.isNotEmpty ? node.id : node.code;
              final crumb = (currentBldName != null && currentFloorName != null)
                  ? '$currentBldName > $currentFloorName > ${node.name}'
                  : node.name;
              widget.onLocationSelected(currentBldId, currentFloorId, rmVal, nodeId, crumb);
            }
          },
        ),
        if (isExpanded && node.children.isNotEmpty)
          ...node.children.map((child) => _buildDynamicTreeNode(
                node: child,
                level: level + 1,
                isDark: isDark,
                parentBuildingId: currentBldId,
                parentBuildingName: currentBldName,
                parentFloorId: currentFloorId,
                parentFloorName: currentFloorName,
              )),
      ],
    );
  }

  bool _hasMatchingChild(LocationTreeNode node, String query) {
    for (final child in node.children) {
      if (child.name.toLowerCase().contains(query)) return true;
      if (_hasMatchingChild(child, query)) return true;
    }
    return false;
  }

  Widget _buildEntireCampusFallback(bool isDark) {
    final activeSel = widget.selectedNodeId;
    final isCampusSelected = activeSel == null || activeSel == 'entire_campus' || activeSel == 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: 'Entire Campus (221)',
          icon: Icons.domain_rounded,
          isExpanded: true,
          isSelected: isCampusSelected,
          level: 0,
          onTap: () {
            widget.onLocationSelected(null, null, null, 'entire_campus', 'Entire Campus');
          },
        ),

        // Buildings (B1 to B6)
        _buildBuildingNode('B1', 'B1 - Academic Block (A)', 217, true, isDark, [
          _buildFloorNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor (37)', true, isDark, [
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'CR-1', 'Room CR-1 (Conference Room)', 6, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'CL-1', 'Room CL-1 (Computer Lab - 1)', 6, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'G001', 'Room G001 (Reception)', 6, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'G002', 'Room G002 (Grade 1 - Section A)', 6, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'G003', 'Room G003 (Grade 1 - Section B)', 5, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'G004', 'Room G004 (Grade 1 - Section C)', 4, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', 'GF', 'Ground Floor', 'G005', 'Room G005 (Grade 1 - Section D)', 4, isDark),
          ]),
          _buildFloorNode('B1', 'Academic Block (A)', '1F', 'First Floor (29)', false, isDark, [
            _buildRoomNode('B1', 'Academic Block (A)', '1F', 'First Floor', 'A1-101', 'Room A1-101 (Classroom)', 7, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', '1F', 'First Floor', 'A1-102', 'Room A1-102 (Classroom)', 6, isDark),
            _buildRoomNode('B1', 'Academic Block (A)', '1F', 'First Floor', 'A1-103', 'Room A1-103 (Classroom)', 8, isDark),
          ]),
          _buildFloorNode('B1', 'Academic Block (A)', '2F', 'Second Floor (12)', false, isDark, []),
          _buildFloorNode('B1', 'Academic Block (A)', 'F3', 'Third Floor (F3) (3)', false, isDark, []),
          _buildFloorNode('B1', 'Academic Block (A)', 'F4', 'Fourth Floor (F4) (2)', false, isDark, []),
        ]),
        _buildBuildingNode('B2', 'B2 - Science Block', 1, false, isDark, []),
        _buildBuildingNode('B3', 'B3 - Admin Block', 1, false, isDark, []),
        _buildBuildingNode('B4', 'B4 - Library Block', 1, false, isDark, []),
        _buildBuildingNode('B5', 'B5 - Hostel Block', 0, false, isDark, []),
        _buildBuildingNode('B6', 'B6 - Sports Complex', 1, false, isDark, []),
      ],
    );
  }

  Widget _buildBuildingNode(
    String bldCode,
    String title,
    int count,
    bool isDefaultExpanded,
    bool isDark,
    List<Widget> children,
  ) {
    if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedNodeIds.contains(bldCode) || _searchQuery.isNotEmpty || isDefaultExpanded;
    final isSelected = widget.selectedNodeId == bldCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: '$title ($count)',
          icon: Icons.apartment_rounded,
          isExpanded: isExpanded,
          isSelected: isSelected,
          level: 1,
          onTap: () {
            setState(() {
              if (_expandedNodeIds.contains(bldCode)) {
                _expandedNodeIds.remove(bldCode);
              } else {
                _expandedNodeIds.add(bldCode);
              }
            });
            widget.onLocationSelected(bldCode, null, null, bldCode, title);
          },
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildFloorNode(
    String bldCode,
    String bldName,
    String floorCode,
    String title,
    bool isDefaultExpanded,
    bool isDark,
    List<Widget> children,
  ) {
    final isExpanded = _expandedNodeIds.contains(floorCode) || _searchQuery.isNotEmpty || isDefaultExpanded;
    final isSelected = widget.selectedNodeId == floorCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: title,
          icon: Icons.layers_outlined,
          isExpanded: isExpanded,
          isSelected: isSelected,
          level: 2,
          onTap: () {
            setState(() {
              if (_expandedNodeIds.contains(floorCode)) {
                _expandedNodeIds.remove(floorCode);
              } else {
                _expandedNodeIds.add(floorCode);
              }
            });
            widget.onLocationSelected(bldCode, floorCode, null, floorCode, '$bldName > $title');
          },
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildRoomNode(
    String bldCode,
    String bldName,
    String floorCode,
    String floorName,
    String roomNumber,
    String title,
    int count,
    bool isDark,
  ) {
    final isSelected = widget.selectedNodeId == roomNumber;

    return _buildTreeItem(
      title: '$title ($count devices)',
      icon: Icons.meeting_room_outlined,
      isExpanded: false,
      isSelected: isSelected,
      level: 3,
      onTap: () {
        widget.onLocationSelected(
          bldCode,
          floorCode,
          roomNumber,
          roomNumber,
          '$bldName > $floorName > $title',
        );
      },
    );
  }

  Widget _buildTreeItem({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required bool isSelected,
    required int level,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: EdgeInsets.only(left: 8.0 + (level * 14.0), right: 8, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: const Color(0xFF2563EB), width: 1.2)
              : null,
        ),
        child: Row(
          children: [
            if (level < 3)
              Icon(
                isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
