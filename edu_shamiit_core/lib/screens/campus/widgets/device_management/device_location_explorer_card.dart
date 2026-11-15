import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceLocationExplorerCard extends StatefulWidget {
  final LocationTreeNode? tree;
  final Function(String? buildingId, String? floorId, String? roomId) onLocationSelected;

  const DeviceLocationExplorerCard({
    super.key,
    required this.tree,
    required this.onLocationSelected,
  });

  @override
  State<DeviceLocationExplorerCard> createState() => _DeviceLocationExplorerCardState();
}

class _DeviceLocationExplorerCardState extends State<DeviceLocationExplorerCard> {
  String _searchQuery = '';
  String? _selectedNodeId = 'F1'; // Highlight First Floor by default as shown in screenshot
  final Set<String> _expandedNodeIds = {'entire_campus', 'B1', 'F1'};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

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
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
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
                      _buildDynamicTreeNode(widget.tree!, 0, isDark),
                  ] else
                    _buildEntireCampusNode(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTreeNode(LocationTreeNode node, int level, bool isDark) {
    if (_searchQuery.isNotEmpty && !node.name.toLowerCase().contains(_searchQuery)) {
      final hasMatching = _hasMatchingChild(node, _searchQuery);
      if (!hasMatching) return const SizedBox.shrink();
    }

    final nodeId = node.id.isNotEmpty ? node.id : (node.code.isNotEmpty ? node.code : 'root');
    final isExpanded = _expandedNodeIds.contains(nodeId) || _searchQuery.isNotEmpty || node.isExpanded || level == 0;
    final isSelected = _selectedNodeId == nodeId;

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
              _selectedNodeId = nodeId;
              if (_expandedNodeIds.contains(nodeId)) {
                _expandedNodeIds.remove(nodeId);
              } else {
                _expandedNodeIds.add(nodeId);
              }
            });
            if (level == 0) {
              widget.onLocationSelected(null, null, null);
            } else if (level == 1) {
              widget.onLocationSelected(node.id.isNotEmpty ? node.id : node.code, null, null);
            } else if (level == 2) {
              widget.onLocationSelected(null, node.id.isNotEmpty ? node.id : node.code, null);
            } else {
              widget.onLocationSelected(null, null, node.id.isNotEmpty ? node.id : node.code);
            }
          },
        ),
        if (isExpanded && node.children.isNotEmpty)
          ...node.children.map((child) => _buildDynamicTreeNode(child, level + 1, isDark)),
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

  Widget _buildEntireCampusNode(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: 'Entire Campus (8,742)',
          icon: Icons.domain_rounded,
          isExpanded: true,
          isSelected: _selectedNodeId == 'entire_campus',
          level: 0,
          onTap: () {
            setState(() => _selectedNodeId = 'entire_campus');
            widget.onLocationSelected(null, null, null);
          },
        ),

        // Buildings (B1 to B6)
        _buildBuildingNode('B1', 'B1 - Academic Block', 1874, true, isDark, [
          _buildFloorNode('G', 'Ground Floor (412)', false, isDark, []),
          _buildFloorNode('F1', 'First Floor (486)', true, isDark, [
            _buildRoomNode('101', 'Room 101 (Classroom)', 5, isDark),
            _buildRoomNode('102', 'Room 102 (Classroom)', 2, isDark),
            _buildRoomNode('103', 'Room 103 (Classroom)', 2, isDark),
          ]),
          _buildFloorNode('F2', 'Second Floor (492)', false, isDark, []),
        ]),
        _buildBuildingNode('B2', 'B2 - Science Block', 1246, false, isDark, []),
        _buildBuildingNode('B3', 'B3 - Admin Block', 1112, false, isDark, []),
        _buildBuildingNode('B4', 'B4 - Library Block', 982, false, isDark, []),
        _buildBuildingNode('B5', 'B5 - Hostel Block', 1320, false, isDark, []),
        _buildBuildingNode('B6', 'B6 - Sports Complex', 1208, false, isDark, []),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTreeItem(
          title: '$title ($count)',
          icon: Icons.apartment_rounded,
          isExpanded: isDefaultExpanded,
          isSelected: _selectedNodeId == bldCode,
          level: 1,
          onTap: () {
            setState(() => _selectedNodeId = bldCode);
            widget.onLocationSelected(bldCode, null, null);
          },
        ),
        if (isDefaultExpanded) ...children,
      ],
    );
  }

  Widget _buildFloorNode(
    String floorCode,
    String title,
    bool isExpanded,
    bool isDark,
    List<Widget> children,
  ) {
    final isSelected = _selectedNodeId == floorCode;

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
            setState(() => _selectedNodeId = floorCode);
            widget.onLocationSelected(null, floorCode, null);
          },
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildRoomNode(
    String roomNumber,
    String title,
    int count,
    bool isDark,
  ) {
    final isSelected = _selectedNodeId == roomNumber;

    return _buildTreeItem(
      title: '$title ($count devices)',
      icon: Icons.meeting_room_outlined,
      isExpanded: false,
      isSelected: isSelected,
      level: 3,
      onTap: () {
        setState(() => _selectedNodeId = roomNumber);
        widget.onLocationSelected(null, null, roomNumber);
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
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: const Color(0xFF2563EB), width: 1)
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
