import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/campus_models.dart';
import '../../models/space_booking_models.dart';
import '../../providers/campus_provider.dart';
import '../../providers/space_booking_provider.dart';
import '../../services/campus_api_service.dart';

class RoomDetailsDrawer extends ConsumerStatefulWidget {
  final RoomModel room;
  final BuildingModel building;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onManageEquipment;
  final VoidCallback onRaiseMaintenance;
  final VoidCallback? onBookSpace;

  const RoomDetailsDrawer({
    super.key,
    required this.room,
    required this.building,
    required this.onClose,
    required this.onEdit,
    required this.onManageEquipment,
    required this.onRaiseMaintenance,
    this.onBookSpace,
  });

  @override
  ConsumerState<RoomDetailsDrawer> createState() => _RoomDetailsDrawerState();
}

class _RoomDetailsDrawerState extends ConsumerState<RoomDetailsDrawer> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void didUpdateWidget(RoomDetailsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id ||
        oldWidget.room.name != widget.room.name ||
        oldWidget.room.maxCapacity != widget.room.maxCapacity ||
        oldWidget.room.currentOccupancy != widget.room.currentOccupancy ||
        oldWidget.room.operationalStatus != widget.room.operationalStatus) {
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await CampusApiService.instance.getRoomDetails(widget.room.id);
      if (mounted) {
        setState(() {
          _details = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
      case 'operational':
        return const Color(0xFF10B981);
      case 'occupied':
      case 'partially occupied':
        return const Color(0xFF3B82F6);
      case 'maintenance':
      case 'under maintenance':
        return const Color(0xFFF59E0B);
      case 'out of service':
      case 'inactive':
      case 'closed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'classroom':
        return const Color(0xFF2563EB);
      case 'computer lab':
      case 'laboratory':
        return const Color(0xFF8B5CF6);
      case 'auditorium':
        return const Color(0xFFD97706);
      case 'library':
        return const Color(0xFF059669);
      case 'staff room':
      case 'conference':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.room;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(480.0, screenWidth * 0.95);

    // Watch live campus maintenance state for this room
    final campusState = ref.watch(campusProvider);
    final roomMaintenance = campusState.buildingMaintenance
        .where((m) => m.roomId == r.id && m.status.toLowerCase() != 'completed' && m.status.toLowerCase() != 'cancelled')
        .toList();

    // Watch live space bookings for this room
    final spaceState = ref.watch(spaceBookingProvider);
    final timelineRoom = spaceState.roomsTimeline.cast<SpaceTimelineRoom?>().firstWhere(
      (tr) => tr?.roomId == r.id,
      orElse: () => null,
    );
    final todayBookings = timelineRoom?.bookings ?? [];

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final occupancyRate = r.maxCapacity > 0
        ? (r.currentOccupancy / r.maxCapacity).clamp(0.0, 1.0)
        : 0.0;
    final occupancyPct = (occupancyRate * 100).toStringAsFixed(1);

    Color occupancyColor = const Color(0xFF10B981);
    if (occupancyRate > 0.90) {
      occupancyColor = const Color(0xFFEF4444);
    } else if (occupancyRate > 0.75) {
      occupancyColor = const Color(0xFFF59E0B);
    }

    return Container(
      width: drawerWidth,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Premium Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        r.roomNumber,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF3B82F6)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: 'Refresh Room Data',
                      color: textSecondary,
                      onPressed: _fetchDetails,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: textSecondary,
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Campus • ${widget.building.name} • ${r.floorName ?? "Floor"} • Room ${r.roomNumber}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 2. Drawer Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. Status & Category Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: _getTypeColor(r.roomType).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getTypeColor(r.roomType).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.meeting_room_outlined, size: 12, color: _getTypeColor(r.roomType)),
                                  const SizedBox(width: 4),
                                  Text(
                                    r.roomType,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getTypeColor(r.roomType)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(r.operationalStatus).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _getStatusColor(r.operationalStatus).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(r.operationalStatus),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    r.operationalStatus,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getStatusColor(r.operationalStatus)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.class_outlined, size: 12, color: Color(0xFF0284C7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    r.assignmentStatus,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // B. Live Capacity & Occupancy Meter Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Capacity & Real-Time Occupancy',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: occupancyColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$occupancyPct% Full',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: occupancyColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: occupancyRate,
                                  minHeight: 8,
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Occupied: ${r.currentOccupancy} students',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Max Capacity: ${r.maxCapacity} seats',
                                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: cardBorder, height: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Seating Chairs',
                                      '${r.seatingCapacity > 0 ? r.seatingCapacity : r.maxCapacity}',
                                      Icons.chair_outlined,
                                      isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Recommended',
                                      '${r.recommendedCapacity}',
                                      Icons.recommend_outlined,
                                      isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricTile(
                                      'Floor Area',
                                      r.area > 0 ? '${r.area} ${r.areaUnit}' : '${r.length}x${r.width} ft',
                                      Icons.square_foot_outlined,
                                      isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // C. Active Space Bookings & Schedule Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Today's Space Schedule",
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (todayBookings.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${todayBookings.length} Slot(s)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (todayBookings.isNotEmpty) ...[
                                ...todayBookings.take(3).map((b) => Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b.title,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${b.startTime} - ${b.endTime} • ${b.organizerName}',
                                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              b.status,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ] else ...[
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Space Free & Available • No conflicts registered today',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // D. Maintenance & Health Status Card (with direct Raise Maintenance action)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: roomMaintenance.isNotEmpty
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                                  : cardBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    roomMaintenance.isNotEmpty ? Icons.warning_amber_rounded : Icons.health_and_safety_outlined,
                                    size: 16,
                                    color: roomMaintenance.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Maintenance & Health Status',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (roomMaintenance.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${roomMaintenance.length} Open Issue(s)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (roomMaintenance.isNotEmpty) ...[
                                ...roomMaintenance.map((m) => Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.build_outlined, size: 14, color: Color(0xFFF59E0B)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.title,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${m.requestType} • Priority: ${m.priority} • ${m.status}',
                                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ] else ...[
                                Row(
                                  children: [
                                    const Icon(Icons.verified_outlined, color: Color(0xFF10B981), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'All Systems Operational • No active tickets reported',
                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: widget.onRaiseMaintenance,
                                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                                  label: const Text(
                                    'Raise Maintenance Request',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // E. Equipment & Fixtures Section
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Equipment & Fixtures',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: widget.onManageEquipment,
                                    icon: const Icon(Icons.tune, size: 13),
                                    label: const Text('Manage', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_isLoading && _details == null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              else if (_details?['equipment'] != null && (_details!['equipment'] as List).isNotEmpty)
                                ...(_details!['equipment'] as List).map((eq) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${eq['equipment_name']} (Qty: ${eq['quantity']})',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: eq['operational_status'] == 'Operational'
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              eq['operational_status'] ?? 'Operational',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: eq['operational_status'] == 'Operational'
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFD97706),
                                              ),
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
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textSecondary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // F. Responsible Personnel & Safety Specifications
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Responsible Department & Access',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow('Department', r.responsibleDepartment ?? 'Unassigned', isDark),
                              _buildDetailRow('Room Incharge', r.responsiblePersonName ?? 'Unassigned', isDark),
                              _buildDetailRow('Lift Access', r.liftProximity, isDark),
                              _buildDetailRow('Emergency Exit', r.emergencyExitProximity, isDark),
                              _buildDetailRow('Accessibility', r.isDifferentlyAbledAccessible ? 'Yes (Wheelchair Accessible)' : 'Standard Access', isDark),
                              if (r.bedCount > 0) _buildDetailRow('Beds Count', '${r.bedCount} Beds', isDark),
                              if (r.workstationCount > 0) _buildDetailRow('Workstations', '${r.workstationCount} Desktops', isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // 3. Premium Drawer Footer Actions (Raise Maintenance + Edit Room)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(top: BorderSide(color: cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onRaiseMaintenance,
                    icon: const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFFD97706)),
                    label: const Text(
                      'Raise Maintenance',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                    label: const Text(
                      'Edit Room',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
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
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
