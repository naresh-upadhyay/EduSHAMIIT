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
      return m.deviceType.toLowerCase() == _activeCategoryFilter.toLowerCase();
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.architecture_rounded, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Interactive 2D Spatial Blueprint & Real-time IoT Node Overlay',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),

                  // Category Filters
                  Wrap(
                    spacing: 6,
                    children: ['All', 'CCTV', 'Lighting', 'HVAC', 'Projector', 'Access Point', 'Audio'].map((cat) {
                      final isSelected = _activeCategoryFilter == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) setState(() => _activeCategoryFilter = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 16),

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
                  const SizedBox(width: 8),
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
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.92),
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
                          const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          _buildLegendRow(Icons.videocam_outlined, 'CCTV (${widget.legend.cctv})', const Color(0xFFDC2626)),
                          _buildLegendRow(Icons.lightbulb_outline_rounded, 'Lighting (${widget.legend.lighting})', const Color(0xFFEAB308)),
                          _buildLegendRow(Icons.ac_unit_rounded, 'HVAC (${widget.legend.hvac})', const Color(0xFF0EA5E9)),
                          _buildLegendRow(Icons.tv_rounded, 'Projector (${widget.legend.projector})', const Color(0xFF8B5CF6)),
                          _buildLegendRow(Icons.wifi_rounded, 'Access Point (${widget.legend.accessPoint})', const Color(0xFF2563EB)),
                          _buildLegendRow(Icons.volume_up_rounded, 'Audio (${widget.legend.audio})', const Color(0xFF10B981)),
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
    );
  }

  Widget _buildLegendRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _buildRoomsLayout(bool isDark, double w, double h) {
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final roomBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFF8FAFC);
    final corrBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);

    Widget makeRoom(String code, String name, double left, double top, double width, double height, {bool isCorridor = false}) {
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
          child: Align(
            alignment: isCorridor ? Alignment.center : Alignment.topLeft,
            child: Text(
              isCorridor ? code : '$code\n$name',
              style: TextStyle(
                fontSize: isCorridor ? 12 : 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      );
    }

    return [
      // Top Row Rooms
      makeRoom('A1-101', 'Classroom', 0.04, 0.08, 0.21, 0.36),
      makeRoom('A1-102', 'Classroom', 0.27, 0.08, 0.21, 0.36),
      makeRoom('A1-103', 'Classroom', 0.50, 0.08, 0.21, 0.36),
      makeRoom('A1-104', 'Classroom', 0.73, 0.08, 0.23, 0.36),

      // Middle Corridor
      makeRoom('Corridor', '', 0.04, 0.46, 0.92, 0.10, isCorridor: true),

      // Bottom Row Rooms
      makeRoom('A1-105', 'Lab', 0.04, 0.58, 0.29, 0.36),
      makeRoom('A1-106', 'Lab', 0.35, 0.58, 0.29, 0.36),
      makeRoom('A1-107', 'Smart Class', 0.66, 0.58, 0.30, 0.36),
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

    final left = marker.posX * w - 16;
    final top = marker.posY * h - 16;

    final isSelected = _selectedMarker?.id == marker.id;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => setState(() => _selectedMarker = marker),
        child: Tooltip(
          message: '${marker.deviceCode} (${marker.deviceType})',
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
