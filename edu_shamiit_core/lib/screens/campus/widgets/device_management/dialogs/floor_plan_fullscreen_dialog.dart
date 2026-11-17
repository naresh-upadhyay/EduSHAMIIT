import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class FloorPlanFullScreenDialog extends StatefulWidget {
  final FloorPlanAssetModel? floorPlan;
  final List<FloorPlanMarkerModel> markers;
  final FloorPlanLegendModel legend;
  final String title;

  const FloorPlanFullScreenDialog({
    super.key,
    this.floorPlan,
    required this.markers,
    required this.legend,
    this.title = 'Academic Block (A) – First Floor Architectural Plan',
  });

  @override
  State<FloorPlanFullScreenDialog> createState() => _FloorPlanFullScreenDialogState();
}

class _FloorPlanFullScreenDialogState extends State<FloorPlanFullScreenDialog> {
  final TransformationController _transformationController = TransformationController();
  String _activeCategoryFilter = 'All';
  FloorPlanMarkerModel? _selectedMarker;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(1.2, 1.2, 1.0, 1.0);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _transformationController.value = matrix;
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredMarkers = widget.markers.where((m) {
      if (_activeCategoryFilter == 'All') return true;
      final typeLower = m.deviceType.toLowerCase();
      final filterLower = _activeCategoryFilter.toLowerCase();
      if (filterLower == 'cctv') return typeLower.contains('cctv') || typeLower.contains('cam');
      if (filterLower == 'lighting') return typeLower.contains('light');
      if (filterLower == 'hvac') return typeLower.contains('hvac') || typeLower.contains('ac');
      if (filterLower == 'projector') return typeLower.contains('proj') || typeLower.contains('disp');
      if (filterLower == 'access point') return typeLower.contains('access') || typeLower.contains('wifi') || typeLower.contains('point');
      if (filterLower == 'audio') return typeLower.contains('audio') || typeLower.contains('speaker');
      if (filterLower == 'fan') return typeLower.contains('fan');
      return typeLower.contains(filterLower);
    }).toList();

    // 100% dynamic counts synchronized with actual markers on this floor
    final cctvCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('cctv')).length;
    final lightingCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('light')).length;
    final hvacCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('hvac') || m.deviceType.toLowerCase().contains('ac')).length;
    final projectorCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('proj')).length;
    final apCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('access') || m.deviceType.toLowerCase().contains('wifi') || m.deviceType.toLowerCase().contains('point')).length;
    final audioCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('audio') || m.deviceType.toLowerCase().contains('speaker')).length;
    final fanCount = widget.markers.where((m) => m.deviceType.toLowerCase().contains('fan')).length;

    final screenSize = MediaQuery.of(context).size;
    final dialogW = (screenSize.width * 0.95).clamp(320.0, 1600.0);
    final dialogH = (screenSize.height * 0.92).clamp(420.0, 1000.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Top Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.architecture_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Interactive 2D Spatial Blueprint & Real-time IoT Node Overlay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Category Filters in horizontal scroll
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'CCTV', 'Lighting', 'HVAC', 'Projector', 'Access Point', 'Audio', 'Fan'].map((cat) {
                            final isSelected = _activeCategoryFilter == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                selected: isSelected,
                                selectedColor: const Color(0xFF2563EB),
                                labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                onSelected: (val) {
                                  if (val) setState(() => _activeCategoryFilter = cat);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Controls
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'Zoom In',
                      onPressed: _zoomIn,
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      tooltip: 'Zoom Out',
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_rounded, size: 20),
                      tooltip: 'Fit to Screen',
                      onPressed: _resetZoom,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

            // Canvas Area
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(100),
                    child: Center(
                      child: Container(
                        width: 1100,
                        height: 650,
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // 1. Rooms Grid & Layout
                            ..._buildRoomsLayout(isDark, 1100, 650),

                            // 2. Plotted Device Markers
                            ...filteredMarkers.map((marker) => _buildDeviceMarker(marker, isDark, 1100, 650)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Selected Device Details Card Overlay
                  if (_selectedMarker != null)
                    Positioned(
                      left: 24,
                      bottom: 24,
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_getIconForType(_selectedMarker!.deviceType), color: const Color(0xFF2563EB), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedMarker!.deviceName,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        _selectedMarker!.deviceCode,
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _selectedMarker = null),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Type:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_selectedMarker!.deviceType, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Status:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Row(
                                  children: [
                                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Legend Box
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.markers.length} Total',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildLegendRow(Icons.videocam_outlined, 'CCTV', cctvCount, const Color(0xFFDC2626)),
                          _buildLegendRow(Icons.lightbulb_outline_rounded, 'Lighting', lightingCount, const Color(0xFFEAB308)),
                          _buildLegendRow(Icons.ac_unit_rounded, 'HVAC', hvacCount, const Color(0xFF0EA5E9)),
                          _buildLegendRow(Icons.tv_rounded, 'Projector', projectorCount, const Color(0xFF8B5CF6)),
                          _buildLegendRow(Icons.wifi_rounded, 'Access Point', apCount, const Color(0xFF2563EB)),
                          _buildLegendRow(Icons.volume_up_rounded, 'Audio', audioCount, const Color(0xFF10B981)),
                          _buildLegendRow(Icons.mode_fan_off_rounded, 'Fan', fanCount, const Color(0xFF14B8A6)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildLegendRow(IconData icon, String category, int count, Color color) {
    final isSelected = _activeCategoryFilter.toLowerCase() == category.toLowerCase();
    return InkWell(
      onTap: () {
        setState(() {
          _activeCategoryFilter = isSelected ? 'All' : category;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        margin: const EdgeInsets.symmetric(vertical: 1.5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: color, width: 1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$category ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoomsLayout(bool isDark, double w, double h) {
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final roomBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFF8FAFC);
    final corrBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
    final rooms = widget.floorPlan?.roomsLayout ?? [];

    Widget makeRoom(String code, String name, double left, double top, double width, double height, int devCount, {bool isCorridor = false}) {
      return Positioned(
        left: left * w,
        top: top * h,
        width: width * w,
        height: height * h,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCorridor ? corrBg : roomBg,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: isCorridor ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisAlignment: isCorridor ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: isCorridor ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: isCorridor ? 12 : 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  if (!isCorridor && devCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$devCount dev',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                ],
              ),
              if (!isCorridor && name.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (rooms.isNotEmpty) {
      return rooms.map((rm) {
        final isCorridor = rm.roomId.toLowerCase() == 'corridor' || rm.code.toLowerCase() == 'corridor';
        final devCount = widget.markers.where((m) => m.roomId == rm.roomId || (rm.code.isNotEmpty && m.roomNumber == rm.code)).length;
        return makeRoom(rm.code, rm.name, rm.x, rm.y, rm.w, rm.h, devCount, isCorridor: isCorridor);
      }).toList();
    }

    return [
      makeRoom('101', 'Classroom', 0.04, 0.08, 0.21, 0.36, 4),
      makeRoom('102', 'Classroom', 0.27, 0.08, 0.21, 0.36, 2),
      makeRoom('103', 'Classroom', 0.50, 0.08, 0.21, 0.36, 2),
      makeRoom('104', 'Classroom', 0.73, 0.08, 0.23, 0.36, 0),
      makeRoom('Corridor', '', 0.04, 0.46, 0.92, 0.10, 1, isCorridor: true),
      makeRoom('105', 'Lab', 0.04, 0.58, 0.29, 0.36, 0),
      makeRoom('106', 'Lab', 0.35, 0.58, 0.29, 0.36, 0),
      makeRoom('107', 'Smart Class', 0.66, 0.58, 0.30, 0.36, 0),
    ];
  }

  Widget _buildDeviceMarker(FloorPlanMarkerModel marker, bool isDark, double w, double h) {
    Color markerColor = const Color(0xFF2563EB);
    final typeLower = marker.deviceType.toLowerCase();
    if (typeLower.contains('cctv')) {
      markerColor = const Color(0xFFDC2626);
    } else if (typeLower.contains('light')) {
      markerColor = const Color(0xFFEAB308);
    } else if (typeLower.contains('hvac') || typeLower.contains('ac')) {
      markerColor = const Color(0xFF0EA5E9);
    } else if (typeLower.contains('proj')) {
      markerColor = const Color(0xFF8B5CF6);
    } else if (typeLower.contains('audio') || typeLower.contains('speaker')) {
      markerColor = const Color(0xFF10B981);
    } else if (typeLower.contains('fan')) {
      markerColor = const Color(0xFF14B8A6);
    }

    // Clamped inside canvas bounds
    final left = (marker.posX * w - 16).clamp(10.0, w - 160.0);
    final top = (marker.posY * h - 16).clamp(10.0, h - 40.0);

    final isSelected = _selectedMarker?.id == marker.id;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => setState(() => _selectedMarker = marker),
        child: Tooltip(
          message: '${marker.deviceCode} (${marker.deviceType})\nRoom: ${marker.roomNumber ?? 'Corridor'}\nStatus: ${marker.isOnline ? 'Online' : 'Offline'}',
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? markerColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(color: markerColor, width: 2),
              boxShadow: [
                BoxShadow(color: markerColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(
              _getIconForType(marker.deviceType),
              size: 15,
              color: isSelected ? Colors.white : markerColor,
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cctv')) return Icons.videocam_outlined;
    if (t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('hvac') || t.contains('ac')) return Icons.ac_unit_rounded;
    if (t.contains('proj')) return Icons.tv_rounded;
    if (t.contains('access_point') || t.contains('point') || t.contains('wifi')) return Icons.wifi_rounded;
    if (t.contains('speaker') || t.contains('audio')) return Icons.volume_up_rounded;
    if (t.contains('fan')) return Icons.mode_fan_off_rounded;
    return Icons.devices_other_rounded;
  }
}
