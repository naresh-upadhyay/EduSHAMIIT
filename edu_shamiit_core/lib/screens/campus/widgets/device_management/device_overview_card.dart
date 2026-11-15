import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceOverviewCard extends StatelessWidget {
  final List<BuildingDeviceBreakdown> buildings;
  final String selectedCampusBuilding;
  final ValueChanged<String> onBuildingChanged;

  const DeviceOverviewCard({
    super.key,
    required this.buildings,
    required this.selectedCampusBuilding,
    required this.onBuildingChanged,
  });

  void _showFullscreenCampusMap(BuildContext context, bool isDark, List<_BadgePos> badges) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 900,
          height: 600,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Campus Device Overview & Building Topology',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _CampusMapPainter(isDark: isDark)),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                            ),
                            child: const Text(
                              'Greenwood High School - Central Campus',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        ...badges.map((b) => Positioned(
                          top: constraints.maxHeight * b.top,
                          left: constraints.maxWidth * b.left,
                          child: _buildBuildingBadge(b, isDark),
                        )),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Total Buildings: ${badges.length}  •  Click any building badge to focus view',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        onBuildingChanged('Entire Campus');
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset to Entire Campus'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const defaultCoords = [
      Offset(0.12, 0.40),
      Offset(0.32, 0.10),
      Offset(0.52, 0.10),
      Offset(0.76, 0.15),
      Offset(0.28, 0.62),
      Offset(0.74, 0.65),
    ];

    final List<_BadgePos> buildingBadges = [];
    if (buildings.isNotEmpty) {
      for (int i = 0; i < buildings.length; i++) {
        final b = buildings[i];
        final coord = i < defaultCoords.length
            ? defaultCoords[i]
            : Offset(0.10 + (i % 3) * 0.30, 0.20 + (i ~/ 3) * 0.25);
        buildingBadges.add(
          _BadgePos(
            code: b.code.isNotEmpty ? b.code : 'B${i + 1}',
            name: b.name,
            count: b.totalDevices,
            pct: b.onlinePct,
            top: coord.dy,
            left: coord.dx,
          ),
        );
      }
    } else {
      buildingBadges.addAll(const [
        _BadgePos(code: 'B1', name: 'Academic Block', count: 1874, pct: 95.2, top: 0.40, left: 0.12),
        _BadgePos(code: 'B2', name: 'Science Block', count: 1246, pct: 95.8, top: 0.10, left: 0.32),
        _BadgePos(code: 'B3', name: 'Admin Block', count: 1112, pct: 96.1, top: 0.10, left: 0.52),
        _BadgePos(code: 'B4', name: 'Library Block', count: 982, pct: 94.6, top: 0.15, left: 0.76),
        _BadgePos(code: 'B5', name: 'Hostel Block', count: 1320, pct: 94.7, top: 0.62, left: 0.28),
        _BadgePos(code: 'B6', name: 'Sports Complex', count: 1208, pct: 95.9, top: 0.65, left: 0.74),
      ]);
    }

    final dropdownOptions = <String, String>{'Entire Campus': 'Entire Campus'};
    if (buildings.isNotEmpty) {
      for (final b in buildings) {
        final code = b.code.isNotEmpty ? b.code : b.name;
        dropdownOptions[code] = '${b.code.isNotEmpty ? "${b.code} - " : ""}${b.name}';
      }
    } else {
      dropdownOptions['B1'] = 'B1 - Academic Block';
      dropdownOptions['B2'] = 'B2 - Science Block';
      dropdownOptions['B3'] = 'B3 - Admin Block';
      dropdownOptions['B4'] = 'B4 - Library Block';
      dropdownOptions['B5'] = 'B5 - Hostel Block';
      dropdownOptions['B6'] = 'B6 - Sports Complex';
    }

    final effectiveSelectedBuilding = dropdownOptions.containsKey(selectedCampusBuilding)
        ? selectedCampusBuilding
        : 'Entire Campus';

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Campus Device Overview (Live)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Entire Campus Dropdown
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveSelectedBuilding,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        items: dropdownOptions.entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) onBuildingChanged(val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Live Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showFullscreenCampusMap(context, isDark, buildingBadges),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(
                        Icons.fullscreen_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Isometric Campus Visual Illustration with Floating Badges
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Campus Graphic / Background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CampusMapPainter(isDark: isDark),
                        ),
                      ),

                      // Center Greenwood High School Grass Courtyard Emblem
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                            ],
                          ),
                          child: const Text(
                            'Greenwood High School',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),

                      // Building Badges matching Screenshot layout
                      ...buildingBadges.map((b) {
                        return Positioned(
                          top: constraints.maxHeight * b.top,
                          left: constraints.maxWidth * b.left,
                          child: _buildBuildingBadge(b, isDark),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingBadge(_BadgePos b, bool isDark) {
    final isSelected = selectedCampusBuilding == b.code;

    return InkWell(
      onTap: () => onBuildingChanged(isSelected ? 'Entire Campus' : b.code),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE))
              : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF2563EB).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.12),
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              b.code,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
              ),
            ),
            Text(
              '${b.count.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Devices',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              '(${b.pct}% Online)',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePos {
  final String code;
  final String name;
  final int count;
  final double pct;
  final double top;
  final double left;

  const _BadgePos({
    required this.code,
    required this.name,
    required this.count,
    required this.pct,
    required this.top,
    required this.left,
  });
}

class _CampusMapPainter extends CustomPainter {
  final bool isDark;
  _CampusMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Green campus turf & lawns
    final lawnPaint = Paint()..color = isDark ? const Color(0xFF14532D).withValues(alpha: 0.5) : const Color(0xFF86EFAC).withValues(alpha: 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.15, size.height * 0.2, size.width * 0.7, size.height * 0.6), const Radius.circular(20)),
      lawnPaint,
    );

    // Campus pathways
    final pathPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), pathPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), pathPaint);

    // Building isometric 3D block approximations
    final buildingPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final blocks = [
      Rect.fromLTWH(size.width * 0.1, size.height * 0.35, size.width * 0.18, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.30, size.height * 0.08, size.width * 0.18, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.08, size.width * 0.18, size.height * 0.18),
      Rect.fromLTWH(size.width * 0.74, size.height * 0.12, size.width * 0.18, size.height * 0.20),
      Rect.fromLTWH(size.width * 0.25, size.height * 0.60, size.width * 0.20, size.height * 0.22),
      Rect.fromLTWH(size.width * 0.70, size.height * 0.62, size.width * 0.20, size.height * 0.22),
    ];

    for (var b in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(8)), buildingPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(b, const Radius.circular(8)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
