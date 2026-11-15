import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';

class RoomDetailsDrawer extends StatefulWidget {
  final RoomModel room;
  final BuildingModel building;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onManageEquipment;
  final VoidCallback onAllocate;

  const RoomDetailsDrawer({
    super.key,
    required this.room,
    required this.building,
    required this.onClose,
    required this.onEdit,
    required this.onManageEquipment,
    required this.onAllocate,
  });

  @override
  State<RoomDetailsDrawer> createState() => _RoomDetailsDrawerState();
}

class _RoomDetailsDrawerState extends State<RoomDetailsDrawer> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final res = await CampusApiService.instance.getRoomDetails(widget.room.id);
    if (mounted) {
      setState(() {
        _details = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.room;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(440.0, screenWidth * 0.95);

    return Container(
      width: drawerWidth,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${r.roomNumber} - ${r.name}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onClose),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Campus / ${widget.building.name} / ${r.floorName ?? 'Floor'} / Room ${r.roomNumber}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Drawer Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status & Type Chips (Wrap to prevent overflow on mobile)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(r.roomType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(r.operationalStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(r.assignmentStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 1: Dimensions & Capacity
                        const Text('Capacity & Space Specifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        const SizedBox(height: 8),
                        _buildRow('Floor Area', '${r.area} ${r.areaUnit}', isDark),
                        _buildRow('Dimensions', '${r.length} ft × ${r.width} ft', isDark),
                        _buildRow('Max Capacity', '${r.maxCapacity} Persons', isDark),
                        _buildRow('Current Occupancy', '${r.currentOccupancy} (${r.maxCapacity > 0 ? ((r.currentOccupancy / r.maxCapacity) * 100).toStringAsFixed(1) : 0}%)', isDark),
                        _buildRow('Recommended Capacity', '${r.recommendedCapacity}', isDark),
                        if (r.seatingCapacity > 0) _buildRow('Seating Capacity', '${r.seatingCapacity} Chairs', isDark),
                        if (r.bedCount > 0) _buildRow('Beds Available', '${r.bedCount} Beds', isDark),
                        if (r.workstationCount > 0) _buildRow('Workstations', '${r.workstationCount} Desktops', isDark),
                        const SizedBox(height: 16),

                        // Section 2: Equipment in Room
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Equipment & Fixtures', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            TextButton.icon(
                              onPressed: widget.onManageEquipment,
                              icon: const Icon(Icons.tune, size: 13),
                              label: const Text('Manage', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_details?['equipment'] != null && (_details!['equipment'] as List).isNotEmpty)
                          ...(_details!['equipment'] as List).map((eq) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${eq['equipment_name']} (Qty: ${eq['quantity']})',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      eq['operational_status'] ?? 'Operational',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: eq['operational_status'] == 'Operational' ? const Color(0xFF059669) : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'No equipment configured for this room.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Section 3: Responsible Personnel & Department
                        const Text('Responsible Personnel & Department', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                        const SizedBox(height: 8),
                        _buildRow('Department', r.responsibleDepartment ?? 'Unassigned', isDark),
                        _buildRow('Room Incharge', r.responsiblePersonName ?? 'Unassigned', isDark),
                        _buildRow('Lift Access', r.liftProximity, isDark),
                        _buildRow('Emergency Exit', r.emergencyExitProximity, isDark),
                        _buildRow('Accessibility', r.isDifferentlyAbledAccessible ? 'Yes (Wheelchair Accessible)' : 'Standard Access', isDark),
                      ],
                    ),
                  ),
          ),

          // Drawer Footer Actions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onAllocate,
                    icon: const Icon(Icons.group_outlined, size: 15),
                    label: const Text('Allocate', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 15, color: Colors.white),
                    label: const Text('Edit Room', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}
